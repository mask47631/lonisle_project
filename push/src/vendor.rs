//! 厂商推送通道抽象（F-PUSH-2）
//!
//! VendorPush trait 抽象厂商通道（APNs/FCM/华为/小米/OPPO/vivo…）。
//! 按设备注册的 vendor 字段分发；未配置真实凭证的厂商回退 MockVendor。

use async_trait::async_trait;
use tracing::info;

/// 厂商推送通道抽象
#[async_trait]
pub trait VendorPush: Send + Sync {
    /// 向某设备 Token 发送通知。
    async fn send_notification(&self, token: &str, title: &str, body: &str);
}

/// Mock 厂商通道：记录日志，不真发。
#[derive(Clone, Default)]
pub struct MockVendor;

#[async_trait]
impl VendorPush for MockVendor {
    async fn send_notification(&self, token: &str, title: &str, body: &str) {
        // 不打印完整 Token，仅打印前 8 位，避免泄露
        let masked = if token.len() > 8 {
            format!("{}...", &token[..8])
        } else {
            token.to_string()
        };
        info!(token = %masked, title = %title, body = %body, "[mock] 厂商推送已发送");
    }
}

/// 厂商注册表：按 vendor 名称分发到对应通道实现。
/// 未接入真实通道的厂商回退 Mock（打日志）。
/// fcm 用 RwLock<Option<Arc<FcmVendor>>> 包装：支持 web 管理端动态配置/更新通道，
/// 发送时先克隆 Arc 再 await（避免锁跨 await 导致 future 非 Send）。
pub struct VendorRegistry {
    fcm: std::sync::RwLock<Option<std::sync::Arc<crate::fcm::FcmVendor>>>,
    mock: MockVendor,
}

impl VendorRegistry {
    /// fcm 为 None 时 FCM 请求回退 Mock。
    pub fn new(fcm: Option<crate::fcm::FcmVendor>) -> Self {
        Self {
            fcm: std::sync::RwLock::new(fcm.map(std::sync::Arc::new)),
            mock: MockVendor,
        }
    }

    /// 动态更新 FCM 通道（None = 回退 Mock）
    pub fn set_fcm(&self, fcm: Option<crate::fcm::FcmVendor>) {
        *self.fcm.write().unwrap() = fcm.map(std::sync::Arc::new);
    }

    /// 是否已配置真实 FCM 通道
    pub fn has_fcm(&self) -> bool {
        self.fcm.read().unwrap().is_some()
    }

    /// 按厂商名发送（未知厂商/未配置回退 Mock 并告警）
    pub async fn send(&self, vendor: &str, token: &str, title: &str, body: &str) {
        match vendor {
            "fcm" | "google" => {
                // 先克隆 Arc，锁在语句结束即释放，再 await（保持 Send）
                let maybe = self.fcm.read().unwrap().clone();
                if let Some(fcm) = maybe {
                    fcm.send_notification(token, title, body).await;
                } else {
                    tracing::warn!("FCM 未配置（web 端 FCM 配置为空），推送回退 Mock");
                    self.mock.send_notification(token, title, body).await;
                }
            }
            // APNs/华为/小米/OPPO/vivo：接口预留（F-PUSH-2 范围外）
            other => {
                tracing::warn!(vendor = %other, "厂商通道未接入，推送回退 Mock");
                self.mock.send_notification(token, title, body).await;
            }
        }
    }
}
