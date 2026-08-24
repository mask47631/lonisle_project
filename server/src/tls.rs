//! 服务器 TLS（F-SID-2）：自签证书生成/加载与证书指纹计算。
//!
//! 证书与服务器身份密钥对（Ed25519）绑定：首次启动用服务器私钥签发
//! 自签证书并持久化；证书指纹 = TLS 证书 DER 的 SHA256（hex），
//! 客户端通过 TOFU 钉住该指纹（F-SID-3）。

use std::path::Path;

use anyhow::Context;
use base64::Engine as _;
use sha2::Digest as _;

/// TLS 材料：PEM 证书/私钥 + 证书指纹。
pub struct TlsMaterial {
    pub cert_pem: String,
    pub key_pem: String,
    /// 证书指纹：SHA256(cert DER) 的 hex 编码（客户端 TOFU 钉住对象）
    pub fingerprint: String,
}

/// 加载或生成自签 TLS 证书（独立 ECDSA P-256 密钥，指纹供 TOFU 钉住）。
pub fn load_or_generate(data_dir: &Path) -> anyhow::Result<TlsMaterial> {
    let cert_path = data_dir.join("tls_cert.pem");
    let key_path = data_dir.join("tls_key.pem");

    if cert_path.exists() && key_path.exists() {
        let cert_pem = std::fs::read_to_string(&cert_path).context("读取 TLS 证书失败")?;
        let key_pem = std::fs::read_to_string(&key_path).context("读取 TLS 私钥失败")?;
        let der = pem_to_der(&cert_pem).context("解析 TLS 证书失败")?;
        let fingerprint = hex::encode(sha2::Sha256::digest(&der));
        tracing::info!(fingerprint = %fingerprint, "已加载现有 TLS 证书");
        return Ok(TlsMaterial {
            cert_pem,
            key_pem,
            fingerprint,
        });
    }

    // TLS 密钥：独立 ECDSA P-256（兼容性优先——Ed25519 证书在 TLS 握手
    // 中不被 LibreSSL/部分客户端的签名算法列表支持，会触发 handshake_failure；
    // 服务器身份仍是 Ed25519 密钥对，TLS 指纹经 TOFU 钉住保证绑定）
    let key_pair = rcgen::KeyPair::generate_for(&rcgen::PKCS_ECDSA_P256_SHA256)
        .map_err(|e| anyhow::anyhow!("生成 TLS 密钥失败: {e}"))?;

    let mut params = rcgen::CertificateParams::new(vec![
        "lonisle-server".to_string(),
        "localhost".to_string(),
    ])
    .map_err(|e| anyhow::anyhow!("构造证书参数失败: {e}"))?;
    params
        .distinguished_name
        .push(rcgen::DnType::CommonName, "LonIsle Server");
    params
        .distinguished_name
        .push(rcgen::DnType::OrganizationName, "LonIsle");
    // 默认 not_after 为 4096 年（TOFU 钉住，不依赖 CA 轮换）

    let cert = params
        .self_signed(&key_pair)
        .map_err(|e| anyhow::anyhow!("签发自签证书失败: {e}"))?;

    let cert_pem = cert.pem();
    let key_pem = key_pair.serialize_pem();
    let fingerprint = hex::encode(sha2::Sha256::digest(cert.der()));

    std::fs::write(&cert_path, &cert_pem).context("写入 TLS 证书失败")?;
    std::fs::write(&key_path, &key_pem).context("写入 TLS 私钥失败")?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(&key_path, std::fs::Permissions::from_mode(0o600));
    }

    Ok(TlsMaterial {
        cert_pem,
        key_pem,
        fingerprint,
    })
}

/// 从 PEM 文本提取首个 CERTIFICATE 块的 DER 字节。
fn pem_to_der(pem: &str) -> anyhow::Result<Vec<u8>> {
    let mut in_block = false;
    let mut b64 = String::new();
    for line in pem.lines() {
        let line = line.trim();
        if line == "-----BEGIN CERTIFICATE-----" {
            in_block = true;
            continue;
        }
        if line == "-----END CERTIFICATE-----" {
            break;
        }
        if in_block {
            b64.push_str(line);
        }
    }
    if b64.is_empty() {
        anyhow::bail!("PEM 中未找到 CERTIFICATE 块");
    }
    base64::engine::general_purpose::STANDARD
        .decode(b64)
        .context("base64 解码证书失败")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generate_and_reload() {
        let dir = std::env::temp_dir().join(format!("lonisle_tls_test_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let m1 = load_or_generate(&dir).unwrap();
        assert!(!m1.cert_pem.is_empty());
        assert_eq!(m1.fingerprint.len(), 64);

        // 再次加载应得到相同指纹（持久化生效）
        let m2 = load_or_generate(&dir).unwrap();
        assert_eq!(m1.fingerprint, m2.fingerprint);

        let _ = std::fs::remove_dir_all(&dir);
    }
}
