//! LonIsle 聊天服务器库
//!
//! 提供存储层、WebSocket 网络层、内嵌管理界面，供二进制入口与集成测试复用。

/// 编译时间版本号（YYYYMMDDHHMM，由 build.rs 注入，如 202608251509）。
pub const SERVER_VERSION: &str = include_str!(concat!(env!("OUT_DIR"), "/build_version.txt"));

pub mod storage;
pub mod ws;
pub mod admin;
pub mod push_client;
pub mod attachments;
pub mod livekit;
pub mod backup;

pub use storage::{SqliteStorage, Storage};
pub use ws::AppState;
