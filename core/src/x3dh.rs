//! X3DH 密钥协商（Signal 规范，M6 E2EE）
//!
//! 基于 X25519 的 X3DH：发起方用 (IK, EK) × (对端 IK, SPK, OPK)，响应方对称。
//! KDF：SK = HKDF-SHA256(F, salt=零, info="LonIsleX3DH")，
//! 其中 F = 0xFF×32 || DH1 || DH2 || DH3 [|| DH4]（Signal 规范格式）。

use hkdf::Hkdf;
use sha2::Sha256;

use crate::x25519::X25519Keypair;

/// X3DH 协商结果：共享密钥（32 字节）。
/// 发起方视角：initiator 的身份密钥 IK、临时密钥 EK。
/// 对端：身份公钥 ik_pub、签名预密钥 spk_pub、一次性预密钥 opk_pub（可选）。
pub fn x3dh_initiator(
    ik: &X25519Keypair,
    ek: &X25519Keypair,
    peer_ik_pub: &[u8; 32],
    peer_spk_pub: &[u8; 32],
    peer_opk_pub: Option<&[u8; 32]>,
) -> [u8; 32] {
    let mut dh_outputs = Vec::new();
    // DH1: IK × peer_SPK
    dh_outputs.extend_from_slice(&ik.dh(peer_spk_pub));
    // DH2: EK × peer_IK
    dh_outputs.extend_from_slice(&ek.dh(peer_ik_pub));
    // DH3: EK × peer_SPK
    dh_outputs.extend_from_slice(&ek.dh(peer_spk_pub));
    // DH4: EK × peer_OPK（若提供）
    if let Some(opk) = peer_opk_pub {
        dh_outputs.extend_from_slice(&ek.dh(opk));
    }

    kdf_from_dh(&dh_outputs)
}

/// 响应方视角：已知发起方的 IK 公钥和 EK 公钥。
pub fn x3dh_responder(
    ik: &X25519Keypair,
    spk: &X25519Keypair,
    opk: Option<&X25519Keypair>,
    peer_ik_pub: &[u8; 32],
    peer_ek_pub: &[u8; 32],
) -> [u8; 32] {
    let mut dh_outputs = Vec::new();
    // DH1: SPK × peer_IK
    dh_outputs.extend_from_slice(&spk.dh(peer_ik_pub));
    // DH2: IK × peer_EK
    dh_outputs.extend_from_slice(&ik.dh(peer_ek_pub));
    // DH3: SPK × peer_EK
    dh_outputs.extend_from_slice(&spk.dh(peer_ek_pub));
    // DH4: OPK × peer_EK（若提供）
    if let Some(opk_kp) = opk {
        dh_outputs.extend_from_slice(&opk_kp.dh(peer_ek_pub));
    }

    kdf_from_dh(&dh_outputs)
}

/// Signal 规范 KDF：F = 0xFF×32 || DH 输出，SK = HKDF(F, 零盐)。
fn kdf_from_dh(dh_outputs: &[u8]) -> [u8; 32] {
    let mut f = Vec::with_capacity(32 + dh_outputs.len());
    f.extend_from_slice(&[0xFFu8; 32]);
    f.extend_from_slice(dh_outputs);

    let hk = Hkdf::<Sha256>::new(None, &f);
    let mut sk = [0u8; 32];
    hk.expand(b"LonIsleX3DH", &mut sk)
        .expect("32 bytes output");
    sk
}

/// 验证 SPK 签名（身份密钥对 SPK 公钥的 Ed25519 签名）。
/// PreKeyBundle.signed_pre_key_sig 字段的消费入口（防中间人替换 SPK）。
pub fn verify_spk_signature(
    identity_pubkey: &[u8; 32],
    spk_pub: &[u8; 32],
    signature: &[u8],
) -> bool {
    use ed25519_dalek::{Signature, Verifier, VerifyingKey};

    let Ok(vk) = VerifyingKey::from_bytes(identity_pubkey) else {
        return false;
    };
    let Ok(sig) = Signature::from_slice(signature) else {
        return false;
    };
    vk.verify(spk_pub, &sig).is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn x3dh_symmetric() {
        let ik_a = X25519Keypair::generate();
        let ek_a = X25519Keypair::generate();
        let ik_b = X25519Keypair::generate();
        let spk_b = X25519Keypair::generate();
        let opk_b = X25519Keypair::generate();

        let init = x3dh_initiator(&ik_a, &ek_a, &ik_b.public, &spk_b.public, Some(&opk_b.public));
        let resp = x3dh_responder(&ik_b, &spk_b, Some(&opk_b), &ik_a.public, &ek_a.public);
        assert_eq!(init, resp);
    }

    #[test]
    fn x3dh_without_opk() {
        let ik_a = X25519Keypair::generate();
        let ek_a = X25519Keypair::generate();
        let ik_b = X25519Keypair::generate();
        let spk_b = X25519Keypair::generate();

        let init = x3dh_initiator(&ik_a, &ek_a, &ik_b.public, &spk_b.public, None);
        let resp = x3dh_responder(&ik_b, &spk_b, None, &ik_a.public, &ek_a.public);
        assert_eq!(init, resp);
    }

    #[test]
    fn spk_signature_verify() {
        use ed25519_dalek::{SigningKey, Signer};
        use rand::rngs::OsRng;

        // 身份密钥（Ed25519）
        let identity = SigningKey::generate(&mut OsRng);
        let identity_pub: [u8; 32] = identity.verifying_key().to_bytes();

        // SPK 公钥签名
        let spk = X25519Keypair::generate();
        let sig = identity.sign(&spk.public).to_bytes();

        assert!(verify_spk_signature(&identity_pub, &spk.public, &sig));

        // 篡改签名 → 失败
        let mut bad = sig.clone();
        bad[0] ^= 0xff;
        assert!(!verify_spk_signature(&identity_pub, &spk.public, &bad));

        // 换 SPK 公钥 → 失败
        let other_spk = X25519Keypair::generate();
        assert!(!verify_spk_signature(&identity_pub, &other_spk.public, &sig));
    }
}
