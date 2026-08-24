//! 推送服务存储层：设备 Token、服务器目录、白名单、免打扰、限速配置、拒绝冷却

use std::sync::Arc;

use async_trait::async_trait;
use sqlx::{sqlite::SqlitePool, Row};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum StorageError {
    #[error("数据库错误：{0}")]
    Db(#[from] sqlx::Error),
    #[error("记录不存在")]
    NotFound,
}

/// 设备 Token 记录
#[derive(Debug, Clone)]
pub struct DeviceToken {
    pub user_id: String,
    pub device_id: String,
    pub vendor: String, // mock/apns/fcm/huawei/xiaomi/...
    pub token: String,
    pub updated_at: i64,
}

/// 服务器目录条目
#[derive(Debug, Clone)]
pub struct DirectoryEntry {
    pub server_id: String,
    pub name: String,
    pub description: String,
    pub icon: String,
    pub address: String,
    pub join_mode: String, // open/approval/invite
    pub approved: bool,    // 是否通过审核
    pub created_at: i64,
}

/// 白名单条目
#[derive(Debug, Clone)]
pub struct WhitelistEntry {
    pub server_id: String,
    pub approved: bool,
    pub applied_at: i64,
    pub health_url: String,   // 健康监测接口地址（P1）
    pub paused: bool,         // 是否因健康检查失败被暂停（P1）
}

/// 存储抽象接口
#[async_trait]
pub trait Storage: Send + Sync {
    // ---- 设备 Token ----
    async fn upsert_device_token(&self, t: &DeviceToken) -> Result<(), StorageError>;
    async fn list_device_tokens(&self, user_id: &str) -> Result<Vec<DeviceToken>, StorageError>;

    // ---- 服务器目录 ----
    async fn upsert_directory(&self, e: &DirectoryEntry) -> Result<(), StorageError>;
    async fn list_directory(&self) -> Result<Vec<DirectoryEntry>, StorageError>;
    async fn remove_directory(&self, server_id: &str) -> Result<(), StorageError>;
    async fn get_directory(&self, server_id: &str) -> Result<Option<DirectoryEntry>, StorageError>;

    // ---- 白名单 ----
    async fn upsert_whitelist(&self, e: &WhitelistEntry) -> Result<(), StorageError>;
    async fn is_whitelisted(&self, server_id: &str) -> Result<bool, StorageError>;
    async fn list_whitelist(&self) -> Result<Vec<WhitelistEntry>, StorageError>;

    // ---- 拒绝冷却 ----
    async fn set_cooldown(&self, server_id: &str, until: i64) -> Result<(), StorageError>;
    async fn get_cooldown(&self, server_id: &str) -> Result<Option<i64>, StorageError>;

    // ---- 用户免打扰 ----
    async fn set_mute(&self, server_id: &str, user_id: &str, muted: bool) -> Result<(), StorageError>;
    async fn is_muted(&self, server_id: &str, user_id: &str) -> Result<bool, StorageError>;

    // ---- 限速配置 ----
    async fn get_rate_limit(&self) -> Result<u32, StorageError>;
    async fn set_rate_limit(&self, per_minute: u32) -> Result<(), StorageError>;

    // ---- FCM 推送配置（web 端配置，替代环境变量） ----
    /// 读取 FCM 配置；未配置返回 None。
    async fn get_fcm_config(&self) -> Result<Option<crate::fcm::FcmConfig>, StorageError>;

    /// 保存 FCM 配置（config 表 5 个 key：4 项 OAuth2 + 服务账号 JSON）。
    async fn set_fcm_config(
        &self,
        project_id: &str,
        client_id: &str,
        client_secret: &str,
        refresh_token: &str,
        service_account_json: &str,
    ) -> Result<(), StorageError>;

    // ---- TLS 证书配置（web 端配置证书文件路径，统一 HTTPS） ----
    /// 读取 TLS 证书路径配置；返回 (cert_path, key_path)，未配置均为空串。
    async fn get_tls_config(&self) -> Result<(String, String), StorageError>;

    /// 保存 TLS 证书路径（config 表 tls_cert_path / tls_key_path）。
    async fn set_tls_config(&self, cert_path: &str, key_path: &str) -> Result<(), StorageError>;

    // ---- 黑名单（P1） ----

    /// 加入黑名单。
    async fn add_blacklist(&self, server_id: &str, reason: &str) -> Result<(), StorageError>;

    /// 移除黑名单。
    async fn remove_blacklist(&self, server_id: &str) -> Result<(), StorageError>;

    /// 检查是否在黑名单。
    async fn is_blacklisted(&self, server_id: &str) -> Result<bool, StorageError>;

    /// 列出黑名单所有条目。
    async fn list_blacklist(&self) -> Result<Vec<(String, String, i64)>, StorageError>;

    /// 设置白名单服务器的暂停状态（健康监测，P1）。
    async fn set_paused(&self, server_id: &str, paused: bool) -> Result<(), StorageError>;
}

/// SQLite 实现
pub struct SqliteStorage {
    pool: SqlitePool,
}

impl SqliteStorage {
    pub async fn open(path: &str) -> Result<Arc<Self>, StorageError> {
        let options = sqlx::sqlite::SqliteConnectOptions::new()
            .filename(path)
            .create_if_missing(true);
        let pool = SqlitePool::connect_with(options).await?;
        let storage = Arc::new(Self { pool });
        storage.migrate().await?;
        Ok(storage)
    }

    pub async fn open_in_memory() -> Result<Arc<Self>, StorageError> {
        let pool = SqlitePool::connect("sqlite::memory:").await?;
        let storage = Arc::new(Self { pool });
        storage.migrate().await?;
        Ok(storage)
    }

    async fn migrate(&self) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS device_tokens (
                user_id   TEXT NOT NULL,
                device_id TEXT NOT NULL,
                vendor    TEXT NOT NULL,
                token     TEXT NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (user_id, device_id)
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS directory (
                server_id   TEXT PRIMARY KEY,
                name        TEXT NOT NULL,
                description TEXT NOT NULL,
                icon        TEXT NOT NULL,
                address     TEXT NOT NULL,
                join_mode   TEXT NOT NULL,
                approved    INTEGER NOT NULL DEFAULT 0,
                created_at  INTEGER NOT NULL
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS whitelist (
                server_id  TEXT PRIMARY KEY,
                approved   INTEGER NOT NULL DEFAULT 0,
                applied_at INTEGER NOT NULL,
                health_url TEXT NOT NULL DEFAULT '',
                paused     INTEGER NOT NULL DEFAULT 0
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS cooldown (
                server_id TEXT PRIMARY KEY,
                until     INTEGER NOT NULL
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS mute (
                server_id TEXT NOT NULL,
                user_id   TEXT NOT NULL,
                PRIMARY KEY (server_id, user_id)
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 黑名单（P1，防滥用）
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS blacklist (
                server_id  TEXT PRIMARY KEY,
                reason     TEXT NOT NULL DEFAULT '',
                created_at INTEGER NOT NULL DEFAULT 0
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS config (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 默认限速 2 条/分钟
        sqlx::query(
            "INSERT OR IGNORE INTO config (key, value) VALUES ('rate_limit_per_minute', '2')",
        )
        .execute(&self.pool)
        .await?;

        Ok(())
    }
}

#[async_trait]
impl Storage for SqliteStorage {
    async fn upsert_device_token(&self, t: &DeviceToken) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            INSERT INTO device_tokens (user_id, device_id, vendor, token, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(user_id, device_id) DO UPDATE SET
                vendor = excluded.vendor,
                token = excluded.token,
                updated_at = excluded.updated_at
            "#,
        )
        .bind(&t.user_id)
        .bind(&t.device_id)
        .bind(&t.vendor)
        .bind(&t.token)
        .bind(t.updated_at)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn list_device_tokens(&self, user_id: &str) -> Result<Vec<DeviceToken>, StorageError> {
        let rows = sqlx::query(
            "SELECT user_id, device_id, vendor, token, updated_at FROM device_tokens WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?;
        Ok(rows.into_iter().map(row_to_device_token).collect())
    }

    async fn upsert_directory(&self, e: &DirectoryEntry) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            INSERT INTO directory (server_id, name, description, icon, address, join_mode, approved, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(server_id) DO UPDATE SET
                name = excluded.name,
                description = excluded.description,
                icon = excluded.icon,
                address = excluded.address,
                join_mode = excluded.join_mode,
                approved = excluded.approved,
                created_at = excluded.created_at
            "#,
        )
        .bind(&e.server_id)
        .bind(&e.name)
        .bind(&e.description)
        .bind(&e.icon)
        .bind(&e.address)
        .bind(&e.join_mode)
        .bind(e.approved as i64)
        .bind(e.created_at)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn list_directory(&self) -> Result<Vec<DirectoryEntry>, StorageError> {
        let rows = sqlx::query(
            "SELECT server_id, name, description, icon, address, join_mode, approved, created_at FROM directory WHERE approved = 1 ORDER BY created_at DESC",
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(rows.into_iter().map(row_to_directory).collect())
    }

    async fn remove_directory(&self, server_id: &str) -> Result<(), StorageError> {
        sqlx::query("DELETE FROM directory WHERE server_id = ?")
            .bind(server_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn get_directory(&self, server_id: &str) -> Result<Option<DirectoryEntry>, StorageError> {
        let row = sqlx::query(
            "SELECT server_id, name, description, icon, address, join_mode, approved, created_at FROM directory WHERE server_id = ?",
        )
        .bind(server_id)
        .fetch_optional(&self.pool)
        .await?;
        Ok(row.map(row_to_directory))
    }

    async fn upsert_whitelist(&self, e: &WhitelistEntry) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            INSERT INTO whitelist (server_id, approved, applied_at, health_url, paused)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(server_id) DO UPDATE SET
                approved = excluded.approved,
                applied_at = excluded.applied_at,
                health_url = excluded.health_url,
                paused = excluded.paused
            "#,
        )
        .bind(&e.server_id)
        .bind(e.approved as i64)
        .bind(e.applied_at)
        .bind(&e.health_url)
        .bind(e.paused as i64)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn is_whitelisted(&self, server_id: &str) -> Result<bool, StorageError> {
        let approved: Option<i64> = sqlx::query_scalar(
            "SELECT approved FROM whitelist WHERE server_id = ? AND approved = 1 AND paused = 0",
        )
        .bind(server_id)
        .fetch_optional(&self.pool)
        .await?;
        Ok(approved.map(|a| a != 0).unwrap_or(false))
    }

    async fn list_whitelist(&self) -> Result<Vec<WhitelistEntry>, StorageError> {
        let rows = sqlx::query("SELECT server_id, approved, applied_at, health_url, paused FROM whitelist")
            .fetch_all(&self.pool)
            .await?;
        Ok(rows.into_iter().map(row_to_whitelist).collect())
    }

    async fn set_cooldown(&self, server_id: &str, until: i64) -> Result<(), StorageError> {
        sqlx::query(
            "INSERT INTO cooldown (server_id, until) VALUES (?, ?) ON CONFLICT(server_id) DO UPDATE SET until = excluded.until",
        )
        .bind(server_id)
        .bind(until)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn get_cooldown(&self, server_id: &str) -> Result<Option<i64>, StorageError> {
        let until: Option<i64> = sqlx::query_scalar("SELECT until FROM cooldown WHERE server_id = ?")
            .bind(server_id)
            .fetch_optional(&self.pool)
            .await?;
        Ok(until)
    }

    async fn set_mute(&self, server_id: &str, user_id: &str, muted: bool) -> Result<(), StorageError> {
        if muted {
            sqlx::query("INSERT OR IGNORE INTO mute (server_id, user_id) VALUES (?, ?)")
                .bind(server_id)
                .bind(user_id)
                .execute(&self.pool)
                .await?;
        } else {
            sqlx::query("DELETE FROM mute WHERE server_id = ? AND user_id = ?")
                .bind(server_id)
                .bind(user_id)
                .execute(&self.pool)
                .await?;
        }
        Ok(())
    }

    async fn is_muted(&self, server_id: &str, user_id: &str) -> Result<bool, StorageError> {
        let count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM mute WHERE server_id = ? AND user_id = ?",
        )
        .bind(server_id)
        .bind(user_id)
        .fetch_one(&self.pool)
        .await?;
        Ok(count > 0)
    }

    async fn get_rate_limit(&self) -> Result<u32, StorageError> {
        let value: String = sqlx::query_scalar(
            "SELECT value FROM config WHERE key = 'rate_limit_per_minute'",
        )
        .fetch_one(&self.pool)
        .await?;
        Ok(value.parse().unwrap_or(2))
    }

    async fn set_rate_limit(&self, per_minute: u32) -> Result<(), StorageError> {
        sqlx::query(
            "INSERT INTO config (key, value) VALUES ('rate_limit_per_minute', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        )
        .bind(per_minute.to_string())
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    // ---- FCM 推送配置（web 端配置，F-PUSH-2） ----

    async fn get_fcm_config(&self) -> Result<Option<crate::fcm::FcmConfig>, StorageError> {
        let mut rows = sqlx::query("SELECT key, value FROM config WHERE key IN ('fcm_project_id','fcm_client_id','fcm_client_secret','fcm_refresh_token','fcm_service_account')")
            .fetch_all(&self.pool)
            .await?;
        let get = |key: &str| -> String {
            rows.iter()
                .find(|r| r.get::<String, _>(0) == key)
                .map(|r| r.get::<String, _>(1))
                .unwrap_or_default()
        };
        let sa = get("fcm_service_account");
        if sa.is_empty() && get("fcm_project_id").is_empty() && get("fcm_client_id").is_empty() {
            return Ok(None);
        }
        Ok(Some(crate::fcm::FcmConfig {
            project_id: get("fcm_project_id"),
            client_id: get("fcm_client_id"),
            client_secret: get("fcm_client_secret"),
            refresh_token: get("fcm_refresh_token"),
            service_account_json: sa,
        }))
    }

    async fn set_fcm_config(
        &self,
        project_id: &str,
        client_id: &str,
        client_secret: &str,
        refresh_token: &str,
        service_account_json: &str,
    ) -> Result<(), StorageError> {
        let kv = [
            ("fcm_project_id", project_id),
            ("fcm_client_id", client_id),
            ("fcm_client_secret", client_secret),
            ("fcm_refresh_token", refresh_token),
            ("fcm_service_account", service_account_json),
        ];
        for (k, v) in kv {
            sqlx::query(
                "INSERT INTO config (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            )
            .bind(k)
            .bind(v)
            .execute(&self.pool)
            .await?;
        }
        Ok(())
    }

    async fn get_tls_config(&self) -> Result<(String, String), StorageError> {
        let rows = sqlx::query("SELECT key, value FROM config WHERE key IN ('tls_cert_path','tls_key_path')")
            .fetch_all(&self.pool)
            .await?;
        let get = |key: &str| -> String {
            rows.iter()
                .find(|r| r.get::<String, _>(0) == key)
                .map(|r| r.get::<String, _>(1))
                .unwrap_or_default()
        };
        Ok((get("tls_cert_path"), get("tls_key_path")))
    }

    async fn set_tls_config(&self, cert_path: &str, key_path: &str) -> Result<(), StorageError> {
        let kv = [("tls_cert_path", cert_path), ("tls_key_path", key_path)];
        for (k, v) in kv {
            sqlx::query(
                "INSERT INTO config (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            )
            .bind(k)
            .bind(v)
            .execute(&self.pool)
            .await?;
        }
        Ok(())
    }

    // ---- 黑名单（P1） ----

    async fn add_blacklist(&self, server_id: &str, reason: &str) -> Result<(), StorageError> {
        sqlx::query(
            "INSERT INTO blacklist (server_id, reason, created_at) VALUES (?, ?, ?) ON CONFLICT(server_id) DO UPDATE SET reason = excluded.reason",
        )
        .bind(server_id)
        .bind(reason)
        .bind(lonisle_core::device::current_unix_time())
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn remove_blacklist(&self, server_id: &str) -> Result<(), StorageError> {
        sqlx::query("DELETE FROM blacklist WHERE server_id = ?")
            .bind(server_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn is_blacklisted(&self, server_id: &str) -> Result<bool, StorageError> {
        let count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM blacklist WHERE server_id = ?",
        )
        .bind(server_id)
        .fetch_one(&self.pool)
        .await?;
        Ok(count > 0)
    }

    async fn list_blacklist(&self) -> Result<Vec<(String, String, i64)>, StorageError> {
        let rows = sqlx::query("SELECT server_id, reason, created_at FROM blacklist")
            .fetch_all(&self.pool)
            .await?;
        Ok(rows
            .into_iter()
            .map(|r| (r.get("server_id"), r.get("reason"), r.get("created_at")))
            .collect())
    }

    async fn set_paused(&self, server_id: &str, paused: bool) -> Result<(), StorageError> {
        sqlx::query("UPDATE whitelist SET paused = ? WHERE server_id = ?")
            .bind(paused as i64)
            .bind(server_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}

fn row_to_device_token(r: sqlx::sqlite::SqliteRow) -> DeviceToken {
    DeviceToken {
        user_id: r.get("user_id"),
        device_id: r.get("device_id"),
        vendor: r.get("vendor"),
        token: r.get("token"),
        updated_at: r.get("updated_at"),
    }
}

fn row_to_directory(r: sqlx::sqlite::SqliteRow) -> DirectoryEntry {
    DirectoryEntry {
        server_id: r.get("server_id"),
        name: r.get("name"),
        description: r.get("description"),
        icon: r.get("icon"),
        address: r.get("address"),
        join_mode: r.get("join_mode"),
        approved: r.get::<i64, _>("approved") != 0,
        created_at: r.get("created_at"),
    }
}

fn row_to_whitelist(r: sqlx::sqlite::SqliteRow) -> WhitelistEntry {
    WhitelistEntry {
        server_id: r.get("server_id"),
        approved: r.get::<i64, _>("approved") != 0,
        applied_at: r.get("applied_at"),
        health_url: r.get("health_url"),
        paused: r.get::<i64, _>("paused") != 0,
    }
}
