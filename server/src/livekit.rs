//! LiveKit Token 签发（音视频话题，F-TOPIC-7）+ 房间人数查询（F-AV-COUNT）
//!
//! 使用 jsonwebtoken 签发 HS256 JWT（LiveKit 自签 Token）。
//! 房间名 = topic_id；Token 含 video grant（房间加入权限）+ 用户身份 + 短时过期。
//! 房间人数经 LiveKit REST API（twirp）查询，供话题列表展示。

use jsonwebtoken::{encode, EncodingKey, Header};
use serde::Serialize;

/// LiveKit video grant 的 claims（JWT 自定义字段）。
#[derive(Serialize)]
struct LiveKitClaims {
    /// 用户身份（身份 ID）
    sub: String,
    /// 显示名称
    name: String,
    /// 视频权限（LiveKit video grant）
    video: VideoGrant,
    /// 过期时间（unix 秒）
    exp: i64,
    /// 签发时间
    nbf: i64,
    /// 签发者（API Key）
    iss: String,
}

#[derive(Serialize)]
struct VideoGrant {
    /// 是否允许加入房间
    #[serde(rename = "roomJoin")]
    room_join: bool,
    /// 房间名（= topic_id）
    room: String,
    /// 是否允许发布（推流）
    #[serde(rename = "canPublish")]
    can_publish: bool,
    /// 是否允许订阅（拉流）
    #[serde(rename = "canSubscribe")]
    can_subscribe: bool,
}

/// LiveKit 服务端 REST API 认证 claims（管理型，非加入房间）。
///
/// 注意（F-AV-COUNT 实测校准）：必须与官方 SDK 一致——
/// - **不带 `sub`**：带 `sub` 会被 LiveKit 识别为用户 Token，服务端权限全部失效（permissions denied）
/// - 权限放在 **`video` grant** 下（与加入 Token 同结构），`roomAdmin`/`roomList` 均为 bool
#[derive(Serialize)]
struct ApiClaims {
    /// 签发者（API Key，LiveKit 服务端认证约定）
    iss: String,
    /// 过期时间（unix 秒）
    exp: i64,
    /// 签发时间
    nbf: i64,
    /// 服务端 API 权限（video grant）
    #[serde(rename = "video")]
    video: ApiVideoGrant,
}

#[derive(Serialize)]
struct ApiVideoGrant {
    /// 管理房间（ListParticipants 等参与者接口必需）
    #[serde(rename = "roomAdmin")]
    room_admin: bool,
    /// 目标房间名（实测校准：仅 roomAdmin 会被该版本 LiveKit 判 permissions denied，
    /// 必须同时指定 `room` 才可 ListParticipants，与官方 SDK 的 authHeader 一致）
    room: String,
    /// 列出房间（ListRooms）
    #[serde(rename = "roomList")]
    room_list: bool,
}

/// 签发 LiveKit 加入 Token。
/// `api_key`：LiveKit API Key；`api_secret`：LiveKit API Secret；
/// `room`：房间名（= topic_id）；`user_id`：用户身份；`ttl_secs`：有效期（秒）。
pub fn issue_join_token(
    api_key: &str,
    api_secret: &str,
    room: &str,
    user_id: &str,
    ttl_secs: i64,
) -> Result<String, String> {
    let now = lonisle_core::device::current_unix_time();
    let claims = LiveKitClaims {
        sub: user_id.to_string(),
        name: user_id.to_string(),
        video: VideoGrant {
            room_join: true,
            room: room.to_string(),
            can_publish: true,
            can_subscribe: true,
        },
        exp: now + ttl_secs,
        nbf: now - 10, // 允许少量时钟偏差
        iss: api_key.to_string(),
    };

    let key = EncodingKey::from_secret(api_secret.as_bytes());
    encode(&Header::default(), &claims, &key).map_err(|e| e.to_string())
}

/// 查询 LiveKit 房间当前参与者人数（F-AV-COUNT，话题列表展示用）。
///
/// `host`：LiveKit 服务地址（`ws://host:7880` / `wss://...` / `http(s)://...` 均可，自动归一化）；
/// 经 `twirp/livekit.RoomService/ListParticipants` 拉取参与者列表计数。
pub async fn count_room_participants(
    host: &str,
    api_key: &str,
    api_secret: &str,
    room: &str,
) -> anyhow::Result<usize> {
    // 归一化为 REST base：ws:// → http://、wss:// → https://
    let rest_base = if host.starts_with("wss://") {
        host.replacen("wss://", "https://", 1)
    } else if host.starts_with("ws://") {
        host.replacen("ws://", "http://", 1)
    } else {
        host.to_string()
    };
    let rest_base = rest_base.trim_end_matches('/');

    // 服务端认证 JWT：iss=api_key，30s 有效；不带 sub、权限放 video grant，
    // 且必须带 room 指定目标房间（F-AV-COUNT 实测校准，与官方 SDK authHeader 一致）
    let now = lonisle_core::device::current_unix_time();
    let claims = ApiClaims {
        iss: api_key.to_string(),
        exp: now + 30,
        nbf: now - 60, // 对齐官方 SDK 默认（60s 时钟偏差余量）
        video: ApiVideoGrant {
            room_admin: true,
            room: room.to_string(),
            room_list: true,
        },
    };
    let token =
        encode(&Header::default(), &claims, &EncodingKey::from_secret(api_secret.as_bytes()))
            .map_err(|e| anyhow::anyhow!("签发 LiveKit API Token 失败：{e}"))?;

    let url = format!("{rest_base}/twirp/livekit.RoomService/ListParticipants");
    let resp = reqwest::Client::new()
        .post(&url)
        .header("Authorization", format!("Bearer {token}"))
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({ "room": room }))
        .send()
        .await
        .map_err(|e| anyhow::anyhow!("请求 LiveKit 失败（{url}）：{e}"))?
        .error_for_status()
        .map_err(|e| anyhow::anyhow!("LiveKit 返回错误（{url}）：{e}"))?;
    let json: serde_json::Value = resp.json().await?;
    Ok(json["participants"]
        .as_array()
        .map(|a| a.len())
        .unwrap_or(0))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn issue_and_parse() {
        let token = issue_join_token("appkey", "secret47631", "topic-1", "user-1", 3600).unwrap();
        // token 应包含三段（header.payload.signature）
        assert_eq!(token.split('.').count(), 3);
    }

    #[test]
    fn different_rooms_different_tokens() {
        let t1 = issue_join_token("appkey", "secret", "room-a", "user-1", 3600).unwrap();
        let t2 = issue_join_token("appkey", "secret", "room-b", "user-1", 3600).unwrap();
        assert_ne!(t1, t2);
    }
}
