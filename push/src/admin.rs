//! 推送服务管理 API：白名单审核、限速配置、目录管理、申请列表
//!
//! M4 提供 JSON 管理 API + 内嵌静态界面。

use std::sync::Arc;

use axum::extract::{Request, State};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use rust_embed::RustEmbed;
use serde::Deserialize;
use serde_json::json;

use crate::storage::WhitelistEntry;
use crate::api::AppState;

/// 内嵌静态资源
#[derive(RustEmbed)]
#[folder = "web/"]
struct WebAssets;

/// 构建管理路由（叠加在 api 路由之上）
pub fn build_admin_router(state: Arc<AppState>) -> Router {
    let admin_api = Router::new()
        .route("/admin/whitelist", get(list_whitelist))
        .route("/admin/whitelist/approve", post(approve_whitelist))
        .route("/admin/whitelist/reject", post(reject_whitelist))
        .route("/admin/rate-limit", get(get_rate))
        .route("/admin/rate-limit/set", post(set_rate))
        .route("/admin/mode", get(get_mode).post(set_mode))
        .route("/admin/directory", get(list_all_directory))
        .route("/admin/directory/remove", post(remove_directory))
        .route("/admin/blacklist", get(list_blacklist))
        .route("/admin/blacklist/add", post(add_blacklist))
        .route("/admin/blacklist/remove", post(remove_blacklist))
        .route("/admin/fcm-config", get(get_fcm_config).post(set_fcm_config))
        .route_layer(axum::middleware::from_fn_with_state(
            state.clone(),
            admin_auth,
        ));

    Router::new()
        .merge(admin_api)
        .route("/", get(serve_index))
        .fallback(serve_static_fallback)
        .with_state(state)
}

/// 运营方管理 API 鉴权中间件：
/// 所有 /admin/* 需 `X-Admin-Key: <admin_key>`；admin_key 为空时放行（仅限开发/测试）。
async fn admin_auth(
    State(state): State<Arc<AppState>>,
    req: Request,
    next: Next,
) -> Response {
    if state.admin_key.is_empty() {
        return next.run(req).await;
    }
    let key = req
        .headers()
        .get("X-Admin-Key")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    if key != state.admin_key {
        return (
            axum::http::StatusCode::UNAUTHORIZED,
            Json(json!({"ok": false, "error": "未授权：缺少或无效的管理 Key"})),
        )
            .into_response();
    }
    next.run(req).await
}

/// 静态资源处理器
async fn serve_index() -> Response {
    serve_static_path("index.html")
}

/// fallback 静态资源服务（从 URI 提取路径）
async fn serve_static_fallback(uri: axum::http::Uri) -> Response {
    let path = uri.path().trim_start_matches('/');
    serve_static_path(path)
}

fn serve_static_path(path: &str) -> Response {
    let path = if path.is_empty() { "index.html" } else { path };
    match WebAssets::get(path) {
        Some(content) => {
            let mime = mime_guess(path);
            axum::response::Response::builder()
                .header("content-type", mime)
                .body(axum::body::Body::from(content.data.into_owned()))
                .unwrap()
        }
        None => axum::response::Response::builder()
            .status(404)
            .body(axum::body::Body::from("not found"))
            .unwrap(),
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
        _ => "application/octet-stream",
    }
}

#[derive(Deserialize)]
struct ModeBody {
    whitelist_mode: bool,
}

/// 查询当前模式（F-RATE-8：状态可见）
async fn get_mode(State(state): State<Arc<AppState>>) -> Response {
    Json(json!({
        "whitelist_mode": state.is_whitelist_mode(),
        "circuit_breaker_threshold": state.circuit_breaker_threshold,
        "fcm_configured": state.vendors.has_fcm(),
    }))
    .into_response()
}

/// 切换白/黑名单模式（F-RATE-5）
async fn set_mode(
    State(state): State<Arc<AppState>>,
    Json(body): Json<ModeBody>,
) -> Response {
    let mode = if body.whitelist_mode { "白名单" } else { "黑名单" };
    tracing::info!(whitelist_mode = body.whitelist_mode, "推送模式切换");
    state.set_whitelist_mode(body.whitelist_mode);
    Json(json!({"ok": true, "whitelist_mode": body.whitelist_mode, "mode": mode})).into_response()
}

// ---- FCM 推送配置（web 端配置，F-PUSH-2） ----

/// 查询当前 FCM 配置（敏感字段仅回传是否已设置）
async fn get_fcm_config(State(state): State<Arc<AppState>>) -> Response {
    let cfg = state.current_fcm_config();
    let (project_id, client_id) = match &cfg {
        Some(c) => (c.project_id.clone(), c.client_id.clone()),
        None => (String::new(), String::new()),
    };
    let sa = cfg.as_ref().map(|c| c.service_account_json.clone()).unwrap_or_default();
    Json(json!({
        "ok": true,
        "configured": state.has_fcm(),
        "project_id": project_id,
        "client_id": client_id,
        "client_secret_set": cfg.as_ref().map(|c| !c.client_secret.is_empty()).unwrap_or(false),
        "refresh_token_set": cfg.as_ref().map(|c| !c.refresh_token.is_empty()).unwrap_or(false),
        "service_account_set": !sa.trim().is_empty(),
        "service_account_json": sa,
    }))
    .into_response()
}

#[derive(Deserialize)]
struct FcmConfigBody {
    project_id: String,
    client_id: String,
    client_secret: String,
    refresh_token: String,
    service_account_json: String,
}

/// 保存 FCM 配置（空字段保留旧值）：持久化 + 动态重建厂商通道
async fn set_fcm_config(
    State(state): State<Arc<AppState>>,
    Json(body): Json<FcmConfigBody>,
) -> Response {
    let old = state.current_fcm_config();
    let keep = |new: &str, old_val: &str| -> String {
        if new.trim().is_empty() {
            old_val.to_string()
        } else {
            new.trim().to_string()
        }
    };
    let config = crate::fcm::FcmConfig {
        project_id: keep(&body.project_id, old.as_ref().map(|c| c.project_id.as_str()).unwrap_or("")),
        client_id: keep(&body.client_id, old.as_ref().map(|c| c.client_id.as_str()).unwrap_or("")),
        client_secret: keep(&body.client_secret, old.as_ref().map(|c| c.client_secret.as_str()).unwrap_or("")),
        refresh_token: keep(&body.refresh_token, old.as_ref().map(|c| c.refresh_token.as_str()).unwrap_or("")),
        service_account_json: keep(&body.service_account_json, old.as_ref().map(|c| c.service_account_json.as_str()).unwrap_or("")),
    };
    if let Err(e) = state
        .storage
        .set_fcm_config(
            &config.project_id,
            &config.client_id,
            &config.client_secret,
            &config.refresh_token,
            &config.service_account_json,
        )
        .await
    {
        return (axum::http::StatusCode::INTERNAL_SERVER_ERROR, Json(json!({"ok": false, "error": e.to_string()}))).into_response();
    }
    let enabled = config.complete();
    state.update_fcm_config(Some(config));
    if enabled {
        tracing::info!("FCM 推送通道已启用（web 管理端配置）");
    } else {
        tracing::warn!("FCM 配置不完整（web 管理端），推送仍为 Mock 通道");
    }
    Json(json!({"ok": true, "enabled": enabled})).into_response()
}

#[derive(Deserialize)]
struct ApproveBody {
    server_id: String,
    approve: bool,
}

#[derive(Deserialize)]
struct RateBody {
    per_minute: u32,
}

#[derive(Deserialize)]
struct RemoveBody {
    server_id: String,
}

#[derive(Deserialize)]
struct BlacklistBody {
    server_id: String,
    reason: String,
}

fn json_ok() -> Response {
    Json(json!({"ok": true})).into_response()
}

fn json_err(msg: &str) -> Response {
    Json(json!({"ok": false, "error": msg})).into_response()
}

/// 白名单列表（含待审核 + 已通过）
async fn list_whitelist(State(state): State<Arc<AppState>>) -> Response {
    match state.storage.list_whitelist().await {
        Ok(entries) => Json(json!({
            "entries": entries.iter().map(|e| json!({
                "server_id": e.server_id,
                "approved": e.approved,
                "applied_at": e.applied_at,
            })).collect::<Vec<_>>(),
        }))
        .into_response(),
        Err(e) => json_err(&e.to_string()),
    }
}

/// 审核白名单（通过/拒绝）
async fn approve_whitelist(
    State(state): State<Arc<AppState>>,
    Json(body): Json<ApproveBody>,
) -> Response {
    if body.approve {
        let entry = WhitelistEntry {
            server_id: body.server_id.clone(),
            approved: true,
            applied_at: current_unix_time(),
            health_url: String::new(),
            paused: false,
        };
        if let Err(e) = state.storage.upsert_whitelist(&entry).await {
            return json_err(&e.to_string());
        }
    } else {
        // 拒绝：记录冷却期（1 个月）
        let cooldown_until = current_unix_time() + 30 * 24 * 3600;
        if let Err(e) = state.storage.set_cooldown(&body.server_id, cooldown_until).await {
            return json_err(&e.to_string());
        }
        let entry = WhitelistEntry {
            server_id: body.server_id,
            approved: false,
            applied_at: current_unix_time(),
            health_url: String::new(),
            paused: false,
        };
        if let Err(e) = state.storage.upsert_whitelist(&entry).await {
            return json_err(&e.to_string());
        }
    }
    json_ok()
}

/// 拒绝白名单（别名）
async fn reject_whitelist(
    State(state): State<Arc<AppState>>,
    Json(body): Json<ApproveBody>,
) -> Response {
    approve_whitelist(State(state), Json(ApproveBody { server_id: body.server_id, approve: false }))
        .await
}

/// 获取限速配置
async fn get_rate(State(state): State<Arc<AppState>>) -> Response {
    match state.storage.get_rate_limit().await {
        Ok(rate) => Json(json!({"per_minute": rate})).into_response(),
        Err(e) => json_err(&e.to_string()),
    }
}

/// 设置限速配置（热更新）
async fn set_rate(State(state): State<Arc<AppState>>, Json(body): Json<RateBody>) -> Response {
    if body.per_minute == 0 {
        return json_err("per_minute 必须大于 0");
    }
    if let Err(e) = state.storage.set_rate_limit(body.per_minute).await {
        return json_err(&e.to_string());
    }
    state.rate_limiter.set_rate(body.per_minute);
    json_ok()
}

/// 所有目录（含未审核）
async fn list_all_directory(State(state): State<Arc<AppState>>) -> Response {
    match state.storage.list_directory().await {
        Ok(entries) => Json(json!({
            "servers": entries.iter().map(|e| json!({
                "server_id": e.server_id,
                "name": e.name,
                "address": e.address,
                "approved": e.approved,
            })).collect::<Vec<_>>(),
        }))
        .into_response(),
        Err(e) => json_err(&e.to_string()),
    }
}

/// 移除目录
async fn remove_directory(
    State(state): State<Arc<AppState>>,
    Json(body): Json<RemoveBody>,
) -> Response {
    match state.storage.remove_directory(&body.server_id).await {
        Ok(_) => json_ok(),
        Err(e) => json_err(&e.to_string()),
    }
}

// ---- 黑名单（P1） ----

/// 列出黑名单。
async fn list_blacklist(State(state): State<Arc<AppState>>) -> Response {
    match state.storage.list_blacklist().await {
        Ok(entries) => Json(json!({
            "entries": entries.iter().map(|(id, reason, created)| json!({
                "server_id": id,
                "reason": reason,
                "created_at": created,
            })).collect::<Vec<_>>(),
        }))
        .into_response(),
        Err(e) => json_err(&e.to_string()),
    }
}

/// 加入黑名单。
async fn add_blacklist(
    State(state): State<Arc<AppState>>,
    Json(body): Json<BlacklistBody>,
) -> Response {
    match state.storage.add_blacklist(&body.server_id, &body.reason).await {
        Ok(_) => json_ok(),
        Err(e) => json_err(&e.to_string()),
    }
}

/// 移除黑名单。
async fn remove_blacklist(
    State(state): State<Arc<AppState>>,
    Json(body): Json<RemoveBody>,
) -> Response {
    match state.storage.remove_blacklist(&body.server_id).await {
        Ok(_) => json_ok(),
        Err(e) => json_err(&e.to_string()),
    }
}

fn current_unix_time() -> i64 {
    lonisle_core::device::current_unix_time()
}
