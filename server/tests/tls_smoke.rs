//! F-SID-2：TLS 服务端冒烟测试 —— 自签证书可由 axum-server 加载并提供 HTTPS 服务，
//! 指纹与证书内容一致。

use std::sync::Arc;

use lonisle_core::device::DeviceKeypair;
use lonisle_server::storage::{SqliteStorage, Storage};
use lonisle_server::ws::AppState;
use sha2::Digest as _;

#[tokio::test]
async fn tls_serving_smoke() {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let dir = std::env::temp_dir().join(format!("lonisle_tls_smoke_{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let keypair = DeviceKeypair::generate();
    let _ = keypair;
    let tls = lonisle_server::tls::load_or_generate(&dir).unwrap();
    assert_eq!(tls.fingerprint.len(), 64);

    let storage = SqliteStorage::open_in_memory().await.unwrap();
    storage
        .ensure_topic("default", "默认话题", "欢迎")
        .await
        .unwrap();
    let state = Arc::new(AppState::new(storage, DeviceKeypair::generate()));
    let router = lonisle_server::admin::build_router(state);

    let addr: std::net::SocketAddr = "127.0.0.1:0".parse().unwrap();
    let listener = std::net::TcpListener::bind(addr).unwrap();
    let local_addr = listener.local_addr().unwrap();
    drop(listener);

    let tls_config = axum_server::tls_rustls::RustlsConfig::from_pem(
        tls.cert_pem.clone().into_bytes(),
        tls.key_pem.clone().into_bytes(),
    )
    .await
    .unwrap();

    let handle = axum_server::bind_rustls(local_addr, tls_config);
    tokio::spawn(async move {
        handle
            .serve(router.into_make_service())
            .await
            .unwrap();
    });

    // 客户端跳过 CA 校验（TOFU 由客户端自行比对指纹），验证 HTTPS 可用
    let client = reqwest::Client::builder()
        .danger_accept_invalid_certs(true)
        .build()
        .unwrap();
    // 等待服务器就绪（绑定与监听存在竞态，重试若干次）
    let mut resp = None;
    for _ in 0..50 {
        match client
            .get(format!("https://{}/", local_addr))
            .send()
            .await
        {
            Ok(r) => {
                resp = Some(r);
                break;
            }
            Err(_) => tokio::time::sleep(std::time::Duration::from_millis(50)).await,
        }
    }
    let resp = resp.expect("服务器未在预期时间内就绪");
    assert_eq!(resp.status().as_u16(), 200);

    // 指纹与证书 DER 一致
    let der = {
        let pem = tls.cert_pem.clone();
        let b64: String = pem
            .lines()
            .filter(|l| !l.starts_with("-----"))
            .collect::<Vec<_>>()
            .join("");
        use base64::Engine as _;
        base64::engine::general_purpose::STANDARD.decode(b64).unwrap()
    };
    let fp = hex::encode(sha2::Sha256::digest(&der));
    assert_eq!(fp, tls.fingerprint);

    let _ = std::fs::remove_dir_all(&dir);
}
