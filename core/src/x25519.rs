//! X25519 密钥对与 DH 计算（M6 E2EE）

use x25519_dalek::{PublicKey, StaticSecret};

/// X25519 密钥对
pub struct X25519Keypair {
    pub secret: [u8; 32],
    pub public: [u8; 32],
}

impl X25519Keypair {
    /// 生成随机密钥对。
    pub fn generate() -> Self {
        let secret = StaticSecret::random_from_rng(rand::rngs::OsRng);
        let public = PublicKey::from(&secret);
        Self {
            secret: secret.to_bytes(),
            public: *public.as_bytes(),
        }
    }

    /// 从私钥字节恢复。
    pub fn from_secret(secret: &[u8; 32]) -> Self {
        let sk = StaticSecret::from(*secret);
        let public = PublicKey::from(&sk);
        Self {
            secret: *secret,
            public: *public.as_bytes(),
        }
    }

    /// X25519 DH：与对端公钥计算共享密钥。
    pub fn dh(&self, peer_public: &[u8; 32]) -> [u8; 32] {
        let sk = StaticSecret::from(self.secret);
        let pk = PublicKey::from(*peer_public);
        *sk.diffie_hellman(&pk).as_bytes()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn dh_symmetric() {
        let a = X25519Keypair::generate();
        let b = X25519Keypair::generate();
        let shared_a = a.dh(&b.public);
        let shared_b = b.dh(&a.public);
        assert_eq!(shared_a, shared_b);
    }

    #[test]
    fn dh_not_zero() {
        let a = X25519Keypair::generate();
        let b = X25519Keypair::generate();
        let shared = a.dh(&b.public);
        assert_ne!(shared, [0u8; 32]);
    }

    #[test]
    fn from_secret_roundtrip() {
        let kp = X25519Keypair::generate();
        let restored = X25519Keypair::from_secret(&kp.secret);
        assert_eq!(kp.public, restored.public);
    }
}
