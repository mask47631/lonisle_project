//! 推送服务端到端冒烟测试
//!
//! 覆盖：注册 Token → 服务器白名单申请 → 目录注册 → 服务器发起推送（验签 + 限速 + 免内容）

use std::sync::Arc;

use ed25519_dalek::{Signer, SigningKey};
use rand::rngs::OsRng;
use serde_json::json;
use tokio::net::TcpListener;

use lonisle_push::admin::build_admin_router;
use lonisle_push::api::{self, AppState};
use lonisle_push::storage::DirectoryEntry;
use lonisle_push::vendor::VendorRegistry;
use lonisle_push::SqliteStorage;

async fn start_server() -> String {
    let storage = SqliteStorage::open_in_memory().await.unwrap();
    let state = Arc::new(AppState::new(storage, Arc::new(VendorRegistry::new(None)), 2));
    let router = api::build_router(state.clone()).merge(build_admin_router(state));
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move {
        axum::serve(listener, router).await.unwrap();
    });
    format!("http://{}", addr)
}

async fn post_json(url: &str, path: &str, body: serde_json::Value) -> (u16, serde_json::Value) {
    let client = reqwest::Client::new();
    let resp = client
        .post(format!("{}{}", url, path))
        .json(&body)
        .send()
        .await
        .unwrap();
    let status = resp.status().as_u16();
    let json = resp.json::<serde_json::Value>().await.unwrap_or(json!({}));
    (status, json)
}

async fn get_json(url: &str, path: &str) -> (u16, serde_json::Value) {
    let client = reqwest::Client::new();
    let resp = client.get(format!("{}{}", url, path)).send().await.unwrap();
    let status = resp.status().as_u16();
    let json = resp.json::<serde_json::Value>().await.unwrap_or(json!({}));
    (status, json)
}

#[tokio::test]
async fn push_flow() {
    let base = start_server().await;

    // 1. 健康监测
    let (status, _) = get_json(&base, "/health").await;
    assert_eq!(status, 200);

    // 2. 客户端注册 Token
    let (status, _) = post_json(
        &base,
        "/register",
        json!({
            "user_id": "user1",
            "device_id": "dev1",
            "vendor": "mock",
            "token": "mock-token-abc123",
        }),
    )
    .await;
    assert_eq!(status, 200);

    // 3. 服务器身份（Ed25519 密钥对）
    let signing_key = SigningKey::generate(&mut OsRng);
    let pubkey = signing_key.verifying_key().to_bytes();
    let server_id = lonisle_core::identity::user_id_from_pubkey(&pubkey);

    // 4. 白名单申请（需健康监测通过，用自身 /health）
    let (status, _) = post_json(
        &base,
        "/apply",
        json!({
            "server_id": server_id,
            "description": "测试服务器",
            "health_url": format!("{}/health", base),
        }),
    )
    .await;
    assert_eq!(status, 200);

    // 5. 管理审核通过白名单
    let (status, _) = post_json(
        &base,
        "/admin/whitelist/approve",
        json!({"server_id": server_id, "approve": true}),
    )
    .await;
    assert_eq!(status, 200);

    // 6. 目录注册
    let (status, _) = post_json(
        &base,
        "/directory/register",
        json!({
            "server_id": server_id,
            "name": "测试社区",
            "description": "测试",
            "icon": "",
            "address": "127.0.0.1:8080",
            "join_mode": "approval",
        }),
    )
    .await;
    assert_eq!(status, 200);

    // 7. 目录查询
    let (status, dir) = get_json(&base, "/directory").await;
    assert_eq!(status, 200);
    let servers = dir["servers"].as_array().unwrap();
    assert_eq!(servers.len(), 1);

    // 8. 服务器发起推送（验签）
    let body = json!({
        "server_id": server_id,
        "user_id": "user1",
        "hint": "审批通过",
    });
    let body_str = body.to_string();
    let sig = signing_key.sign(body_str.as_bytes()).to_bytes();

    let client = reqwest::Client::new();
    let resp = client
        .post(format!("{}/push", base))
        .header("x-server-id", &server_id)
        .header("x-server-pubkey", hex::encode(pubkey))
        .header("x-server-signature", hex::encode(sig))
        .json(&body)
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200);

    // 9. 限速：连续推送超过阈值应 429
    // 默认 2 条/分钟，第一次突发可用 2 个令牌，第三次应超限
    let mut rate_limited = false;
    for _ in 0..5 {
        let body_str = body.to_string();
        let sig = signing_key.sign(body_str.as_bytes()).to_bytes();
        let resp = client
            .post(format!("{}/push", base))
            .header("x-server-id", &server_id)
            .header("x-server-pubkey", hex::encode(pubkey))
            .header("x-server-signature", hex::encode(sig))
            .json(&body)
            .send()
            .await
            .unwrap();
        if resp.status().as_u16() == 429 {
            rate_limited = true;
            break;
        }
    }
    assert!(rate_limited, "应触发限速 429");
}

#[tokio::test]
async fn unauthenticated_push_rejected() {
    let base = start_server().await;

    // 未验签的推送请求应 401
    let client = reqwest::Client::new();
    let resp = client
        .post(format!("{}/push", base))
        .json(&json!({"server_id": "fake", "user_id": "u1", "hint": "x"}))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 401);
}

/// P1 黑名单 API 流程
#[tokio::test]
async fn blacklist_flow() {
    let base = start_server().await;

    // 加入黑名单
    let (status, _) = post_json(
        &base,
        "/admin/blacklist/add",
        json!({"server_id": "bad-server", "reason": "滥用"}),
    )
    .await;
    assert_eq!(status, 200);

    // 列出黑名单
    let (status, body) = get_json(&base, "/admin/blacklist").await;
    assert_eq!(status, 200);
    assert_eq!(body["entries"].as_array().unwrap().len(), 1);

    // 移除黑名单
    let (status, _) = post_json(
        &base,
        "/admin/blacklist/remove",
        json!({"server_id": "bad-server"}),
    )
    .await;
    assert_eq!(status, 200);

    // 再次列出为空
    let (_, body) = get_json(&base, "/admin/blacklist").await;
    assert_eq!(body["entries"].as_array().unwrap().len(), 0);
}

/// 管理 API 鉴权：配置 admin_key 后，无 Key 请求 401，带 Key 请求通过
#[tokio::test]
async fn admin_auth_enforced() {
    let storage = SqliteStorage::open_in_memory().await.unwrap();
    let mut app_state = AppState::new(storage, Arc::new(VendorRegistry::new(None)), 2);
    app_state.admin_key = "test-admin-key".to_string();
    let state = Arc::new(app_state);
    let router = api::build_router(state.clone()).merge(build_admin_router(state));
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move {
        axum::serve(listener, router).await.unwrap();
    });
    let base = format!("http://{}", addr);

    let client = reqwest::Client::new();

    // 无 Key → 401
    let resp = client
        .get(format!("{}/admin/whitelist", base))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 401);

    // 错误 Key → 401
    let resp = client
        .get(format!("{}/admin/whitelist", base))
        .header("X-Admin-Key", "wrong")
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 401);

    // 正确 Key → 200
    let resp = client
        .get(format!("{}/admin/whitelist", base))
        .header("X-Admin-Key", "test-admin-key")
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200);

    // 公共 API 不受影响
    let resp = client
        .get(format!("{}/health", base))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200);
}

/// F-RATE-5：白/黑名单模式切换 API
#[tokio::test]
async fn mode_switch_api() {
    let storage = SqliteStorage::open_in_memory().await.unwrap();
    let app_state = AppState::new(storage, Arc::new(VendorRegistry::new(None)), 2);
    let state = Arc::new(app_state);
    let router = api::build_router(state.clone()).merge(build_admin_router(state.clone()));
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, router).await.unwrap(); });
    let base = format!("http://{}", addr);

    // 默认白名单模式
    let (_, body) = get_json(&base, "/admin/mode").await;
    assert_eq!(body["whitelist_mode"], true);

    // 切到黑名单模式
    let (status, body) = post_json(&base, "/admin/mode", json!({"whitelist_mode": false})).await;
    assert_eq!(status, 200);
    assert_eq!(body["whitelist_mode"], false);
    let (_, body) = get_json(&base, "/admin/mode").await;
    assert_eq!(body["whitelist_mode"], false);

    // 切回白名单
    let (status, _) = post_json(&base, "/admin/mode", json!({"whitelist_mode": true})).await;
    assert_eq!(status, 200);
    assert!(state.is_whitelist_mode());
}

/// F-RATE-6：白名单模式下黑名单同样生效（熔断在默认模式拦截）
#[tokio::test]
async fn blacklist_enforced_in_whitelist_mode() {
    let storage: Arc<dyn lonisle_push::storage::Storage> =
        SqliteStorage::open_in_memory().await.unwrap();
    // 服务器密钥对（真实签名头）
    let signing_key = SigningKey::generate(&mut OsRng);
    let pubkey = signing_key.verifying_key().to_bytes();
    let server_id = lonisle_core::identity::user_id_from_pubkey(&pubkey);

    // 白名单中加入该服务器，然后拉黑 → 默认白名单模式下推送也被拒
    storage
        .upsert_whitelist(&lonisle_push::storage::WhitelistEntry {
            server_id: server_id.clone(),
            approved: true,
            applied_at: 0,
            health_url: String::new(),
            paused: false,
        })
        .await
        .unwrap();
    storage.add_blacklist(&server_id, "测试拉黑").await.unwrap();

    let app_state = AppState::new(storage.clone(), Arc::new(VendorRegistry::new(None)), 100);
    let state = Arc::new(app_state);
    assert!(state.is_whitelist_mode());
    let router = api::build_router(state.clone()).merge(build_admin_router(state));
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, router).await.unwrap(); });
    let base = format!("http://{}", addr);

    // 真实签名推送 → 黑名单拦截 403（F-RATE-6）
    let body = json!({"server_id": server_id, "user_id": "user-1", "hint": "hi"});
    let sig = signing_key.sign(body.to_string().as_bytes()).to_bytes();
    let resp = reqwest::Client::new()
        .post(format!("{}/push", base))
        .header("x-server-id", &server_id)
        .header("x-server-pubkey", hex::encode(pubkey))
        .header("x-server-signature", hex::encode(sig))
        .json(&body)
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 403);
}

/// F-DISC-2：目录关键词搜索
#[tokio::test]
async fn directory_search() {
    let storage: Arc<dyn lonisle_push::storage::Storage> =
        SqliteStorage::open_in_memory().await.unwrap();
    storage
        .upsert_directory(&DirectoryEntry {
            server_id: "srv-game".into(),
            name: "游戏交流".into(),
            description: "联机开黑".into(),
            icon: String::new(),
            address: "127.0.0.1:9001".into(),
            join_mode: "open".into(),
            approved: true,
            created_at: 0,
        })
        .await
        .unwrap();
    storage
        .upsert_directory(&DirectoryEntry {
            server_id: "srv-music".into(),
            name: "音乐分享".into(),
            description: "Hi-Res 无损".into(),
            icon: String::new(),
            address: "127.0.0.1:9002".into(),
            join_mode: "approval".into(),
            approved: true,
            created_at: 0,
        })
        .await
        .unwrap();

    let app_state = AppState::new(storage.clone(), Arc::new(VendorRegistry::new(None)), 2);
    let state = Arc::new(app_state);
    let router = api::build_router(state.clone()).merge(build_admin_router(state));
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    tokio::spawn(async move { axum::serve(listener, router).await.unwrap(); });
    let base = format!("http://{}", addr);

    // 无关键词 → 全部
    let (_, body) = get_json(&base, "/directory").await;
    assert_eq!(body["servers"].as_array().unwrap().len(), 2);

    // 按名称搜索
    let (_, body) = get_json(&base, "/directory?q=游戏").await;
    let arr = body["servers"].as_array().unwrap();
    assert_eq!(arr.len(), 1);
    assert_eq!(arr[0]["server_id"], "srv-game");

    // 按描述搜索
    let (_, body) = get_json(&base, "/directory?q=无损").await;
    let arr = body["servers"].as_array().unwrap();
    assert_eq!(arr.len(), 1);
    assert_eq!(arr[0]["server_id"], "srv-music");

    // 无命中
    let (_, body) = get_json(&base, "/directory?q=不存在").await;
    assert_eq!(body["servers"].as_array().unwrap().len(), 0);
}
