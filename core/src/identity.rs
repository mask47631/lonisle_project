//! 身份系统：主密钥对生成、用户 ID 派生、展示名编码

use ed25519_dalek::{SigningKey, VerifyingKey};
use rand::rngs::OsRng;
use sha2::{Digest, Sha256};
use thiserror::Error;

/// 主密钥对（Ed25519）。主私钥仅存本地，永不上传。
pub struct MasterKeypair {
    pub signing_key: SigningKey,
    pub verifying_key: VerifyingKey,
}

/// 身份相关错误
#[derive(Debug, Error)]
pub enum IdentityError {
    #[error("无效的公钥长度：{0}")]
    InvalidPublicKey(usize),
    #[error("无效的私钥长度：{0}")]
    InvalidSecretKey(usize),
}

impl MasterKeypair {
    /// 生成本地随机主密钥对（密码学随机 256bit，碰撞概率可忽略）。
    pub fn generate() -> Self {
        let signing_key = SigningKey::generate(&mut OsRng);
        let verifying_key = signing_key.verifying_key();
        Self {
            signing_key,
            verifying_key,
        }
    }

    /// 从 32 字节种子/私钥字节恢复主密钥对。
    pub fn from_bytes(secret: &[u8]) -> Result<Self, IdentityError> {
        let arr: [u8; 32] = secret
            .try_into()
            .map_err(|_| IdentityError::InvalidSecretKey(secret.len()))?;
        let signing_key = SigningKey::from_bytes(&arr);
        let verifying_key = signing_key.verifying_key();
        Ok(Self {
            signing_key,
            verifying_key,
        })
    }

    /// 导出主私钥字节（仅用于本地安全存储，勿上传）。
    pub fn secret_bytes(&self) -> [u8; 32] {
        self.signing_key.to_bytes()
    }

    /// 导出主公钥字节。
    pub fn public_bytes(&self) -> [u8; 32] {
        self.verifying_key.to_bytes()
    }

    /// 计算用户 ID = 主公钥哈希（SHA-256，取前 16 字节 → Base32 小写）。
    pub fn user_id(&self) -> String {
        user_id_from_pubkey(&self.public_bytes())
    }
}

/// 由主公钥字节计算用户 ID（SHA-256 哈希的 Base32 小写编码）。
pub fn user_id_from_pubkey(pubkey: &[u8]) -> String {
    let hash = Sha256::digest(pubkey);
    base32::encode(base32::Alphabet::Crockford, &hash)
        .to_lowercase()
}

/// 短哈希（ID 展示后缀，如 `3f9a2b`）。
pub fn short_hash(user_id: &str) -> String {
    // 取 ID 前 6 字符作为短哈希展示
    let chars: String = user_id
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .take(6)
        .collect();
    chars
}

/// 展示名格式：`名称#短哈希`（如 `Alice#3f9a2b`）。
pub fn display_name(name: &str, user_id: &str) -> String {
    format!("{}#{}", name, short_hash(user_id))
}

/// 由用户 ID 派生 Identicon 头像种子（稳定的字节序列）。
pub fn avatar_seed(user_id: &str) -> [u8; 8] {
    let hash = Sha256::digest(user_id.as_bytes());
    let mut seed = [0u8; 8];
    seed.copy_from_slice(&hash[..8]);
    seed
}

/// 随机默认昵称。
pub fn random_default_name(user_id: &str) -> String {
    format!("User#{}", short_hash(user_id))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generate_and_derive_id() {
        let kp = MasterKeypair::generate();
        let id = kp.user_id();
        assert!(!id.is_empty());
        // 幂等：相同公钥 → 相同 ID
        assert_eq!(id, user_id_from_pubkey(&kp.public_bytes()));
    }

    #[test]
    fn display_name_format() {
        let name = display_name("Alice", "abcdef123456");
        assert_eq!(name, "Alice#abcdef");
    }

    #[test]
    fn short_hash_strips_non_alnum() {
        assert_eq!(short_hash("ab-cd12"), "abcd12");
    }

    #[test]
    fn restore_from_bytes_roundtrip() {
        let kp = MasterKeypair::generate();
        let restored = MasterKeypair::from_bytes(&kp.secret_bytes()).unwrap();
        assert_eq!(restored.public_bytes(), kp.public_bytes());
    }
}
