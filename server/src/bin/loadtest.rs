//! LonIsle 聊天服务器负载测试工具
//!
//! 模拟 N 个并发 WebSocket 连接，测量：
//! - 连接建立时间（P50/P95/P99）
//! - 消息往返延迟（发消息 → 收广播，P50/P95/P99）
//!
//! 用法：
//!   cargo run --release --bin loadtest -- --host 127.0.0.1 --port 8080 --connections 1000 --messages 10
//!
//! 注意：1000 连接需提高系统文件描述符上限（ulimit -n 10000）。

use std::time::Instant;

use clap::Parser;
use futures_util::{SinkExt, StreamExt};
use lonisle_core::device::{issue_device_cert, DeviceKeypair};
use lonisle_core::identity::MasterKeypair;
use lonisle_core::proto::{
    client_envelope::MsgType as ClientMsgType, server_envelope::MsgType as ServerMsgType,
    ClientEnvelope, Hello, Identity, SendMessage, ServerEnvelope,
};
use lonisle_core::signature::{hello_signing_payload, send_message_signing_payload};
use prost::Message as _;
use tokio_tungstenite::tungstenite::Message as WsMsg;

#[derive(Parser, Debug)]
#[command(name = "lonisle-loadtest", version, about = "LonIsle 聊天服务器负载测试")]
struct Args {
    /// 目标地址
    #[arg(long, default_value = "127.0.0.1")]
    host: String,

    /// 目标端口
    #[arg(long, default_value = "8080")]
    port: u16,

    /// 并发连接数
    #[arg(long, default_value = "1000")]
    connections: usize,

    /// 每连接发送的消息数
    #[arg(long, default_value = "10")]
    messages: usize,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    let url = format!("ws://{}:{}/ws", args.host, args.port);

    println!(
        "负载测试：{} 连接 × {} 消息/连接，目标 {}",
        args.connections, args.messages, url
    );

    // 阶段 1：并发建立连接（Hello 握手）
    let connect_start = Instant::now();
    let mut connect_times = Vec::with_capacity(args.connections);
    let mut all_rtts: Vec<u64> = Vec::new();
    let mut handles = Vec::with_capacity(args.connections);

    for i in 0..args.connections {
        let url = url.clone();
        let messages = args.messages;
        let handle = tokio::spawn(async move {
            let t0 = Instant::now();
            let (ws, _) = match tokio_tungstenite::connect_async(&url).await {
                Ok(c) => c,
                Err(e) => {
                    eprintln!("连接 {} 失败：{}", i, e);
                    return None;
                }
            };
            let connect_ms = t0.elapsed().as_millis() as u64;

            // Hello 握手
            let master = MasterKeypair::generate();
            let device = DeviceKeypair::generate();
            let user_id = master.user_id();
            let cert = issue_device_cert(&master.signing_key, &user_id, &device, "loadtest");
            let identity = Identity {
                user_id: user_id.clone(),
                master_pubkey: master.public_bytes().to_vec(),
                display_name: format!("load-{}", i),
                avatar_seed: String::new(),
            };
            let mut hello = Hello {
                protocol_version: 1,
                identity: Some(identity.clone()),
                device_cert: Some(cert),
                device_signature: vec![],
                bot_token: String::new(),
            };
            let sig_payload = hello_signing_payload(&hello);
            hello.device_signature = device.sign(&sig_payload);
            let env = ClientEnvelope {
                r#type: ClientMsgType::Hello as i32,
                request_id: 1,
                payload: hello.encode_to_vec(),
            };
            let (mut sink, mut stream) = ws.split();
            if sink.send(WsMsg::Binary(env.encode_to_vec().into())).await.is_err() {
                return None;
            }
            // 等 HelloResponse
            let mut ok = false;
            while let Some(Ok(msg)) = stream.next().await {
                if let WsMsg::Binary(data) = msg {
                    if let Ok(resp) = ServerEnvelope::decode(data.as_slice()) {
                        if resp.r#type() == ServerMsgType::HelloResponse {
                            ok = true;
                            break;
                        }
                    }
                }
            }
            if !ok {
                eprintln!("连接 {} Hello 握手失败", i);
                return None;
            }

            // 加入（开放加入模式下即入服；审批模式返回 pending）
            let join = lonisle_core::proto::JoinRequest {
                reason: "loadtest".into(),
                push_service_url: String::new(),
                identity: Some(identity.clone()),
                claim_code: String::new(),
                invite_token: String::new(),
            };
            let join_env = ClientEnvelope {
                r#type: ClientMsgType::Join as i32,
                request_id: 2,
                payload: join.encode_to_vec(),
            };
            if sink.send(WsMsg::Binary(join_env.encode_to_vec().into())).await.is_err() {
                return None;
            }
            while let Some(Ok(m)) = stream.next().await {
                if let WsMsg::Binary(data) = m {
                    if let Ok(resp) = ServerEnvelope::decode(data.as_slice()) {
                        if resp.r#type() == ServerMsgType::JoinResponse {
                            break;
                        }
                    }
                }
            }

            // 阶段 2：发消息测往返延迟
            let mut rtts: Vec<u64> = Vec::with_capacity(messages);
            for m in 0..messages {
                let mut msg = SendMessage {
                    topic_id: "default".into(),
                    msg_id: format!("lt-{}-{}", i, m),
                    author_id: user_id.clone().into_bytes(),
                    device_id: device.device_id(),
                    client_ts: 0,
                    content: Some(lonisle_core::proto::MessageContent {
                        text: format!("loadtest {}", m),
                        attachment: None,
                        encrypted: vec![],
                    }),
                    signature: vec![],
                    reply_to: String::new(),
                };
                let payload = send_message_signing_payload(&msg);
                msg.signature = device.sign(&payload);
                let env = ClientEnvelope {
                    r#type: ClientMsgType::SendMessage as i32,
                    request_id: (m + 2) as u64,
                    payload: msg.encode_to_vec(),
                };
                let t0 = Instant::now();
                if sink.send(WsMsg::Binary(env.encode_to_vec().into())).await.is_err() {
                    break;
                }
                // 等 SendMessageAck 或 Broadcast
                let mut got = false;
                while let Some(Ok(m)) = stream.next().await {
                    if let WsMsg::Binary(data) = m {
                        if let Ok(resp) = ServerEnvelope::decode(data.as_slice()) {
                            if resp.r#type() == ServerMsgType::SendMessageAck
                                || resp.r#type() == ServerMsgType::Broadcast
                            {
                                got = true;
                                break;
                            }
                        }
                    }
                }
                if got {
                    rtts.push(t0.elapsed().as_millis() as u64); // ms
                }
            }

            Some((connect_ms, rtts))
        });
        handles.push(handle);
    }

    for handle in handles {
        if let Ok(Some((connect_ms, rtts))) = handle.await {
            connect_times.push(connect_ms);
            all_rtts.extend(rtts);
        }
    }

    println!(
        "连接建立：成功 {} / {}，耗时 {:.2}s",
        connect_times.len(),
        args.connections,
        connect_start.elapsed().as_secs_f64()
    );
    if !connect_times.is_empty() {
        print_percentiles("连接建立时间", &connect_times);
    }
    if !all_rtts.is_empty() {
        print_percentiles("消息往返延迟", &all_rtts);
    }

    Ok(())
}

/// 打印百分位统计。
fn print_percentiles(label: &str, data: &[u64]) {
    let mut sorted = data.to_vec();
    sorted.sort_unstable();
    let p = |q: f64| -> u64 {
        let idx = ((sorted.len() as f64 - 1.0) * q).round() as usize;
        sorted[idx.min(sorted.len() - 1)]
    };
    println!(
        "{}：P50={}ms P95={}ms P99={}ms（样本 {}）",
        label,
        p(0.50),
        p(0.95),
        p(0.99),
        sorted.len()
    );
}
