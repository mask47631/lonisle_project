//! 设备密钥对与设备证书链
//!
//! 每台设备生成独立设备密钥对；设备证书由主私钥签发，
//! 绑定 (user_id + device_pubkey)。证书长期有效、不设过期时间，
//! 仅靠吊销列表管理生命周期（M1 不涉及吊销）。

use crate::proto::DeviceCert;
use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use rand::rngs::OsRng;
use sha2::{Digest, Sha256};
use thiserror::Error;

/// 设备密钥对
pub struct DeviceKeypair {
    pub signing_key: SigningKey,
    pub verifying_key: VerifyingKey,
}

#[derive(Debug, Error)]
pub enum DeviceError {
    #[error("无效的设备公钥长度：{0}")]
    InvalidPublicKey(usize),
    #[error("无效的签名长度：{0}")]
    InvalidSignature(usize),
    #[error("证书签名验证失败")]
    InvalidCertSignature,
    #[error("证书 user_id 与主密钥不匹配")]
    UserIdMismatch,
}

impl DeviceKeypair {
    /// 生成设备密钥对。
    pub fn generate() -> Self {
        let signing_key = SigningKey::generate(&mut OsRng);
        let verifying_key = signing_key.verifying_key();
        Self {
            signing_key,
            verifying_key,
        }
    }

    /// 从私钥字节恢复。
    pub fn from_bytes(secret: &[u8]) -> Result<Self, DeviceError> {
        let arr: [u8; 32] = secret
            .try_into()
            .map_err(|_| DeviceError::InvalidPublicKey(secret.len()))?;
        let signing_key = SigningKey::from_bytes(&arr);
        let verifying_key = signing_key.verifying_key();
        Ok(Self {
            signing_key,
            verifying_key,
        })
    }

    pub fn public_bytes(&self) -> [u8; 32] {
        self.verifying_key.to_bytes()
    }

    pub fn secret_bytes(&self) -> [u8; 32] {
        self.signing_key.to_bytes()
    }

    /// 设备 ID = 设备公钥哈希（Base32 小写）。
    pub fn device_id(&self) -> String {
        device_id_from_pubkey(&self.public_bytes())
    }

    /// 对任意字节签名。
    pub fn sign(&self, data: &[u8]) -> Vec<u8> {
        self.signing_key.sign(data).to_bytes().to_vec()
    }
}

/// 从设备公钥计算设备 ID（公钥哈希 Base32 小写）。
pub fn device_id_from_pubkey(pubkey: &[u8]) -> String {
    let hash = Sha256::digest(pubkey);
    base32::encode(base32::Alphabet::Crockford, &hash).to_lowercase()
}

/// 计算设备证书的待签名载荷（固定字段序，保证签发与验证一致）。
pub fn cert_signing_payload(cert: &DeviceCert) -> Vec<u8> {
    let mut payload = Vec::new();
    payload.extend_from_slice(b"lonisle-device-cert-v1\0");
    payload.extend_from_slice(cert.user_id.as_bytes());
    payload.push(0);
    payload.extend_from_slice(&cert.device_pubkey);
    payload.push(0);
    payload.extend_from_slice(cert.device_name.as_bytes());
    payload.push(0);
    payload.extend_from_slice(&cert.issued_at.to_be_bytes());
    // X25519 身份公钥（E2EE，M6）
    if !cert.x25519_pubkey.is_empty() {
        payload.push(0);
        payload.extend_from_slice(&cert.x25519_pubkey);
    }
    payload
}

/// 由主密钥对设备证书签发（首设备自签：主私钥即设备自身所在）。
/// `master_signing_key` 为身份主私钥；`device_keypair` 为新设备密钥对。
pub fn issue_device_cert(
    master_signing_key: &SigningKey,
    user_id: &str,
    device_keypair: &DeviceKeypair,
    device_name: &str,
) -> DeviceCert {
    issue_device_cert_with_pubkey(
        master_signing_key,
        user_id,
        &device_keypair.public_bytes(),
        device_name,
    )
}

/// 由主私钥 + 设备公钥字节签发设备证书（无需设备私钥）。
pub fn issue_device_cert_with_pubkey(
    master_signing_key: &SigningKey,
    user_id: &str,
    device_pubkey: &[u8],
    device_name: &str,
) -> DeviceCert {
    issue_device_cert_full(master_signing_key, user_id, device_pubkey, device_name, &[])
}

/// 签发设备证书（含 X25519 身份公钥绑定，E2EE）。
pub fn issue_device_cert_full(
    master_signing_key: &SigningKey,
    user_id: &str,
    device_pubkey: &[u8],
    device_name: &str,
    x25519_pubkey: &[u8],
) -> DeviceCert {
    let issued_at = current_unix_time();
    let mut cert = DeviceCert {
        user_id: user_id.to_string(),
        device_pubkey: device_pubkey.to_vec(),
        device_name: device_name.to_string(),
        issued_at,
        signature: Vec::new(),
        x25519_pubkey: x25519_pubkey.to_vec(),
    };
    let payload = cert_signing_payload(&cert);
    cert.signature = master_signing_key.sign(&payload).to_bytes().to_vec();
    cert
}

/// 验证设备证书链：证书签名有效 且 user_id 与主密钥派生一致。
/// `master_pubkey` 为主公钥（可由 user_id 对应身份提供）。
pub fn verify_device_cert(cert: &DeviceCert, master_pubkey: &[u8]) -> Result<(), DeviceError> {
    let arr: [u8; 32] = master_pubkey
        .try_into()
        .map_err(|_| DeviceError::InvalidPublicKey(master_pubkey.len()))?;
    let master_vk = VerifyingKey::from_bytes(&arr)
        .map_err(|_| DeviceError::InvalidPublicKey(master_pubkey.len()))?;

    // 校验 user_id 与主公钥派生一致
    let derived = crate::identity::user_id_from_pubkey(master_pubkey);
    if derived != cert.user_id {
        return Err(DeviceError::UserIdMismatch);
    }

    let sig_arr: [u8; 64] = cert
        .signature
        .as_slice()
        .try_into()
        .map_err(|_| DeviceError::InvalidSignature(cert.signature.len()))?;
    let signature = Signature::from_bytes(&sig_arr);
    let payload = cert_signing_payload(cert);

    master_vk
        .verify(&payload, &signature)
        .map_err(|_| DeviceError::InvalidCertSignature)
}

/// 验证设备对某字节数据的签名。
pub fn verify_device_signature(
    device_pubkey: &[u8],
    data: &[u8],
    signature: &[u8],
) -> Result<(), DeviceError> {
    let arr: [u8; 32] = device_pubkey
        .try_into()
        .map_err(|_| DeviceError::InvalidPublicKey(device_pubkey.len()))?;
    let vk = VerifyingKey::from_bytes(&arr)
        .map_err(|_| DeviceError::InvalidPublicKey(device_pubkey.len()))?;
    let sig_arr: [u8; 64] = signature
        .try_into()
        .map_err(|_| DeviceError::InvalidSignature(signature.len()))?;
    let sig = Signature::from_bytes(&sig_arr);
    vk.verify(data, &sig)
        .map_err(|_| DeviceError::InvalidCertSignature)
}

// ---- 吊销证明（M3） ----

/// 计算吊销证明的待签名载荷（固定字段序）。
pub fn revocation_signing_payload(proof: &crate::proto::RevocationProof) -> Vec<u8> {
    let mut payload = Vec::new();
    payload.extend_from_slice(b"lonisle-revocation-v1\0");
    payload.extend_from_slice(proof.user_id.as_bytes());
    payload.push(0);
    payload.extend_from_slice(&proof.device_pubkey);
    payload.push(0);
    payload.extend_from_slice(&proof.revoked_at.to_be_bytes());
    payload
}

/// 由主私钥签发吊销证明（绑定被吊销设备公钥）。
pub fn issue_revocation(
    master_signing_key: &SigningKey,
    user_id: &str,
    device_pubkey: &[u8],
) -> crate::proto::RevocationProof {
    let revoked_at = current_unix_time();
    let mut proof = crate::proto::RevocationProof {
        user_id: user_id.to_string(),
        device_pubkey: device_pubkey.to_vec(),
        revoked_at,
        signature: Vec::new(),
    };
    let payload = revocation_signing_payload(&proof);
    proof.signature = master_signing_key.sign(&payload).to_bytes().to_vec();
    proof
}

/// 验证吊销证明：签名有效 且 user_id 与主公钥派生一致。
pub fn verify_revocation(
    proof: &crate::proto::RevocationProof,
    master_pubkey: &[u8],
) -> Result<(), DeviceError> {
    let arr: [u8; 32] = master_pubkey
        .try_into()
        .map_err(|_| DeviceError::InvalidPublicKey(master_pubkey.len()))?;
    let master_vk = VerifyingKey::from_bytes(&arr)
        .map_err(|_| DeviceError::InvalidPublicKey(master_pubkey.len()))?;

    // 校验 user_id 与主公钥派生一致
    let derived = crate::identity::user_id_from_pubkey(master_pubkey);
    if derived != proof.user_id {
        return Err(DeviceError::UserIdMismatch);
    }

    let sig_arr: [u8; 64] = proof
        .signature
        .as_slice()
        .try_into()
        .map_err(|_| DeviceError::InvalidSignature(proof.signature.len()))?;
    let signature = Signature::from_bytes(&sig_arr);
    let payload = revocation_signing_payload(proof);

    master_vk
        .verify(&payload, &signature)
        .map_err(|_| DeviceError::InvalidCertSignature)
}

/// 当前 unix 秒。
pub fn current_unix_time() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::identity::MasterKeypair;

    #[test]
    fn cert_issue_and_verify() {
        let master = MasterKeypair::generate();
        let device = DeviceKeypair::generate();
        let cert = issue_device_cert(
            &master.signing_key,
            &master.user_id(),
            &device,
            "Alice's iPhone",
        );

        assert!(verify_device_cert(&cert, &master.public_bytes()).is_ok());
    }

    #[test]
    fn cert_tamper_fails() {
        let master = MasterKeypair::generate();
        let device = DeviceKeypair::generate();
        let mut cert = issue_device_cert(
            &master.signing_key,
            &master.user_id(),
            &device,
            "Alice's iPhone",
        );
        cert.device_name = "Mallory's iPhone".to_string();
        assert!(verify_device_cert(&cert, &master.public_bytes()).is_err());
    }

    #[test]
    fn cert_wrong_master_fails() {
        let master = MasterKeypair::generate();
        let other = MasterKeypair::generate();
        let device = DeviceKeypair::generate();
        let cert = issue_device_cert(
            &master.signing_key,
            &master.user_id(),
            &device,
            "Alice's iPhone",
        );
        assert!(verify_device_cert(&cert, &other.public_bytes()).is_err());
    }

    #[test]
    fn device_sign_and_verify() {
        let device = DeviceKeypair::generate();
        let data = b"hello world";
        let sig = device.sign(data);
        assert!(verify_device_signature(&device.public_bytes(), data, &sig).is_ok());
        assert!(verify_device_signature(&device.public_bytes(), b"tampered", &sig).is_err());
    }
}
