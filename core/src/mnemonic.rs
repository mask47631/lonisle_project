//! 主密钥助记词（M3）
//!
//! BIP39 助记词：主私钥 32 字节作为熵，派生 24 词助记词。
//! 导出仅可在已认证设备上、经用户显式确认后进行。
//! 恢复时校验助记词有效性，反推 32 字节种子（即主私钥）。

use bip39::Mnemonic;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum MnemonicError {
    #[error("助记词无效：{0}")]
    InvalidMnemonic(String),
    #[error("种子长度错误：{0}")]
    InvalidSeedLength(usize),
}

/// 从 32 字节主私钥种子生成 24 词助记词。
pub fn generate_mnemonic(seed: &[u8; 32]) -> Result<String, MnemonicError> {
    let mnemonic = Mnemonic::from_entropy(seed)
        .map_err(|e| MnemonicError::InvalidMnemonic(e.to_string()))?;
    Ok(mnemonic.to_string())
}

/// 从助记词恢复 32 字节种子（主私钥）。
pub fn recover_seed(mnemonic_str: &str) -> Result<[u8; 32], MnemonicError> {
    let mnemonic =
        Mnemonic::parse(mnemonic_str).map_err(|e| MnemonicError::InvalidMnemonic(e.to_string()))?;
    let entropy = mnemonic.to_entropy();
    entropy
        .as_slice()
        .try_into()
        .map_err(|_| MnemonicError::InvalidSeedLength(entropy.len()))
}

/// 校验助记词是否合法。
pub fn validate_mnemonic(mnemonic_str: &str) -> bool {
    Mnemonic::parse(mnemonic_str).is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip() {
        let seed = [7u8; 32];
        let mnemonic = generate_mnemonic(&seed).unwrap();
        // 24 词
        assert_eq!(mnemonic.split_whitespace().count(), 24);
        let recovered = recover_seed(&mnemonic).unwrap();
        assert_eq!(recovered, seed);
    }

    #[test]
    fn invalid_mnemonic_fails() {
        assert!(!validate_mnemonic("not a valid mnemonic"));
        assert!(recover_seed("not a valid mnemonic").is_err());
    }
}
