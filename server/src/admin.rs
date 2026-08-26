//! 内嵌 Web 管理界面：静态资源 + 管理 API
//!
//! 静态资源经 rust-embed 编译进二进制，单文件部署。
//! M2 提供完整管理能力：状态、成员管理、审批、话题管理、服务器设置。

use std::sync::Arc;

use axum::extract::{Request, State};
use axum::middleware::Next;
use axum::response::{Html, IntoResponse, Response};
use axum::routing::{get, post};
use axum::Router;
use rust_embed::RustEmbed;
use serde::Deserialize;
use serde_json::json;

use crate::storage::{JoinStatus, JoinStrategy, MemberRole, Topic, TopicPermission, TopicType};
use crate::ws::AppState;

/// 广播话题变更事件（与 ws.rs 的 broadcast_simple 语义一致）。
/// 管理 API 改动话题后通知在线客户端刷新（F-TOPIC-3）。
fn broadcast_topic_updated(state: &Arc<AppState>) {
    use lonisle_core::proto::server_envelope::MsgType as ServerMsgType;
    let env = lonisle_core::proto::ServerEnvelope {
        r#type: ServerMsgType::TopicUpdated as i32,
        request_id: 0,
        payload: vec![],
        error: String::new(),
    };
    let _ = state.broadcast.send(env);
}

/// 广播成员列表变更（审批通过/移除成员等管理操作后调用，
/// 在线客户端实时刷新成员列表）。
fn broadcast_member_updated(state: &Arc<AppState>) {
    use lonisle_core::proto::server_envelope::MsgType as ServerMsgType;
    let env = lonisle_core::proto::ServerEnvelope {
        r#type: ServerMsgType::MemberUpdated as i32,
        request_id: 0,
        payload: vec![],
        error: String::new(),
    };
    let _ = state.broadcast.send(env);
}

/// 广播审批结果更新（F-JOIN：待审批客户端收到后自动重新 join 完成加入）。
fn broadcast_join_request_updated(
    state: &Arc<AppState>,
    jr: &crate::storage::JoinRequest,
    approved: bool,
) {
    use lonisle_core::proto::server_envelope::MsgType as ServerMsgType;
    use prost::Message as _;
    let info = lonisle_core::proto::JoinRequestInfo {
        request_id: jr.request_id.clone(),
        user_id: jr.user_id.clone(),
        display_name: jr.display_name.clone(),
        reason: jr.reason.clone(),
        push_service_url: jr.push_service_url.clone(),
        status: if approved {
            lonisle_core::proto::JoinStatus::Approved as i32
        } else {
            lonisle_core::proto::JoinStatus::Rejected as i32
        },
        created_at: jr.created_at,
    };
    let env = lonisle_core::proto::ServerEnvelope {
        r#type: ServerMsgType::JoinRequestUpdated as i32,
        request_id: 0,
        payload: info.encode_to_vec(),
        error: String::new(),
    };
    let _ = state.broadcast.send(env);
}

/// 内嵌静态资源
#[derive(RustEmbed)]
#[folder = "web/"]
struct WebAssets;

/// 高危操作路径（除 Bearer 鉴权外，还需 X-Admin-Confirm 二次确认，F-PERM-2b）
const HIGH_RISK_PATHS: &[&str] = &[
    "/api/clear/topic",
    "/api/clear/range",
    "/api/clear/user",
    "/api/clear/all",
    "/api/export",
    "/api/livekit/update",
    "/api/migrate/update",
];

/// 构建完整路由（WebSocket + 管理界面 + 管理 API）
pub fn build_router(state: Arc<AppState>) -> Router {
    let api = Router::new()
        .route("/api/status", get(api_status))
        .route("/api/members", get(api_members))
        .route("/api/members/role", post(api_set_member_role))
        .route("/api/members/mute", post(api_set_mute))
        .route("/api/members/ban", post(api_set_ban))
        .route("/api/members/kick", post(api_kick))
        .route("/api/join-requests", get(api_join_requests))
        .route("/api/join-requests/process", post(api_process_join_request))
        .route("/api/join-requests/ignore", post(api_ignore_join_request))
        .route("/api/invites", get(api_list_invites).post(api_create_invite))
        .route("/api/invites/revoke", post(api_revoke_invite))
        .route("/api/topics", get(api_topics))
        .route("/api/topics/create", post(api_create_topic))
        .route("/api/topics/update", post(api_update_topic))
        .route("/api/topics/delete", post(api_delete_topic))
        .route("/api/topics/reorder", post(api_reorder_topics))
        .route("/api/settings", get(api_settings))
        .route("/api/settings/update", post(api_update_settings))
        .route("/api/settings/icon", post(api_upload_icon))
        .route("/api/tls-config", get(api_get_tls_config).post(api_set_tls_config))
        .route("/api/migrate", get(api_get_migrate))
        .route("/api/migrate/update", post(api_set_migrate))
        .route("/api/limits", get(api_get_limits))
        .route("/api/limits/update", post(api_set_limits))
        .route("/api/mention-read", get(api_get_mention_read))
        .route("/api/mention-read/update", post(api_set_mention_read))
        .route("/api/bots", get(api_bot_list))
        .route("/api/bots/create", post(api_bot_create))
        .route("/api/bots/revoke", post(api_bot_revoke))
        .route("/api/bots/events", post(api_bot_events))
        .route("/api/livekit", get(api_get_livekit))
        .route("/api/livekit/update", post(api_set_livekit))
        .route("/api/export", get(api_export))
        .route("/api/export.zip", get(api_export_zip))
        .route("/api/clear/topic", post(api_clear_topic))
        .route("/api/clear/range", post(api_clear_range))
        .route("/api/clear/user", post(api_clear_user))
        .route("/api/clear/all", post(api_clear_all))
        // 表情包管理（F-STICKER：管理员增删改排序，成员只读）
        .route("/api/sticker-packs", get(api_list_sticker_packs))
        .route("/api/sticker-packs/save", post(api_save_sticker_pack))
        .route("/api/sticker-packs/delete", post(api_delete_sticker_pack))
        .route("/api/sticker-packs/reorder", post(api_reorder_sticker_packs))
        .route("/api/stickers/save", post(api_save_sticker))
        .route("/api/stickers/delete", post(api_delete_sticker))
        .route("/api/stickers/reorder", post(api_reorder_stickers))
        // 日志查看（管理界面「日志」页，读 {data_dir}/logs 最新文件尾部）
        .route("/api/logs", get(api_logs))
        .route_layer(axum::middleware::from_fn_with_state(
            state.clone(),
            admin_auth,
        ));

    Router::new()
        .route("/ws", axum::routing::get(crate::ws::ws_handler))
        .route("/icon", get(serve_icon))
        // 公开状态接口（目录/健康监测用，无需鉴权，F-DISC-3）
        .route("/status", get(public_status))
        .merge(api)
        .fallback_service(ServeWebAssets)
        .with_state(state)
}

/// 公开状态接口：供推送服务目录监测使用（人数/加入方式/名称/描述）。
async fn public_status(State(state): State<Arc<AppState>>) -> Html<String> {
    let meta = state.storage.get_server_meta().await.ok().flatten();
    let members = state.storage.list_members().await.unwrap_or_default();
    let body = json!({
        "server_id": state.server_id(),
        "name": meta.as_ref().map(|m| m.name.clone()).unwrap_or_default(),
        "description": meta.as_ref().map(|m| m.description.clone()).unwrap_or_default(),
        "join_mode": meta.as_ref().map(|m| strategy_to_str(m.strategy)).unwrap_or("approval"),
        "online": state.online.lock().await.len(),
        "total": members.len(),
        "protocol_version": lonisle_core::version::PROTOCOL_VERSION,
        "server_version": crate::SERVER_VERSION,
    });
    Html(body.to_string())
}

/// 管理 API 鉴权中间件：
/// - 所有 /api/* 需 `Authorization: Bearer <admin_token>`
/// - 高危操作另需 `X-Admin-Confirm: <admin_token>` 二次确认（F-PERM-2b）
/// - admin_token 为空（未配置）时放行并告警（仅限开发/测试）
async fn admin_auth(
    State(state): State<Arc<AppState>>,
    req: Request,
    next: Next,
) -> Response {
    if state.admin_token.is_empty() {
        return next.run(req).await;
    }

    let unauthorized = || {
        (
            axum::http::StatusCode::UNAUTHORIZED,
            axum::Json(json!({"ok": false, "error": "未授权：缺少或无效的管理 Token"})),
        )
            .into_response()
    };

    let bearer = req
        .headers()
        .get(axum::http::header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .unwrap_or("");
    if bearer != state.admin_token {
        return unauthorized();
    }

    // 高危操作二次确认：要求重复出示管理 Token
    if HIGH_RISK_PATHS.contains(&req.uri().path()) {
        let confirm = req
            .headers()
            .get("X-Admin-Confirm")
            .and_then(|v| v.to_str().ok())
            .unwrap_or("");
        if confirm != state.admin_token {
            return (
                axum::http::StatusCode::FORBIDDEN,
                axum::Json(json!({"ok": false, "error": "高危操作需要二次确认（X-Admin-Confirm）"})),
            )
                .into_response();
        }
    }

    next.run(req).await
}

// ---- 请求体 ----

#[derive(Deserialize)]
struct SetRoleBody {
    user_id: String,
    role: String,
}

#[derive(Deserialize)]
struct SetFlagBody {
    user_id: String,
    value: bool,
}

#[derive(Deserialize)]
struct KickBody {
    user_id: String,
}

#[derive(Deserialize)]
struct ProcessBody {
    request_id: String,
    approve: bool,
}

#[derive(Deserialize)]
struct IgnoreBody {
    request_id: String,
}

#[derive(Deserialize)]
struct TopicBody {
    topic_id: Option<String>,
    name: String,
    description: String,
    #[serde(rename = "type")]
    topic_type: String,
    permission: String,
    /// 话题推送开关：开启后该话题新消息推送所有客户端（F-PUSH-8）
    #[serde(default)]
    push_enabled: bool,
}

#[derive(Deserialize)]
struct DeleteTopicBody {
    topic_id: String,
}

#[derive(Deserialize)]
struct SettingsBody {
    name: String,
    description: String,
    strategy: String,
}

#[derive(Deserialize)]
struct ClearTopicBody {
    topic_id: String,
}

#[derive(Deserialize)]
struct ClearRangeBody {
    start: i64,
    end: i64,
}

#[derive(Deserialize)]
struct ClearUserBody {
    user_id: String,
}

#[derive(Deserialize)]
struct MigrateBody {
    target_address: String,
    target_fingerprint: String,
}

#[derive(Deserialize)]
struct LimitsBody {
    rate_limit_per_minute: u32,
    max_attachment_size: u64,
}

#[derive(Deserialize)]
struct MentionReadBody {
    enabled: bool,
}

// ---- Bot 管理（F-BOT） ----

#[derive(Deserialize)]
struct BotCreateBody {
    name: String,
}

#[derive(Deserialize)]
struct BotEventsBody {
    bot_id: String,
    /// 订阅事件（message/member/join/system；空数组 = 全部）
    events: Vec<String>,
}

#[derive(Deserialize)]
struct BotIdBody {
    bot_id: String,
}

/// 注册 Bot：生成一次性可见的 Token（仅 SHA-256 哈希落库）。
async fn api_bot_create(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<BotCreateBody>,
) -> Html<String> {
    if body.name.trim().is_empty() {
        return json_err("Bot 名称不能为空");
    }
    // 生成 bot_id 与 Token（128bit + 256bit）
    let mut id_bytes = [0u8; 16];
    let mut tok_bytes = [0u8; 32];
    use rand::RngCore;
    rand::rngs::OsRng.fill_bytes(&mut id_bytes);
    rand::rngs::OsRng.fill_bytes(&mut tok_bytes);
    let bot_id = format!(
        "bot-{}",
        id_bytes.iter().map(|b| format!("{b:02x}")).collect::<String>()
    );
    let token = tok_bytes.iter().map(|b| format!("{b:02x}")).collect::<String>();

    let token_hash = {
        use sha2::Digest;
        let mut h = sha2::Sha256::new();
        h.update(token.as_bytes());
        hex::encode(h.finalize())
    };

    if let Err(e) = state.storage.create_bot(&bot_id, body.name.trim(), &token_hash).await {
        return json_err(&e.to_string());
    }
    tracing::info!(bot_id = %bot_id, name = %body.name, "注册 Bot");
    Html(json!({
        "ok": true,
        "bot_id": bot_id,
        "token": token, // 明文仅此一次返回
    })
    .to_string())
}

/// 列出全部 Bot（不含 Token 明文）。
async fn api_bot_list(State(state): State<Arc<AppState>>) -> Html<String> {
    let bots = state.storage.list_bots().await.unwrap_or_default();
    Html(json!({
        "bots": bots.iter().map(|b| json!({
            "bot_id": b.bot_id,
            "name": b.name,
            "events": if b.events.is_empty() { "[]".to_string() } else { b.events.clone() },
            "created_at": b.created_at,
            "revoked": b.revoked,
        })).collect::<Vec<_>>(),
    })
    .to_string())
}

/// 撤销 Bot（Token 立即失效）。
async fn api_bot_revoke(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<BotIdBody>,
) -> Html<String> {
    if let Err(e) = state.storage.revoke_bot(&body.bot_id).await {
        return json_err(&e.to_string());
    }
    json_ok()
}

/// 设置 Bot 事件订阅过滤。
async fn api_bot_events(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<BotEventsBody>,
) -> Html<String> {
    let valid: Vec<&str> = body
        .events
        .iter()
        .map(|s| s.as_str())
        .filter(|s| matches!(*s, "message" | "member" | "join" | "system"))
        .collect();
    let events_json = serde_json::to_string(&valid).unwrap_or_default();
    if let Err(e) = state.storage.set_bot_events(&body.bot_id, &events_json).await {
        return json_err(&e.to_string());
    }
    json_ok()
}

#[derive(Deserialize)]
struct LiveKitBody {
    url: String,
    api_key: String,
    api_secret: String,
}

/// 静态资源处理器
#[derive(Clone)]
struct ServeWebAssets;

impl tower::Service<axum::http::Request<axum::body::Body>> for ServeWebAssets {
    type Response = axum::response::Response;
    type Error = std::convert::Infallible;
    type Future = std::future::Ready<Result<Self::Response, Self::Error>>;

    fn poll_ready(
        &mut self,
        _cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<Result<(), Self::Error>> {
        std::task::Poll::Ready(Ok(()))
    }

    fn call(&mut self, req: axum::http::Request<axum::body::Body>) -> Self::Future {
        let path = req.uri().path().trim_start_matches('/');
        // API 与附件路径不 fallback 到 index.html（避免遮蔽真实路由）
        if path.starts_with("api/") || path.starts_with("attachments/") {
            return std::future::ready(Ok(axum::response::Response::builder()
                .status(404)
                .body(axum::body::Body::from("not found"))
                .unwrap()));
        }
        let path = if path.is_empty() { "index.html" } else { path };

        let response = match WebAssets::get(path) {
            Some(content) => {
                let mime = mime_guess(path);
                axum::response::Response::builder()
                    .header("content-type", mime)
                    .body(axum::body::Body::from(content.data.into_owned()))
                    .unwrap()
            }
            None => {
                // 回退到 index.html（SPA 风格）
                match WebAssets::get("index.html") {
                    Some(content) => axum::response::Response::builder()
                        .header("content-type", "text/html; charset=utf-8")
                        .body(axum::body::Body::from(content.data.into_owned()))
                        .unwrap(),
                    None => axum::response::Response::builder()
                        .status(404)
                        .body(axum::body::Body::from("not found"))
                        .unwrap(),
                }
            }
        };

        std::future::ready(Ok(response))
    }
}

fn mime_guess(path: &str) -> &'static str {
    match path.rsplit('.').next().unwrap_or("") {
        "html" => "text/html; charset=utf-8",
        "css" => "text/css; charset=utf-8",
        "js" => "application/javascript; charset=utf-8",
        "json" => "application/json",
        "svg" => "image/svg+xml",
        "png" => "image/png",
        "ico" => "image/x-icon",
        _ => "application/octet-stream",
    }
}

/// 服务器状态 API
async fn api_status(State(state): State<Arc<AppState>>) -> Html<String> {
    let meta = state.storage.get_server_meta().await.ok().flatten();
    let member_count = state.storage.list_members().await.map(|m| m.len()).unwrap_or(0);

    let body = json!({
        "server_id": state.server_id(),
        "name": meta.as_ref().map(|m| m.name.clone()).unwrap_or_default(),
        "description": meta.as_ref().map(|m| m.description.clone()).unwrap_or_default(),
        "strategy": meta.as_ref().map(|m| strategy_to_str(m.strategy)).unwrap_or("approval"),
        "member_count": member_count,
        "online": state.online.lock().await.len(),
        "protocol_version": lonisle_core::version::PROTOCOL_VERSION,
        "server_version": crate::SERVER_VERSION,
    });

    Html(body.to_string())
}

/// 成员列表 API（含角色/禁言/封禁/覆盖）
async fn api_members(State(state): State<Arc<AppState>>) -> Html<String> {
    let members = state.storage.list_members().await.unwrap_or_default();
    let body = json!({
        "members": members.iter().map(|m| json!({
            "user_id": m.user_id,
            "display_name": m.effective_name(),
            "role": match m.role {
                crate::storage::MemberRole::Owner => "owner",
                crate::storage::MemberRole::Admin => "admin",
                crate::storage::MemberRole::Member => "member",
            },
            "is_owner": m.is_owner(),
            "muted": m.muted,
            "banned": m.banned,
            "joined_at": m.joined_at,
        })).collect::<Vec<_>>(),
    });

    Html(body.to_string())
}

// ---- 成员管理 API ----

async fn api_set_member_role(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<SetRoleBody>,
) -> Html<String> {
    let role = match body.role.as_str() {
        "owner" => MemberRole::Owner,
        "admin" => MemberRole::Admin,
        _ => MemberRole::Member,
    };
    let result = state.storage.set_member_role(&body.user_id, role).await;
    json_result(result)
}

async fn api_set_mute(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<SetFlagBody>,
) -> Html<String> {
    let result = state.storage.set_member_muted(&body.user_id, body.value).await;
    json_result(result)
}

async fn api_set_ban(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<SetFlagBody>,
) -> Html<String> {
    let result = state.storage.set_member_banned(&body.user_id, body.value).await;
    json_result(result)
}

async fn api_kick(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<KickBody>,
) -> Html<String> {
    let result = state.storage.remove_member(&body.user_id).await;
    json_result(result)
}

// ---- 审批 API ----

async fn api_join_requests(State(state): State<Arc<AppState>>) -> Html<String> {
    let requests = state.storage.list_join_requests().await.unwrap_or_default();
    let body = json!({
        "requests": requests.iter().map(|r| json!({
            "request_id": r.request_id,
            "user_id": r.user_id,
            "display_name": r.display_name,
            "reason": r.reason,
            "created_at": r.created_at,
        })).collect::<Vec<_>>(),
    });
    Html(body.to_string())
}

async fn api_process_join_request(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<ProcessBody>,
) -> Html<String> {
    let jr = match state.storage.get_join_request(&body.request_id).await {
        Ok(Some(j)) => j,
        Ok(None) => return json_err("申请不存在"),
        Err(e) => return json_err(&e.to_string()),
    };
    if body.approve {
        let _ = state
            .storage
            .set_join_request_status(&body.request_id, JoinStatus::Approved)
            .await;
        let is_owner = state.storage.list_members().await.map(|m| m.is_empty()).unwrap_or(false);
        let member = crate::storage::Member {
            user_id: jr.user_id.clone(),
            display_name: jr.display_name.clone(),
            avatar_seed: String::new(),
            role: if is_owner { MemberRole::Owner } else { MemberRole::Member },
            muted: false,
            banned: false,
            server_nickname: None,
            server_avatar: None,
            push_service_url: jr.push_service_url.clone(),
            is_bot: false,
            joined_at: lonisle_core::device::current_unix_time(),
            // 主公钥在该成员下次 Hello 握手时补录
            master_pubkey: vec![],
        };
        let _ = state.storage.upsert_member(&member).await;

        // 广播成员列表变更：在线客户端实时刷新成员列表
        broadcast_member_updated(&state);
        // 离线推送「审批通过」唤醒（F-PUSH-7：仅离线成员走推送，在线走广播）
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
        let _ = state
            .storage
            .set_join_request_status(&body.request_id, JoinStatus::Rejected)
            .await;
    }
    // 广播审批结果（待审批客户端收到后自动重新 join 完成加入/获知结果）
    broadcast_join_request_updated(&state, &jr, body.approve);
    json_ok()
}

async fn api_ignore_join_request(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<IgnoreBody>,
) -> Html<String> {
    let result = state
        .storage
        .set_join_request_status(&body.request_id, JoinStatus::Ignored)
        .await;
    json_result(result)
}

// ---- 话题管理 API ----

async fn api_topics(State(state): State<Arc<AppState>>) -> Html<String> {
    let topics = state.storage.list_topics().await.unwrap_or_default();
    let body = json!({
        "topics": topics.iter().map(|t| json!({
            "topic_id": t.topic_id,
            "name": t.name,
            "description": t.description,
            "type": topic_type_to_str(t.topic_type),
            "permission": permission_to_str(t.permission),
            "sort_order": t.sort_order,
            "push_enabled": t.push_enabled,
        })).collect::<Vec<_>>(),
    });
    Html(body.to_string())
}

async fn api_create_topic(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<TopicBody>,
) -> Html<String> {
    if body.name.trim().is_empty() {
        return json_err("话题名称不能为空");
    }
    let topic = Topic {
        topic_id: format!("t-{}", unique_id()),
        name: body.name,
        description: body.description,
        topic_type: str_to_topic_type(&body.topic_type),
        permission: str_to_permission(&body.permission),
        sort_order: 0,
        push_enabled: body.push_enabled,
    };
    let result = state.storage.create_topic(&topic).await;
    if result.is_ok() {
        broadcast_topic_updated(&state);
    }
    json_result(result)
}

async fn api_update_topic(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<TopicBody>,
) -> Html<String> {
    let Some(topic_id) = body.topic_id else {
        return json_err("缺少 topic_id");
    };
    let topic = Topic {
        topic_id,
        name: body.name,
        description: body.description,
        topic_type: str_to_topic_type(&body.topic_type),
        permission: str_to_permission(&body.permission),
        sort_order: 0,
        push_enabled: body.push_enabled,
    };
    let result = state.storage.update_topic(&topic).await;
    if result.is_ok() {
        broadcast_topic_updated(&state);
    }
    json_result(result)
}

async fn api_delete_topic(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<DeleteTopicBody>,
) -> Html<String> {
    let result = state.storage.delete_topic(&body.topic_id).await;
    if result.is_ok() {
        broadcast_topic_updated(&state);
    }
    json_result(result)
}

#[derive(Deserialize)]
struct ReorderTopicsBody {
    topic_ids: Vec<String>,
}

/// 话题排序（按给定顺序重排，F-TOPIC-2）
async fn api_reorder_topics(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<ReorderTopicsBody>,
) -> Html<String> {
    let result = state.storage.reorder_topics(&body.topic_ids).await;
    if result.is_ok() {
        broadcast_topic_updated(&state);
    }
    json_result(result)
}

// ---- 服务器设置 API ----

async fn api_settings(State(state): State<Arc<AppState>>) -> Html<String> {
    let meta = state.storage.get_server_meta().await.ok().flatten();
    let body = json!({
        "name": meta.as_ref().map(|m| m.name.clone()).unwrap_or_default(),
        "description": meta.as_ref().map(|m| m.description.clone()).unwrap_or_default(),
        "strategy": meta.as_ref().map(|m| strategy_to_str(m.strategy)).unwrap_or("approval"),
        "icon": meta.as_ref().map(|m| m.icon.clone()).unwrap_or_default(),
    });
    Html(body.to_string())
}

/// 上传服务器图标（F-PERM-2，multipart）：
/// 魔数校验图片格式，落盘 data_dir/server_icon.<ext>，
/// meta.icon 记录 "ext:时间戳" 版本标识（客户端据此失效重拉，走公开 GET /icon）
async fn api_upload_icon(
    State(state): State<Arc<AppState>>,
    mut multipart: axum::extract::Multipart,
) -> Html<String> {
    let mut data: Option<Vec<u8>> = None;
    while let Ok(Some(field)) = multipart.next_field().await {
        if field.name() == Some("file") {
            match field.bytes().await {
                Ok(b) => data = Some(b.to_vec()),
                Err(e) => return Html(json!({"ok": false, "error": e.to_string()}).to_string()),
            }
        }
    }
    let Some(data) = data else {
        return Html(json!({"ok": false, "error": "缺少文件"}).to_string());
    };
    if data.len() > 2 * 1024 * 1024 {
        return Html(json!({"ok": false, "error": "图标不能超过 2MB"}).to_string());
    }
    let ext = match sniff_image_ext(&data) {
        Some(e) => e,
        None => return Html(json!({"ok": false, "error": "仅支持 png/jpg/gif/webp"}).to_string()),
    };
    let path = std::path::Path::new(&state.data_dir).join(format!("server_icon.{ext}"));
    if let Err(e) = std::fs::write(&path, &data) {
        return Html(json!({"ok": false, "error": e.to_string()}).to_string());
    }
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    match state.storage.get_server_meta().await {
        Ok(Some(mut meta)) => {
            meta.icon = format!("{ext}:{ts}");
            let result = json_result(state.storage.set_server_meta(&meta).await);
            // 在线客户端实时刷新图标（F-PERM-2）
            crate::ws::broadcast_server_info(&state).await;
            result
        }
        _ => Html(json!({"ok": false, "error": "服务器元数据未初始化"}).to_string()),
    }
}

/// 查询当前 TLS 证书配置（证书/私钥路径 + HTTPS 是否使用外部证书）
async fn api_get_tls_config(State(state): State<Arc<AppState>>) -> Html<String> {
    match state.storage.get_tls_config().await {
        Ok((cert_path, key_path)) => {
            let external = !cert_path.is_empty() && !key_path.is_empty();
            Html(
                json!({
                    "ok": true,
                    "external": external,
                    "cert_path": cert_path,
                    "key_path": key_path,
                })
                .to_string(),
            )
        }
        Err(e) => Html(json!({"ok": false, "error": e.to_string()}).to_string()),
    }
}

#[derive(Deserialize)]
struct TlsConfigBody {
    cert_path: String,
    key_path: String,
}

/// 保存 TLS 证书路径（两字段同时为空 = 清空配置恢复自签；单字段空保留旧值）；重启生效
async fn api_set_tls_config(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<TlsConfigBody>,
) -> Html<String> {
    let old = match state.storage.get_tls_config().await {
        Ok(v) => v,
        Err(e) => return Html(json!({"ok": false, "error": e.to_string()}).to_string()),
    };
    let (cert_path, key_path) = if body.cert_path.trim().is_empty() && body.key_path.trim().is_empty()
    {
        // 显式清空：恢复自签证书
        (String::new(), String::new())
    } else {
        let cert_path = if body.cert_path.trim().is_empty() {
            old.0
        } else {
            body.cert_path.trim().to_string()
        };
        let key_path = if body.key_path.trim().is_empty() {
            old.1
        } else {
            body.key_path.trim().to_string()
        };
        (cert_path, key_path)
    };
    if let Err(e) = state.storage.set_tls_config(&cert_path, &key_path).await {
        return Html(json!({"ok": false, "error": e.to_string()}).to_string());
    }
    let external = !cert_path.is_empty() && !key_path.is_empty();
    if external {
        tracing::info!("TLS 证书路径已保存（cert: {cert_path}），重启后启用外部证书");
    } else {
        tracing::warn!("TLS 证书路径已清空，重启后回退自签证书");
    }
    Html(json!({"ok": true, "external": external}).to_string())
}

/// 图片魔数嗅探（png/jpg/gif/webp）
fn sniff_image_ext(data: &[u8]) -> Option<&'static str> {
    if data.len() < 12 {
        return None;
    }
    if data.starts_with(&[0x89, 0x50, 0x4E, 0x47]) {
        Some("png")
    } else if data.starts_with(&[0xFF, 0xD8]) {
        Some("jpg")
    } else if data.starts_with(b"GIF8") {
        Some("gif")
    } else if data.starts_with(b"RIFF") && &data[8..12] == b"WEBP" {
        Some("webp")
    } else {
        None
    }
}

/// 公开图标下载（无需管理 Token；客户端 TOFU 通道内获取）
pub async fn serve_icon(State(state): State<Arc<AppState>>) -> axum::response::Response {
    use axum::response::IntoResponse;
    let meta = state.storage.get_server_meta().await.ok().flatten();
    let Some(icon) = meta.map(|m| m.icon).filter(|s| !s.is_empty()) else {
        return axum::http::StatusCode::NOT_FOUND.into_response();
    };
    let ext = icon.split(':').next().unwrap_or("png");
    let path = std::path::Path::new(&state.data_dir).join(format!("server_icon.{ext}"));
    match std::fs::read(&path) {
        Ok(bytes) => {
            let mime = match ext {
                "jpg" => "image/jpeg",
                "gif" => "image/gif",
                "webp" => "image/webp",
                _ => "image/png",
            };
            (
                [(axum::http::header::CONTENT_TYPE, mime)],
                bytes,
            )
                .into_response()
        }
        Err(_) => axum::http::StatusCode::NOT_FOUND.into_response(),
    }
}

async fn api_update_settings(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<SettingsBody>,
) -> Html<String> {
    let mut meta = match state.storage.get_server_meta().await {
        Ok(Some(m)) => m,
        _ => crate::storage::ServerMeta {
            server_id: state.server_id(),
            name: String::new(),
            description: String::new(),
            strategy: JoinStrategy::Approval,
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
        },
    };
    if !body.name.is_empty() {
        meta.name = body.name;
    }
    meta.description = body.description;
    meta.strategy = str_to_strategy(&body.strategy);
    let result = json_result(state.storage.set_server_meta(&meta).await);
    // 在线客户端实时刷新服务器资料（F-PERM-2）
    crate::ws::broadcast_server_info(&state).await;
    result
}

// ---- 仅邀请模式邀请令牌（F-JOIN-5） ----

/// 列出全部邀请令牌（含使用/撤销状态；令牌明文仅创建时返回一次，列表脱敏）。
async fn api_list_invites(State(state): State<Arc<AppState>>) -> Html<String> {
    match state.storage.list_invites().await {
        Ok(invites) => {
            let body = json!({
                "invites": invites.iter().map(|i| json!({
                    // 脱敏：仅显示前 8 位（创建时完整返回过一次）
                    "token": if i.token.len() > 8 { format!("{}…", &i.token[..8]) } else { i.token.clone() },
                    "created_by": i.created_by,
                    "created_at": i.created_at,
                    "used": i.used,
                    "revoked": i.revoked,
                })).collect::<Vec<_>>(),
            });
            Html(body.to_string())
        }
        Err(e) => Html(json!({"error": e.to_string()}).to_string()),
    }
}

/// 创建一次性邀请令牌（完整令牌仅此一次返回）。
async fn api_create_invite(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<InviteBody>,
) -> Html<String> {
    match state.storage.create_invite(&body.created_by).await {
        Ok(token) => Html(json!({"ok": true, "token": token}).to_string()),
        Err(e) => Html(json!({"error": e.to_string()}).to_string()),
    }
}

/// 撤销邀请令牌。
async fn api_revoke_invite(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<InviteBody>,
) -> Html<String> {
    if body.token.is_empty() {
        return Html(json!({"error": "token 不能为空"}).to_string());
    }
    match state.storage.revoke_invite(&body.token).await {
        Ok(()) => Html(json!({"ok": true}).to_string()),
        Err(e) => Html(json!({"error": e.to_string()}).to_string()),
    }
}

#[derive(Deserialize)]
struct InviteBody {
    #[serde(default)]
    token: String,
    #[serde(default)]
    created_by: String,
}

// ---- 服务器迁移/限制（P1） ----

/// 读取迁移配置。
async fn api_get_migrate(State(state): State<Arc<AppState>>) -> Html<String> {
    let meta = state.storage.get_server_meta().await.ok().flatten();
    let body = json!({
        "target_address": meta.as_ref().map(|m| m.migration_target_address.clone()).unwrap_or_default(),
        "target_fingerprint": meta.as_ref().map(|m| m.migration_target_fingerprint.clone()).unwrap_or_default(),
    });
    Html(body.to_string())
}

/// 设置迁移配置。
async fn api_set_migrate(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<MigrateBody>,
) -> Html<String> {
    let mut meta = match state.storage.get_server_meta().await {
        Ok(Some(m)) => m,
        _ => crate::storage::ServerMeta {
            server_id: state.server_id(),
            name: String::new(),
            description: String::new(),
            strategy: JoinStrategy::Approval,
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
        },
    };
    meta.migration_target_address = body.target_address;
    meta.migration_target_fingerprint = body.target_fingerprint;
    // F-JOIN-8：迁移公告用旧服务器私钥签名（防中间人替换迁移目标）
    meta.migration_signature = if meta.migration_target_address.is_empty() {
        String::new()
    } else {
        let payload = migration_signing_payload(
            &meta.migration_target_address,
            &meta.migration_target_fingerprint,
            &state.server_id(),
        );
        hex::encode(state.keypair.sign(payload.as_bytes()))
    };
    json_result(state.storage.set_server_meta(&meta).await)
}

/// 迁移公告签名载荷（与客户端验证约定一致的固定字段序）
pub fn migration_signing_payload(address: &str, fingerprint: &str, server_id: &str) -> String {
    format!("lonisle-migrate-v1\0{address}\0{fingerprint}\0{server_id}")
}

/// 读取服务器限制配置。
async fn api_get_limits(State(state): State<Arc<AppState>>) -> Html<String> {
    let meta = state.storage.get_server_meta().await.ok().flatten();
    let body = json!({
        "rate_limit_per_minute": meta.as_ref().map(|m| m.rate_limit_per_minute).unwrap_or(0),
        "max_attachment_size": meta.as_ref().map(|m| m.max_attachment_size).unwrap_or(0),
    });
    Html(body.to_string())
}

/// 设置服务器限制配置。
async fn api_set_limits(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<LimitsBody>,
) -> Html<String> {
    let mut meta = match state.storage.get_server_meta().await {
        Ok(Some(m)) => m,
        _ => crate::storage::ServerMeta {
            server_id: state.server_id(),
            name: String::new(),
            description: String::new(),
            strategy: JoinStrategy::Approval,
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
        },
    };
    meta.rate_limit_per_minute = body.rate_limit_per_minute;
    meta.max_attachment_size = body.max_attachment_size;
    json_result(state.storage.set_server_meta(&meta).await)
}

// ---- @提及已读开关（P2） ----

/// 读取已读开关。
async fn api_get_mention_read(State(state): State<Arc<AppState>>) -> Html<String> {
    let meta = state.storage.get_server_meta().await.ok().flatten();
    let body = json!({
        "enabled": meta.as_ref().map(|m| m.mention_read_enabled).unwrap_or(false),
    });
    Html(body.to_string())
}

/// 设置已读开关。
async fn api_set_mention_read(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<MentionReadBody>,
) -> Html<String> {
    let mut meta = match state.storage.get_server_meta().await {
        Ok(Some(m)) => m,
        _ => crate::storage::ServerMeta {
            server_id: state.server_id(),
            name: String::new(),
            description: String::new(),
            strategy: JoinStrategy::Approval,
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
        },
    };
    meta.mention_read_enabled = body.enabled;
    json_result(state.storage.set_server_meta(&meta).await)
}

// ---- LiveKit 配置（音视频话题） ----

/// 读取 LiveKit 配置（api_secret 脱敏）。
async fn api_get_livekit(State(state): State<Arc<AppState>>) -> Html<String> {
    let meta = state.storage.get_server_meta().await.ok().flatten();
    let body = json!({
        "url": meta.as_ref().map(|m| m.livekit_url.clone()).unwrap_or_default(),
        "api_key": meta.as_ref().map(|m| m.livekit_api_key.clone()).unwrap_or_default(),
        "api_secret": "", // 脱敏：不返回 secret
    });
    Html(body.to_string())
}

/// 设置 LiveKit 配置。
async fn api_set_livekit(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<LiveKitBody>,
) -> Html<String> {
    let mut meta = match state.storage.get_server_meta().await {
        Ok(Some(m)) => m,
        _ => crate::storage::ServerMeta {
            server_id: state.server_id(),
            name: String::new(),
            description: String::new(),
            strategy: JoinStrategy::Approval,
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
        },
    };
    meta.livekit_url = body.url;
    meta.livekit_api_key = body.api_key;
    // api_secret 仅在非空时更新（避免误覆盖）
    if !body.api_secret.is_empty() {
        meta.livekit_api_secret = body.api_secret;
    }
    json_result(state.storage.set_server_meta(&meta).await)
}

// ---- 数据导出/清除（P1） ----

/// 导出服务器全量数据（消息/成员/话题/配置）为 JSON。
async fn api_export(State(state): State<Arc<AppState>>) -> Html<String> {
    let messages = state.storage.list_all_messages().await.unwrap_or_default();
    let members = state.storage.list_members().await.unwrap_or_default();
    let topics = state.storage.list_topics().await.unwrap_or_default();
    let meta = state.storage.get_server_meta().await.ok().flatten();

    let body = json!({
        "server": {
            "server_id": state.server_id(),
            "name": meta.as_ref().map(|m| m.name.clone()).unwrap_or_default(),
            "description": meta.as_ref().map(|m| m.description.clone()).unwrap_or_default(),
            "strategy": meta.as_ref().map(|m| strategy_to_str(m.strategy)).unwrap_or("approval"),
        },
        "topics": topics.iter().map(|t| json!({
            "topic_id": t.topic_id,
            "name": t.name,
            "description": t.description,
            "type": topic_type_to_str(t.topic_type),
            "permission": permission_to_str(t.permission),
            "sort_order": t.sort_order,
        })).collect::<Vec<_>>(),
        "members": members.iter().map(|m| json!({
            "user_id": m.user_id,
            "display_name": m.display_name,
            "role": role_to_str(m.role),
            "joined_at": m.joined_at,
        })).collect::<Vec<_>>(),
        "messages": messages.iter().map(|m| json!({
            "seq": m.seq,
            "topic_id": m.topic_id,
            "msg_id": m.msg_id,
            "author_id": m.author_id,
            "author_name": m.author_name,
            "server_ts": m.server_ts,
            "content": m.content_text,
            "edited": m.edited,
            "deleted": m.deleted,
        })).collect::<Vec<_>>(),
    });

    Html(body.to_string())
}

/// 导出全量数据为 zip 包（F-PERM-2a：JSON + 附件文件）。
/// GET /api/export.zip
async fn api_export_zip(State(state): State<Arc<AppState>>) -> axum::response::Response {
    use std::io::Write as _;

    // 复用 JSON 导出逻辑
    let json_body = {
        let messages = state.storage.list_all_messages().await.unwrap_or_default();
        let members = state.storage.list_members().await.unwrap_or_default();
        let topics = state.storage.list_topics().await.unwrap_or_default();
        let meta = state.storage.get_server_meta().await.ok().flatten();
        json!({
            "server": {
                "server_id": state.server_id(),
                "name": meta.as_ref().map(|m| m.name.clone()).unwrap_or_default(),
            },
            "topics": topics.iter().map(|t| json!({"topic_id": t.topic_id, "name": t.name})).collect::<Vec<_>>(),
            "members": members.iter().map(|m| json!({
                "user_id": m.user_id, "display_name": m.display_name, "role": role_to_str(m.role),
            })).collect::<Vec<_>>(),
            "messages": messages.iter().map(|m| json!({
                "seq": m.seq, "topic_id": m.topic_id, "msg_id": m.msg_id,
                "author_id": m.author_id, "author_name": m.author_name,
                "server_ts": m.server_ts, "content": m.content_text,
                "edited": m.edited, "deleted": m.deleted,
                "attachment": m.attachment_json,
            })).collect::<Vec<_>>(),
        })
        .to_string()
    };

    let mut zip = zip::ZipWriter::new(std::io::Cursor::new(Vec::new()));
    let options =
        zip::write::SimpleFileOptions::default().compression_method(zip::CompressionMethod::Deflated);

    // data.json
    if zip.start_file("data.json", options).is_ok() {
        let _ = zip.write_all(json_body.as_bytes());
    }

    // 附件目录（全部附件文件打包）
    let attachments = state.storage.list_all_attachments().await.unwrap_or_default();
    let base = crate::attachments::state_dir(&state);
    for att in attachments {
        let full = std::path::Path::new(&base).join(&att.path);
        if let Ok(data) = std::fs::read(&full) {
            if zip.start_file(format!("attachments/{}", att.attachment_id), options).is_ok() {
                let _ = zip.write_all(&data);
            }
        }
    }

    match zip.finish() {
        Ok(cursor) => axum::response::Response::builder()
            .header("content-type", "application/zip")
            .header(
                "content-disposition",
                format!("attachment; filename=\"lonisle-export-{}.zip\"", state.server_id()),
            )
            .body(axum::body::Body::from(cursor.into_inner()))
            .unwrap(),
        Err(e) => axum::response::Response::builder()
            .status(axum::http::StatusCode::INTERNAL_SERVER_ERROR)
            .header("content-type", "application/json")
            .body(axum::body::Body::from(format!("{{\"ok\":false,\"error\":\"打包失败: {e}\"}}")))
            .unwrap(),
    }
}

/// 按话题清除消息（连带清附件）。
async fn api_clear_topic(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<ClearTopicBody>,
) -> Html<String> {
    let records = match state.storage.delete_messages_by_topic(&body.topic_id).await {
        Ok(r) => r,
        Err(e) => return json_err(&e.to_string()),
    };
    cleanup_attachments_for_messages(&state, &records).await;
    json_ok()
}

/// 按时间段清除消息。
async fn api_clear_range(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<ClearRangeBody>,
) -> Html<String> {
    let records = match state.storage.delete_messages_in_range(body.start, body.end).await {
        Ok(r) => r,
        Err(e) => return json_err(&e.to_string()),
    };
    cleanup_attachments_for_messages(&state, &records).await;
    json_ok()
}

/// 清除某成员的全部消息。
async fn api_clear_user(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<ClearUserBody>,
) -> Html<String> {
    let records = match state.storage.delete_messages_by_user(&body.user_id).await {
        Ok(r) => r,
        Err(e) => return json_err(&e.to_string()),
    };
    cleanup_attachments_for_messages(&state, &records).await;
    json_ok()
}

/// 清空整个服务器消息。
async fn api_clear_all(State(state): State<Arc<AppState>>) -> Html<String> {
    let records = match state.storage.clear_all_messages().await {
        Ok(r) => r,
        Err(e) => return json_err(&e.to_string()),
    };
    cleanup_attachments_for_messages(&state, &records).await;
    json_ok()
}

/// 级联清理消息关联的附件（记录 + 文件；附件去重：共享文件仅最后引用删除时落盘）。
async fn cleanup_attachments_for_messages(state: &Arc<AppState>, records: &[crate::storage::StoredMessage]) {
    for msg in records {
        if let Ok(attachments) = state.storage.list_attachments_for_message(&msg.msg_id).await {
            for att in attachments {
                let path = att.path.clone();
                let _ = state.storage.delete_attachment(&att.attachment_id).await;
                if state
                    .storage
                    .count_attachments_by_path(&path)
                    .await
                    .unwrap_or(1)
                    == 0
                {
                    let full = std::path::Path::new(&state.data_dir).join(&path);
                    let _ = std::fs::remove_file(&full);
                }
            }
        }
    }
}

// ---- 表情包管理 API（F-STICKER：管理员增删改排序，成员只读） ----

#[derive(serde::Deserialize)]
struct StickerPackBody {
    id: String,
    name: String,
    icon: String,
}

#[derive(serde::Deserialize)]
struct StickerBody {
    id: String,
    pack_id: String,
    r#type: String,
    content: String,
}

#[derive(serde::Deserialize)]
struct StickerReorderBody {
    pack_id: String,
    ids: Vec<String>,
}

#[derive(serde::Deserialize)]
struct IdsBody {
    ids: Vec<String>,
}

fn sticker_packs_json(packs: Vec<crate::storage::StickerPackRecord>) -> serde_json::Value {
    serde_json::json!({
        "packs": packs.into_iter().map(|p| serde_json::json!({
            "id": p.id,
            "name": p.name,
            "icon": p.icon,
            "sort": p.sort,
            "stickers": p.stickers.into_iter().map(|s| serde_json::json!({
                "id": s.id,
                "pack_id": s.pack_id,
                "type": s.r#type,
                "content": s.content,
                "sort": s.sort,
            })).collect::<Vec<_>>(),
        })).collect::<Vec<_>>(),
    })
}

async fn api_list_sticker_packs(State(state): State<Arc<AppState>>) -> Html<String> {
    match state.storage.list_sticker_packs().await {
        Ok(packs) => Html(sticker_packs_json(packs).to_string()),
        Err(e) => json_err(&e.to_string()),
    }
}

async fn api_save_sticker_pack(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<StickerPackBody>,
) -> Html<String> {
    let id = if body.id.is_empty() {
        unique_id()
    } else {
        body.id
    };
    let sort = state
        .storage
        .list_sticker_packs()
        .await
        .map(|p| p.len() as i32)
        .unwrap_or(0);
    let result = state
        .storage
        .upsert_sticker_pack(&id, &body.name, &body.icon, sort)
        .await;
    if result.is_ok() {
        crate::ws::broadcast_sticker_packs(&state).await;
    }
    json_result(result)
}

async fn api_delete_sticker_pack(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<serde_json::Value>,
) -> Html<String> {
    let id = body.get("id").and_then(|v| v.as_str()).unwrap_or("");
    let result = state.storage.delete_sticker_pack(id).await;
    if result.is_ok() {
        crate::ws::broadcast_sticker_packs(&state).await;
    }
    json_result(result)
}

async fn api_reorder_sticker_packs(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<IdsBody>,
) -> Html<String> {
    let order: Vec<(String, i32)> = body.ids.iter().enumerate().map(|(i, id)| (id.clone(), i as i32)).collect();
    let result = state.storage.reorder_stickers(None, &order).await;
    if result.is_ok() {
        crate::ws::broadcast_sticker_packs(&state).await;
    }
    json_result(result)
}

async fn api_save_sticker(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<StickerBody>,
) -> Html<String> {
    let is_new = body.id.is_empty();
    let id = if is_new { unique_id() } else { body.id };
    let sort = if is_new {
        // 新表情追加到包尾（sort = 当前最大 + 1）
        state
            .storage
            .list_sticker_packs()
            .await
            .ok()
            .and_then(|packs| {
                packs
                    .into_iter()
                    .find(|p| p.id == body.pack_id)
                    .map(|p| p.stickers.len() as i32)
            })
            .unwrap_or(0)
    } else {
        0
    };
    let result = state
        .storage
        .upsert_sticker(&id, &body.pack_id, &body.r#type, &body.content, sort)
        .await;
    if result.is_ok() {
        crate::ws::broadcast_sticker_packs(&state).await;
    }
    json_result(result)
}

async fn api_delete_sticker(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<serde_json::Value>,
) -> Html<String> {
    let id = body.get("id").and_then(|v| v.as_str()).unwrap_or("");
    let result = state.storage.delete_sticker(id).await;
    if result.is_ok() {
        crate::ws::broadcast_sticker_packs(&state).await;
    }
    json_result(result)
}

async fn api_reorder_stickers(
    State(state): State<Arc<AppState>>,
    axum::Json(body): axum::Json<StickerReorderBody>,
) -> Html<String> {
    let order: Vec<(String, i32)> = body.ids.iter().enumerate().map(|(i, id)| (id.clone(), i as i32)).collect();
    let result = state
        .storage
        .reorder_stickers(Some(&body.pack_id), &order)
        .await;
    if result.is_ok() {
        crate::ws::broadcast_sticker_packs(&state).await;
    }
    json_result(result)
}

// ---- 辅助 ----

fn json_ok() -> Html<String> {
    Html(json!({"ok": true}).to_string())
}

/// 生成纳秒级唯一 ID。
fn unique_id() -> String {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("{}-{:x}", nanos, std::process::id())
}

fn json_err(msg: &str) -> Html<String> {
    Html(json!({"ok": false, "error": msg}).to_string())
}

fn json_result<T>(result: Result<T, crate::storage::StorageError>) -> Html<String> {
    match result {
        Ok(_) => json_ok(),
        Err(e) => json_err(&e.to_string()),
    }
}

fn strategy_to_str(s: JoinStrategy) -> &'static str {
    match s {
        JoinStrategy::Open => "open",
        JoinStrategy::InviteOnly => "invite_only",
        JoinStrategy::Approval => "approval",
    }
}

fn str_to_strategy(s: &str) -> JoinStrategy {
    match s {
        "open" => JoinStrategy::Open,
        "invite_only" => JoinStrategy::InviteOnly,
        _ => JoinStrategy::Approval,
    }
}

fn topic_type_to_str(t: TopicType) -> &'static str {
    match t {
        TopicType::Announcement => "announcement",
        TopicType::Av => "av",
        TopicType::Text => "text",
    }
}

fn str_to_topic_type(s: &str) -> TopicType {
    match s {
        "announcement" => TopicType::Announcement,
        "av" => TopicType::Av,
        _ => TopicType::Text,
    }
}

fn permission_to_str(p: TopicPermission) -> &'static str {
    match p {
        TopicPermission::Readonly => "readonly",
        TopicPermission::Public => "public",
    }
}

fn str_to_permission(s: &str) -> TopicPermission {
    match s {
        "readonly" => TopicPermission::Readonly,
        _ => TopicPermission::Public,
    }
}

fn role_to_str(r: MemberRole) -> &'static str {
    match r {
        MemberRole::Owner => "owner",
        MemberRole::Admin => "admin",
        MemberRole::Member => "member",
    }
}

/// 读取最新日志文件末尾 N 行（管理界面「日志」页）
/// 返回 { file, content }；日志目录为空时返回空内容。
async fn api_logs(
    State(state): State<Arc<AppState>>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> impl IntoResponse {
    let lines = params
        .get("lines")
        .and_then(|v| v.parse::<usize>().ok())
        .unwrap_or(500)
        .min(5000);
    match lonisle_core::logging::read_tail(std::path::Path::new(&state.log_dir), lines) {
        Ok((file, content)) => axum::Json(json!({"ok": true, "file": file, "content": content})),
        Err(_) => axum::Json(json!({"ok": true, "file": "", "content": ""})),
    }
}
