//! LonIsle 聊天服务器库
//!
//! 提供存储层、WebSocket 网络层、内嵌管理界面，供二进制入口与集成测试复用。

pub mod storage;
pub mod ws;
pub mod admin;
pub mod push_client;
pub mod attachments;
pub mod livekit;
pub mod tls;
pub mod backup;

pub use storage::{SqliteStorage, Storage};
pub use ws::AppState;
