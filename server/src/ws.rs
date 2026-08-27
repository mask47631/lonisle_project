//! WebSocket 网络层：握手、加入、话题管理、成员管理、消息收发、广播、游标同步

use std::sync::Arc;

use axum::extract::ws::{Message as WsMessage, WebSocket, WebSocketUpgrade};
use axum::extract::State;
use axum::response::Response;
use futures_util::{SinkExt, StreamExt};
use lonisle_core::device::{verify_device_cert, verify_device_signature, DeviceKeypair};
use lonisle_core::proto::{
    self, client_envelope::MsgType as ClientMsgType, server_envelope::MsgType as ServerMsgType,
    ClientEnvelope, Hello, HelloResponse, HistoryRequest, HistoryResponse, JoinRequest,
    JoinResponse, MemberInfo, SendMessage, SendMessageAck, ServerEnvelope, StickerPack,
    StickerPackListResponse, Sticker, SyncRequest, SyncResponse,
};
use lonisle_core::signature::{
    hello_signing_payload, verify_delete_message, verify_edit_message, verify_send_message,
};
use lonisle_core::version::{is_compatible, PROTOCOL_VERSION};
use prost::Message as _;
use sha2::Digest as _;
use tokio::sync::{broadcast, Mutex};
use tracing::{debug, info, warn};

use crate::storage::{self, MemberRole, Storage, StoredMessage, TopicPermission, TopicType};

/// 默认话题 ID
pub const DEFAULT_TOPIC_ID: &str = "default";

/// 应用共享状态
pub struct AppState {
    pub storage: Arc<dyn Storage>,
    pub keypair: DeviceKeypair,
    /// 在线连接广播通道
    pub broadcast: broadcast::Sender<ServerEnvelope>,
    /// 在线成员：user_id -> 连接数
    pub online: Mutex<std::collections::HashMap<String, usize>>,
    /// 数据目录（附件存储）
    pub data_dir: String,
    /// 日志目录（管理界面「日志」页读取，{data_dir}/logs）
    pub log_dir: String,
    /// Bot Token（M6，Bot 认证用；空表示未配置）
    pub bot_token: String,
    /// 管理 API Token（空 = 鉴权关闭，仅限开发/测试）
    pub admin_token: String,
    /// TLS 证书指纹（F-SID-2/3，空 = 未启用 TLS，仅限开发/测试）
    pub tls_fingerprint: String,
    /// 发言频率限速：user_id -> (窗口起始时间戳, 窗口内计数)（P1）
    pub speak_limits: Mutex<std::collections::HashMap<String, (i64, u32)>>,
    /// 音视频话题房间人数缓存：topic_id -> 人数（后台任务定时刷新，F-AV-COUNT）
    pub live_participants: tokio::sync::RwLock<std::collections::HashMap<String, usize>>,
}

impl AppState {
    pub fn new(storage: Arc<dyn Storage>, keypair: DeviceKeypair) -> Self {
        let (broadcast, _) = broadcast::channel(1024);
        Self {
            storage,
            keypair,
            broadcast,
            online: Mutex::new(std::collections::HashMap::new()),
            data_dir: String::new(),
            log_dir: String::new(),
            bot_token: String::new(),
            admin_token: String::new(),
            tls_fingerprint: String::new(),
            speak_limits: Mutex::new(std::collections::HashMap::new()),
            live_participants: tokio::sync::RwLock::new(std::collections::HashMap::new()),
        }
    }

    pub fn with_data_dir(storage: Arc<dyn Storage>, keypair: DeviceKeypair, data_dir: String) -> Self {
        let mut state = Self::new(storage, keypair);
        state.log_dir = std::path::Path::new(&data_dir).join("logs").to_string_lossy().into_owned();
        state.data_dir = data_dir;
        state
    }

    pub fn server_id(&self) -> String {
        lonisle_core::identity::user_id_from_pubkey(&self.keypair.public_bytes())
    }

    /// 标记用户上线（连接数 +1）
    async fn mark_online(&self, user_id: &str) {
        let mut online = self.online.lock().await;
        *online.entry(user_id.to_string()).or_insert(0) += 1;
    }

    /// 标记用户下线（连接数 -1，归零移除）
    async fn mark_offline(&self, user_id: &str) {
        let mut online = self.online.lock().await;
        if let Some(count) = online.get_mut(user_id) {
            *count -= 1;
            if *count == 0 {
                online.remove(user_id);
            }
        }
    }

    /// 判断用户是否在线
    pub async fn is_online(&self, user_id: &str) -> bool {
        let online = self.online.lock().await;
        online.contains_key(user_id)
    }
}

/// WebSocket 升级处理入口
pub async fn ws_handler(State(state): State<Arc<AppState>>, ws: WebSocketUpgrade) -> Response {
    ws.on_upgrade(move |socket| handle_socket(socket, state))
}

/// 单个连接的处理循环
async fn handle_socket(socket: WebSocket, state: Arc<AppState>) {
    let (mut sender, mut receiver) = socket.split();
    let mut current_user: Option<String> = None;
    // 当前连接已验证的设备公钥（Hello 验证书链后记录；Bot 连接为 None）
    let mut current_device: Option<Vec<u8>> = None;
    let mut broadcast_rx = state.broadcast.subscribe();

    loop {
        tokio::select! {
            // 广播转发
            Ok(env) = broadcast_rx.recv() => {
                let data = env.encode_to_vec();
                if let Err(e) = sender.send(WsMessage::Binary(data)).await {
                    debug!("广播发送失败：{e}");
                    break;
                }
            }
            // 客户端消息
            msg = receiver.next() => {
                match msg {
                    Some(Ok(WsMessage::Binary(data))) => {
                        if let Err(e) = handle_client_message(&state, &mut sender, &mut current_user, &mut current_device, &data).await {
                            debug!("处理客户端消息失败：{e}");
                        }
                    }
                    Some(Ok(WsMessage::Text(_))) => {
                        let _ = sender.send(WsMessage::Binary(encode_error(0, "仅支持二进制 protobuf 消息"))).await;
                    }
                    Some(Ok(WsMessage::Ping(_))) => {
                        let _ = sender.send(WsMessage::Pong(Vec::new())).await;
                    }
                    Some(Ok(WsMessage::Close(_))) | None => {
                        debug!("连接关闭");
                        break;
                    }
                    Some(Ok(WsMessage::Pong(_))) => {}
                    Some(Err(e)) => {
                        debug!("接收错误：{e}");
                        break;
                    }
                }
            }
        }
    }

    if let Some(user) = current_user {
        state.mark_offline(&user).await;
        debug!(user_id = %user, "成员离线");
    }
}

/// 处理一条客户端消息
async fn handle_client_message(
    state: &Arc<AppState>,
    sender: &mut futures_util::stream::SplitSink<WebSocket, WsMessage>,
    current_user: &mut Option<String>,
    current_device: &mut Option<Vec<u8>>,
    data: &[u8],
) -> anyhow::Result<()> {
    let env = match ClientEnvelope::decode(data) {
        Ok(e) => e,
        Err(_) => {
            send_raw(sender, encode_error(0, "无效的消息格式")).await?;
            return Ok(());
        }
    };

    let req_id = env.request_id;
    let payload = env.payload.as_slice();

    let resp_env = match env.r#type() {
        ClientMsgType::Hello => handle_hello(state, current_user, current_device, payload).await?,
        ClientMsgType::Join => handle_join(state, current_user, payload).await?,
        ClientMsgType::SendMessage => {
            handle_send_message(state, current_user, current_device, payload).await?
        }
        ClientMsgType::Sync => handle_sync(state, payload).await?,
        ClientMsgType::History => handle_history(state, payload).await?,
        ClientMsgType::StickerPacksList => handle_sticker_packs(state).await?,
        ClientMsgType::ListMembers => handle_list_members(state).await?,
        ClientMsgType::ListTopics => handle_list_topics(state).await?,
        ClientMsgType::CreateTopic => handle_create_topic(state, current_user, payload).await?,
        ClientMsgType::UpdateTopic => handle_update_topic(state, current_user, payload).await?,
        ClientMsgType::DeleteTopic => handle_delete_topic(state, current_user, payload).await?,
        ClientMsgType::ReorderTopics => handle_reorder_topics(state, current_user, payload).await?,
        ClientMsgType::ListJoinRequests => {
            handle_list_join_requests(state, current_user).await?
        }
        ClientMsgType::ProcessJoinRequest => {
            handle_process_join_request(state, current_user, payload).await?
        }
        ClientMsgType::IgnoreJoinRequest => {
            handle_ignore_join_request(state, current_user, payload).await?
        }
        ClientMsgType::SetMemberRole => {
            handle_set_member_role(state, current_user, payload).await?
        }
        ClientMsgType::SetMute => handle_set_mute(state, current_user, payload).await?,
        ClientMsgType::KickMember => handle_kick_member(state, current_user, payload).await?,
        ClientMsgType::SetBan => handle_set_ban(state, current_user, payload).await?,
        ClientMsgType::UpdateServerProfile => {
            handle_update_server_profile(state, current_user, payload).await?
        }
        ClientMsgType::UpdateServerSettings => {
            handle_update_server_settings(state, current_user, payload).await?
        }
        ClientMsgType::LeaveServer => handle_leave_server(state, current_user).await?,
        ClientMsgType::EditMessage => {
            handle_edit_message(state, current_user, current_device, payload).await?
        }
        ClientMsgType::DeleteMessage => {
            handle_delete_message(state, current_user, current_device, payload).await?
        }
        ClientMsgType::RegisterDevice => {
            handle_register_device(state, current_user, payload).await?
        }
        ClientMsgType::ListDevices => handle_list_devices(state, current_user).await?,
        ClientMsgType::RevokeDevice => {
            handle_revoke_device(state, current_user, payload).await?
        }
        ClientMsgType::AddReaction => {
            handle_add_reaction(state, current_user, payload).await?
        }
        ClientMsgType::RemoveReaction => {
            handle_remove_reaction(state, current_user, payload).await?
        }
        ClientMsgType::UploadPreKeys => {
            handle_upload_pre_keys(state, current_user, payload).await?
        }
        ClientMsgType::FetchPreKeys => {
            handle_fetch_pre_keys(state, payload).await?
        }
        ClientMsgType::UpsertRole => {
            handle_upsert_role(state, current_user, payload).await?
        }
        ClientMsgType::DeleteRole => {
            handle_delete_role(state, current_user, payload).await?
        }
        ClientMsgType::ListRoles => handle_list_roles(state).await?,
        ClientMsgType::AssignRole => {
            handle_assign_role(state, current_user, payload).await?
        }
        ClientMsgType::UnassignRole => {
            handle_unassign_role(state, current_user, payload).await?
        }
        ClientMsgType::MarkMentionRead => {
            handle_mark_mention_read(state, current_user, payload).await?
        }
        ClientMsgType::MentionReadList => {
            handle_mention_read_list(state, payload).await?
        }
        ClientMsgType::JoinAv => {
            handle_join_av(state, current_user, payload).await?
        }
        ClientMsgType::Ping => ServerEnvelope {
            r#type: ServerMsgType::Pong as i32,
            request_id: req_id,
            payload: vec![],
            error: String::new(),
        },
    };

    let resp_env = ServerEnvelope {
        request_id: req_id,
        ..resp_env
    };

    send_raw(sender, resp_env.encode_to_vec()).await?;
    Ok(())
}

/// Hello 握手：协议版本协商 + 设备证书链验证
async fn handle_hello(
    state: &Arc<AppState>,
    current_user: &mut Option<String>,
    current_device: &mut Option<Vec<u8>>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let hello = Hello::decode(payload)?;

    let compatible = is_compatible(hello.protocol_version);
    let mut response = HelloResponse {
        protocol_version: PROTOCOL_VERSION,
        compatible,
        min_supported: 1,
        max_supported: 1,
        server_id: state.server_id(),
        server_pubkey: state.keypair.public_bytes().to_vec(),
        server_name: String::new(),
        server_desc: String::new(),
        is_member: false,
        migration_target: String::new(),
        migration_fingerprint: String::new(),
        av_enabled: false,
        migration_signature: String::new(),
    };

    if let Some(meta) = state.storage.get_server_meta().await? {
        response.server_name = meta.name;
        response.server_desc = meta.description;
        response.migration_target = meta.migration_target_address.clone();
        response.migration_fingerprint = meta.migration_target_fingerprint.clone();
        response.migration_signature = meta.migration_signature.clone();
        response.av_enabled = !meta.livekit_url.is_empty();
    }

    if compatible {
        let user_id = hello
            .identity
            .as_ref()
            .map(|i| i.user_id.clone())
            .unwrap_or_default();

        // Bot 认证：hello.bot_token 非空则走 Bot 认证（跳过设备证书链）
        let is_bot = !hello.bot_token.is_empty();
        if is_bot {
            // F-BOT：优先按 Bot 注册表验证（SHA-256 哈希比对），兼容旧共享 Token
            let token_hash = {
                use sha2::Digest;
                let mut h = sha2::Sha256::new();
                h.update(hello.bot_token.as_bytes());
                hex::encode(h.finalize())
            };
            let registered = state.storage.find_bot_by_token(&token_hash).await.ok().flatten();
            let legacy_ok =
                !state.bot_token.is_empty() && hello.bot_token == state.bot_token;
            if registered.is_none() && !legacy_ok {
                return Ok(err_env("Bot Token 无效"));
            }
            if let Some(bot) = &registered {
                info!(bot_id = %bot.bot_id, "Bot 认证通过（注册 Bot）");
            } else {
                info!(user_id = %user_id, "Bot 认证通过（共享 Token）");
            }
            *current_device = None;
        } else {
            // 普通客户端：强制携带设备证书（F-DEV-3），验证证书链 + 设备签名
            let cert = match &hello.device_cert {
                Some(c) => c,
                None => return Ok(err_env("缺少设备证书")),
            };
            let master_pubkey = hello
                .identity
                .as_ref()
                .map(|i| i.master_pubkey.clone())
                .unwrap_or_default();
            if verify_device_cert(cert, &master_pubkey).is_err() {
                return Ok(err_env("设备证书验证失败"));
            }
            let sig_payload = hello_signing_payload(&hello);
            if verify_device_signature(&cert.device_pubkey, &sig_payload, &hello.device_signature)
                .is_err()
            {
                return Ok(err_env("设备签名验证失败"));
            }

            // 吊销验证：设备公钥在本地吊销列表 → 拒绝连接
            if state
                .storage
                .is_revoked(&user_id, &cert.device_pubkey)
                .await?
            {
                warn!(user_id = %user_id, "已吊销设备尝试连接，拒绝");
                return Ok(err_env("该设备已被吊销"));
            }

            // 记录本会话已验证的设备公钥，供消息验签使用（F-ID-4）
            *current_device = Some(cert.device_pubkey.clone());

            // 补录成员主公钥（吊销证明验签所需，F-DEV-4）
            let _ = state
                .storage
                .set_member_master_pubkey(&user_id, &master_pubkey)
                .await;
        }

        *current_user = Some(user_id.clone());
        state.mark_online(&user_id).await;

        response.is_member = state.storage.get_member(&user_id).await?.is_some();
    }

    Ok(ServerEnvelope {
        r#type: ServerMsgType::HelloResponse as i32,
        request_id: 0,
        payload: response.encode_to_vec(),
        error: String::new(),
    })
}

/// 加入：根据服务器加入策略处理（审批/开放/仅邀请）
async fn handle_join(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let req = JoinRequest::decode(payload)?;
    let user_id = current_user
        .clone()
        .unwrap_or_else(|| req.identity.as_ref().map(|i| i.user_id.clone()).unwrap_or_default());

    let identity = req
        .identity
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("缺少身份"))?;

    // 已封禁则拒绝
    if let Some(m) = state.storage.get_member(&user_id).await? {
        if m.banned {
            return Ok(join_response(JoinResponse {
                accepted: false,
                reason: "你已被封禁".into(),
                ..Default::default()
            }));
        }
        // 已是成员，直接返回成功（幂等）
        return Ok(join_success_response(state, user_id, m.is_owner()).await?);
    }

    // Owner 一次性认领码（F-PERM-1）：持有效认领码完成加入的用户直接成为 Owner，
    // 认领码随即失效；不受加入策略限制（部署者首次自举）。
    if !req.claim_code.is_empty() {
        let stored_hash = state.storage.get_owner_claim_hash().await?;
        let valid = match &stored_hash {
            Some(hash) => {
                let code_hash = hex::encode(sha2::Sha256::digest(req.claim_code.trim().as_bytes()));
                &code_hash == hash
            }
            None => false,
        };
        if !valid {
            return Ok(join_response(JoinResponse {
                accepted: false,
                reason: "认领码无效或已被使用".into(),
                ..Default::default()
            }));
        }

        // 认领成功：加入为 Owner 并销毁认领码
        let member = storage::Member {
            user_id: user_id.clone(),
            display_name: identity.display_name.clone(),
            avatar_seed: identity.avatar_seed.clone(),
            role: MemberRole::Owner,
            muted: false,
            banned: false,
            server_nickname: None,
            server_avatar: None,
            push_service_url: req.push_service_url.clone(),
            is_bot: false,
            joined_at: lonisle_core::device::current_unix_time(),
            master_pubkey: identity.master_pubkey.clone(),
        };
        state.storage.upsert_member(&member).await?;
        state.storage.clear_owner_claim_hash().await?;
        info!(user_id = %user_id, "Owner 认领成功，认领码已失效");
        return join_success_response(state, user_id, true).await;
    }

    let meta = state
        .storage
        .get_server_meta()
        .await?
        .unwrap_or(storage::ServerMeta {
            server_id: state.server_id(),
            name: "LonIsle Server".into(),
            description: String::new(),
            strategy: storage::JoinStrategy::Approval,
            migration_target_address: String::new(),
            migration_target_fingerprint: String::new(),
            migration_signature: String::new(),
            rate_limit_per_minute: 0,
            max_attachment_size: 0,
            attachment_quota: 0,
            mention_read_enabled: false,
            livekit_url: String::new(),
            livekit_api_key: String::new(),
            livekit_api_secret: String::new(),
            icon: String::new(),
        });

    match meta.strategy {
        storage::JoinStrategy::Open => {
            // 开放加入：直接入服
            let is_owner = state.storage.list_members().await?.is_empty();
            let member = storage::Member {
                user_id: user_id.clone(),
                display_name: identity.display_name.clone(),
                avatar_seed: identity.avatar_seed.clone(),
                role: if is_owner {
                    MemberRole::Owner
                } else {
                    MemberRole::Member
                },
                muted: false,
                banned: false,
                server_nickname: None,
                server_avatar: None,
                push_service_url: req.push_service_url.clone(),
                is_bot: false,
                joined_at: lonisle_core::device::current_unix_time(),
                master_pubkey: identity.master_pubkey.clone(),
            };
            state.storage.upsert_member(&member).await?;
            info!(user_id = %user_id, "开放加入");
            join_success_response(state, user_id, is_owner).await
        }
        storage::JoinStrategy::InviteOnly => {
            // 仅邀请：携带有效一次性令牌可直接加入（F-JOIN-5）
            let valid = !req.invite_token.is_empty()
                && state.storage.consume_invite(&req.invite_token).await.unwrap_or(false);
            if !valid {
                return Ok(join_response(JoinResponse {
                    accepted: false,
                    reason: "该服务器仅限邀请加入（需要有效邀请码）".into(),
                    ..Default::default()
                }));
            }
            info!(user_id = %user_id, "凭邀请令牌加入");
            let is_owner = state.storage.list_members().await?.is_empty();
            let member = storage::Member {
                user_id: user_id.clone(),
                display_name: identity.display_name.clone(),
                avatar_seed: String::new(),
                role: if is_owner {
                    storage::MemberRole::Owner
                } else {
                    storage::MemberRole::Member
                },
                muted: false,
                banned: false,
                server_nickname: None,
                server_avatar: None,
                push_service_url: req.push_service_url.clone(),
                is_bot: false,
                joined_at: lonisle_core::device::current_unix_time(),
                master_pubkey: identity.master_pubkey.clone(),
            };
            state.storage.upsert_member(&member).await?;
            join_success_response(state, user_id, is_owner).await
        }
        storage::JoinStrategy::Approval => {
            // 审批加入：创建待审批申请（纳秒时间戳保证唯一）
            let request_id = format!("jr-{}", unique_id());
            let jr = storage::JoinRequest {
                request_id: request_id.clone(),
                user_id: user_id.clone(),
                display_name: identity.display_name.clone(),
                reason: req.reason.clone(),
                push_service_url: req.push_service_url.clone(),
                status: storage::JoinStatus::Pending,
                created_at: lonisle_core::device::current_unix_time(),
            };
            state.storage.create_join_request(&jr).await?;
            info!(user_id = %user_id, "提交加入申请，等待审批");

            // 通知管理员（广播审批列表更新）
            broadcast_simple(state, ServerMsgType::JoinRequestUpdated, vec![]);

            let resp = JoinResponse {
                accepted: false, // 尚未加入
                reason: "申请已提交，等待管理员审批".into(),
                is_owner: false,
                server_info: Some(server_info(state, &meta)),
                topics: vec![],
                status: proto::JoinStatus::Pending as i32,
                request_id,
                strategy: proto::JoinStrategy::Approval as i32,
            };
            Ok(join_response(resp))
        }
    }
}

/// 构造加入成功响应（含服务器资料与话题列表）
async fn join_success_response(
    state: &Arc<AppState>,
    _user_id: String,
    is_owner: bool,
) -> anyhow::Result<ServerEnvelope> {
    let meta = state.storage.get_server_meta().await?.unwrap_or(storage::ServerMeta {
        server_id: state.server_id(),
        name: "LonIsle Server".into(),
        description: String::new(),
        strategy: storage::JoinStrategy::Approval,
            migration_target_address: String::new(),
            migration_target_fingerprint: String::new(),
            migration_signature: String::new(),
            rate_limit_per_minute: 0,
            max_attachment_size: 0,
            attachment_quota: 0,
            mention_read_enabled: false,
            livekit_url: String::new(),
            livekit_api_key: String::new(),
            livekit_api_secret: String::new(),
            icon: String::new(),
    });

    let topics = state.storage.list_topics().await?;
    let live = state.live_participants.read().await;
    let topic_infos: Vec<proto::TopicInfo> = topics
        .into_iter()
        .map(|t| {
            let n = live.get(&t.topic_id).copied().unwrap_or(0);
            topic_to_proto(t, n)
        })
        .collect();

    let resp = JoinResponse {
        accepted: true,
        reason: String::new(),
        is_owner,
        server_info: Some(server_info(state, &meta)),
        topics: topic_infos,
        status: proto::JoinStatus::Approved as i32,
        request_id: String::new(),
        strategy: strategy_to_proto(meta.strategy),
    };

    Ok(join_response(resp))
}

fn join_response(resp: JoinResponse) -> ServerEnvelope {
    ServerEnvelope {
        r#type: ServerMsgType::JoinResponse as i32,
        request_id: 0,
        payload: resp.encode_to_vec(),
        error: String::new(),
    }
}

/// storage JoinStrategy（0 基）→ proto JoinStrategy（1 基）编号转换
fn strategy_to_proto(s: storage::JoinStrategy) -> i32 {
    match s {
        storage::JoinStrategy::Approval => proto::JoinStrategy::Approval as i32,
        storage::JoinStrategy::Open => proto::JoinStrategy::Open as i32,
        storage::JoinStrategy::InviteOnly => proto::JoinStrategy::InviteOnly as i32,
    }
}

fn server_info(state: &Arc<AppState>, meta: &storage::ServerMeta) -> proto::ServerInfo {
    proto::ServerInfo {
        server_id: meta.server_id.clone(),
        name: meta.name.clone(),
        description: meta.description.clone(),
        // 证书指纹（F-SID-2）：TLS 启用时为 TLS 证书 SHA256，否则回退 server_id
        fingerprint: if state.tls_fingerprint.is_empty() {
            state.server_id()
        } else {
            state.tls_fingerprint.clone()
        },
        strategy: strategy_to_proto(meta.strategy),
        icon: meta.icon.clone(),
        rate_limit_per_minute: meta.rate_limit_per_minute,
        max_attachment_size: meta.max_attachment_size,
        attachment_quota: 0, // 已取消单成员附件总配额（字段保留兼容）
        server_version: crate::SERVER_VERSION.to_string(),
    }
}

fn topic_to_proto(t: storage::Topic, live_participants: usize) -> proto::TopicInfo {
    proto::TopicInfo {
        topic_id: t.topic_id,
        name: t.name,
        description: t.description,
        sort_order: t.sort_order,
        r#type: match t.topic_type {
            TopicType::Announcement => proto::TopicType::Announcement as i32,
            TopicType::Av => proto::TopicType::Av as i32,
            _ => proto::TopicType::Text as i32,
        },
        permission: match t.permission {
            TopicPermission::Readonly => proto::TopicPermission::Readonly as i32,
            _ => proto::TopicPermission::Public as i32,
        },
        live_participants: live_participants as i32,
    }
}

fn broadcast_simple(state: &Arc<AppState>, msg_type: ServerMsgType, payload: Vec<u8>) {
    let env = ServerEnvelope {
        r#type: msg_type as i32,
        request_id: 0,
        payload,
        error: String::new(),
    };
    let _ = state.broadcast.send(env);
}

/// 广播服务器资料变更（名称/简介/图标，F-PERM-2）：
/// 管理界面保存设置或上传图标后调用，在线客户端实时刷新，无需重连
pub async fn broadcast_server_info(state: &Arc<AppState>) {
    if let Ok(Some(meta)) = state.storage.get_server_meta().await {
        let info = server_info(state, &meta);
        broadcast_simple(
            state,
            ServerMsgType::ServerInfoUpdated,
            info.encode_to_vec(),
        );
    }
}

/// F-JOIN-6：被踢出/封禁成员的定向通知。
/// 广播 MEMBER_UPDATED 且 payload 携带受害者 MemberInfo（客户端比对 user_id 提示本人）；
/// 受害者离线时同时走推送唤醒（免内容）。
async fn notify_member_removal(state: &Arc<AppState>, victim: &str, reason: &str) {
    let members = match state.storage.list_members().await {
        Ok(m) => m,
        Err(_) => return,
    };
    let info = members.iter().find(|m| m.user_id == victim).map(|m| MemberInfo {
        user_id: m.user_id.clone(),
        display_name: m.effective_name().to_string(),
        avatar_seed: m.effective_avatar().to_string(),
        is_owner: m.is_owner(),
        joined_at: m.joined_at,
        role: match m.role {
            MemberRole::Owner => proto::MemberRole::Owner as i32,
            MemberRole::Admin => proto::MemberRole::Admin as i32,
            MemberRole::Member => proto::MemberRole::Member as i32,
        },
        muted: m.muted,
        banned: m.banned,
        is_online: false,
        server_nickname: m.server_nickname.clone().unwrap_or_default(),
        server_avatar: m.server_avatar.clone().unwrap_or_default(),
        is_bot: m.is_bot,
    });
    // payload 携带受害者 MemberInfo：客户端比对 user_id 提示本人（F-JOIN-6）
    broadcast_simple(
        state,
        ServerMsgType::MemberUpdated,
        info.map(|i| i.encode_to_vec()).unwrap_or_default(),
    );

    // 离线且登记了推送服务 → 唤醒推送（F-JOIN-6 离线触达）
    if !state.is_online(victim).await {
        if let Some(m) = members
            .iter()
            .find(|m| m.user_id == victim && !m.push_service_url.is_empty())
        {
            // 大标题 = 服务器名（推送内容可读性，F-PUSH-4）
            let server_name = state
                .storage
                .get_server_meta()
                .await
                .ok()
                .flatten()
                .map(|meta| meta.name)
                .unwrap_or_default();
            crate::push_client::fire_push(
                m.push_service_url.clone(),
                state.server_id(),
                state.keypair.secret_bytes(),
                victim.to_string(),
                reason.to_string(),
                Some(server_name),
            );
        }
    }
}

/// 发送消息：权限/禁言/话题类型校验 → 落库分配序号 → 广播
async fn handle_send_message(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    current_device: &Option<Vec<u8>>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let msg = SendMessage::decode(payload)?;
    let user_id = current_user.clone().unwrap_or_default();

    // 作者身份须与当前连接一致
    if msg.author_id != user_id.as_bytes() {
        return Ok(err_env("作者身份与连接不符"));
    }

    // 消息设备签名验证（F-ID-4；Bot 连接无设备公钥，由 Bot Token 认证兜底）
    if let Some(device_pubkey) = current_device {
        if verify_send_message(&msg, device_pubkey).is_err() {
            warn!(user_id = %user_id, msg_id = %msg.msg_id, "消息签名验证失败");
            return Ok(err_env("消息签名验证失败"));
        }
    }

    // 成员校验：是否存在、是否封禁、是否禁言
    let member = match state.storage.get_member(&user_id).await? {
        Some(m) => m,
        None => return Ok(err_env("尚未加入服务器")),
    };
    if member.banned {
        return Ok(err_env("你已被封禁"));
    }
    if member.muted {
        return Ok(err_env("你已被禁言"));
    }

    // 发言频率限制（P1，服主可配）
    if let Ok(Some(meta)) = state.storage.get_server_meta().await {
        if meta.rate_limit_per_minute > 0 {
            let now = lonisle_core::device::current_unix_time();
            let mut limits = state.speak_limits.lock().await;
            let entry = limits.entry(user_id.clone()).or_insert((now, 0));
            // 窗口：60 秒
            if now - entry.0 >= 60 {
                *entry = (now, 1);
            } else {
                entry.1 += 1;
                if entry.1 > meta.rate_limit_per_minute {
                    return Ok(err_env("发言过于频繁"));
                }
            }
        }
    }

    let topic_id = if msg.topic_id.is_empty() {
        DEFAULT_TOPIC_ID.to_string()
    } else {
        msg.topic_id.clone()
    };

    // 话题校验：是否存在、类型/权限是否允许发言
    let topic = match state.storage.get_topic(&topic_id).await? {
        Some(t) => t,
        None => return Ok(err_env("话题不存在")),
    };
    let is_admin = member.role >= MemberRole::Admin;
    let can_speak = match topic.topic_type {
        TopicType::Announcement => is_admin, // 订阅话题仅管理员发言
        TopicType::Text => match topic.permission {
            TopicPermission::Readonly => is_admin,
            TopicPermission::Public => true,
        },
        TopicType::Av => match topic.permission {
            TopicPermission::Readonly => is_admin,
            TopicPermission::Public => true,
        },
    };
    if !can_speak {
        return Ok(err_env("无发言权限"));
    }

    let author_name = member.effective_name().to_string();
    let text = msg
        .content
        .as_ref()
        .map(|c| c.text.clone())
        .unwrap_or_default();

    // ---- @提及解析（服务端权威，F-MSG-6/F-TOPIC-5） ----
    let members = state.storage.list_members().await?;
    let mention_tokens: Vec<String> = text
        .split_whitespace()
        .filter_map(|t| {
            let t = t.strip_prefix('@')?;
            let t = t.trim_end_matches(['.', ',', '!', '?', ';', ':', ')', '，', '。', '！', '？']);
            if t.is_empty() {
                None
            } else {
                Some(t.to_string())
            }
        })
        .collect();

    // @everyone 仅管理员可用（F-TOPIC-5）
    let has_everyone = mention_tokens.iter().any(|t| t == "everyone");
    if has_everyone && !is_admin {
        return Ok(err_env("@everyone 仅管理员可用"));
    }

    // 匹配成员：server 昵称 > 全局昵称（# 前的名字部分），大小写不敏感
    let mut mentioned_user_ids: Vec<String> = Vec::new();
    for token in &mention_tokens {
        if token == "everyone" {
            continue;
        }
        let token_lower = token.to_lowercase();
        for m in &members {
            let nick_match = m
                .server_nickname
                .as_deref()
                .map(|n| !n.is_empty() && n.to_lowercase() == token_lower)
                .unwrap_or(false);
            let name_part = m.display_name.split('#').next().unwrap_or("").to_lowercase();
            if nick_match || (!name_part.is_empty() && name_part == token_lower) {
                if m.user_id != user_id && !mentioned_user_ids.contains(&m.user_id) {
                    mentioned_user_ids.push(m.user_id.clone());
                }
                break;
            }
        }
    }

    // mentions 持久化为 JSON 数组（@everyone 用字面量 "everyone" 表示）
    let mut mention_entries = mentioned_user_ids.clone();
    if has_everyone {
        mention_entries.push("everyone".to_string());
    }
    let mentions_json = if mention_entries.is_empty() {
        String::new()
    } else {
        serde_json::to_string(&mention_entries).unwrap_or_default()
    };

    // 附件文件名补全：表情等"引用发送"（客户端仅传 attachment_id）可能不带扩展名，
    // 用附件记录的真实文件名/mime/尺寸覆盖，避免接收方下载得到无后缀名文件、
    // 消息流图片比例错误显示正方形（F-STICKER）
    let mut attachment_json = String::new();
    if let Some(c) = msg.content.as_ref() {
        if let Some(att) = c.attachment.as_ref() {
            let mut att = att.clone();
            if !att.attachment_id.is_empty() {
                if let Ok(Some(record)) =
                    state.storage.get_attachment(&att.attachment_id).await
                {
                    let has_ext = att.filename.contains('.');
                    if att.filename.is_empty()
                        || (!has_ext && !record.filename.is_empty())
                    {
                        att.filename = record.filename.clone();
                    }
                    if att.mime.is_empty() || att.mime == "image/*" {
                        att.mime = record.mime.clone();
                    }
                    // 尺寸/时长/大小补全（引用发送时客户端未知，靠记录补）
                    if att.width == 0 && record.width > 0 {
                        att.width = record.width;
                    }
                    if att.height == 0 && record.height > 0 {
                        att.height = record.height;
                    }
                    if att.duration == 0 && record.duration > 0 {
                        att.duration = record.duration;
                    }
                    if att.size == 0 {
                        att.size = record.size;
                    }
                }
            }
            attachment_json = storage::attachment_to_json(&att);
        }
    }

    let stored = StoredMessage {
        seq: 0,
        topic_id: topic_id.clone(),
        msg_id: msg.msg_id.clone(),
        author_id: user_id.clone(),
        device_id: msg.device_id.clone(),
        author_name,
        server_ts: lonisle_core::device::current_unix_time(),
        content_text: text.clone(),
        edited: false,
        deleted: false,
        mentions: mentions_json.clone(),
        reply_to: msg.reply_to.clone(),
        attachment_json,
    };

    // 落库分配序号（幂等去重）
    let seq = match state.storage.append_message(&stored).await {
        Ok(seq) => seq,
        Err(storage::StorageError::DuplicateMessage) => {
            warn!(user_id = %user_id, msg_id = %msg.msg_id, "重复消息（幂等忽略）");
            return Ok(ServerEnvelope {
                r#type: ServerMsgType::SendMessageAck as i32,
                request_id: 0,
                payload: SendMessageAck {
                    msg_id: msg.msg_id.clone(),
                    seq: 0,
                    duplicated: true,
                }
                .encode_to_vec(),
                error: String::new(),
            });
        }
        Err(e) => return Err(anyhow::anyhow!("落库失败：{e}")),
    };

    // 广播给所有在线成员（先用附件记录补全 attachment 字段，
    // 修复历史消息 attachment_json 旧值/客户端 SendMessage 占位值问题，F-MEDIA-10）
    let mut enriched_content = msg.content.clone();
    enrich_attachment_from_record(
        state,
        enriched_content.as_mut().and_then(|c| c.attachment.as_mut()),
    )
    .await;
    let broadcast_msg = proto::BroadcastMessage {
        seq,
        topic_id: topic_id.clone(),
        msg_id: msg.msg_id.clone(),
        author_id: msg.author_id.clone(),
        device_id: msg.device_id.clone(),
        author_name: stored.author_name.clone(),
        server_ts: stored.server_ts,
        content: enriched_content,
        edited: false,
        deleted: false,
        mentions: mentions_json.clone(),
        reactions: vec![],
        reply_to: msg.reply_to.clone(),
    };
    let env = ServerEnvelope {
        r#type: ServerMsgType::Broadcast as i32,
        request_id: 0,
        payload: broadcast_msg.encode_to_vec(),
        error: String::new(),
    };
    let _ = state.broadcast.send(env);

    // 离线提及推送（F-PUSH-4）：被提及且离线的成员始终推送（不受话题推送开关影响）
    if has_everyone || !mentioned_user_ids.is_empty() {
        let push_targets: Vec<String> = if has_everyone {
            members.iter().map(|m| m.user_id.clone()).collect()
        } else {
            mentioned_user_ids.clone()
        };
        for uid in push_targets {
            if uid == user_id || state.is_online(&uid).await {
                continue;
            }
            if let Some(m) = members.iter().find(|m| m.user_id == uid) {
                if !m.push_service_url.is_empty() {
                    // 推送内容：大标题=服务器名，内容=在「话题」中被 @（F-PUSH-4）
                    let server_name = state
                        .storage
                        .get_server_meta()
                        .await
                        .ok()
                        .flatten()
                        .map(|meta| meta.name)
                        .unwrap_or_default();
                    let topic_name = state
                        .storage
                        .get_topic(&msg.topic_id)
                        .await
                        .ok()
                        .flatten()
                        .map(|t| t.name)
                        .unwrap_or_default();
                    crate::push_client::fire_push(
                        m.push_service_url.clone(),
                        state.server_id(),
                        state.keypair.secret_bytes(),
                        uid.clone(),
                        format!(
                            "在「{}」中被 @提及",
                            if topic_name.is_empty() { "默认话题" } else { &topic_name }
                        ),
                        Some(server_name),
                    );
                }
            }
        }
    }

    // 话题推送开关（F-PUSH-8）：开启后该话题新消息广播推送给服务器下所有客户端
    if topic.push_enabled {
        // 新消息广播推送：推送给服务器下所有客户端
        let server_name = state
            .storage
            .get_server_meta()
            .await
            .ok()
            .flatten()
            .map(|meta| meta.name)
            .unwrap_or_default();
        let topic_name = if topic.name.is_empty() {
            "默认话题"
        } else {
            &topic.name
        };
        let hint = format!("「{}」有新消息", topic_name);
        for m in &members {
            // 不推发送者本人
            if m.user_id == user_id || m.push_service_url.is_empty() {
                continue;
            }
            crate::push_client::fire_push(
                m.push_service_url.clone(),
                state.server_id(),
                state.keypair.secret_bytes(),
                m.user_id.clone(),
                hint.clone(),
                Some(server_name.clone()),
            );
        }
    }

    // 回执（含服务器分配的序号）
    Ok(ServerEnvelope {
        r#type: ServerMsgType::SendMessageAck as i32,
        request_id: 0,
        payload: SendMessageAck {
            msg_id: msg.msg_id.clone(),
            seq,
            duplicated: false,
        }
        .encode_to_vec(),
        error: String::new(),
    })
}

/// StoredMessage → 广播消息（同步/历史翻页共用映射）
/// `StoredMessage` → `BroadcastMessage`（async：用当前附件记录补全 attachment 字段）
async fn stored_to_broadcast(
    state: &Arc<AppState>,
    m: StoredMessage,
) -> proto::BroadcastMessage {
    let mut bc = proto::BroadcastMessage {
        seq: m.seq,
        topic_id: m.topic_id,
        msg_id: m.msg_id,
        author_id: m.author_id.into_bytes(),
        device_id: m.device_id,
        author_name: m.author_name,
        server_ts: m.server_ts,
        content: Some(proto::MessageContent {
            text: m.content_text,
            attachment: storage::attachment_from_json(&m.attachment_json),
            encrypted: vec![],
        }),
        edited: m.edited,
        deleted: m.deleted,
        mentions: m.mentions,
        reactions: vec![],
        reply_to: m.reply_to,
    };
    // 用附件记录补全（修复历史消息 attachment_json 旧值/客户端 SendMessage 占位值问题）
    enrich_attachment_from_record(state, bc.content.as_mut().and_then(|c| c.attachment.as_mut())).await;
    bc
}

/// 广播/同步附件时，用 attachments 表当前记录补全 attachment 字段
/// （修复历史消息 attachment_json 写入了占位值的旧问题，F-STICKER/F-MEDIA-10）
async fn enrich_attachment_from_record(
    state: &Arc<AppState>,
    att: Option<&mut lonisle_core::proto::Attachment>,
) {
    let Some(att) = att else { return };
    if att.attachment_id.is_empty() {
        return;
    }
    let Ok(Some(record)) = state.storage.get_attachment(&att.attachment_id).await else {
        return;
    };
    let has_ext = att.filename.contains('.');
    if att.filename.is_empty() || (!has_ext && !record.filename.is_empty()) {
        att.filename = record.filename.clone();
    }
    if att.mime.is_empty() || att.mime == "image/*" {
        att.mime = record.mime.clone();
    }
    if att.width == 0 && record.width > 0 {
        att.width = record.width;
    }
    if att.height == 0 && record.height > 0 {
        att.height = record.height;
    }
    if att.size == 0 {
        att.size = record.size;
    }
    if att.duration == 0 && record.duration > 0 {
        att.duration = record.duration;
    }
}

/// 表情包记录 → proto（包 + 表情，F-STICKER）
fn sticker_packs_to_proto(
    packs: Vec<crate::storage::StickerPackRecord>,
) -> Vec<StickerPack> {
    packs
        .into_iter()
        .map(|p| StickerPack {
            id: p.id,
            name: p.name,
            icon: p.icon,
            sort: p.sort,
            stickers: p
                .stickers
                .into_iter()
                .map(|s| Sticker {
                    id: s.id,
                    pack_id: s.pack_id,
                    r#type: s.r#type,
                    content: s.content,
                    sort: s.sort,
                })
                .collect(),
        })
        .collect()
}

/// 拉取服务器表情包（join 后调用一次）
async fn handle_sticker_packs(state: &Arc<AppState>) -> anyhow::Result<ServerEnvelope> {
    let packs = state.storage.list_sticker_packs().await?;
    let resp = StickerPackListResponse {
        packs: sticker_packs_to_proto(packs),
    };
    Ok(ServerEnvelope {
        r#type: ServerMsgType::StickerPacksResponse as i32,
        request_id: 0,
        payload: resp.encode_to_vec(),
        error: String::new(),
    })
}

/// 广播表情包变更（管理页增删改排序后调用，在线成员实时刷新）
pub async fn broadcast_sticker_packs(state: &Arc<AppState>) {
    if let Ok(packs) = state.storage.list_sticker_packs().await {
        let resp = StickerPackListResponse {
            packs: sticker_packs_to_proto(packs),
        };
        broadcast_simple(
            state,
            ServerMsgType::StickerPacksUpdated,
            resp.encode_to_vec(),
        );
    }
}

/// 历史消息向前翻页（加载更早消息，F-MSG：滚动到顶部触发）
async fn handle_history(
    state: &Arc<AppState>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let req = HistoryRequest::decode(payload)?;
    let topic_id = if req.topic_id.is_empty() {
        DEFAULT_TOPIC_ID.to_string()
    } else {
        req.topic_id.clone()
    };
    let limit = if req.limit == 0 { 50 } else { req.limit.min(100) };

    // before_seq=0 表示从该话题最新往前翻
    let before_seq = if req.before_seq == 0 {
        u64::MAX
    } else {
        req.before_seq
    };
    let msgs = state
        .storage
        .get_messages_before(&topic_id, before_seq, limit)
        .await?;
    let has_more = msgs.len() as u32 == limit;

    let mut broadcast_msgs: Vec<proto::BroadcastMessage> = Vec::with_capacity(msgs.len());
    for m in msgs {
        broadcast_msgs.push(stored_to_broadcast(state, m).await);
    }

    let resp = HistoryResponse {
        topic_id,
        messages: broadcast_msgs,
        has_more,
    };
    Ok(ServerEnvelope {
        r#type: ServerMsgType::HistoryResponse as i32,
        request_id: 0,
        payload: resp.encode_to_vec(),
        error: String::new(),
    })
}

/// 游标增量同步
async fn handle_sync(state: &Arc<AppState>, payload: &[u8]) -> anyhow::Result<ServerEnvelope> {
    let req = SyncRequest::decode(payload)?;
    let topic_id = if req.topic_id.is_empty() {
        DEFAULT_TOPIC_ID.to_string()
    } else {
        req.topic_id.clone()
    };
    let limit = if req.limit == 0 {
        100
    } else {
        req.limit.min(500)
    };

    let msgs = state
        .storage
        .get_messages_since(&topic_id, req.after_seq, limit)
        .await?;
    let latest = state.storage.latest_seq(&topic_id).await?;

    let mut broadcast_msgs: Vec<proto::BroadcastMessage> = Vec::with_capacity(msgs.len());
    for m in msgs {
        broadcast_msgs.push(stored_to_broadcast(state, m).await);
    }

    let resp = SyncResponse {
        topic_id,
        latest_seq: latest,
        messages: broadcast_msgs,
    };

    Ok(ServerEnvelope {
        r#type: ServerMsgType::SyncResponse as i32,
        request_id: 0,
        payload: resp.encode_to_vec(),
        error: String::new(),
    })
}

/// 成员列表（含角色、在线状态、服务器内覆盖）
async fn handle_list_members(state: &Arc<AppState>) -> anyhow::Result<ServerEnvelope> {
    let members = state.storage.list_members().await?;
    let mut infos: Vec<MemberInfo> = Vec::with_capacity(members.len());
    for m in members {
        let is_online = state.is_online(&m.user_id).await;
        let effective_name = m.effective_name().to_string();
        let effective_avatar = m.effective_avatar().to_string();
        let nickname = m.server_nickname.clone().unwrap_or_default();
        let avatar = m.server_avatar.clone().unwrap_or_default();
        let is_owner = m.is_owner();
        let role = match m.role {
            MemberRole::Owner => proto::MemberRole::Owner as i32,
            MemberRole::Admin => proto::MemberRole::Admin as i32,
            MemberRole::Member => proto::MemberRole::Member as i32,
        };
        infos.push(MemberInfo {
            user_id: m.user_id,
            display_name: effective_name,
            avatar_seed: effective_avatar,
            is_owner,
            joined_at: m.joined_at,
            role,
            muted: m.muted,
            banned: m.banned,
            is_online,
            server_nickname: nickname,
            server_avatar: avatar,
            is_bot: m.is_bot,
        });
    }

    let resp = proto::MemberListResponse { members: infos };
    Ok(ServerEnvelope {
        r#type: ServerMsgType::MemberListResponse as i32,
        request_id: 0,
        payload: resp.encode_to_vec(),
        error: String::new(),
    })
}

// ---- 话题管理 handler ----

async fn handle_list_topics(state: &Arc<AppState>) -> anyhow::Result<ServerEnvelope> {
    let topics = state.storage.list_topics().await?;
    let live = state.live_participants.read().await;
    let infos: Vec<proto::TopicInfo> = topics
        .into_iter()
        .map(|t| {
            let n = live.get(&t.topic_id).copied().unwrap_or(0);
            topic_to_proto(t, n)
        })
        .collect();
    let resp = proto::TopicListResponse { topics: infos };
    Ok(ServerEnvelope {
        r#type: ServerMsgType::TopicListResponse as i32,
        request_id: 0,
        payload: resp.encode_to_vec(),
        error: String::new(),
    })
}

async fn handle_create_topic(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    require_role(state, &user_id, MemberRole::Admin).await?;

    let req = proto::CreateTopicRequest::decode(payload)?;
    if req.name.trim().is_empty() {
        return Ok(err_env("话题名称不能为空"));
    }
    let topic_type = proto_topic_type_to_storage(req.r#type);
    // AV 话题需服务器已配置 LiveKit
    if topic_type == TopicType::Av {
        let meta = state.storage.get_server_meta().await?;
        if meta.map(|m| m.livekit_url.is_empty()).unwrap_or(true) {
            return Ok(err_env("服务器未配置 LiveKit，无法创建音视频话题"));
        }
    }
    let topic = storage::Topic {
        topic_id: format!("t-{}", unique_id()),
        name: req.name.clone(),
        description: req.description.clone(),
        topic_type,
        permission: proto_permission_to_storage(req.permission),
        sort_order: 0,
        push_enabled: false,
    };
    state.storage.create_topic(&topic).await?;
    info!(user_id = %user_id, topic = %topic.topic_id, "创建话题");
    broadcast_simple(state, ServerMsgType::TopicUpdated, vec![]);
    Ok(ok_env())
}

async fn handle_update_topic(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    require_role(state, &user_id, MemberRole::Admin).await?;

    let req = proto::UpdateTopicRequest::decode(payload)?;
    let topic = storage::Topic {
        topic_id: req.topic_id.clone(),
        name: req.name.clone(),
        description: req.description.clone(),
        topic_type: proto_topic_type_to_storage(req.r#type),
        permission: proto_permission_to_storage(req.permission),
        sort_order: 0,
        push_enabled: false,
    };
    state.storage.update_topic(&topic).await?;
    info!(user_id = %user_id, topic = %req.topic_id, "编辑话题");
    broadcast_simple(state, ServerMsgType::TopicUpdated, vec![]);
    Ok(ok_env())
}

async fn handle_delete_topic(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    require_role(state, &user_id, MemberRole::Admin).await?;

    let req = proto::DeleteTopicRequest::decode(payload)?;
    state.storage.delete_topic(&req.topic_id).await?;
    info!(user_id = %user_id, topic = %req.topic_id, "删除话题");
    broadcast_simple(state, ServerMsgType::TopicUpdated, vec![]);
    Ok(ok_env())
}

async fn handle_reorder_topics(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    require_role(state, &user_id, MemberRole::Admin).await?;

    let req = proto::ReorderTopicsRequest::decode(payload)?;
    state.storage.reorder_topics(&req.topic_ids).await?;
    info!(user_id = %user_id, "话题排序");
    broadcast_simple(state, ServerMsgType::TopicUpdated, vec![]);
    Ok(ok_env())
}

// ---- 审批 handler ----

async fn handle_list_join_requests(
    state: &Arc<AppState>,
    current_user: &Option<String>,
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    require_role(state, &user_id, MemberRole::Admin).await?;

    let requests = state.storage.list_join_requests().await?;
    let infos: Vec<proto::JoinRequestInfo> = requests
        .into_iter()
        .map(|r| proto::JoinRequestInfo {
            request_id: r.request_id,
            user_id: r.user_id,
            display_name: r.display_name,
            reason: r.reason,
            push_service_url: r.push_service_url,
            status: join_status_to_proto(r.status),
            created_at: r.created_at,
        })
        .collect();

    let resp = proto::JoinRequestListResponse { requests: infos };
    Ok(ServerEnvelope {
        r#type: ServerMsgType::JoinRequestListResponse as i32,
        request_id: 0,
        payload: resp.encode_to_vec(),
        error: String::new(),
    })
}

async fn handle_process_join_request(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let operator = current_user.clone().unwrap_or_default();
    require_role(state, &operator, MemberRole::Admin).await?;

    let req = proto::ProcessJoinRequest::decode(payload)?;
    let jr = match state.storage.get_join_request(&req.request_id).await? {
        Some(j) => j,
        None => return Ok(err_env("申请不存在")),
    };
    if jr.status != storage::JoinStatus::Pending {
        return Ok(err_env("申请已处理"));
    }

    if req.approve {
        // 同意：更新状态 + 加入成员（同一逻辑）
        state
            .storage
            .set_join_request_status(&req.request_id, storage::JoinStatus::Approved)
            .await?;
        let is_owner = state.storage.list_members().await?.is_empty();
        let member = storage::Member {
            user_id: jr.user_id.clone(),
            display_name: jr.display_name.clone(),
            avatar_seed: String::new(),
            role: if is_owner {
                MemberRole::Owner
            } else {
                MemberRole::Member
            },
            muted: false,
            banned: false,
            server_nickname: None,
            server_avatar: None,
            push_service_url: jr.push_service_url.clone(),
            is_bot: false,
            joined_at: lonisle_core::device::current_unix_time(),
            // 主公钥在该成员下次 Hello 握手时补录（join_requests 不存主公钥）
            master_pubkey: vec![],
        };
        state.storage.upsert_member(&member).await?;
        info!(operator = %operator, user_id = %jr.user_id, "审批通过加入申请");

        // 离线推送：向被审批用户登记的推送服务发送"审批通过"唤醒（免内容）
        // F-PUSH-7：仅离线成员走推送（在线成员由 WebSocket 实时收到审批结果）
        if !jr.push_service_url.is_empty() && !state.is_online(&jr.user_id).await {
            let server_name = state
                .storage
                .get_server_meta()
                .await
                .ok()
                .flatten()
                .map(|meta| meta.name)
                .unwrap_or_default();
            crate::push_client::fire_push(
                jr.push_service_url.clone(),
                state.server_id(),
                state.keypair.secret_bytes(),
                jr.user_id.clone(),
                "你的加入申请已通过".to_string(),
                Some(server_name),
            );
        }
    } else {
        state
            .storage
            .set_join_request_status(&req.request_id, storage::JoinStatus::Rejected)
            .await?;
        info!(operator = %operator, user_id = %jr.user_id, "拒绝加入申请");
    }

    // 广播审批结果（含 request_id + 结果）
    let updated = proto::JoinRequestInfo {
        request_id: jr.request_id.clone(),
        user_id: jr.user_id.clone(),
        display_name: jr.display_name,
        reason: jr.reason,
        push_service_url: jr.push_service_url,
        status: if req.approve {
            proto::JoinStatus::Approved as i32
        } else {
            proto::JoinStatus::Rejected as i32
        },
        created_at: jr.created_at,
    };
    broadcast_simple(state, ServerMsgType::JoinRequestUpdated, updated.encode_to_vec());

    Ok(ok_env())
}

async fn handle_ignore_join_request(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let operator = current_user.clone().unwrap_or_default();
    require_role(state, &operator, MemberRole::Admin).await?;

    let req = proto::IgnoreJoinRequest::decode(payload)?;
    state
        .storage
        .set_join_request_status(&req.request_id, storage::JoinStatus::Ignored)
        .await?;
    info!(operator = %operator, request = %req.request_id, "忽略加入申请");
    Ok(ok_env())
}

// ---- 成员管理 handler ----

async fn handle_set_member_role(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let operator = current_user.clone().unwrap_or_default();
    require_role(state, &operator, MemberRole::Admin).await?;

    let req = proto::SetMemberRoleRequest::decode(payload)?;
    let role = proto_role_to_storage(req.role);
    state.storage.set_member_role(&req.user_id, role).await?;
    info!(operator = %operator, target = %req.user_id, role = ?role, "设置成员角色");
    broadcast_simple(state, ServerMsgType::MemberUpdated, vec![]);
    Ok(ok_env())
}

async fn handle_set_mute(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let operator = current_user.clone().unwrap_or_default();
    require_role(state, &operator, MemberRole::Admin).await?;

    let req = proto::SetMuteRequest::decode(payload)?;
    state.storage.set_member_muted(&req.user_id, req.muted).await?;
    info!(operator = %operator, target = %req.user_id, muted = req.muted, "设置禁言");
    broadcast_simple(state, ServerMsgType::MemberUpdated, vec![]);
    Ok(ok_env())
}

async fn handle_kick_member(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let operator = current_user.clone().unwrap_or_default();
    require_role(state, &operator, MemberRole::Admin).await?;

    let req = proto::KickMemberRequest::decode(payload)?;
    state.storage.remove_member(&req.user_id).await?;
    info!(operator = %operator, target = %req.user_id, "踢出成员");
    // F-JOIN-6：广播带受害者信息，客户端据此向受害者本人提示"被移出"
    notify_member_removal(state, &req.user_id, "你已被管理员移出该服务器").await;
    broadcast_simple(state, ServerMsgType::MemberUpdated, vec![]);
    Ok(ok_env())
}

async fn handle_set_ban(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let operator = current_user.clone().unwrap_or_default();
    require_role(state, &operator, MemberRole::Admin).await?;

    let req = proto::SetBanRequest::decode(payload)?;
    state.storage.set_member_banned(&req.user_id, req.banned).await?;
    info!(operator = %operator, target = %req.user_id, banned = req.banned, "封禁/解封成员");
    // F-JOIN-6：封禁时向受害者本人定向提示
    if req.banned {
        notify_member_removal(state, &req.user_id, "你已被该服务器封禁").await;
    }
    broadcast_simple(state, ServerMsgType::MemberUpdated, vec![]);
    Ok(ok_env())
}

// ---- 资料与设置 handler ----

async fn handle_update_server_profile(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    let req = proto::UpdateServerProfileRequest::decode(payload)?;

    // optional 字段：None = 未携带（不动该列），Some("") = 清除覆盖
    let nickname = req.server_nickname.as_deref();
    let avatar = req.server_avatar.as_deref();
    state
        .storage
        .update_server_profile(&user_id, nickname, avatar)
        .await?;
    info!(user_id = %user_id, "更新服务器内资料");
    broadcast_simple(state, ServerMsgType::MemberUpdated, vec![]);
    Ok(ok_env())
}

async fn handle_update_server_settings(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let operator = current_user.clone().unwrap_or_default();
    require_role(state, &operator, MemberRole::Admin).await?;

    let req = proto::UpdateServerSettingsRequest::decode(payload)?;
    let mut meta = state
        .storage
        .get_server_meta()
        .await?
        .unwrap_or(storage::ServerMeta {
            server_id: state.server_id(),
            name: "LonIsle Server".into(),
            description: String::new(),
            strategy: storage::JoinStrategy::Approval,
            migration_target_address: String::new(),
            migration_target_fingerprint: String::new(),
            migration_signature: String::new(),
            rate_limit_per_minute: 0,
            max_attachment_size: 0,
            attachment_quota: 0,
            mention_read_enabled: false,
            livekit_url: String::new(),
            livekit_api_key: String::new(),
            livekit_api_secret: String::new(),
            icon: String::new(),
        });
    if !req.name.is_empty() {
        meta.name = req.name;
    }
    meta.description = req.description;
    meta.strategy = match req.strategy {
        // proto 编号：1=APPROVAL 2=OPEN 3=INVITE_ONLY
        2 => storage::JoinStrategy::Open,
        3 => storage::JoinStrategy::InviteOnly,
        _ => storage::JoinStrategy::Approval,
    };
    state.storage.set_server_meta(&meta).await?;
    info!(operator = %operator, "更新服务器设置");
    Ok(ok_env())
}

async fn handle_leave_server(
    state: &Arc<AppState>,
    current_user: &Option<String>,
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    state.storage.remove_member(&user_id).await?;
    info!(user_id = %user_id, "退出服务器");
    broadcast_simple(state, ServerMsgType::MemberUpdated, vec![]);
    Ok(ok_env())
}

// ---- 消息编辑/删除 handler ----

async fn handle_edit_message(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    current_device: &Option<Vec<u8>>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    let req = proto::EditMessageRequest::decode(payload)?;

    // 编辑请求设备签名验证（F-ID-4；Bot 连接由 Token 认证兜底）
    if let Some(device_pubkey) = current_device {
        if verify_edit_message(&req, device_pubkey).is_err() {
            warn!(user_id = %user_id, msg_id = %req.msg_id, "编辑消息签名验证失败");
            return Ok(err_env("签名验证失败"));
        }
    }

    let existing = state
        .storage
        .get_message_by_id(&req.topic_id, &req.msg_id)
        .await?;
    let existing = match existing {
        Some(m) => m,
        None => return Ok(err_env("消息不存在")),
    };
    // 仅作者可编辑
    if existing.author_id != user_id {
        return Ok(err_env("无权编辑他人消息"));
    }
    if existing.deleted {
        return Ok(err_env("消息已删除"));
    }

    // 编辑 = 删旧行 + 新序号事件行（F-MSG-13）
    let edited = state
        .storage
        .edit_message(&req.topic_id, &req.msg_id, &req.new_text)
        .await?;

    // 广播编辑事件（新 seq，edited=true）
    let broadcast_msg = proto::BroadcastMessage {
        seq: edited.seq,
        topic_id: edited.topic_id.clone(),
        msg_id: edited.msg_id.clone(),
        author_id: edited.author_id.clone().into_bytes(),
        device_id: edited.device_id.clone(),
        author_name: edited.author_name.clone(),
        server_ts: edited.server_ts,
        content: Some(proto::MessageContent {
            text: edited.content_text.clone(),
            attachment: storage::attachment_from_json(&edited.attachment_json),
            encrypted: vec![],
        }),
        edited: true,
        deleted: false,
        mentions: edited.mentions.clone(),
        reactions: vec![],
        reply_to: edited.reply_to.clone(),
    };
    broadcast_simple(
        state,
        ServerMsgType::Broadcast,
        broadcast_msg.encode_to_vec(),
    );
    info!(user_id = %user_id, msg_id = %req.msg_id, "编辑消息");
    Ok(ok_env())
}

async fn handle_delete_message(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    current_device: &Option<Vec<u8>>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    let req = proto::DeleteMessageRequest::decode(payload)?;

    // 删除请求设备签名验证（F-ID-4；Bot 连接由 Token 认证兜底）
    if let Some(device_pubkey) = current_device {
        if verify_delete_message(&req, device_pubkey).is_err() {
            warn!(user_id = %user_id, msg_id = %req.msg_id, "删除消息签名验证失败");
            return Ok(err_env("签名验证失败"));
        }
    }

    let existing = state
        .storage
        .get_message_by_id(&req.topic_id, &req.msg_id)
        .await?;
    let existing = match existing {
        Some(m) => m,
        None => return Ok(err_env("消息不存在")),
    };
    // 作者或管理员可删除
    let member = state.storage.get_member(&user_id).await?;
    let is_admin = member.map(|m| m.role >= MemberRole::Admin).unwrap_or(false);
    if existing.author_id != user_id && !is_admin {
        return Ok(err_env("无权删除他人消息"));
    }

    // 删除 = 硬删原行 + 新序号删除事件行（F-MSG-13/14）
    let tombstone = state
        .storage
        .delete_message(&req.topic_id, &req.msg_id)
        .await?;

    // 级联删除该消息的附件（F-MEDIA-9：管理员删消息连带清附件）
    if let Some(att) = storage::attachment_from_json(&existing.attachment_json) {
        if let Ok(Some(record)) = state.storage.get_attachment(&att.attachment_id).await {
            // 先删记录，再按引用计数删文件（附件去重：共享文件仅最后引用删除时落盘）
            let path = record.path.clone();
            let _ = state.storage.delete_attachment(&att.attachment_id).await;
            if state
                .storage
                .count_attachments_by_path(&path)
                .await
                .unwrap_or(1)
                == 0
            {
                let base = crate::attachments::state_dir(state);
                let _ = std::fs::remove_file(std::path::Path::new(&base).join(&path));
            }
        }
    }

    // 广播删除事件（新 seq，deleted=true，内容清空）
    let broadcast_msg = proto::BroadcastMessage {
        seq: tombstone.seq,
        topic_id: tombstone.topic_id.clone(),
        msg_id: tombstone.msg_id.clone(),
        author_id: tombstone.author_id.clone().into_bytes(),
        device_id: tombstone.device_id.clone(),
        author_name: tombstone.author_name.clone(),
        server_ts: tombstone.server_ts,
        content: Some(proto::MessageContent {
            text: String::new(),
            attachment: None,
            encrypted: vec![],
        }),
        edited: false,
        deleted: true,
        mentions: String::new(),
        reactions: vec![],
        reply_to: String::new(),
    };
    broadcast_simple(
        state,
        ServerMsgType::Broadcast,
        broadcast_msg.encode_to_vec(),
    );
    info!(user_id = %user_id, msg_id = %req.msg_id, "删除消息");
    Ok(ok_env())
}

// ---- Reaction（M5） ----

/// 添加表情回应
async fn handle_add_reaction(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    let req = proto::AddReactionRequest::decode(payload)?;

    state
        .storage
        .add_reaction(&req.topic_id, &req.msg_id, &user_id, &req.emoji)
        .await?;

    // 广播 Reaction 更新（复用 Broadcast 事件，仅携带 reactions 增量）
    broadcast_reaction(state, &req.topic_id, &req.msg_id).await?;
    Ok(ok_env())
}

/// 移除表情回应
async fn handle_remove_reaction(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    let req = proto::RemoveReactionRequest::decode(payload)?;

    state
        .storage
        .remove_reaction(&req.topic_id, &req.msg_id, &user_id, &req.emoji)
        .await?;

    broadcast_reaction(state, &req.topic_id, &req.msg_id).await?;
    Ok(ok_env())
}

// ---- 预密钥（M6 E2EE） ----

/// 上传预密钥束
async fn handle_upload_pre_keys(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    let req = proto::UploadPreKeysRequest::decode(payload)?;

    let bundle = req.bundle.ok_or_else(|| anyhow::anyhow!("缺少预密钥束"))?;
    let opks: Vec<Vec<u8>> = bundle.one_time_pre_keys.clone();

    state
        .storage
        .upload_pre_keys(
            &user_id,
            &bundle.identity_key,
            &bundle.signed_pre_key,
            &bundle.signed_pre_key_sig,
            &opks,
        )
        .await?;

    info!(user_id = %user_id, "上传预密钥束");
    Ok(ok_env())
}

/// 拉取某用户的预密钥束
async fn handle_fetch_pre_keys(
    state: &Arc<AppState>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let req = proto::FetchPreKeysRequest::decode(payload)?;

    let result = state.storage.fetch_pre_keys(&req.user_id).await?;
    match result {
        Some((identity_key, signed_pre_key, signed_pre_key_sig, opk)) => {
            let bundle = proto::PreKeyBundle {
                user_id: req.user_id.clone(),
                identity_key,
                signed_pre_key,
                signed_pre_key_sig,
                one_time_pre_keys: vec![opk],
            };
            let resp = proto::PreKeyBundleResponse { bundle: Some(bundle) };
            Ok(ServerEnvelope {
                r#type: ServerMsgType::PreKeyBundleResponse as i32,
                request_id: 0,
                payload: resp.encode_to_vec(),
                error: String::new(),
            })
        }
        None => Ok(err_env("该用户无预密钥")),
    }
}

// ---- RBAC 角色管理（P2） ----

/// 创建/更新角色（仅 Owner，需 MANAGE_ROLES 权限）
async fn handle_upsert_role(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    require_permission(state, &user_id, storage::perm::MANAGE_ROLES).await?;

    let req = proto::UpsertRoleRequest::decode(payload)?;
    if req.role_id.is_empty() || req.name.is_empty() {
        return Ok(err_env("角色 ID 和名称不能为空"));
    }
    // 内置角色不可覆盖
    if matches!(req.role_id.as_str(), "owner" | "admin" | "member") {
        return Ok(err_env("内置角色不可修改"));
    }

    let role = storage::RoleInfo {
        role_id: req.role_id,
        name: req.name,
        permissions: req.permissions,
    };
    state.storage.upsert_role(&role).await?;
    info!(user_id = %user_id, role_id = %role.role_id, "创建/更新角色");
    Ok(ok_env())
}

/// 删除角色（仅 Owner，需 MANAGE_ROLES）
async fn handle_delete_role(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    require_permission(state, &user_id, storage::perm::MANAGE_ROLES).await?;

    let req = proto::DeleteRoleRequest::decode(payload)?;
    state.storage.delete_role(&req.role_id).await?;
    info!(user_id = %user_id, role_id = %req.role_id, "删除角色");
    Ok(ok_env())
}

/// 列出所有角色。
async fn handle_list_roles(state: &Arc<AppState>) -> anyhow::Result<ServerEnvelope> {
    let roles = state.storage.list_roles().await?;
    let infos: Vec<proto::RoleInfo> = roles
        .into_iter()
        .map(|r| proto::RoleInfo {
            role_id: r.role_id,
            name: r.name,
            permissions: r.permissions,
        })
        .collect();
    let resp = proto::RoleListResponse { roles: infos };
    Ok(ServerEnvelope {
        r#type: ServerMsgType::RoleListResponse as i32,
        request_id: 0,
        payload: resp.encode_to_vec(),
        error: String::new(),
    })
}

/// 给成员分配角色（需 MANAGE_ROLES）
async fn handle_assign_role(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let operator = current_user.clone().unwrap_or_default();
    require_permission(state, &operator, storage::perm::MANAGE_ROLES).await?;

    let req = proto::AssignRoleRequest::decode(payload)?;
    state.storage.assign_role(&req.user_id, &req.role_id).await?;
    info!(operator = %operator, user_id = %req.user_id, role_id = %req.role_id, "分配角色");
    Ok(ok_env())
}

/// 移除成员角色（需 MANAGE_ROLES）
async fn handle_unassign_role(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let operator = current_user.clone().unwrap_or_default();
    require_permission(state, &operator, storage::perm::MANAGE_ROLES).await?;

    let req = proto::UnassignRoleRequest::decode(payload)?;
    state.storage.unassign_role(&req.user_id, &req.role_id).await?;
    info!(operator = %operator, user_id = %req.user_id, role_id = %req.role_id, "移除角色");
    Ok(ok_env())
}

// ---- @提及已读回执（P2） ----

/// 标记 @提及已读。
async fn handle_mark_mention_read(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    let req = proto::MarkMentionReadRequest::decode(payload)?;

    // 服务器开关检查：未开启则忽略
    if let Ok(Some(meta)) = state.storage.get_server_meta().await {
        if !meta.mention_read_enabled {
            return Ok(ok_env()); // 未开启，静默忽略
        }
    }

    state.storage.mark_mention_read(&req.msg_id, &user_id).await?;
    Ok(ok_env())
}

/// 查询某消息的已读列表。
async fn handle_mention_read_list(
    state: &Arc<AppState>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let req = proto::MentionReadListRequest::decode(payload)?;

    // 服务器开关检查：未开启则返回空列表（与 mark 行为一致）
    if let Ok(Some(meta)) = state.storage.get_server_meta().await {
        if !meta.mention_read_enabled {
            return Ok(ServerEnvelope {
                r#type: ServerMsgType::MentionReadListResponse as i32,
                request_id: 0,
                payload: proto::MentionReadListResponse {
                    user_id: vec![],
                    read_at: 0,
                }
                .encode_to_vec(),
                error: String::new(),
            });
        }
    }

    let users = state.storage.list_mention_reads(&req.msg_id).await?;
    let resp = proto::MentionReadListResponse {
        user_id: users,
        read_at: lonisle_core::device::current_unix_time(),
    };
    Ok(ServerEnvelope {
        r#type: ServerMsgType::MentionReadListResponse as i32,
        request_id: 0,
        payload: resp.encode_to_vec(),
        error: String::new(),
    })
}

// ---- 音视频话题（LiveKit，F-TOPIC-7） ----

/// 加入音视频话题：校验话题类型 + LiveKit 配置，签发短时 Token。
async fn handle_join_av(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    let req = proto::JoinAvRequest::decode(payload)?;

    // 校验话题存在且为 AV 类型
    let topic = match state.storage.get_topic(&req.topic_id).await? {
        Some(t) => t,
        None => return Ok(err_env("话题不存在")),
    };
    if topic.topic_type != TopicType::Av {
        return Ok(err_env("该话题不是音视频话题"));
    }

    // 校验 LiveKit 配置
    let meta = match state.storage.get_server_meta().await? {
        Some(m) => m,
        None => return Ok(err_env("服务器未配置 LiveKit")),
    };
    if meta.livekit_url.is_empty() || meta.livekit_api_secret.is_empty() {
        return Ok(err_env("服务器未配置 LiveKit"));
    }

    // 签发短时 Token（1 小时）
    let token = crate::livekit::issue_join_token(
        &meta.livekit_api_key,
        &meta.livekit_api_secret,
        &req.topic_id,
        &user_id,
        3600,
    )
    .map_err(|e| anyhow::anyhow!("签发 Token 失败：{e}"))?;

    let resp = proto::JoinAvResponse {
        url: meta.livekit_url.clone(),
        token,
    };
    info!(user_id = %user_id, topic_id = %req.topic_id, "加入音视频话题");
    Ok(ServerEnvelope {
        r#type: ServerMsgType::JoinAvResponse as i32,
        request_id: 0,
        payload: resp.encode_to_vec(),
        error: String::new(),
    })
}

/// 广播某消息的最新 reactions（通过 Broadcast 事件携带）
async fn broadcast_reaction(
    state: &Arc<AppState>,
    topic_id: &str,
    msg_id: &str,
) -> anyhow::Result<()> {
    let reactions = state.storage.get_reactions(msg_id).await?;
    let reaction_list: Vec<proto::Reaction> = reactions
        .into_iter()
        .map(|(emoji, users)| proto::Reaction {
            emoji,
            user_id: users,
        })
        .collect();

    let event = proto::BroadcastMessage {
        seq: 0, // Reaction 事件不占序号（M5 简化）
        topic_id: topic_id.to_string(),
        msg_id: msg_id.to_string(),
        author_id: vec![],
        device_id: String::new(),
        author_name: String::new(),
        server_ts: lonisle_core::device::current_unix_time(),
        content: None,
        edited: false,
        deleted: false,
        mentions: String::new(),
        reactions: reaction_list,
        reply_to: String::new(),
    };
    broadcast_simple(state, ServerMsgType::Broadcast, event.encode_to_vec());
    Ok(())
}

// ---- 多设备（M3） ----

/// 注册设备（携带设备证书 + 吊销证明）
async fn handle_register_device(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    let req = proto::RegisterDeviceRequest::decode(payload)?;

    let Some(device) = &req.device else {
        return Ok(err_env("缺少设备信息"));
    };

    // 验证设备证书链
    let cert = match proto::DeviceCert::decode(req.device_cert.as_slice()) {
        Ok(c) => c,
        Err(_) => return Ok(err_env("设备证书无效")),
    };

    // 验证证书 user_id 与当前用户一致
    if cert.user_id != user_id {
        return Ok(err_env("设备证书与身份不符"));
    }

    // 验证证书链（需主公钥，但服务器存的是 user_id 而非主公钥；
    // M3 简化：证书签名在 Hello 阶段已通过 identity.master_pubkey 验证，
    // 此处仅校验 user_id 匹配 + 未被吊销）
    if state
        .storage
        .is_revoked(&user_id, &cert.device_pubkey)
        .await?
    {
        return Ok(err_env("该设备已被吊销"));
    }

    // 落库设备
    let record = storage::DeviceRecord {
        user_id: user_id.clone(),
        device_id: device.device_id.clone(),
        device_name: device.device_name.clone(),
        platform: device.platform.clone(),
        pubkey: cert.device_pubkey.clone(),
        last_active: lonisle_core::device::current_unix_time(),
    };
    state.storage.upsert_device(&record).await?;

    // 处理客户端携带的吊销证明（F-DEV-8 跨成员被动学习）：
    // 逐条验签（主私钥签名），通过则并入本地吊销列表并广播，
    // 支持携带其他成员的吊销证明（不限于当前用户）。
    for proof in &req.revocations {
        // 需该成员的主公钥记录方可验签（未知成员无法信任，跳过）
        let master_pubkey = match state.storage.get_member(&proof.user_id).await {
            Ok(Some(m)) if m.master_pubkey.len() == 32 => m.master_pubkey,
            _ => {
                warn!(owner = %proof.user_id, "无主公钥记录，跳过吊销证明");
                continue;
            }
        };
        match lonisle_core::device::verify_revocation(proof, &master_pubkey) {
            Ok(()) => {
                let already = state
                    .storage
                    .is_revoked(&proof.user_id, &proof.device_pubkey)
                    .await?;
                state
                    .storage
                    .add_revocation(&proof.user_id, &proof.device_pubkey, proof.revoked_at)
                    .await?;
                if !already {
                    info!(
                        owner = %proof.user_id,
                        device_id = %lonisle_core::device::device_id_from_pubkey(&proof.device_pubkey),
                        "被动学习到吊销证明（验签通过）"
                    );
                    broadcast_device_change(
                        state,
                        &proof.user_id,
                        &proof.device_pubkey,
                        false,
                        Some(proof),
                    );
                }
            }
            Err(e) => {
                warn!(
                    owner = %proof.user_id,
                    error = %e,
                    "吊销证明验签失败，已忽略"
                );
            }
        }
    }

    // 广播成员设备变更事件（新增设备）
    broadcast_device_change(state, &user_id, &cert.device_pubkey, true, None);

    info!(user_id = %user_id, device_id = %device.device_id, "注册设备");
    Ok(ok_env())
}

/// 广播成员设备变更事件（吊销时携带证明原文，供其他成员被动学习，F-DEV-8）。
fn broadcast_device_change(
    state: &Arc<AppState>,
    user_id: &str,
    device_pubkey: &[u8],
    added: bool,
    proof: Option<&proto::RevocationProof>,
) {
    let event = proto::MemberDeviceChangeEvent {
        user_id: user_id.to_string(),
        device_id: lonisle_core::device::device_id_from_pubkey(device_pubkey),
        added,
        changed_at: lonisle_core::device::current_unix_time(),
        revocation_proof: proof.map(|p| p.encode_to_vec()).unwrap_or_default(),
    };
    broadcast_simple(
        state,
        ServerMsgType::MemberDeviceChange,
        event.encode_to_vec(),
    );
}

/// 列出当前用户的所有设备
async fn handle_list_devices(
    state: &Arc<AppState>,
    current_user: &Option<String>,
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    let devices = state.storage.list_devices(&user_id).await?;

    let infos: Vec<proto::DeviceInfo> = devices
        .iter()
        .map(|d| proto::DeviceInfo {
            device_id: d.device_id.clone(),
            device_name: d.device_name.clone(),
            platform: d.platform.clone(),
            last_active: d.last_active,
            is_current: false,
            device_pubkey: d.pubkey.clone(),
        })
        .collect();

    let resp = proto::DeviceListResponse { devices: infos };
    Ok(ServerEnvelope {
        r#type: ServerMsgType::DeviceListResponse as i32,
        request_id: 0,
        payload: resp.encode_to_vec(),
        error: String::new(),
    })
}

/// 撤销设备（携带吊销证明）
async fn handle_revoke_device(
    state: &Arc<AppState>,
    current_user: &Option<String>,
    payload: &[u8],
) -> anyhow::Result<ServerEnvelope> {
    let user_id = current_user.clone().unwrap_or_default();
    let req = proto::RevokeDeviceRequest::decode(payload)?;

    let Some(proof) = &req.proof else {
        return Ok(err_env("缺少吊销证明"));
    };

    // 校验吊销证明的 user_id 与当前用户一致
    if proof.user_id != user_id {
        return Ok(err_env("吊销证明与身份不符"));
    }

    // 吊销证明主私钥签名验证（F-DEV-4）：取成员主公钥验签
    let master_pubkey = state
        .storage
        .get_member(&user_id)
        .await?
        .map(|m| m.master_pubkey)
        .unwrap_or_default();
    if master_pubkey.len() != 32 {
        return Ok(err_env("无法验证吊销证明（缺少主公钥记录）"));
    }
    if lonisle_core::device::verify_revocation(proof, &master_pubkey).is_err() {
        warn!(user_id = %user_id, "吊销证明签名验证失败");
        return Ok(err_env("吊销证明签名验证失败"));
    }

    // 记录吊销
    state
        .storage
        .add_revocation(&user_id, &req.device_pubkey, proof.revoked_at)
        .await?;

    // 删除设备记录
    state
        .storage
        .remove_device(&user_id, &lonisle_core::device::device_id_from_pubkey(&req.device_pubkey))
        .await?;

    // 广播成员设备变更事件（撤销设备，携带证明供跨成员被动学习，F-DEV-8）
    broadcast_device_change(state, &user_id, &req.device_pubkey, false, Some(proof));

    info!(user_id = %user_id, "撤销设备");
    Ok(ok_env())
}

// ---- 权限与类型转换辅助 ----

/// 校验当前用户角色至少达到 min_role，否则返回错误信封。
async fn require_role(
    state: &Arc<AppState>,
    user_id: &str,
    min_role: MemberRole,
) -> anyhow::Result<()> {
    let member = state.storage.get_member(user_id).await?;
    match member {
        Some(m) if m.role >= min_role => Ok(()),
        Some(_) => Err(anyhow::anyhow!("无权限")),
        None => Err(anyhow::anyhow!("尚未加入服务器")),
    }
}

/// 校验用户是否拥有某权限位（RBAC，P2）。
/// 内置 Owner/Admin 拥有全部权限；其他成员查自定义角色权限位掩码。
async fn require_permission(
    state: &Arc<AppState>,
    user_id: &str,
    permission: u32,
) -> anyhow::Result<()> {
    let member = match state.storage.get_member(user_id).await? {
        Some(m) => m,
        None => return Err(anyhow::anyhow!("尚未加入服务器")),
    };
    // 内置 Owner/Admin 全权
    if member.role >= MemberRole::Admin {
        return Ok(());
    }
    // 查自定义角色权限位
    let perms = state.storage.get_member_permissions(user_id).await?;
    if perms & permission != 0 {
        Ok(())
    } else {
        Err(anyhow::anyhow!("无权限"))
    }
}

fn ok_env() -> ServerEnvelope {
    ServerEnvelope {
        r#type: ServerMsgType::Ok as i32,
        request_id: 0,
        payload: vec![],
        error: String::new(),
    }
}

/// 生成纳秒级唯一 ID（时间戳 + 随机后缀）。
fn unique_id() -> String {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("{}-{:x}", nanos, rand_suffix())
}

/// 简单随机后缀（基于时间与地址，M2 足够）。
fn rand_suffix() -> u64 {
    use std::hash::{Hash, Hasher};
    let mut h = std::collections::hash_map::DefaultHasher::new();
    std::time::SystemTime::now().hash(&mut h);
    std::process::id().hash(&mut h);
    h.finish()
}

fn proto_topic_type_to_storage(v: i32) -> TopicType {
    if v == proto::TopicType::Announcement as i32 {
        TopicType::Announcement
    } else if v == proto::TopicType::Av as i32 {
        TopicType::Av
    } else {
        TopicType::Text
    }
}

fn proto_permission_to_storage(v: i32) -> TopicPermission {
    if v == proto::TopicPermission::Readonly as i32 {
        TopicPermission::Readonly
    } else {
        TopicPermission::Public
    }
}

fn proto_role_to_storage(v: i32) -> MemberRole {
    match v {
        x if x == proto::MemberRole::Owner as i32 => MemberRole::Owner,
        x if x == proto::MemberRole::Admin as i32 => MemberRole::Admin,
        _ => MemberRole::Member,
    }
}

fn join_status_to_proto(s: storage::JoinStatus) -> i32 {
    match s {
        storage::JoinStatus::Approved => proto::JoinStatus::Approved as i32,
        storage::JoinStatus::Rejected => proto::JoinStatus::Rejected as i32,
        storage::JoinStatus::Ignored => proto::JoinStatus::Ignored as i32,
        storage::JoinStatus::Pending => proto::JoinStatus::Pending as i32,
    }
}

// ---- 辅助函数 ----

fn err_env(msg: &str) -> ServerEnvelope {
    ServerEnvelope {
        r#type: ServerMsgType::Error as i32,
        request_id: 0,
        payload: vec![],
        error: msg.to_string(),
    }
}

fn encode_error(req_id: u64, msg: &str) -> Vec<u8> {
    ServerEnvelope {
        r#type: ServerMsgType::Error as i32,
        request_id: req_id,
        payload: vec![],
        error: msg.to_string(),
    }
    .encode_to_vec()
}

async fn send_raw(
    sender: &mut futures_util::stream::SplitSink<WebSocket, WsMessage>,
    data: Vec<u8>,
) -> anyhow::Result<()> {
    sender.send(WsMessage::Binary(data)).await?;
    Ok(())
}
