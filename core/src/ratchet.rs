//! 双棘轮（Signal 规范实现，M6 E2EE）
//!
//! 完整 Signal 双棘轮：
//! - DH 棘轮：KDF_RK(root_key, dh_out) → (新 root_key, 新 chain_key)
//! - 对称棘轮：KDF_CK(chain_key) → (message_key, 新 chain_key)
//! - 发送链/接收链独立推进
//! - 乱序消息：接收方按 header 的 pn/n 缓存跳过的消息密钥（上限防 DoS）
//!
//! 消息格式：header(DH公钥32 + 前链长度pn 4 + 消息序号n 4) + AES-GCM 密文

use hmac::{Hmac, Mac};
use hkdf::Hkdf;
use sha2::Sha256;

use crate::aes_gcm::{decrypt, encrypt};
use crate::x25519::X25519Keypair;

type HmacSha256 = Hmac<Sha256>;

/// 乱序消息密钥缓存上限（每会话，防内存膨胀/DoS）
pub const MAX_SKIP: u32 = 200;

const HEADER_LEN: usize = 40;

/// KDF_RK：DH 棘轮步进（HKDF-SHA256，64 字节输出 = 新 root + 新 chain）
fn kdf_rk(root_key: &[u8; 32], dh_out: &[u8; 32]) -> ([u8; 32], [u8; 32]) {
    let hk = Hkdf::<Sha256>::new(Some(root_key), dh_out);
    let mut okm = [0u8; 64];
    hk.expand(b"lonisle-ratchet-rk", &mut okm)
        .expect("64 bytes output");
    let rk: [u8; 32] = okm[..32].try_into().unwrap();
    let ck: [u8; 32] = okm[32..].try_into().unwrap();
    (rk, ck)
}

/// KDF_CK：对称棘轮步进（HMAC-SHA256）
fn kdf_ck(chain_key: &[u8; 32]) -> ([u8; 32], [u8; 32]) {
    let mk = hmac_sha256(chain_key, &[0x01]);
    let ck = hmac_sha256(chain_key, &[0x02]);
    (mk, ck)
}

fn hmac_sha256(key: &[u8; 32], data: &[u8]) -> [u8; 32] {
    let mut mac = HmacSha256::new_from_slice(key).expect("hmac key");
    mac.update(data);
    let out = mac.finalize().into_bytes();
    out.into()
}

/// 消息 header：DH 公钥 + 前链长度 pn + 消息序号 n
#[derive(Debug, Clone)]
pub struct RatchetHeader {
    pub dh_public: [u8; 32],
    pub pn: u32, // 发出此消息前发送链上已产生的消息数
    pub n: u32,  // 本链消息序号
}

impl RatchetHeader {
    fn encode(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(HEADER_LEN);
        out.extend_from_slice(&self.dh_public);
        out.extend_from_slice(&self.pn.to_be_bytes());
        out.extend_from_slice(&self.n.to_be_bytes());
        out
    }

    fn decode(data: &[u8]) -> Result<Self, String> {
        if data.len() < HEADER_LEN {
            return Err("header 过短".to_string());
        }
        Ok(Self {
            dh_public: data[0..32].try_into().unwrap(),
            pn: u32::from_be_bytes(data[32..36].try_into().unwrap()),
            n: u32::from_be_bytes(data[36..40].try_into().unwrap()),
        })
    }
}

/// 双棘轮状态（可序列化持久化的部分由上层负责）
pub struct RatchetState {
    /// 当前 DH 密钥对
    pub dh_keypair: X25519Keypair,
    /// 对端当前 DH 公钥
    pub peer_dh_public: Option<[u8; 32]>,
    /// 根密钥
    pub root_key: [u8; 32],
    /// 发送链密钥（None = 尚未与对端完成 DH 棘轮）
    send_chain_key: Option<[u8; 32]>,
    /// 接收链密钥
    recv_chain_key: Option<[u8; 32]>,
    /// 发送链已发送消息数（作为下一条的 n，也作为 DH 步进时的 pn）
    send_n: u32,
    /// 发送链上一次 DH 步进前的长度（pn）
    send_pn: u32,
    /// 接收链当前序号
    recv_n: u32,
    /// 乱序消息密钥缓存：(dh_pub, n) → message_key
    skipped_keys: std::collections::HashMap<([u8; 32], u32), [u8; 32]>,
}

impl RatchetState {
    /// 初始化棘轮。root_key 来自 X3DH 协商结果。
    /// 响应方（鲍勃）：dh_keypair = SPK（或新 DH 对）。
    pub fn init(root_key: [u8; 32], dh_keypair: X25519Keypair) -> Self {
        Self {
            dh_keypair,
            peer_dh_public: None,
            root_key,
            send_chain_key: None,
            recv_chain_key: None,
            send_n: 0,
            send_pn: 0,
            recv_n: 0,
            skipped_keys: std::collections::HashMap::new(),
        }
    }

    /// X3DH 后设置初始发送链（发起方）：root = KDF_RK(root, DH(IK_a, SPK_b)) 已在
    /// x3dh 模块完成到 root_key；这里由发起方直接生成首条发送链。
    pub fn initiator_setup(&mut self, peer_spk_pub: &[u8; 32]) {
        // 发起方首次发送即触发 DH 棘轮
        self.peer_dh_public = Some(*peer_spk_pub);
        self.dh_keypair = X25519Keypair::generate();
        let shared = self.dh_keypair.dh(peer_spk_pub);
        let (rk, ck) = kdf_rk(&self.root_key, &shared);
        self.root_key = rk;
        self.send_chain_key = Some(ck);
        self.send_n = 0;
        self.send_pn = 0;
    }

    /// 丢弃密钥超出范围的旧消息
    fn skip_message_keys(&mut self, until: u32) -> Result<(), String> {
        let Some(ck) = self.recv_chain_key else {
            return Ok(());
        };
        if self.recv_n + MAX_SKIP < until {
            return Err(format!("乱序跨度超过上限（{until} - {} > {MAX_SKIP}）", self.recv_n));
        }
        let mut ck = ck;
        // 若 recv_n == until 且 pn 覆盖完整则无跳过
        if until > self.recv_n {
            let mut n = self.recv_n;
            while n < until {
                let (mk, next_ck) = kdf_ck(&ck);
                // 缓存跳过的密钥（以当前对端 DH 标识）
                if let Some(peer) = self.peer_dh_public {
                    self.skipped_keys.insert((peer, n), mk);
                }
                ck = next_ck;
                n += 1;
            }
            self.recv_chain_key = Some(ck);
            self.recv_n = until;
        }
        Ok(())
    }

    /// DH 棘轮步进（收到对端新 DH 公钥时）
    fn dh_ratchet(&mut self, header: &RatchetHeader) -> Result<(), String> {
        // 1) 先为旧接收链补齐跳过的密钥
        self.skip_message_keys(header.pn)?;

        // 2) DH 步进：更新接收链
        self.peer_dh_public = Some(header.dh_public);
        let shared = self.dh_keypair.dh(&header.dh_public);
        let (rk, recv_ck) = kdf_rk(&self.root_key, &shared);
        self.root_key = rk;
        self.recv_chain_key = Some(recv_ck);
        self.recv_n = 0;

        // 3) 生成新 DH 对，更新发送链
        self.dh_keypair = X25519Keypair::generate();
        let shared2 = self.dh_keypair.dh(&header.dh_public);
        let (rk2, send_ck) = kdf_rk(&self.root_key, &shared2);
        self.root_key = rk2;
        self.send_chain_key = Some(send_ck);
        self.send_n = 0;
        self.send_pn = header.pn;
        Ok(())
    }

    /// 加密一条消息，返回 header + 密文。
    /// 首次发送前需已完成 initiator_setup 或收到过对端消息。
    pub fn encrypt(&mut self, plaintext: &[u8]) -> Result<Vec<u8>, String> {
        let Some(ck) = self.send_chain_key else {
            return Err("发送链未初始化（先 initiator_setup 或收到对端消息）".to_string());
        };

        let header = RatchetHeader {
            dh_public: self.dh_keypair.public,
            pn: self.send_pn,
            n: self.send_n,
        };

        let (mk, next_ck) = kdf_ck(&ck);
        self.send_chain_key = Some(next_ck);
        self.send_n += 1;

        let header_bytes = header.encode();
        let ciphertext = encrypt(&mk, plaintext, &header_bytes).map_err(|e| e.to_string())?;
        let mut out = header_bytes;
        out.extend_from_slice(&ciphertext);
        Ok(out)
    }

    /// 解密一条消息（header + 密文）。支持乱序（缓存跳过的密钥）。
    pub fn decrypt(&mut self, data: &[u8]) -> Result<Vec<u8>, String> {
        if data.len() < HEADER_LEN + 16 {
            return Err("消息过短".to_string());
        }
        let header = RatchetHeader::decode(data)?;

        // 1) 乱序命中：缓存中的消息密钥直接用
        if let Some(mk) = self.skipped_keys.remove(&(header.dh_public, header.n)) {
            return decrypt(&mk, &data[HEADER_LEN..], &data[..HEADER_LEN])
                .map_err(|e| e.to_string());
        }

        // 2) 对端新 DH 公钥 → DH 棘轮步进
        if self.peer_dh_public.map(|p| p != header.dh_public).unwrap_or(true) {
            self.dh_ratchet(&header)?;
        } else if header.n < self.recv_n {
            // 同链旧消息且不在缓存中：不可重放
            return Err(format!(
                "消息序号回退（{} < {}）且密钥已丢弃",
                header.n, self.recv_n
            ));
        }

        // 3) 同链序号推进（可能需要跳过中间消息）
        self.skip_message_keys(header.n)?;

        let Some(ck) = self.recv_chain_key else {
            return Err("接收链未初始化".to_string());
        };
        let (mk, next_ck) = kdf_ck(&ck);
        self.recv_chain_key = Some(next_ck);
        self.recv_n = header.n + 1;

        decrypt(&mk, &data[HEADER_LEN..], &data[..HEADER_LEN]).map_err(|e| e.to_string())
    }

    /// 序列化状态（客户端持久化会话用）。
    /// 格式：magic(5) + dh_secret(32) + dh_public(32) + peer(1+32) +
    /// root(32) + send_ck(1+32) + recv_ck(1+32) + n/pn/nr(12) +
    /// skipped_count(4) + entries(peer32+n4+key32)
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(160 + self.skipped_keys.len() * 68);
        out.extend_from_slice(b"LNRS1");
        out.extend_from_slice(&self.dh_keypair.secret);
        out.extend_from_slice(&self.dh_keypair.public);
        match self.peer_dh_public {
            Some(p) => {
                out.push(1);
                out.extend_from_slice(&p);
            }
            None => out.push(0),
        }
        out.extend_from_slice(&self.root_key);
        match self.send_chain_key {
            Some(k) => {
                out.push(1);
                out.extend_from_slice(&k);
            }
            None => out.push(0),
        }
        match self.recv_chain_key {
            Some(k) => {
                out.push(1);
                out.extend_from_slice(&k);
            }
            None => out.push(0),
        }
        out.extend_from_slice(&self.send_n.to_be_bytes());
        out.extend_from_slice(&self.send_pn.to_be_bytes());
        out.extend_from_slice(&self.recv_n.to_be_bytes());
        out.extend_from_slice(&(self.skipped_keys.len() as u32).to_be_bytes());
        for ((peer, n), key) in &self.skipped_keys {
            out.extend_from_slice(peer);
            out.extend_from_slice(&n.to_be_bytes());
            out.extend_from_slice(key);
        }
        out
    }

    /// 反序列化状态。
    pub fn from_bytes(data: &[u8]) -> Result<Self, String> {
        if data.len() < 5 + 32 + 32 + 1 + 32 + 1 + 1 + 1 + 12 + 4 || &data[..5] != b"LNRS1" {
            return Err("棘轮状态格式错误".to_string());
        }
        let mut off = 5;
        let mut take32 = |off: &mut usize| -> Result<[u8; 32], String> {
            let v: [u8; 32] = data[*off..*off + 32]
                .try_into()
                .map_err(|_| "格式错误".to_string())?;
            *off += 32;
            Ok(v)
        };
        let mut take_opt32 = |off: &mut usize| -> Result<Option<[u8; 32]>, String> {
            let flag = data[*off];
            *off += 1;
            if flag == 0 {
                Ok(None)
            } else {
                Ok(Some(take32(off)?))
            }
        };

        let dh_secret = take32(&mut off)?;
        let dh_public = take32(&mut off)?;
        let peer_dh_public = take_opt32(&mut off)?;
        let root_key = take32(&mut off)?;
        let send_chain_key = take_opt32(&mut off)?;
        let recv_chain_key = take_opt32(&mut off)?;
        let send_n = u32::from_be_bytes(data[off..off + 4].try_into().unwrap());
        off += 4;
        let send_pn = u32::from_be_bytes(data[off..off + 4].try_into().unwrap());
        off += 4;
        let recv_n = u32::from_be_bytes(data[off..off + 4].try_into().unwrap());
        off += 4;
        let count = u32::from_be_bytes(data[off..off + 4].try_into().unwrap()) as usize;
        off += 4;

        if data.len() < off + count * 68 {
            return Err("棘轮状态截断".to_string());
        }
        let mut skipped_keys = std::collections::HashMap::with_capacity(count);
        for _ in 0..count {
            let peer: [u8; 32] = data[off..off + 32].try_into().unwrap();
            off += 32;
            let n = u32::from_be_bytes(data[off..off + 4].try_into().unwrap());
            off += 4;
            let key: [u8; 32] = data[off..off + 32].try_into().unwrap();
            off += 32;
            skipped_keys.insert((peer, n), key);
        }

        Ok(Self {
            dh_keypair: X25519Keypair { secret: dh_secret, public: dh_public },
            peer_dh_public,
            root_key,
            send_chain_key,
            recv_chain_key,
            send_n,
            send_pn,
            recv_n,
            skipped_keys,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 构造协商好的一对棘轮（模拟 X3DH 结果）
    fn make_pair() -> (RatchetState, RatchetState) {
        let root = [9u8; 32];
        let kp_a = X25519Keypair::generate();
        let kp_b = X25519Keypair::generate();
        let mut a = RatchetState::init(root, kp_a);
        let mut b = RatchetState::init(root, kp_b);
        // A 发起：用 B 的公钥做首条发送链
        a.initiator_setup(&b.dh_keypair.public);
        // B 收到 A 首条消息时自然完成 DH 棘轮（解密内处理）
        let _ = &mut b;
        (a, b)
    }

    #[test]
    fn encrypt_decrypt_roundtrip() {
        let (mut a, mut b) = make_pair();

        // A -> B（首条触发 B 侧 DH 棘轮）
        let ct = a.encrypt(b"hello").unwrap();
        let pt = b.decrypt(&ct).unwrap();
        assert_eq!(pt, b"hello");

        // B -> A
        let ct2 = b.encrypt(b"world").unwrap();
        let pt2 = a.decrypt(&ct2).unwrap();
        assert_eq!(pt2, b"world");
    }

    #[test]
    fn multiple_messages() {
        let (mut a, mut b) = make_pair();
        for i in 0..5 {
            let ct = a.encrypt(format!("msg {}", i).as_bytes()).unwrap();
            let pt = b.decrypt(&ct).unwrap();
            assert_eq!(pt, format!("msg {}", i).as_bytes());
        }
        for i in 0..5 {
            let ct = b.encrypt(format!("reply {}", i).as_bytes()).unwrap();
            let pt = a.decrypt(&ct).unwrap();
            assert_eq!(pt, format!("reply {}", i).as_bytes());
        }
    }

    #[test]
    fn out_of_order_delivery() {
        let (mut a, mut b) = make_pair();
        // A 连发 3 条，B 乱序收到（3,1,2）
        let c1 = a.encrypt(b"one").unwrap();
        let c2 = a.encrypt(b"two").unwrap();
        let c3 = a.encrypt(b"three").unwrap();

        assert_eq!(b.decrypt(&c3).unwrap(), b"three");
        assert_eq!(b.decrypt(&c1).unwrap(), b"one");
        assert_eq!(b.decrypt(&c2).unwrap(), b"two");
    }

    #[test]
    fn interleaved_conversation() {
        let (mut a, mut b) = make_pair();
        // 交错收发（每次都触发 DH 棘轮）
        for round in 0..4 {
            let ct = a.encrypt(format!("a{}", round).as_bytes()).unwrap();
            assert_eq!(b.decrypt(&ct).unwrap(), format!("a{}", round).as_bytes());
            let ct = b.encrypt(format!("b{}", round).as_bytes()).unwrap();
            assert_eq!(a.decrypt(&ct).unwrap(), format!("b{}", round).as_bytes());
        }
    }

    #[test]
    fn tampered_fails() {
        let (mut a, mut b) = make_pair();
        let mut ct = a.encrypt(b"secret").unwrap();
        let len = ct.len();
        ct[len - 1] ^= 0xff;
        assert!(b.decrypt(&ct).is_err());
    }

    #[test]
    fn replay_rejected() {
        let (mut a, mut b) = make_pair();
        let ct = a.encrypt(b"once").unwrap();
        assert!(b.decrypt(&ct).is_ok());
        // 重放同一条：序号回退且密钥已被消费
        assert!(b.decrypt(&ct).is_err());
    }

    #[test]
    fn serialization_roundtrip() {
        let (mut a, mut b) = make_pair();
        let ct = a.encrypt(b"hello").unwrap();
        let _ = b.decrypt(&ct).unwrap();

        // 中途序列化/反序列化，继续会话
        let bytes = a.to_bytes();
        let mut a2 = RatchetState::from_bytes(&bytes).unwrap();
        let ct2 = a2.encrypt(b"after restore").unwrap();
        assert_eq!(b.decrypt(&ct2).unwrap(), b"after restore");

        // 含乱序缓存的状态序列化
        let c1 = a2.encrypt(b"skipped").unwrap();
        let _c2 = a2.encrypt(b"latest").unwrap();
        let bytes_b = b.to_bytes();
        let mut b2 = RatchetState::from_bytes(&bytes_b).unwrap();
        assert_eq!(b2.decrypt(&c1).unwrap(), b"skipped");
    }

    #[test]
    fn skip_beyond_limit_rejected() {
        let (mut a, mut b) = make_pair();
        // 发 MAX_SKIP+2 条，B 只收最后一条 → 跨度超限被拒
        let mut last = Vec::new();
        for _ in 0..(MAX_SKIP + 2) {
            last = a.encrypt(b"x").unwrap();
        }
        assert!(b.decrypt(&last).is_err());
    }
}
