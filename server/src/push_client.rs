//! 聊天服务器 → 推送服务的 HTTP 客户端
//!
//! 在需要离线推送时（审批结果、@提及），向成员登记的推送服务地址
//! 发起免内容推送请求，用服务器私钥对请求体签名（F-PUSH-4/6）。
//! 异步 fire-and-forget，失败仅记日志不阻断主流程。

use ed25519_dalek::Signer;
use serde_json::json;

/// 异步向推送服务发起免内容推送。
/// `push_service_url`：成员登记的推送服务地址（如 http://push.example.com:8081）。
/// `server_keypair`：聊天服务器密钥对（用于签名）。
/// `user_id`：目标用户；`hint`：唤醒提示（如"审批通过"）；`title`：通知大标题（如服务器名，None 用默认）。
pub async fn send_push_async(
    push_service_url: &str,
    server_id: &str,
    server_secret: &[u8; 32],
    user_id: &str,
    hint: &str,
    title: Option<&str>,
) {
    // 构造请求体（免内容：仅 server_id + hint + title）
    let mut body = json!({
        "server_id": server_id,
        "user_id": user_id,
        "hint": hint,
    });
    if let Some(t) = title {
        body["title"] = json!(t);
    }
    let body_str = body.to_string();

    // 用服务器私钥签名
    let signing_key = ed25519_dalek::SigningKey::from_bytes(server_secret);
    let pubkey = signing_key.verifying_key().to_bytes();
    let signature = signing_key.sign(body_str.as_bytes()).to_bytes();

    // 跳过证书校验：推送服务可能使用自签 TLS 证书（与 push 端探测服务器一致）
    let client = reqwest::Client::builder()
        .danger_accept_invalid_certs(true)
        .build()
        .unwrap_or_default();
    let url = format!("{}/push", push_service_url.trim_end_matches('/'));
    let result = client
        .post(&url)
        .header("x-server-id", server_id)
        .header("x-server-pubkey", hex::encode(pubkey))
        .header("x-server-signature", hex::encode(signature))
        .json(&body)
        .timeout(std::time::Duration::from_secs(5))
        .send()
        .await;

    match result {
        Ok(resp) => {
            let status = resp.status().as_u16();
            if status == 200 {
                tracing::debug!(user_id = %user_id, "离线推送已发送");
            } else if status == 429 {
                tracing::warn!(user_id = %user_id, "推送被限速（429），退避");
            } else {
                tracing::warn!(status, user_id = %user_id, "推送服务返回非 200");
            }
        }
        Err(e) => {
            tracing::warn!(error = %e, "推送服务调用失败");
        }
    }
}

/// 同步封装：在 tokio 上下文中 fire-and-forget。
/// 返回立即，推送在后台完成。
pub fn fire_push(
    push_service_url: String,
    server_id: String,
    server_secret: [u8; 32],
    user_id: String,
    hint: String,
    title: Option<String>,
) {
    tokio::spawn(async move {
        send_push_async(
            &push_service_url,
            &server_id,
            &server_secret,
            &user_id,
            &hint,
            title.as_deref(),
        )
        .await;
    });
}
