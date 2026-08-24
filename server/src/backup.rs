//! 服务器密钥加密备份（F-SID-5）。
//!
//! 备份格式：magic(12) + salt(16) + AES-256-GCM(nonce(12) + 密文)。
//! 密钥由用户口令经 HKDF-SHA256 派生，不落盘、不打印。

use aes_gcm::aead::rand_core::RngCore as _;

/// 备份文件魔数
pub const BACKUP_MAGIC: &[u8; 12] = b"LONISLE-BKP1";

const HKDF_INFO: &[u8] = b"lonisle-server-key-backup-v1";

/// 由口令 + 盐派生 32 字节加密密钥（HKDF-SHA256）。
fn derive_key(passphrase: &str, salt: &[u8]) -> [u8; 32] {
    let hk = hkdf::Hkdf::<sha2::Sha256>::new(Some(salt), passphrase.as_bytes());
    let mut key = [0u8; 32];
    hk.expand(HKDF_INFO, &mut key)
        .expect("HKDF expand 32 字节不可失败");
    key
}

/// 加密备份：口令加密 32 字节服务器私钥，返回完整备份文件内容。
pub fn encrypt_backup(passphrase: &str, secret: &[u8; 32]) -> anyhow::Result<Vec<u8>> {
    if passphrase.len() < 8 {
        anyhow::bail!("备份口令至少 8 个字符");
    }
    let mut salt = [0u8; 16];
    aes_gcm::aead::rand_core::OsRng.fill_bytes(&mut salt);
    let key = derive_key(passphrase, &salt);
    let encrypted = lonisle_core::aes_gcm::encrypt(&key, secret, BACKUP_MAGIC)
        .map_err(|e| anyhow::anyhow!("加密失败: {e}"))?;

    let mut out = Vec::with_capacity(12 + 16 + encrypted.len());
    out.extend_from_slice(BACKUP_MAGIC);
    out.extend_from_slice(&salt);
    out.extend_from_slice(&encrypted);
    Ok(out)
}

/// 解密备份：识别加密格式并还原 32 字节私钥。
/// 兼容旧版明文备份（无魔数、恰为 32 字节）。
pub fn decrypt_backup(passphrase: &str, data: &[u8]) -> anyhow::Result<[u8; 32]> {
    // 旧版明文备份（向后兼容）
    if data.len() == 32 && !data.starts_with(BACKUP_MAGIC) {
        let secret: [u8; 32] = data.try_into().expect("长度已校验");
        return Ok(secret);
    }

    if data.len() < 12 + 16 + 12 + 16 || !data.starts_with(BACKUP_MAGIC) {
        anyhow::bail!("备份文件格式错误（非 LonIsle 加密备份）");
    }
    let salt = &data[12..28];
    let encrypted = &data[28..];
    let key = derive_key(passphrase, salt);
    let plain = lonisle_core::aes_gcm::decrypt(&key, encrypted, BACKUP_MAGIC)
        .map_err(|_| anyhow::anyhow!("解密失败：口令错误或备份已损坏"))?;
    let secret: [u8; 32] = plain
        .try_into()
        .map_err(|_| anyhow::anyhow!("备份内容长度异常"))?;
    Ok(secret)
}

/// 判断备份文件是否为加密格式。
pub fn is_encrypted_backup(data: &[u8]) -> bool {
    data.starts_with(BACKUP_MAGIC)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn backup_roundtrip() {
        let secret = [42u8; 32];
        let data = encrypt_backup("correct horse battery", &secret).unwrap();
        assert!(is_encrypted_backup(&data));
        let restored = decrypt_backup("correct horse battery", &data).unwrap();
        assert_eq!(restored, secret);
    }

    #[test]
    fn wrong_passphrase_fails() {
        let secret = [7u8; 32];
        let data = encrypt_backup("right-password", &secret).unwrap();
        assert!(decrypt_backup("wrong-password", &data).is_err());
    }

    #[test]
    fn legacy_plaintext_compat() {
        let secret = [9u8; 32];
        let restored = decrypt_backup("ignored", &secret).unwrap();
        assert_eq!(restored, secret);
    }

    #[test]
    fn short_passphrase_rejected() {
        assert!(encrypt_backup("short", &[0u8; 32]).is_err());
    }
}
