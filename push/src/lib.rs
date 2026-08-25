//! LonIsle 推送服务库
//!
//! 半中心组件：厂商推送中继 + 服务器发现目录，不接触消息内容。
//! 模块导出供二进制入口与集成测试复用。

/// 编译时间版本号（YYYYMMDDHHMM，由 build.rs 注入，如 202608251509）。
pub const SERVER_VERSION: &str = include_str!(concat!(env!("OUT_DIR"), "/build_version.txt"));

pub mod storage;
pub mod vendor;
pub mod rate_limit;
pub mod auth;
pub mod api;
pub mod admin;
pub mod fcm;

pub use storage::{SqliteStorage, Storage};
pub use vendor::{MockVendor, VendorPush, VendorRegistry};
pub use rate_limit::RateLimiter;
pub use fcm::{FcmConfig, FcmVendor};
