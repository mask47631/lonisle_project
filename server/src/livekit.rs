//! LiveKit Token 签发（音视频话题，F-TOPIC-7）
//!
//! 使用 jsonwebtoken 签发 HS256 JWT（LiveKit 自签 Token）。
//! 房间名 = topic_id；Token 含 video grant（房间加入权限）+ 用户身份 + 短时过期。

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
