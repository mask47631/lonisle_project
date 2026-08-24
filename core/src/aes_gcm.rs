//! AES-256-GCM 对称加解密（M6 E2EE）

use aes_gcm::aead::{Aead, KeyInit, OsRng};
use aes_gcm::{Aes256Gcm, Key, Nonce};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AesError {
    #[error("加密失败：{0}")]
    Encrypt(String),
    #[error("解密失败：{0}")]
    Decrypt(String),
    #[error("无效密钥长度：{0}")]
    InvalidKey(usize),
}

/// AES-256-GCM 加密。返回 nonce(12字节) + 密文(含 tag)。
pub fn encrypt(key: &[u8; 32], plaintext: &[u8], aad: &[u8]) -> Result<Vec<u8>, AesError> {
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(key));
    // 用 OsRng 生成随机 nonce
    let mut nonce_bytes = [0u8; 12];
    aes_gcm::aead::rand_core::RngCore::fill_bytes(&mut OsRng, &mut nonce_bytes);
    let nonce = Nonce::from_slice(&nonce_bytes);

    let ciphertext = cipher
        .encrypt(nonce, aes_gcm::aead::Payload { msg: plaintext, aad })
        .map_err(|e| AesError::Encrypt(e.to_string()))?;

    let mut out = Vec::with_capacity(12 + ciphertext.len());
    out.extend_from_slice(&nonce_bytes);
    out.extend_from_slice(&ciphertext);
    Ok(out)
}

/// AES-256-GCM 解密。输入 nonce(12字节) + 密文。
pub fn decrypt(key: &[u8; 32], data: &[u8], aad: &[u8]) -> Result<Vec<u8>, AesError> {
    if data.len() < 12 {
        return Err(AesError::Decrypt("密文过短".to_string()));
    }
    let cipher = Aes256Gcm::new(Key::<Aes256Gcm>::from_slice(key));
    let (nonce_bytes, ciphertext) = data.split_at(12);
    let nonce = Nonce::from_slice(nonce_bytes);

    cipher
        .decrypt(nonce, aes_gcm::aead::Payload { msg: ciphertext, aad })
        .map_err(|e| AesError::Decrypt(e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip() {
        let key = [7u8; 32];
        let plaintext = b"hello e2ee";
        let aad = b"header";
        let ct = encrypt(&key, plaintext, aad).unwrap();
        let pt = decrypt(&key, &ct, aad).unwrap();
        assert_eq!(pt, plaintext);
    }

    #[test]
    fn wrong_key_fails() {
        let key = [7u8; 32];
        let wrong = [8u8; 32];
        let ct = encrypt(&key, b"secret", b"").unwrap();
        assert!(decrypt(&wrong, &ct, b"").is_err());
    }

    #[test]
    fn tampered_fails() {
        let key = [7u8; 32];
        let mut ct = encrypt(&key, b"secret", b"").unwrap();
        ct[13] ^= 0xff;
        assert!(decrypt(&key, &ct, b"").is_err());
    }
}
