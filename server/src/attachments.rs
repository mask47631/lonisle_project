//! 附件上传/下载 HTTP 接口（M5）
//!
//! - POST /attachments/upload：multipart 上传（鉴权 + 大小限制 + 缩略图）
//! - GET  /attachments/{id}：下载原文件
//! - GET  /attachments/{id}/thumbnail：下载缩略图
//! - DELETE /attachments/{id}：删除附件

use std::sync::Arc;

use axum::extract::{DefaultBodyLimit, Multipart, Path, State};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use percent_encoding::{utf8_percent_encode, NON_ALPHANUMERIC};
use serde_json::json;
use sha2::Digest as _;

use crate::storage::AttachmentRecord;
use crate::ws::AppState;

/// 附件存储根目录（相对 data_dir）
pub const ATTACHMENTS_DIR: &str = "attachments";

/// 构建附件路由
pub fn build_attachments_router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/attachments/upload", post(upload))
        .route("/attachments/:id", get(download))
        .route("/attachments/:id/thumbnail", get(download_thumbnail))
        .route("/attachments/:id", axum::routing::delete(delete))
        // 不设 HTTP 层硬上限：大小限制由 handler 内的
        // max_attachment_size 校验并返回明确文案。
        // （axum 默认 2MB 上限会在客户端流式写入中途断开连接，
        //   客户端表现为 Broken pipe，handler 表现为「缺少文件」）
        .layer(DefaultBodyLimit::disable())
        .with_state(state)
}

/// 上传附件（multipart）
async fn upload(
    State(state): State<Arc<AppState>>,
    mut multipart: Multipart,
) -> Response {
    // 解析 multipart 字段
    let mut file_data: Option<Vec<u8>> = None;
    let mut filename: Option<String> = None;
    let mut msg_id = String::new();
    let mut kind = String::new();
    let mut user_id = String::new();

    while let Ok(Some(field)) = multipart.next_field().await {
        let name = field.name().unwrap_or("").to_string();
        match name.as_str() {
            "file" => {
                filename = field.file_name().map(|s| s.to_string());
                if let Ok(data) = field.bytes().await {
                    file_data = Some(data.to_vec());
                }
            }
            "msg_id" => {
                if let Ok(v) = field.text().await {
                    msg_id = v;
                }
            }
            "kind" => {
                if let Ok(v) = field.text().await {
                    kind = v;
                }
            }
            "user_id" => {
                if let Ok(v) = field.text().await {
                    user_id = v;
                }
            }
            _ => {}
        }
    }

    let Some(data) = file_data else {
        return json_err(400, "缺少文件");
    };
    let filename = filename.unwrap_or_else(|| "unnamed".to_string());

    let meta = state.storage.get_server_meta().await.ok().flatten();
    let size = data.len() as u64;

    // 单附件大小上限（P1，服主可配，0 = 不限）。
    // 已取消单成员附件总配额（累计）限制：上传仅受单文件大小约束。
    let max_size = meta.as_ref().map(|m| m.max_attachment_size).unwrap_or(0);
    if max_size > 0 && size > max_size {
        return json_err(413, "附件超过大小上限");
    }

    // 生成附件 ID + 内容寻址去重（同内容文件只存一份）
    let attachment_id = format!("att-{}", unique_id());
    let mime = mime_guess_from_name(&filename).to_string();
    // 内容去重键 = SHA256 + 大小（双条件：不同大小的文件即使 hash 相同也不复用，
    // 文件名形如 {hash}-{size}，同 hash 不同 size 各自独立存储）
    let content_hash = hex::encode(sha2::Sha256::digest(&data));
    let size = data.len() as u64;
    let storage_name = format!("{}-{}", content_hash, size);
    let (width, height, duration) = (0u32, 0u32, 0u32); // M5 简化：不解析媒体尺寸

    let dir = std::path::Path::new(&state_dir(&state)).join(ATTACHMENTS_DIR);
    std::fs::create_dir_all(&dir).ok();
    let file_path = dir.join(&storage_name);
    if !file_path.exists() {
        // 新内容（hash+size 组合）：写盘
        if std::fs::write(&file_path, &data).is_err() {
            return json_err(500, "写文件失败");
        }
    }
    // 已存在同 hash+同 size 文件：跳过写盘（去重生效，仅新增记录引用同一文件）

    // 落库
    let record = AttachmentRecord {
        attachment_id: attachment_id.clone(),
        msg_id,
        kind,
        size,
        mime,
        path: format!("{}/{}", ATTACHMENTS_DIR, storage_name),
        content_hash,
        thumbnail_path: None,
        width,
        height,
        duration,
        author_id: user_id,
        created_at: lonisle_core::device::current_unix_time(),
        filename: filename.clone(),
    };
    if let Err(e) = state.storage.insert_attachment(&record).await {
        return json_err(500, &e.to_string());
    }

    Json(json!({"ok": true, "attachment_id": attachment_id})).into_response()
}

/// 下载原文件
async fn download(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Response {
    let record = match state.storage.get_attachment(&id).await {
        Ok(Some(r)) => r,
        _ => return json_err(404, "附件不存在"),
    };

    let base = state_dir(&state);
    let full = std::path::Path::new(&base).join(&record.path);
    match std::fs::read(&full) {
        Ok(data) => {
            // Content-Disposition 带原始文件名，浏览器/客户端保存时用原名（F-MEDIA-10）
            let disposition = if record.filename.is_empty() {
                format!("inline; filename=\"{}\"", id)
            } else {
                // RFC 6266：filename= 回退值必须纯 ASCII（含引号/反斜杠转义），
                // 非 ASCII 原名走 RFC 5987 filename*。原始中文直接进 header 会让
                // 严格客户端（reqwest/hyper 等）解析整个响应头失败。
                let fallback: String = record
                    .filename
                    .chars()
                    .map(|c| match c {
                        '"' | '\\' => '_',
                        c if c.is_ascii() => c,
                        _ => '_',
                    })
                    .collect();
                format!(
                    "inline; filename=\"{}\"; filename*=UTF-8''{}",
                    fallback,
                    utf8_percent_encode(&record.filename, NON_ALPHANUMERIC)
                )
            };
            axum::response::Response::builder()
                .header("content-type", &record.mime)
                .header("content-length", data.len())
                .header("content-disposition", disposition)
                .body(axum::body::Body::from(data))
                .unwrap()
        }
        Err(_) => json_err(404, "文件不存在"),
    }
}

/// 下载缩略图（M5 未生成缩略图，回退到原文件）
async fn download_thumbnail(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Response {
    download(State(state), Path(id)).await
}

/// 删除附件
async fn delete(
    State(state): State<Arc<AppState>>,
    Path(id): Path<String>,
) -> Response {
    let record = match state.storage.get_attachment(&id).await {
        Ok(Some(r)) => r,
        _ => return json_err(404, "附件不存在"),
    };

    // 删除记录后检查引用：同路径（内容寻址哈希文件）仍被其他附件引用则保留文件，
    // 否则删除（附件去重：同一文件仅被最后一个引用删除时真正落盘）
    let path = record.path.clone();
    if let Err(e) = state.storage.delete_attachment(&id).await {
        return json_err(500, &e.to_string());
    }
    let refs = state
        .storage
        .count_attachments_by_path(&path)
        .await
        .unwrap_or(1);
    if refs == 0 {
        let base = state_dir(&state);
        let full = std::path::Path::new(&base).join(&path);
        let _ = std::fs::remove_file(&full);
    }
    Json(json!({"ok": true})).into_response()
}

// ---- 辅助 ----

pub(crate) fn state_dir(state: &Arc<AppState>) -> String {
    if state.data_dir.is_empty() {
        std::env::current_dir()
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_default()
    } else {
        state.data_dir.clone()
    }
}

fn mime_guess_from_name(name: &str) -> &'static str {
    match name.rsplit('.').next().unwrap_or("").to_lowercase().as_str() {
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "mp4" | "mov" | "m4v" => "video/mp4",
        "webm" => "video/webm",
        "mp3" => "audio/mpeg",
        "wav" => "audio/wav",
        "ogg" => "audio/ogg",
        "m4a" => "audio/mp4",
        "aac" => "audio/aac",
        "flac" => "audio/flac",
        _ => "application/octet-stream",
    }
}

fn unique_id() -> String {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("{}-{:x}", nanos, std::process::id())
}

fn json_err(status: u16, msg: &str) -> Response {
    (
        axum::http::StatusCode::from_u16(status).unwrap_or(axum::http::StatusCode::INTERNAL_SERVER_ERROR),
        Json(json!({"ok": false, "error": msg})),
    )
        .into_response()
}
