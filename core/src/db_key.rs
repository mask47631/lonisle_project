//! 本地库加密密钥派生（M5）
//!
//! SQLCipher 密钥派生自设备密钥，HMAC-SHA256(device_secret, "lonisle-db")。
//! 密钥在 Rust 侧派生，避免明文密钥在 Dart 侧出现。

use hmac::{Hmac, Mac};
use sha2::Sha256;

type HmacSha256 = Hmac<Sha256>;

/// 从设备私钥字节派生 SQLCipher 数据库密钥（返回 32 字节 hex）。
pub fn derive_db_key(device_secret: &[u8]) -> String {
    let mut mac = HmacSha256::new_from_slice(b"lonisle-db").expect("HMAC key");
    mac.update(device_secret);
    let result = mac.finalize();
    hex::encode(result.into_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deterministic() {
        let secret = [7u8; 32];
        let k1 = derive_db_key(&secret);
        let k2 = derive_db_key(&secret);
        assert_eq!(k1, k2);
        assert_eq!(k1.len(), 64); // 32 字节 hex
    }

    #[test]
    fn different_secret_different_key() {
        let a = derive_db_key(&[1u8; 32]);
        let b = derive_db_key(&[2u8; 32]);
        assert_ne!(a, b);
    }
}
