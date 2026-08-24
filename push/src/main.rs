//! LonIsle 推送服务二进制入口

use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;

use anyhow::Context;
use clap::Parser;
use tracing::info;

use lonisle_push::api::{self, AppState};
use lonisle_push::admin::build_admin_router;
use lonisle_push::fcm::{FcmConfig, FcmVendor};
use lonisle_push::storage::{SqliteStorage, Storage};
use lonisle_push::vendor::VendorRegistry;

#[derive(Parser, Debug)]
#[command(name = "lonisle-push", version, about = "LonIsle 推送服务")]
struct Args {
    /// 监听地址（可用环境变量 LISTEN 覆盖）
    #[arg(long, default_value = "127.0.0.1:8081", env = "LISTEN")]
    listen: String,

    /// 数据目录（可用环境变量 DATA_DIR 覆盖）
    #[arg(long, default_value = "./data", env = "DATA_DIR")]
    data_dir: PathBuf,

    /// 默认限速（条/分钟，可用环境变量 RATE_PER_MINUTE 覆盖）
    #[arg(long, default_value = "2", env = "RATE_PER_MINUTE")]
    rate_per_minute: u32,

    /// 运营方管理 API Key（可用环境变量 PUSH_ADMIN_KEY 覆盖；
    /// 缺省时从数据目录加载或自动生成并打印一次）
    #[arg(long, default_value = "", env = "PUSH_ADMIN_KEY")]
    admin_key: String,

    // ---- FCM（F-PUSH-2，全部配置齐全才启用真实通道，否则回退 Mock） ----

    /// FCM 项目 ID
    #[arg(long, default_value = "", env = "FCM_PROJECT_ID")]
    fcm_project_id: String,

    /// FCM OAuth2 Client ID
    #[arg(long, default_value = "", env = "FCM_CLIENT_ID")]
    fcm_client_id: String,

    /// FCM OAuth2 Client Secret
    #[arg(long, default_value = "", env = "FCM_CLIENT_SECRET")]
    fcm_client_secret: String,

    /// FCM OAuth2 Refresh Token
    #[arg(long, default_value = "", env = "FCM_REFRESH_TOKEN")]
    fcm_refresh_token: String,

    /// FCM 服务账号 JSON（Firebase Admin SDK 同款；非空时优先于 OAuth2 方式）
    #[arg(long, default_value = "", env = "FCM_SERVICE_ACCOUNT")]
    fcm_service_account: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,tower_http=warn".into()),
        )
        .init();

    let args = Args::parse();
    std::fs::create_dir_all(&args.data_dir).context("创建数据目录失败")?;

    let db_path = args.data_dir.join("push.db");
    let storage = SqliteStorage::open(db_path.to_str().unwrap())
        .await
        .context("打开数据库失败")?;

    // 运营方管理 API Key：参数/环境变量 > 数据目录持久化 > 自动生成
    let admin_key = load_or_generate_admin_key(&args.data_dir, &args.admin_key)?;

    // FCM 通道：优先数据库（web 管理端配置），回退命令行/环境变量；
    // 四项凭证齐全才启用（F-PUSH-2），否则回退 Mock
    let mut fcm_config = FcmConfig {
        project_id: args.fcm_project_id.clone(),
        client_id: args.fcm_client_id.clone(),
        client_secret: args.fcm_client_secret.clone(),
        refresh_token: args.fcm_refresh_token.clone(),
        service_account_json: args.fcm_service_account.clone(),
    };
    match storage.get_fcm_config().await {
        Ok(Some(stored)) => {
            info!("FCM 配置：使用 web 管理端保存的配置（project: {}）", stored.project_id);
            fcm_config = stored;
        }
        Ok(None) => {
            if fcm_config.complete() {
                if fcm_config.use_service_account() {
                    info!("FCM 配置：来自环境变量（服务账号方式）");
                } else {
                    info!("FCM 配置：来自命令行/环境变量（project: {}）", args.fcm_project_id);
                }
            }
        }
        Err(e) => {
            tracing::warn!(error = %e, "读取 FCM 配置失败，使用命令行/环境变量");
        }
    }
    let fcm_vendor = if fcm_config.complete() {
        info!("FCM 推送通道已启用（project: {}）", fcm_config.project_id);
        Some(FcmVendor::new(fcm_config.clone()))
    } else {
        info!("FCM 凭证未配置，推送回退 Mock 通道（可在 web 管理端配置）");
        None
    };

    let mut app_state = AppState::new(
        storage,
        Arc::new(VendorRegistry::new(fcm_vendor)),
        args.rate_per_minute,
    );
    app_state.admin_key = admin_key;
    *app_state.fcm_config.write().unwrap() = if fcm_config.complete() {
        Some(fcm_config)
    } else {
        None
    };
    let state = Arc::new(app_state);

    // 健康监测后台 task（P1）：定期探测白名单服务器健康接口
    let health_state = state.clone();
    tokio::spawn(async move {
        health_monitor_loop(health_state).await;
    });

    // 叠加管理路由
    let router = api::build_router(state.clone()).merge(build_admin_router(state.clone()));

    let addr: SocketAddr = args.listen.parse().context("无效监听地址")?;
    let listener = tokio::net::TcpListener::bind(addr).await?;
    info!(%addr, "推送服务已启动");
    axum::serve(listener, router).await?;

    Ok(())
}

/// 加载或生成运营方管理 API Key（32 字节随机 hex），持久化到数据目录（0600）。
/// 优先级：命令行/环境变量 > 数据目录文件 > 自动生成（打印一次）。
fn load_or_generate_admin_key(data_dir: &std::path::Path, explicit: &str) -> anyhow::Result<String> {
    if !explicit.is_empty() {
        info!("管理 API Key 已由参数/环境变量提供");
        return Ok(explicit.to_string());
    }

    let key_path = data_dir.join("admin_key");
    if key_path.exists() {
        let key = std::fs::read_to_string(&key_path)
            .context("读取管理 Key 失败")?
            .trim()
            .to_string();
        if !key.is_empty() {
            info!("已加载现有管理 API Key");
            return Ok(key);
        }
    }

    let mut bytes = [0u8; 32];
    use rand::RngCore;
    rand::rngs::OsRng.fill_bytes(&mut bytes);
    let key = hex::encode(bytes);
    std::fs::write(&key_path, &key).context("写入管理 Key 失败")?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(&key_path, std::fs::Permissions::from_mode(0o600));
    }
    info!("已生成新的管理 API Key（已持久化到数据目录）");
    println!("==================================================");
    println!(" LonIsle 推送服务管理 API Key（Web 管理界面凭证）：");
    println!(" {key}");
    println!("==================================================");
    Ok(key)
}

/// 健康监测循环：
/// 1. 白名单服务器 health_url 探测（连续不可用暂停推送资格，原有逻辑）
/// 2. 目录服务器公开状态接口探测（/status），刷新在线/离线与人数（F-DISC-3）
async fn health_monitor_loop(state: Arc<AppState>) {
    // 跳过证书校验：服务器多为自签 TLS 证书（F-DISC-3）
    let client = reqwest::Client::builder()
        .danger_accept_invalid_certs(true)
        .build()
        .unwrap_or_default();
    let mut interval = tokio::time::interval(std::time::Duration::from_secs(60));
    loop {
        interval.tick().await;

        // 1) 白名单 health 探测（推送资格）
        let entries = match state.storage.list_whitelist().await {
            Ok(e) => e,
            Err(_) => continue,
        };
        for entry in entries {
            if !entry.approved || entry.health_url.is_empty() {
                continue;
            }
            let healthy = match client
                .get(&entry.health_url)
                .timeout(std::time::Duration::from_secs(5))
                .send()
                .await
            {
                Ok(resp) => resp.status().is_success(),
                Err(_) => false,
            };
            // 暂停/恢复推送资格
            if !healthy && !entry.paused {
                let _ = state.storage.set_paused(&entry.server_id, true).await;
                tracing::warn!(server_id = %entry.server_id, "健康检查失败，暂停推送资格");
            } else if healthy && entry.paused {
                let _ = state.storage.set_paused(&entry.server_id, false).await;
                tracing::info!(server_id = %entry.server_id, "健康恢复，解除暂停");
            }
        }

        // 2) 目录服务器状态刷新（在线/离线 + 人数 + 最新元数据）
        let dir_entries = match state.storage.list_directory().await {
            Ok(e) => e,
            Err(_) => continue,
        };
        let mut statuses = std::collections::HashMap::new();
        for entry in dir_entries {
            let address = entry
                .address
                .trim()
                .trim_start_matches("http://")
                .trim_start_matches("https://");
            let mut st = lonisle_push::api::DirectoryStatus {
                status: "offline".into(),
                name: entry.name.clone(),
                description: entry.description.clone(),
                join_mode: entry.join_mode.clone(),
                online: 0,
                total: 0,
                checked_at: lonisle_core::device::current_unix_time(),
            };
            // TLS 服务器优先 https（自签证书跳过校验），失败回退 http
            let mut resp = None;
            for scheme in ["https", "http"] {
                let url = format!("{scheme}://{address}/status");
                match client
                    .get(&url)
                    .timeout(std::time::Duration::from_secs(5))
                    .send()
                    .await
                {
                    Ok(r) if r.status().is_success() => {
                        resp = Some(r);
                        break;
                    }
                    _ => continue,
                }
            }
            match resp {
                Some(r) => {
                    // 解析服务器动态状态（人数/加入方式/名称/描述）
                    if let Ok(body) = r.json::<serde_json::Value>().await {
                        st.status = "online".into();
                        st.online = body["online"].as_u64().unwrap_or(0) as u32;
                        st.total = body["total"].as_u64().unwrap_or(0) as u32;
                        if let Some(n) = body["name"].as_str() {
                            if !n.is_empty() {
                                st.name = n.to_string();
                            }
                        }
                        if let Some(d) = body["description"].as_str() {
                            if !d.is_empty() {
                                st.description = d.to_string();
                            }
                        }
                        if let Some(m) = body["join_mode"].as_str() {
                            if !m.is_empty() {
                                st.join_mode = m.to_string();
                            }
                        }
                    } else {
                        // 返回 200 但非 JSON：仅标记在线
                        st.status = "online".into();
                    }
                }
                None => {
                    // 接口报错/超时 → 离线
                    st.status = "offline".into();
                }
            }
            statuses.insert(entry.server_id, st);
        }
        *state.directory_status.write().unwrap() = statuses;
    }
}
