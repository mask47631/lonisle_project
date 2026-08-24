//! 服务器验签：验证聊天服务器发起的 /push 请求签名
//!
//! 聊天服务器用自身密钥对（Ed25519）对请求体签名，
//! 推送服务用服务器公钥验签，防止滥用（F-PUSH-6）。
//! M4 简化：请求头携带 server_id + 公钥 hex + 签名 hex，
//! 推送服务验签「server_id == 公钥哈希」且「签名有效」。

use ed25519_dalek::{Signature, Verifier, VerifyingKey};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AuthError {
    #[error("缺少认证头")]
    MissingHeader,
    #[error("server_id 与公钥不匹配")]
    IdMismatch,
    #[error("签名验证失败")]
    InvalidSignature,
    #[error("公钥格式错误")]
    InvalidPubkey,
}

/// 验证服务器签名。
/// `server_id` 为服务器公钥哈希；`pubkey_hex` 为公钥 hex；`sig_hex` 为签名 hex；`body` 为请求体。
pub fn verify_server_signature(
    server_id: &str,
    pubkey_hex: &str,
    sig_hex: &str,
    body: &[u8],
) -> Result<(), AuthError> {
    let pubkey_bytes = hex::decode(pubkey_hex).map_err(|_| AuthError::InvalidPubkey)?;
    let arr: [u8; 32] = pubkey_bytes
        .as_slice()
        .try_into()
        .map_err(|_| AuthError::InvalidPubkey)?;
    let vk = VerifyingKey::from_bytes(&arr).map_err(|_| AuthError::InvalidPubkey)?;

    // 校验 server_id 与公钥哈希一致
    let derived = lonisle_core::identity::user_id_from_pubkey(&pubkey_bytes);
    if derived != server_id {
        return Err(AuthError::IdMismatch);
    }

    let sig_bytes = hex::decode(sig_hex).map_err(|_| AuthError::InvalidSignature)?;
    let sig_arr: [u8; 64] = sig_bytes
        .as_slice()
        .try_into()
        .map_err(|_| AuthError::InvalidSignature)?;
    let sig = Signature::from_bytes(&sig_arr);

    vk.verify(body, &sig).map_err(|_| AuthError::InvalidSignature)
}

#[cfg(test)]
mod tests {
    use super::*;
    use ed25519_dalek::{Signer, SigningKey};
    use rand::rngs::OsRng;

    #[test]
    fn valid_signature() {
        let signing_key = SigningKey::generate(&mut OsRng);
        let pubkey = signing_key.verifying_key().to_bytes();
        let server_id = lonisle_core::identity::user_id_from_pubkey(&pubkey);

        let body = b"{\"server_id\":\"x\"}";
        let sig = signing_key.sign(body).to_bytes();

        assert!(verify_server_signature(
            &server_id,
            &hex::encode(pubkey),
            &hex::encode(sig),
            body
        )
        .is_ok());
    }

    #[test]
    fn tampered_body_fails() {
        let signing_key = SigningKey::generate(&mut OsRng);
        let pubkey = signing_key.verifying_key().to_bytes();
        let server_id = lonisle_core::identity::user_id_from_pubkey(&pubkey);

        let body = b"original";
        let sig = signing_key.sign(body).to_bytes();

        assert!(verify_server_signature(
            &server_id,
            &hex::encode(pubkey),
            &hex::encode(sig),
            b"tampered"
        )
        .is_err());
    }
}
