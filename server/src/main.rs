//! LonIsle 聊天服务器二进制入口

use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;

use anyhow::Context;
use clap::Parser;
use lonisle_core::identity::user_id_from_pubkey;
use sha2::Digest as _;
use tracing::{info, warn};

use lonisle_server::storage::{JoinStrategy, SqliteStorage, Storage, TopicType};
use lonisle_server::ws::AppState;

/// LonIsle 聊天服务器命令行参数
#[derive(Parser, Debug)]
#[command(name = "lonisle-server", version, about = "LonIsle 分布式聊天服务器")]
struct Args {
    /// 监听地址
    #[arg(long, default_value = "127.0.0.1:8080")]
    listen: String,

    /// 数据目录（密钥、SQLite 数据库）
    #[arg(long, default_value = "./data")]
    data_dir: PathBuf,

    /// 服务器显示名称
    #[arg(long, default_value = "LonIsle Server")]
    name: String,

    /// 服务器简介
    #[arg(long, default_value = "")]
    description: String,

    /// Bot Token（M6，Bot 认证用；空表示未启用 Bot）
    #[arg(long, default_value = "")]
    bot_token: String,

    /// 管理 API Token（可用环境变量 LONISLE_ADMIN_TOKEN 覆盖；
    /// 缺省时从数据目录加载或自动生成并打印一次）
    #[arg(long, default_value = "", env = "LONISLE_ADMIN_TOKEN")]
    admin_token: String,

    /// TLS 证书 PEM 文件路径（web 管理端配置优先；未配置则自动生成自签证书）
    #[arg(long, default_value = "", env = "TLS_CERT")]
    tls_cert: String,

    /// TLS 私钥 PEM 文件路径（web 管理端配置优先；未配置则自动生成自签证书）
    #[arg(long, default_value = "", env = "TLS_KEY")]
    tls_key: String,

    /// 密钥备份导出路径（加密备份服务器密钥对，F-SID-5）
    #[arg(long)]
    backup_key: Option<PathBuf>,

    /// 密钥恢复路径（从备份恢复服务器密钥对）
    #[arg(long)]
    restore_key: Option<PathBuf>,

    /// 备份口令（可用环境变量 LONISLE_BACKUP_PASSPHRASE；备份/恢复加密格式时必填）
    #[arg(long, default_value = "", env = "LONISLE_BACKUP_PASSPHRASE")]
    backup_passphrase: String,

    /// 日志文件保留天数（文件日志按天轮转，写入 {data_dir}/logs）
    #[arg(long, default_value_t = 7, env = "LOG_RETAIN_DAYS")]
    log_retain_days: u32,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    // 准备数据目录（日志子目录随后由 init_logging 创建）
    std::fs::create_dir_all(&args.data_dir)
        .with_context(|| format!("创建数据目录失败：{:?}", args.data_dir))?;

    // 日志：stdout + 文件（按天轮转，{data_dir}/logs，保留 N 天）
    lonisle_core::logging::init("lonisle-server", &args.data_dir, args.log_retain_days)?;

    // rustls CryptoProvider（ring，供 TLS 使用）
    let _ = rustls::crypto::ring::default_provider().install_default();

    // 密钥恢复：从备份恢复服务器密钥对
    if let Some(restore_path) = &args.restore_key {
        restore_keypair(&args.data_dir, restore_path, &args.backup_passphrase)?;
        info!("已从备份恢复服务器密钥对");
        return Ok(());
    }

    // 加载或生成服务器密钥对
    let keypair = load_or_generate_keypair(&args.data_dir)?;

    // 密钥备份（F-SID-5）：口令加密备份服务器密钥对
    if let Some(backup_path) = &args.backup_key {
        backup_keypair(&keypair, backup_path, &args.backup_passphrase)?;
        info!("服务器密钥对已加密备份到 {:?}", backup_path);
        return Ok(());
    }
    let server_id = user_id_from_pubkey(&keypair.public_bytes());
    info!(server_id = %server_id, "服务器身份已就绪");
    info!("server_id={}，请妥善备份数据目录中的密钥，丢失即身份失效", server_id);

    // 初始化存储
    let db_path = args.data_dir.join("lonisle.db");
    let storage = SqliteStorage::open(db_path.to_str().unwrap())
        .await
        .context("打开数据库失败")?;

    // 持久化服务器元数据（保留已有配置，首次默认审批加入）
    let existing = storage.get_server_meta().await?;
    let meta = lonisle_server::storage::ServerMeta {
        server_id: server_id.clone(),
        name: if args.name != "LonIsle Server" {
            args.name.clone()
        } else {
            existing.as_ref().map(|m| m.name.clone()).unwrap_or(args.name.clone())
        },
        // 简介：命令行非空才覆盖，否则保留 DB 已有值（避免重启丢失）
        description: if !args.description.is_empty() {
            args.description.clone()
        } else {
            existing
                .as_ref()
                .map(|m| m.description.clone())
                .unwrap_or_default()
        },
        strategy: existing
            .as_ref()
            .map(|m| m.strategy)
            .unwrap_or(JoinStrategy::Approval),
        migration_target_address: existing
            .as_ref()
            .map(|m| m.migration_target_address.clone())
            .unwrap_or_default(),
        migration_target_fingerprint: existing
            .as_ref()
            .map(|m| m.migration_target_fingerprint.clone())
            .unwrap_or_default(),
        migration_signature: existing
            .as_ref()
            .map(|m| m.migration_signature.clone())
            .unwrap_or_default(),
        rate_limit_per_minute: existing
            .as_ref()
            .map(|m| m.rate_limit_per_minute)
            .unwrap_or(0),
        max_attachment_size: existing
            .as_ref()
            .map(|m| m.max_attachment_size)
            .unwrap_or(0),
        attachment_quota: existing
            .as_ref()
            .map(|m| m.attachment_quota)
            .unwrap_or(0),
        mention_read_enabled: existing
            .as_ref()
            .map(|m| m.mention_read_enabled)
            .unwrap_or(false),
        livekit_url: existing
            .as_ref()
            .map(|m| m.livekit_url.clone())
            .unwrap_or_default(),
        livekit_api_key: existing
            .as_ref()
            .map(|m| m.livekit_api_key.clone())
            .unwrap_or_default(),
        livekit_api_secret: existing
            .as_ref()
            .map(|m| m.livekit_api_secret.clone())
            .unwrap_or_default(),
        icon: existing
            .as_ref()
            .map(|m| m.icon.clone())
            .unwrap_or_default(),
    };
    storage.set_server_meta(&meta).await?;

    // 默认话题（M1 单话题）
    storage
        .ensure_topic("default", "默认话题", "欢迎来到 LonIsle")
        .await?;

    // Owner 一次性认领码（F-PERM-1）：无成员且无未使用认领码时生成并打印
    ensure_owner_claim_code(&storage).await?;

    // 初始化附件目录
    let attachments_dir = args.data_dir.join("attachments");
    std::fs::create_dir_all(&attachments_dir).context("创建附件目录失败")?;

    // 管理 API Token：参数/环境变量 > 数据目录持久化 > 自动生成
    let admin_token = load_or_generate_admin_token(&args.data_dir, &args.admin_token)?;

    // TLS（F-SID-2）：web 管理端配置的证书路径优先 → 命令行/环境变量 → 自动生成自签
    let mut tls_cert_path = args.tls_cert.clone();
    let mut tls_key_path = args.tls_key.clone();
    match storage.get_tls_config().await {
        Ok((cert, key)) => {
            if !cert.is_empty() && !key.is_empty() {
                info!("TLS 证书：使用 web 管理端保存的路径（cert: {cert}）");
                tls_cert_path = cert;
                tls_key_path = key;
            }
        }
        Err(e) => {
            tracing::warn!(error = %e, "读取 TLS 配置失败，使用命令行/环境变量");
        }
    }
    let tls = if !tls_cert_path.is_empty() && !tls_key_path.is_empty() {
        lonisle_core::tls::load_external(
            std::path::Path::new(&tls_cert_path),
            std::path::Path::new(&tls_key_path),
        )?
    } else {
        lonisle_core::tls::load_or_generate(&args.data_dir)?
    };
    println!("==================================================");
    println!(" LonIsle 服务器证书指纹（邀请链接 # 后缀，F-JOIN-7）：");
    println!(" {}", tls.fingerprint);
    println!("==================================================");

    // 构建共享应用状态
    let mut state = AppState::with_data_dir(
        storage.clone(),
        keypair,
        args.data_dir.to_string_lossy().to_string(),
    );
    state.bot_token = args.bot_token.clone();
    state.admin_token = admin_token;
    state.tls_fingerprint = tls.fingerprint.clone();
    let state = Arc::new(state);

    // 构建路由：WebSocket + 管理界面 + 附件
    let app = lonisle_server::admin::build_router(state.clone())
        .merge(lonisle_server::attachments::build_attachments_router(state.clone()));

    // 后台任务：定时刷新音视频话题房间人数（F-AV-COUNT）
    spawn_live_participants_loop(state.clone());

    let addr: SocketAddr = args.listen.parse().context("无效的监听地址")?;
    info!(%addr, fingerprint = %tls.fingerprint, "聊天服务器已启动（TLS）");

    let tls_config = axum_server::tls_rustls::RustlsConfig::from_pem(
        tls.cert_pem.into_bytes(),
        tls.key_pem.into_bytes(),
    )
    .await
    .context("加载 TLS 配置失败")?;

    axum_server::bind_rustls(addr, tls_config)
        .serve(app.into_make_service())
        .await?;

    Ok(())
}

/// 确保 Owner 一次性认领码就绪（F-PERM-1）。
/// 仅当服务器无任何成员且不存在未使用的认领码时生成；
/// 认领码明文只打印到控制台一次，库中仅存 SHA256 哈希。
async fn ensure_owner_claim_code(
    storage: &SqliteStorage,
) -> anyhow::Result<()> {
    let has_members = !storage.list_members().await?.is_empty();
    let has_code = storage.get_owner_claim_hash().await?.is_some();
    if has_members || has_code {
        return Ok(());
    }

    // 生成可读认领码：16 字节随机 → Crockford Base32 小写，按 4 位分组
    let mut bytes = [0u8; 16];
    use rand::RngCore;
    rand::rngs::OsRng.fill_bytes(&mut bytes);
    let raw = base32::encode(base32::Alphabet::Crockford, &bytes).to_lowercase();
    let code = raw
        .chars()
        .collect::<Vec<_>>()
        .chunks(4)
        .map(|c| c.iter().collect::<String>())
        .collect::<Vec<_>>()
        .join("-");

    let hash = hex::encode(sha2::Sha256::digest(code.as_bytes()));
    storage.set_owner_claim_hash(&hash).await?;

    println!("==================================================");
    println!(" LonIsle Owner 一次性认领码（F-PERM-1）：");
    println!(" {code}");
    println!(" 首个持此码完成加入的用户自动成为 Owner，认领码随即失效。");
    println!(" 此码仅显示一次，请妥善保管；丢失可在删除数据目录后重新部署。");
    println!("==================================================");
    Ok(())
}

/// 加载或生成管理 API Token（32 字节随机 hex），持久化到数据目录（0600）。
/// 优先级：命令行/环境变量 > 数据目录文件 > 自动生成（打印一次）。
fn load_or_generate_admin_token(data_dir: &PathBuf, explicit: &str) -> anyhow::Result<String> {
    if !explicit.is_empty() {
        info!("管理 API Token 已由参数/环境变量提供");
        return Ok(explicit.to_string());
    }

    let token_path = data_dir.join("admin_token");
    if token_path.exists() {
        let token = std::fs::read_to_string(&token_path)
            .context("读取管理 Token 失败")?
            .trim()
            .to_string();
        if !token.is_empty() {
            info!("已加载现有管理 API Token");
            return Ok(token);
        }
    }

    // 生成 32 字节随机 Token（hex 编码 64 字符）
    let mut bytes = [0u8; 32];
    use rand::RngCore;
    rand::rngs::OsRng.fill_bytes(&mut bytes);
    let token = hex::encode(bytes);
    std::fs::write(&token_path, &token).context("写入管理 Token 失败")?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(&token_path, std::fs::Permissions::from_mode(0o600));
    }
    info!("已生成新的管理 API Token（已持久化到数据目录）");
    println!("==================================================");
    println!(" LonIsle 管理 API Token（Web 管理界面登录凭证）：");
    println!(" {token}");
    println!("==================================================");
    Ok(token)
}

/// 加载或生成服务器密钥对（Ed25519），持久化到数据目录。
fn load_or_generate_keypair(
    data_dir: &PathBuf,
) -> anyhow::Result<lonisle_core::device::DeviceKeypair> {
    use lonisle_core::device::DeviceKeypair;

    let key_path = data_dir.join("server_key.bin");
    if key_path.exists() {
        let bytes = std::fs::read(&key_path).context("读取服务器密钥失败")?;
        let kp = DeviceKeypair::from_bytes(&bytes).context("解析服务器密钥失败")?;
        warn!("已加载现有服务器密钥（{} 字节）", bytes.len());
        return Ok(kp);
    }

    let kp = DeviceKeypair::generate();
    std::fs::write(&key_path, kp.secret_bytes()).context("写入服务器密钥失败")?;
    // 限制权限（仅属主可读）
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(&key_path, std::fs::Permissions::from_mode(0o600));
    }
    info!("已生成新的服务器密钥对");
    Ok(kp)
}

/// 备份服务器密钥对到指定路径（口令加密，F-SID-5）。
fn backup_keypair(
    keypair: &lonisle_core::device::DeviceKeypair,
    backup_path: &PathBuf,
    passphrase: &str,
) -> anyhow::Result<()> {
    if passphrase.is_empty() {
        anyhow::bail!(
            "加密备份需要口令：请通过 --backup-passphrase 或环境变量 LONISLE_BACKUP_PASSPHRASE 提供"
        );
    }
    let data = lonisle_server::backup::encrypt_backup(passphrase, &keypair.secret_bytes())?;
    std::fs::write(backup_path, data).context("写入备份文件失败")?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(backup_path, std::fs::Permissions::from_mode(0o600));
    }
    Ok(())
}

/// 从备份恢复服务器密钥对到数据目录（自动识别加密/旧版明文格式）。
fn restore_keypair(
    data_dir: &PathBuf,
    backup_path: &PathBuf,
    passphrase: &str,
) -> anyhow::Result<()> {
    let bytes = std::fs::read(backup_path).context("读取备份文件失败")?;
    let secret = if lonisle_server::backup::is_encrypted_backup(&bytes) {
        if passphrase.is_empty() {
            anyhow::bail!(
                "该备份为加密格式：请通过 --backup-passphrase 或环境变量 LONISLE_BACKUP_PASSPHRASE 提供口令"
            );
        }
        lonisle_server::backup::decrypt_backup(passphrase, &bytes)?
    } else {
        // 旧版明文备份（向后兼容）
        bytes
            .as_slice()
            .try_into()
            .map_err(|_| anyhow::anyhow!("备份文件格式错误（应为 32 字节密钥）"))?
    };

    let key_path = data_dir.join("server_key.bin");
    std::fs::write(&key_path, secret).context("写入服务器密钥失败")?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(&key_path, std::fs::Permissions::from_mode(0o600));
    }
    Ok(())
}

/// 后台任务：每 15s 查询音视频话题房间人数并缓存，变化时广播 TOPIC_UPDATED（F-AV-COUNT）。
/// 客户端收到 TOPIC_UPDATED 后自动重新拉取话题列表，话题名后的在线人数随之刷新。
fn spawn_live_participants_loop(state: Arc<AppState>) {
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(15));
        // 首次立即执行，避免启动后 15s 内人数为空
        interval.tick().await;
        loop {
            interval.tick().await;
            if let Err(e) = update_live_participants(&state).await {
                tracing::warn!(error = %e, "刷新 LiveKit 房间人数失败");
            }
        }
    });
}

/// 查询所有音视频话题房间人数，与缓存不一致时更新并广播话题变更。
async fn update_live_participants(state: &Arc<AppState>) -> anyhow::Result<()> {
    let meta = state.storage.get_server_meta().await?;
    let meta = match meta {
        Some(m) => m,
        None => return Ok(()),
    };
    // LiveKit 未配置（url/key/secret 缺一）时跳过
    if meta.livekit_url.is_empty()
        || meta.livekit_api_key.is_empty()
        || meta.livekit_api_secret.is_empty()
    {
        return Ok(());
    }

    let topics = state.storage.list_topics().await?;
    let av_topics: Vec<_> = topics
        .into_iter()
        .filter(|t| t.topic_type == TopicType::Av)
        .collect();
    if av_topics.is_empty() {
        return Ok(());
    }

    let mut fresh = std::collections::HashMap::new();
    for t in &av_topics {
        match lonisle_server::livekit::count_room_participants(
            &meta.livekit_url,
            &meta.livekit_api_key,
            &meta.livekit_api_secret,
            &t.topic_id,
        )
        .await
        {
            Ok(n) => {
                fresh.insert(t.topic_id.clone(), n);
            }
            Err(e) => {
                tracing::warn!(topic = %t.topic_id, error = %e, "查询房间人数失败");
            }
        }
    }

    // 与缓存比较，有变化才广播（避免 15s 一次无意义推送）
    let changed = {
        let cache = state.live_participants.read().await;
        *cache != fresh
    };
    if changed {
        let mut cache = state.live_participants.write().await;
        *cache = fresh;
        drop(cache);
        use lonisle_core::proto::server_envelope::MsgType as ServerMsgType;
        let env = lonisle_core::proto::ServerEnvelope {
            r#type: ServerMsgType::TopicUpdated as i32,
            request_id: 0,
            payload: vec![],
            error: String::new(),
        };
        let _ = state.broadcast.send(env);
        tracing::debug!("音视频话题人数已更新并广播");
    }
    Ok(())
}
