//! FCM HTTP v1 推送通道（F-PUSH-2）
//!
//! 两种凭证方式（web 管理端任选其一）：
//!   1. 服务账号（Firebase Admin SDK 同款，推荐）：上传服务账号 JSON，
//!      用 private_key 自签 RS256 JWT 换取 access_token（googleapis JWT bearer）。
//!   2. OAuth2 Refresh Token：Client ID/Secret + Refresh Token，
//!      POST oauth2.googleapis.com/token（grant_type=refresh_token）。
//! 流程：换 access_token → POST fcm.googleapis.com/v1/projects/{project}/messages:send
//! access_token 进程内缓存，过期前 60 秒刷新。

use std::sync::Mutex;
use std::time::{Duration, Instant};

use async_trait::async_trait;
use serde::Deserialize;
use serde_json::json;

use crate::vendor::VendorPush;

/// FCM 配置（web 管理端配置；两种凭证方式任一可用）
#[derive(Clone, Debug)]
pub struct FcmConfig {
    pub project_id: String,
    pub client_id: String,
    pub client_secret: String,
    pub refresh_token: String,
    /// 服务账号 JSON（Firebase Admin SDK 同款；非空时优先使用）
    pub service_account_json: String,
}

/// Firebase 服务账号（从 JSON 解析）
#[derive(Deserialize)]
pub struct ServiceAccount {
    #[serde(rename = "type")]
    pub account_type: Option<String>,
    pub project_id: String,
    /// PKCS8 PEM 私钥
    pub private_key: String,
    pub client_email: String,
    pub token_uri: Option<String>,
}

impl FcmConfig {
    /// 凭证是否可用：服务账号 JSON 非空，或 4 项 OAuth2 凭证齐全
    pub fn complete(&self) -> bool {
        if !self.service_account_json.trim().is_empty() {
            return true;
        }
        !self.project_id.is_empty()
            && !self.client_id.is_empty()
            && !self.client_secret.is_empty()
            && !self.refresh_token.is_empty()
    }

    /// 是否为服务账号方式
    pub fn use_service_account(&self) -> bool {
        !self.service_account_json.trim().is_empty()
    }
}

struct CachedToken {
    access_token: String,
    fetched_at: Instant,
    expires_in: u64,
}

/// FCM HTTP v1 通道
pub struct FcmVendor {
    config: FcmConfig,
    http: reqwest::Client,
    token: Mutex<Option<CachedToken>>,
}

impl FcmVendor {
    pub fn new(config: FcmConfig) -> Self {
        Self {
            config,
            http: reqwest::Client::new(),
            token: Mutex::new(None),
        }
    }

    /// 获取（或刷新）OAuth2 access_token
    async fn access_token(&self) -> Result<String, String> {
        // 快路径：缓存未过期（提前 60s 失效）
        if let Some(t) = self.token.lock().unwrap().as_ref() {
            if t.fetched_at.elapsed()
                < Duration::from_secs(t.expires_in.saturating_sub(60))
            {
                return Ok(t.access_token.clone());
            }
        }

        #[derive(Deserialize)]
        struct TokenResp {
            access_token: String,
            expires_in: u64,
        }

        let resp = if self.config.use_service_account() {
            // 方式 1：服务账号 JSON → RS256 JWT 自签 → JWT bearer 换 token
            let jwt = self.service_account_jwt().map_err(|e| e.to_string())?;
            self.http
                .post("https://oauth2.googleapis.com/token")
                .form(&[
                    (
                        "grant_type",
                        "urn:ietf:params:oauth:grant-type:jwt-bearer",
                    ),
                    ("assertion", jwt.as_str()),
                ])
                .timeout(Duration::from_secs(10))
                .send()
                .await
                .map_err(|e| format!("JWT bearer token 请求失败: {e}"))?
        } else {
            // 方式 2：OAuth2 Refresh Token
            self.http
                .post("https://oauth2.googleapis.com/token")
                .form(&[
                    ("grant_type", "refresh_token"),
                    ("client_id", self.config.client_id.as_str()),
                    ("client_secret", self.config.client_secret.as_str()),
                    ("refresh_token", self.config.refresh_token.as_str()),
                ])
                .timeout(Duration::from_secs(10))
                .send()
                .await
                .map_err(|e| format!("OAuth2 token 请求失败: {e}"))?
        };

        if !resp.status().is_success() {
            let status = resp.status();
            let body = resp.text().await.unwrap_or_default();
            return Err(format!("OAuth2 token 响应 {status}: {body}"));
        }

        let tr: TokenResp = resp
            .json()
            .await
            .map_err(|e| format!("OAuth2 token 解析失败: {e}"))?;

        *self.token.lock().unwrap() = Some(CachedToken {
            access_token: tr.access_token.clone(),
            fetched_at: Instant::now(),
            expires_in: tr.expires_in,
        });
        Ok(tr.access_token)
    }

    /// 服务账号 RS256 JWT 自签（Firebase Admin SDK 同款算法）
    fn service_account_jwt(&self) -> Result<String, Box<dyn std::error::Error>> {
        use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};

        let sa: ServiceAccount =
            serde_json::from_str(&self.config.service_account_json.trim())?;
        let token_uri = sa
            .token_uri
            .unwrap_or_else(|| "https://oauth2.googleapis.com/token".to_string());
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)?
            .as_secs();

        let claims = json!({
            "iss": sa.client_email,
            "scope": "https://www.googleapis.com/auth/firebase.messaging",
            "aud": token_uri,
            "iat": now,
            "exp": now + 3600,
        });

        let key = EncodingKey::from_rsa_pem(sa.private_key.as_bytes())?;
        Ok(encode(&Header::new(Algorithm::RS256), &claims, &key)?)
    }
}

#[async_trait]
impl VendorPush for FcmVendor {
    async fn send_notification(&self, token: &str, title: &str, body: &str) {
        let access_token = match self.access_token().await {
            Ok(t) => t,
            Err(e) => {
                tracing::error!(error = %e, "FCM 获取 access_token 失败，推送丢弃");
                return;
            }
        };

        // project_id：优先配置字段，服务账号方式可回退到 JSON 内字段
        let project_id = if self.config.project_id.is_empty() {
            serde_json::from_str::<ServiceAccount>(&self.config.service_account_json)
                .map(|sa| sa.project_id)
                .unwrap_or_default()
        } else {
            self.config.project_id.clone()
        };
        let url = format!(
            "https://fcm.googleapis.com/v1/projects/{}/messages:send",
            project_id
        );
        let payload = serde_json::json!({
            "message": {
                "token": token,
                "notification": {
                    "title": title,
                    "body": body,
                },
                // 免内容：仅唤醒（F-PUSH-5），data 不含消息内容
                "data": {
                    "kind": "wake",
                },
                "android": {
                    "priority": "high",
                },
            }
        });

        match self
            .http
            .post(&url)
            .bearer_auth(&access_token)
            .json(&payload)
            .timeout(Duration::from_secs(10))
            .send()
            .await
        {
            Ok(resp) if resp.status().is_success() => {
                tracing::info!("[fcm] 推送成功");
            }
            Ok(resp) => {
                let status = resp.status();
                let body = resp.text().await.unwrap_or_default();
                // 404 = token 无效/已卸载；410 = token 过期：上层可据此清理
                tracing::warn!(status = %status, body = %body, "[fcm] 推送被拒");
            }
            Err(e) => {
                tracing::warn!(error = %e, "[fcm] 推送请求失败");
            }
        }
    }
}
