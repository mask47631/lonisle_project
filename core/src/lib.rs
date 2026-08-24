//! LonIsle core 共享库
//!
//! 协议、加密、身份、设备、游标等核心逻辑，供聊天服务器与客户端复用，
//! 从根本上一端实现、杜绝两端偏差。

pub mod proto;
pub mod version;
pub mod identity;
pub mod device;
pub mod signature;
pub mod cursor;
pub mod mnemonic;
pub mod db_key;
pub mod x25519;
pub mod aes_gcm;
pub mod ratchet;
pub mod x3dh;

pub use version::PROTOCOL_VERSION;
