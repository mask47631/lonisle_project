//! 推送服务 HTTP API
//!
//! 路由：
//! - GET  /health              健康监测（白名单申请前置校验）
//! - POST /register            客户端注册设备 Token
//! - POST /push                聊天服务器发起推送（验签 + 限速 + 免内容）
//! - GET  /directory           服务器目录查询
//! - POST /directory/register  服务器注册目录
//! - POST /directory/update    服务器更新目录
//! - POST /directory/remove    服务器下架目录
//! - POST /apply               白名单申请（含健康监测前置校验）
//! - POST /mute                用户免打扰

use std::sync::Arc;

use axum::extract::State;
use axum::http::HeaderMap;
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use serde::Deserialize;
use serde_json::json;

use crate::auth::verify_server_signature;
use crate::fcm::{FcmConfig, FcmVendor};
use crate::rate_limit::RateLimiter;
use crate::storage::{self, DirectoryEntry, Storage};
use crate::vendor::VendorRegistry;

/// 目录服务器实时状态（health monitor 定时刷新，F-DISC-3）
#[derive(Clone, Debug)]
pub struct DirectoryStatus {
    pub status: String, // "online" | "offline"
    pub name: String,
    pub description: String,
    pub join_mode: String,
    pub online: u32,
    pub total: u32,
    pub checked_at: i64,
}

/// 应用共享状态
pub struct AppState {
    pub storage: Arc<dyn Storage>,
    pub rate_limiter: Arc<RateLimiter>,
    /// 厂商通道注册表（按设备 vendor 字段分发）
    pub vendors: Arc<VendorRegistry>,
    /// 是否白名单模式（默认 true；运营方可切换，F-RATE-5）
    pub whitelist_mode: std::sync::RwLock<bool>,
    /// 熔断阈值：累计超限次数达此值自动加入黑名单（0 表示不熔断）
    pub circuit_breaker_threshold: u32,
    /// 运营方管理 API Key（空 = 鉴权关闭，仅限开发/测试）
    pub admin_key: String,
    /// FCM 推送配置（web 端配置，动态更新，F-PUSH-2）
    pub fcm_config: std::sync::RwLock<Option<FcmConfig>>,
    /// 目录服务器实时状态缓存（server_id -> DirectoryStatus）
    pub directory_status: std::sync::RwLock<std::collections::HashMap<String, DirectoryStatus>>,
}

impl AppState {
    pub fn new(
        storage: Arc<dyn Storage>,
        vendors: Arc<VendorRegistry>,
        initial_rate: u32,
    ) -> Self {
        Self {
            storage,
            rate_limiter: Arc::new(RateLimiter::new(initial_rate)),
            vendors,
            whitelist_mode: std::sync::RwLock::new(true),
            circuit_breaker_threshold: 100,
            admin_key: String::new(),
            fcm_config: std::sync::RwLock::new(None),
            directory_status: std::sync::RwLock::new(std::collections::HashMap::new()),
        }
    }

    /// 当前是否白名单模式
    pub fn is_whitelist_mode(&self) -> bool {
        *self.whitelist_mode.read().unwrap()
    }

    /// 切换白/黑名单模式（F-RATE-5）
    pub fn set_whitelist_mode(&self, whitelist: bool) {
        *self.whitelist_mode.write().unwrap() = whitelist;
    }

    /// 当前 FCM 配置（克隆）
    pub fn current_fcm_config(&self) -> Option<FcmConfig> {
        self.fcm_config.read().unwrap().clone()
    }

    /// FCM 通道是否已启用（四项凭据齐全）
    pub fn has_fcm(&self) -> bool {
        self.vendors.has_fcm()
    }

    /// 动态更新 FCM 配置：重建厂商通道（不完整/None → 回退 Mock）。
    /// 持久化由调用方（管理 API）完成。
    pub fn update_fcm_config(&self, config: Option<FcmConfig>) {
        let vendor = match &config {
            Some(c) if c.complete() => Some(FcmVendor::new(c.clone())),
            _ => None,
        };
        *self.fcm_config.write().unwrap() = config;
        self.vendors.set_fcm(vendor);
    }
}

/// 构建路由
pub fn build_router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/register", post(register))
        .route("/push", post(push))
        .route("/directory", get(directory))
        .route("/directory/register", post(directory_register))
        .route("/directory/update", post(directory_update))
        .route("/directory/remove", post(directory_remove))
        .route("/apply", post(apply))
        .route("/mute", post(mute))
        .with_state(state)
}

// ---- 请求体 ----

#[derive(Deserialize)]
struct RegisterBody {
    user_id: String,
    device_id: String,
    vendor: String,
    token: String,
}

#[derive(Deserialize)]
struct PushBody {
    server_id: String,
    user_id: String,
    hint: String, // 唤醒提示（如 "审批通过" / "在「话题」中被 @提及"），不含消息内容
    title: Option<String>, // 通知大标题（如服务器名；缺省用 "LonIsle"）
}

#[derive(Deserialize)]
struct DirectoryBody {
    server_id: String,
    name: String,
    description: String,
    icon: String,
    address: String,
    join_mode: String,
}

#[derive(Deserialize)]
struct RemoveBody {
    server_id: String,
}

#[derive(Deserialize)]
struct ApplyBody {
    server_id: String,
    description: String,
    health_url: String,
}

#[derive(Deserialize)]
struct MuteBody {
    server_id: String,
    user_id: String,
    muted: bool,
}

// ---- 响应辅助 ----

fn json_ok() -> Response {
    Json(json!({"ok": true})).into_response()
}

fn json_err(status: axum::http::StatusCode, msg: &str) -> Response {
    (status, Json(json!({"ok": false, "error": msg}))).into_response()
}

// ---- 处理器 ----

/// 健康监测：返回 200 + 版本（白名单申请前置校验用）
async fn health() -> Response {
    Json(json!({
        "ok": true,
        "server_version": crate::SERVER_VERSION,
    }))
    .into_response()
}

/// 客户端注册设备 Token
async fn register(
    State(state): State<Arc<AppState>>,
    Json(body): Json<RegisterBody>,
) -> Response {
    let token = storage::DeviceToken {
        user_id: body.user_id,
        device_id: body.device_id,
        vendor: body.vendor,
        token: body.token,
        updated_at: current_unix_time(),
    };
    match state.storage.upsert_device_token(&token).await {
        Ok(_) => json_ok(),
        Err(e) => json_err(axum::http::StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    }
}

/// 聊天服务器发起推送：验签 → 白名单 → 免打扰 → 限速 → 转发厂商
async fn push(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    body: axum::body::Bytes,
) -> Response {
    // 解析 JSON
    let push_body: PushBody = match serde_json::from_slice(&body) {
        Ok(b) => b,
        Err(_) => return json_err(axum::http::StatusCode::BAD_REQUEST, "无效的请求体"),
    };

    // 验签（服务器身份认证）
    let server_id = header_str(&headers, "x-server-id").unwrap_or_default();
    let pubkey = header_str(&headers, "x-server-pubkey").unwrap_or_default();
    let sig = header_str(&headers, "x-server-signature").unwrap_or_default();

    if let Err(e) = verify_server_signature(&server_id, &pubkey, &sig, &body) {
        return json_err(axum::http::StatusCode::UNAUTHORIZED, &e.to_string());
    }
    // server_id 与请求体一致
    if push_body.server_id != server_id {
        return json_err(axum::http::StatusCode::UNAUTHORIZED, "server_id 不一致");
    }

    // 黑名单检查（两种模式都生效，F-RATE-6：熔断在白名单模式下同样拦截）
    if let Ok(true) = state.storage.is_blacklisted(&server_id).await {
        return json_err(axum::http::StatusCode::FORBIDDEN, "server_blacklisted");
    }

    // 白名单模式检查（F-RATE-4/F-RATE-5）
    if state.is_whitelist_mode() {
        match state.storage.is_whitelisted(&server_id).await {
            Ok(true) => {}
            Ok(false) => return json_err(axum::http::StatusCode::FORBIDDEN, "server_not_whitelisted"),
            Err(e) => return json_err(axum::http::StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
        }
    }

    // 用户免打扰检查
    if let Ok(true) = state.storage.is_muted(&server_id, &push_body.user_id).await {
        return json_ok(); // 静默丢弃（用户已免打扰）
    }

    // 限速检查
    if !state.rate_limiter.try_acquire(&server_id, &push_body.user_id) {
        // 熔断计数：累计超限次数达阈值自动加入黑名单（F-RATE-6）
        state.rate_limiter.record_violation(&server_id);
        if state.circuit_breaker_threshold > 0
            && state.rate_limiter.violation_count(&server_id) >= state.circuit_breaker_threshold
        {
            let _ = state.storage.add_blacklist(&server_id, "自动熔断：限速超限").await;
            tracing::warn!(server_id = %server_id, "自动熔断：加入黑名单");
        }
        return json_err(axum::http::StatusCode::TOO_MANY_REQUESTS, "rate_limited");
    }

    // 查用户设备 Token 并按厂商分发（免内容：仅唤醒提示）
    match state.storage.list_device_tokens(&push_body.user_id).await {
        Ok(tokens) => {
            let title = push_body
                .title
                .as_deref()
                .filter(|t| !t.trim().is_empty())
                .unwrap_or("LonIsle");
            for t in tokens {
                state
                    .vendors
                    .send(&t.vendor, &t.token, title, &push_body.hint)
                    .await;
            }
            json_ok()
        }
        Err(e) => json_err(axum::http::StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    }
}

/// 服务器目录查询（仅返回已审核通过的；支持 ?q= 关键词搜索，F-DISC-2）
/// 合并健康监测实时状态：online/offline、在线人数、最新名称/描述/加入方式（F-DISC-3）
async fn directory(
    State(state): State<Arc<AppState>>,
    axum::extract::Query(params): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Response {
    let q = params.get("q").map(|s| s.to_lowercase()).unwrap_or_default();
    let statuses = state.directory_status.read().unwrap().clone();
    match state.storage.list_directory().await {
        Ok(entries) => {
            let filtered: Vec<_> = entries
                .into_iter()
                .filter(|e| {
                    q.is_empty()
                        || e.name.to_lowercase().contains(&q)
                        || e.description.to_lowercase().contains(&q)
                })
                .collect();
            Json(json!({
                "servers": filtered.iter().map(|e| {
                    // 动态状态覆盖静态目录数据（最新名称/描述/人数/状态）
                    let st = statuses.get(&e.server_id);
                    json!({
                        "server_id": e.server_id,
                        "name": st.as_ref().map(|s| s.name.clone()).filter(|n| !n.is_empty()).unwrap_or_else(|| e.name.clone()),
                        "description": st.as_ref().map(|s| s.description.clone()).filter(|d| !d.is_empty()).unwrap_or_else(|| e.description.clone()),
                        "icon": e.icon,
                        "address": e.address,
                        "join_mode": st.as_ref().map(|s| s.join_mode.clone()).filter(|m| !m.is_empty()).unwrap_or_else(|| e.join_mode.clone()),
                        "status": st.as_ref().map(|s| s.status.clone()).unwrap_or_else(|| "offline".to_string()),
                        "online": st.as_ref().map(|s| s.online).unwrap_or(0),
                        "total": st.as_ref().map(|s| s.total).unwrap_or(0),
                        "checked_at": st.as_ref().map(|s| s.checked_at).unwrap_or(0),
                    })
                }).collect::<Vec<_>>(),
            }))
            .into_response()
        }
        Err(e) => json_err(axum::http::StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    }
}

/// 服务器注册目录（需已白名单）
async fn directory_register(
    State(state): State<Arc<AppState>>,
    Json(body): Json<DirectoryBody>,
) -> Response {
    // 仅白名单服务器可注册目录
    if let Ok(false) = state.storage.is_whitelisted(&body.server_id).await {
        return json_err(axum::http::StatusCode::FORBIDDEN, "server_not_whitelisted");
    }
    let entry = DirectoryEntry {
        server_id: body.server_id,
        name: body.name,
        description: body.description,
        icon: body.icon,
        address: body.address,
        join_mode: body.join_mode,
        approved: true,
        created_at: current_unix_time(),
    };
    match state.storage.upsert_directory(&entry).await {
        Ok(_) => json_ok(),
        Err(e) => json_err(axum::http::StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    }
}

/// 服务器更新目录
async fn directory_update(
    State(state): State<Arc<AppState>>,
    Json(body): Json<DirectoryBody>,
) -> Response {
    let existing = match state.storage.get_directory(&body.server_id).await {
        Ok(Some(e)) => e,
        Ok(None) => return json_err(axum::http::StatusCode::NOT_FOUND, "未注册"),
        Err(e) => return json_err(axum::http::StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    };
    let entry = DirectoryEntry {
        server_id: body.server_id,
        name: if body.name.is_empty() { existing.name } else { body.name },
        description: body.description,
        icon: body.icon,
        address: body.address,
        join_mode: body.join_mode,
        approved: existing.approved,
        created_at: existing.created_at,
    };
    match state.storage.upsert_directory(&entry).await {
        Ok(_) => json_ok(),
        Err(e) => json_err(axum::http::StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    }
}

/// 服务器下架目录
async fn directory_remove(
    State(state): State<Arc<AppState>>,
    Json(body): Json<RemoveBody>,
) -> Response {
    match state.storage.remove_directory(&body.server_id).await {
        Ok(_) => json_ok(),
        Err(e) => json_err(axum::http::StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    }
}

/// 白名单申请（含健康监测前置校验）
async fn apply(State(state): State<Arc<AppState>>, Json(body): Json<ApplyBody>) -> Response {
    // 拒绝冷却检查（1 个月不得重新申请）
    if let Ok(Some(until)) = state.storage.get_cooldown(&body.server_id).await {
        if until > current_unix_time() {
            return json_err(axum::http::StatusCode::FORBIDDEN, "in_cooldown");
        }
    }

    // 健康监测前置校验：health_url 必须返回 200
    let healthy = match reqwest::Client::new()
        .get(&body.health_url)
        .timeout(std::time::Duration::from_secs(5))
        .send()
        .await
    {
        Ok(resp) => resp.status().is_success(),
        Err(_) => false,
    };
    if !healthy {
        return json_err(axum::http::StatusCode::BAD_REQUEST, "health_check_failed");
    }

    // 创建待审核白名单申请
    tracing::info!(
        server_id = %body.server_id,
        description = %body.description,
        "收到白名单申请"
    );
    let entry = storage::WhitelistEntry {
        server_id: body.server_id,
        approved: false,
        applied_at: current_unix_time(),
        health_url: body.health_url,
        paused: false,
    };
    match state.storage.upsert_whitelist(&entry).await {
        Ok(_) => json_ok(),
        Err(e) => json_err(axum::http::StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    }
}

/// 用户免打扰（客户端上报"不再接收某服务器推送"）
async fn mute(State(state): State<Arc<AppState>>, Json(body): Json<MuteBody>) -> Response {
    match state
        .storage
        .set_mute(&body.server_id, &body.user_id, body.muted)
        .await
    {
        Ok(_) => json_ok(),
        Err(e) => json_err(axum::http::StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    }
}

// ---- 辅助 ----

fn header_str<'a>(headers: &'a HeaderMap, name: &str) -> Option<&'a str> {
    headers.get(name).and_then(|v| v.to_str().ok())
}

fn current_unix_time() -> i64 {
    lonisle_core::device::current_unix_time()
}
