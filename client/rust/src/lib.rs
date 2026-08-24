//! LonIsle 客户端 Rust 桥接层
//!
//! 经 flutter_rust_bridge 暴露给 Flutter（Dart）调用，
//! 复用 core 库的身份/设备/协议逻辑，确保与服务器一致。

mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

pub mod api;

pub use api::*;
