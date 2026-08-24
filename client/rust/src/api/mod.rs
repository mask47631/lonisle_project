//! 桥接 API：暴露给 Dart 的身份/设备/签名操作
//!
//! M1 聚焦本地身份生成与设备证书（首设备自签），
//! 以及发送消息前的签名构造。

use lonisle_core::device::DeviceKeypair;
use lonisle_core::identity::MasterKeypair;
use prost::Message as _;

/// 生成新的主密钥对，返回 (user_id, 主私钥 hex, 主公钥 hex)。
/// 主私钥仅应由 Dart 侧存入系统安全存储，Rust 层不持久化。
#[flutter_rust_bridge::frb(sync)]
pub fn generate_identity() -> IdentityBundle {
    let master = MasterKeypair::generate();
    IdentityBundle {
        user_id: master.user_id(),
        display_name: lonisle_core::identity::random_default_name(&master.user_id()),
        master_secret_hex: hex::encode(master.secret_bytes()),
        master_pubkey_hex: hex::encode(master.public_bytes()),
        avatar_seed: hex::encode(lonisle_core::identity::avatar_seed(&master.user_id())),
    }
}

/// 从主私钥 hex 恢复主密钥对，返回 (user_id, 主公钥 hex)。
#[flutter_rust_bridge::frb(sync)]
pub fn restore_identity(master_secret_hex: String) -> Result<IdentityBundle, String> {
    let secret = hex::decode(&master_secret_hex).map_err(|e| e.to_string())?;
    let master = MasterKeypair::from_bytes(&secret).map_err(|e| e.to_string())?;
    Ok(IdentityBundle {
        user_id: master.user_id(),
        display_name: lonisle_core::identity::random_default_name(&master.user_id()),
        master_secret_hex: master_secret_hex,
        master_pubkey_hex: hex::encode(master.public_bytes()),
        avatar_seed: hex::encode(lonisle_core::identity::avatar_seed(&master.user_id())),
    })
}

/// 生成设备密钥对，返回 (device_id, 设备私钥 hex, 设备公钥 hex)。
#[flutter_rust_bridge::frb(sync)]
pub fn generate_device() -> DeviceBundle {
    let device = DeviceKeypair::generate();
    DeviceBundle {
        device_id: device.device_id(),
        device_secret_hex: hex::encode(device.secret_bytes()),
        device_pubkey_hex: hex::encode(device.public_bytes()),
    }
}

/// 用主私钥为设备签发证书（首设备自签）。
/// 返回设备证书的 protobuf 编码 hex。
#[flutter_rust_bridge::frb(sync)]
pub fn issue_device_certificate(
    master_secret_hex: String,
    user_id: String,
    device_pubkey_hex: String,
    device_name: String,
) -> Result<String, String> {
    let secret = hex::decode(&master_secret_hex).map_err(|e| e.to_string())?;
    let master = MasterKeypair::from_bytes(&secret).map_err(|e| e.to_string())?;
    let pubkey = hex::decode(&device_pubkey_hex).map_err(|e| e.to_string())?;

    let cert = lonisle_core::device::issue_device_cert_with_pubkey(
        &master.signing_key,
        &user_id,
        &pubkey,
        &device_name,
    );
    let bytes = cert.encode_to_vec();
    Ok(hex::encode(bytes))
}

/// 构造发送消息的签名载荷签名。
/// 输入：设备私钥 hex、topic_id、msg_id、author_id、device_id、client_ts、text、reply_to。
/// 返回消息签名 hex。
#[flutter_rust_bridge::frb(sync)]
pub fn sign_send_message(
    device_secret_hex: String,
    topic_id: String,
    msg_id: String,
    author_id: String,
    device_id: String,
    client_ts: i64,
    text: String,
    reply_to: String,
) -> Result<String, String> {
    let secret = hex::decode(&device_secret_hex).map_err(|e| e.to_string())?;
    let device = DeviceKeypair::from_bytes(&secret).map_err(|e| e.to_string())?;

    let msg = lonisle_core::proto::SendMessage {
        topic_id,
        msg_id,
        author_id: author_id.into_bytes(),
        device_id,
        client_ts,
        content: Some(lonisle_core::proto::MessageContent { text, attachment: None, encrypted: vec![] }),
        signature: vec![],
        reply_to,
    };
    let payload = lonisle_core::signature::send_message_signing_payload(&msg);
    Ok(hex::encode(device.sign(&payload)))
}

/// 通用设备签名：对任意 payload 字节用设备私钥签名。
/// 输入：设备私钥 hex、payload hex。返回签名 hex。
#[flutter_rust_bridge::frb(sync)]
pub fn sign_payload(device_secret_hex: String, payload_hex: String) -> Result<String, String> {
    let secret = hex::decode(&device_secret_hex).map_err(|e| e.to_string())?;
    let device = DeviceKeypair::from_bytes(&secret).map_err(|e| e.to_string())?;
    let payload = hex::decode(&payload_hex).map_err(|e| e.to_string())?;
    Ok(hex::encode(device.sign(&payload)))
}

/// 构造带附件消息的签名（F-MEDIA-1：附件元数据纳入载荷）。
/// 载荷与 core signature::send_message_signing_payload 的附件段一致。
#[flutter_rust_bridge::frb(sync)]
pub fn sign_send_message_with_attachment(
    device_secret_hex: String,
    topic_id: String,
    msg_id: String,
    author_id: String,
    device_id: String,
    client_ts: i64,
    text: String,
    attachment_id: String,
    kind: String,
    size: i64,
    mime: String,
    width: i64,
    height: i64,
    duration: i64,
    thumbnail_id: String,
    filename: String,
) -> Result<String, String> {
    let secret = hex::decode(&device_secret_hex).map_err(|e| e.to_string())?;
    let device = DeviceKeypair::from_bytes(&secret).map_err(|e| e.to_string())?;

    let attachment = lonisle_core::proto::Attachment {
        attachment_id,
        kind,
        size: size as u64,
        mime,
        width: width as u32,
        height: height as u32,
        duration: duration as u32,
        thumbnail_id,
        filename,
    };
    let msg = lonisle_core::proto::SendMessage {
        topic_id,
        msg_id,
        author_id: author_id.into_bytes(),
        device_id,
        client_ts,
        content: Some(lonisle_core::proto::MessageContent {
            text,
            attachment: Some(attachment),
            encrypted: vec![],
        }),
        signature: vec![],
        reply_to: String::new(),
    };
    let payload = lonisle_core::signature::send_message_signing_payload(&msg);
    Ok(hex::encode(device.sign(&payload)))
}

/// 验证服务器迁移公告签名（F-JOIN-8）。
/// 载荷与 server 端 admin::migration_signing_payload 一致：
/// "lonisle-migrate-v1\0{address}\0{fingerprint}\0{server_id}"
#[flutter_rust_bridge::frb(sync)]
pub fn verify_migration_signature(
    server_pubkey_hex: String,
    address: String,
    fingerprint: String,
    server_id: String,
    signature_hex: String,
) -> Result<bool, String> {
    use ed25519_dalek::Verifier;

    let pubkey_bytes: [u8; 32] = decode32(&server_pubkey_hex)?;
    let pubkey = ed25519_dalek::VerifyingKey::from_bytes(&pubkey_bytes)
        .map_err(|e| format!("服务器公钥无效: {e}"))?;
    let sig_bytes = hex::decode(&signature_hex).map_err(|e| e.to_string())?;
    let sig = ed25519_dalek::Signature::from_slice(&sig_bytes)
        .map_err(|e| format!("签名格式无效: {e}"))?;

    let payload = format!("lonisle-migrate-v1\0{address}\0{fingerprint}\0{server_id}");
    Ok(pubkey.verify(payload.as_bytes(), &sig).is_ok())
}

/// 构造 Hello 握手签名（在 Rust 侧统一构造载荷，与 server 端一致）。
/// 输入：设备私钥 hex、协议版本、user_id、master_pubkey_hex、display_name、设备证书 hex。
/// 返回签名 hex。
#[flutter_rust_bridge::frb(sync)]
pub fn sign_hello(
    device_secret_hex: String,
    protocol_version: i32,
    user_id: String,
    master_pubkey_hex: String,
    display_name: String,
    device_cert_hex: String,
) -> Result<String, String> {
    let secret = hex::decode(&device_secret_hex).map_err(|e| e.to_string())?;
    let device = DeviceKeypair::from_bytes(&secret).map_err(|e| e.to_string())?;
    let master_pubkey = hex::decode(&master_pubkey_hex).map_err(|e| e.to_string())?;
    let cert_bytes = hex::decode(&device_cert_hex).map_err(|e| e.to_string())?;
    let cert = lonisle_core::proto::DeviceCert::decode(cert_bytes.as_slice())
        .map_err(|e| e.to_string())?;

    let hello = lonisle_core::proto::Hello {
        protocol_version,
        identity: Some(lonisle_core::proto::Identity {
            user_id,
            master_pubkey,
            display_name,
            avatar_seed: String::new(),
        }),
        device_cert: Some(cert),
        device_signature: vec![],
        bot_token: String::new(),
    };
    let payload = lonisle_core::signature::hello_signing_payload(&hello);
    Ok(hex::encode(device.sign(&payload)))
}

/// 签发吊销证明（主私钥对「被吊销设备公钥」签名）。
/// 返回吊销证明的 protobuf 编码 hex。
#[flutter_rust_bridge::frb(sync)]
pub fn issue_revocation(
    master_secret_hex: String,
    user_id: String,
    device_pubkey_hex: String,
) -> Result<String, String> {
    let secret = hex::decode(&master_secret_hex).map_err(|e| e.to_string())?;
    let master = MasterKeypair::from_bytes(&secret).map_err(|e| e.to_string())?;
    let pubkey = hex::decode(&device_pubkey_hex).map_err(|e| e.to_string())?;

    let proof = lonisle_core::device::issue_revocation(&master.signing_key, &user_id, &pubkey);
    Ok(hex::encode(proof.encode_to_vec()))
}

/// 生成主密钥助记词（24 词）。仅可在已认证设备上、经用户确认后调用。
#[flutter_rust_bridge::frb(sync)]
pub fn generate_mnemonic(master_secret_hex: String) -> Result<String, String> {
    let secret = hex::decode(&master_secret_hex).map_err(|e| e.to_string())?;
    let seed: [u8; 32] = secret
        .try_into()
        .map_err(|_| "主私钥长度错误".to_string())?;
    lonisle_core::mnemonic::generate_mnemonic(&seed).map_err(|e| e.to_string())
}

/// 从助记词恢复主私钥（返回主私钥 hex）。
#[flutter_rust_bridge::frb(sync)]
pub fn recover_from_mnemonic(mnemonic: String) -> Result<String, String> {
    let seed = lonisle_core::mnemonic::recover_seed(&mnemonic).map_err(|e| e.to_string())?;
    Ok(hex::encode(seed))
}

/// 校验助记词是否合法。
#[flutter_rust_bridge::frb(sync)]
pub fn validate_mnemonic(mnemonic: String) -> bool {
    lonisle_core::mnemonic::validate_mnemonic(&mnemonic)
}

/// 派生本地数据库加密密钥（SQLCipher），密钥派生自设备私钥。
/// 返回 32 字节 hex。密钥在 Rust 侧派生，避免明文出现在 Dart 侧。
#[flutter_rust_bridge::frb(sync)]
pub fn derive_db_key(device_secret_hex: String) -> Result<String, String> {
    let secret = hex::decode(&device_secret_hex).map_err(|e| e.to_string())?;
    Ok(lonisle_core::db_key::derive_db_key(&secret))
}

// ---- M6 E2EE ----

/// 生成 X25519 密钥对。
#[flutter_rust_bridge::frb(sync)]
pub fn generate_x25519() -> X25519Bundle {
    let kp = lonisle_core::x25519::X25519Keypair::generate();
    X25519Bundle {
        secret_hex: hex::encode(kp.secret),
        public_hex: hex::encode(kp.public),
    }
}

/// X3DH 协商（发起方），返回根密钥 hex。
#[flutter_rust_bridge::frb(sync)]
pub fn x3dh_initiate(
    ik_secret_hex: String,
    ek_secret_hex: String,
    peer_ik_hex: String,
    peer_spk_hex: String,
    peer_opk_hex: Option<String>,
) -> Result<String, String> {
    let ik_secret: [u8; 32] = decode32(&ik_secret_hex)?;
    let ek_secret: [u8; 32] = decode32(&ek_secret_hex)?;
    let ik = lonisle_core::x25519::X25519Keypair::from_secret(&ik_secret);
    let ek = lonisle_core::x25519::X25519Keypair::from_secret(&ek_secret);
    let peer_ik: [u8; 32] = decode32(&peer_ik_hex)?;
    let peer_spk: [u8; 32] = decode32(&peer_spk_hex)?;
    let peer_opk: Option<[u8; 32]> = peer_opk_hex
        .as_deref()
        .map(decode32)
        .transpose()?;

    let root = lonisle_core::x3dh::x3dh_initiator(&ik, &ek, &peer_ik, &peer_spk, peer_opk.as_ref());
    Ok(hex::encode(root))
}

/// 验证对端预密钥束的 SPK 签名（主身份 Ed25519 公钥对 SPK 签名，F-DEV）。
#[flutter_rust_bridge::frb(sync)]
pub fn verify_spk_signature(
    master_pubkey_hex: String,
    spk_pub_hex: String,
    signature_hex: String,
) -> Result<bool, String> {
    let master: [u8; 32] = decode32(&master_pubkey_hex)?;
    let spk: [u8; 32] = decode32(&spk_pub_hex)?;
    let sig = hex::decode(&signature_hex).map_err(|e| e.to_string())?;
    Ok(lonisle_core::x3dh::verify_spk_signature(&master, &spk, &sig))
}

/// E2EE 会话操作结果：新状态 hex + 载荷 hex
pub struct E2eeSessionOutput {
    pub new_state_hex: String,
    pub payload_hex: String,
}

/// 建立会话（发起方）：X3DH 协商 + 初始化双棘轮。
/// 返回可持久化的会话状态 hex（后续 encrypt/decrypt 传入）。
#[flutter_rust_bridge::frb(sync)]
pub fn e2ee_establish_initiator(
    ik_secret_hex: String,
    ek_secret_hex: String,
    peer_ik_hex: String,
    peer_spk_hex: String,
    peer_opk_hex: Option<String>,
) -> Result<E2eeSessionOutput, String> {
    let ik_secret: [u8; 32] = decode32(&ik_secret_hex)?;
    let ek_secret: [u8; 32] = decode32(&ek_secret_hex)?;
    let ik = lonisle_core::x25519::X25519Keypair::from_secret(&ik_secret);
    let ek = lonisle_core::x25519::X25519Keypair::from_secret(&ek_secret);
    let peer_ik: [u8; 32] = decode32(&peer_ik_hex)?;
    let peer_spk: [u8; 32] = decode32(&peer_spk_hex)?;
    let peer_opk: Option<[u8; 32]> = peer_opk_hex.as_deref().map(decode32).transpose()?;

    let root = lonisle_core::x3dh::x3dh_initiator(&ik, &ek, &peer_ik, &peer_spk, peer_opk.as_ref());

    // 初始 DH 对 = EK，发起方设置首条发送链
    let mut state = lonisle_core::ratchet::RatchetState::init(root, ek);
    state.initiator_setup(&peer_spk);
    Ok(E2eeSessionOutput {
        new_state_hex: hex::encode(state.to_bytes()),
        payload_hex: String::new(),
    })
}

/// 建立会话（响应方）：X3DH 协商 + 初始化双棘轮。
#[flutter_rust_bridge::frb(sync)]
pub fn e2ee_establish_responder(
    ik_secret_hex: String,
    spk_secret_hex: String,
    opk_secret_hex: Option<String>,
    peer_ik_hex: String,
    peer_ek_hex: String,
) -> Result<E2eeSessionOutput, String> {
    let ik_secret: [u8; 32] = decode32(&ik_secret_hex)?;
    let spk_secret: [u8; 32] = decode32(&spk_secret_hex)?;
    let ik = lonisle_core::x25519::X25519Keypair::from_secret(&ik_secret);
    let spk = lonisle_core::x25519::X25519Keypair::from_secret(&spk_secret);
    let opk = opk_secret_hex
        .as_deref()
        .map(|s| decode32(s).map(|sec| lonisle_core::x25519::X25519Keypair::from_secret(&sec)))
        .transpose()?;
    let peer_ik: [u8; 32] = decode32(&peer_ik_hex)?;
    let peer_ek: [u8; 32] = decode32(&peer_ek_hex)?;

    let root = lonisle_core::x3dh::x3dh_responder(&ik, &spk, opk.as_ref(), &peer_ik, &peer_ek);

    // 响应方：初始 DH 对 = SPK；收到发起方首条消息时自动完成 DH 棘轮
    let state = lonisle_core::ratchet::RatchetState::init(root, spk);
    Ok(E2eeSessionOutput {
        new_state_hex: hex::encode(state.to_bytes()),
        payload_hex: String::new(),
    })
}

/// E2EE 会话加密（双棘轮）。返回新状态 + 密文（含 header）。
#[flutter_rust_bridge::frb(sync)]
pub fn e2ee_session_encrypt(
    state_hex: String,
    plaintext_hex: String,
) -> Result<E2eeSessionOutput, String> {
    let state_bytes = hex::decode(&state_hex).map_err(|e| e.to_string())?;
    let mut state = lonisle_core::ratchet::RatchetState::from_bytes(&state_bytes)?;
    let plaintext = hex::decode(&plaintext_hex).map_err(|e| e.to_string())?;
    let ct = state.encrypt(&plaintext)?;
    Ok(E2eeSessionOutput {
        new_state_hex: hex::encode(state.to_bytes()),
        payload_hex: hex::encode(ct),
    })
}

/// E2EE 会话解密（双棘轮，支持乱序）。返回新状态 + 明文。
#[flutter_rust_bridge::frb(sync)]
pub fn e2ee_session_decrypt(
    state_hex: String,
    ciphertext_hex: String,
) -> Result<E2eeSessionOutput, String> {
    let state_bytes = hex::decode(&state_hex).map_err(|e| e.to_string())?;
    let mut state = lonisle_core::ratchet::RatchetState::from_bytes(&state_bytes)?;
    let ct = hex::decode(&ciphertext_hex).map_err(|e| e.to_string())?;
    let pt = state.decrypt(&ct)?;
    Ok(E2eeSessionOutput {
        new_state_hex: hex::encode(state.to_bytes()),
        payload_hex: hex::encode(pt),
    })
}

/// 兼容旧接口：E2EE 加密（无状态对称棘轮）。
/// 仅供测试/过渡使用，正式链路用 e2ee_session_encrypt。
#[flutter_rust_bridge::frb(sync)]
pub fn e2ee_encrypt(root_hex: String, msg_number: u32, plaintext_hex: String) -> Result<String, String> {
    let root: [u8; 32] = decode32(&root_hex)?;
    let plaintext = hex::decode(&plaintext_hex).map_err(|e| e.to_string())?;
    let msg_key = ratchet_message_key(&root, msg_number);
    let ct = lonisle_core::aes_gcm::encrypt(&msg_key, &plaintext, b"").map_err(|e| e.to_string())?;
    Ok(hex::encode(ct))
}

/// 兼容旧接口：E2EE 解密。
#[flutter_rust_bridge::frb(sync)]
pub fn e2ee_decrypt(root_hex: String, msg_number: u32, ciphertext_hex: String) -> Result<String, String> {
    let root: [u8; 32] = decode32(&root_hex)?;
    let ct = hex::decode(&ciphertext_hex).map_err(|e| e.to_string())?;
    let msg_key = ratchet_message_key(&root, msg_number);
    let pt = lonisle_core::aes_gcm::decrypt(&msg_key, &ct, b"").map_err(|e| e.to_string())?;
    String::from_utf8(pt).map_err(|e| e.to_string())
}

/// 从根密钥 + 序号派生消息密钥（兼容旧接口）。
fn ratchet_message_key(root: &[u8; 32], msg_number: u32) -> [u8; 32] {
    use hkdf::Hkdf;
    use sha2::Sha256;
    let mut info = Vec::with_capacity(12);
    info.extend_from_slice(b"lonisle-msg");
    info.extend_from_slice(&msg_number.to_be_bytes());
    let hk = Hkdf::<Sha256>::new(None, root);
    let mut out = [0u8; 32];
    hk.expand(&info, &mut out).expect("32");
    out
}

fn decode32(hex_str: &str) -> Result<[u8; 32], String> {
    let bytes = hex::decode(hex_str).map_err(|e| e.to_string())?;
    bytes.try_into().map_err(|_| "长度不是 32 字节".to_string())
}

// ---- 返回类型 ----

/// X25519 密钥对
pub struct X25519Bundle {
    pub secret_hex: String,
    pub public_hex: String,
}

/// 身份信息包
pub struct IdentityBundle {
    pub user_id: String,
    pub display_name: String,
    pub master_secret_hex: String,
    pub master_pubkey_hex: String,
    pub avatar_seed: String,
}

/// 设备信息包
pub struct DeviceBundle {
    pub device_id: String,
    pub device_secret_hex: String,
    pub device_pubkey_hex: String,
}
