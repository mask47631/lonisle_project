//! 存储层：Storage trait + SQLite 实现
//!
//! 服务器端为权威数据源。消息、成员、服务器元数据均落库；
//! 维护全局单调递增消息序号（由 SQLite 自增主键分配，重启不重置）。
//! Storage trait 抽象隔离存储后端，未来可新增 PostgreSQL 实现。

use std::sync::Arc;

use async_trait::async_trait;
use sqlx::{sqlite::SqlitePool, Row};
use thiserror::Error;

/// 存储错误
#[derive(Debug, Error)]
pub enum StorageError {
    #[error("数据库错误：{0}")]
    Db(#[from] sqlx::Error),
    #[error("消息已存在（幂等去重命中）")]
    DuplicateMessage,
    #[error("记录不存在")]
    NotFound,
}

/// 成员角色（内置：Owner/Admin/Member）
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum MemberRole {
    Member = 0,
    Admin = 1,
    Owner = 2,
}

impl MemberRole {
    pub fn as_i64(self) -> i64 {
        self as i64
    }
    pub fn from_i64(v: i64) -> Self {
        match v {
            2 => MemberRole::Owner,
            1 => MemberRole::Admin,
            _ => MemberRole::Member,
        }
    }
}

// ---- RBAC 权限位掩码（P2） ----

/// 权限位常量（位掩码）
pub mod perm {
    pub const MANAGE_TOPICS: u32 = 1 << 0;   // 管理话题
    pub const APPROVE_JOIN: u32 = 1 << 1;    // 审批加入
    pub const MUTE_MEMBER: u32 = 1 << 2;     // 禁言
    pub const KICK_MEMBER: u32 = 1 << 3;     // 踢出
    pub const BAN_MEMBER: u32 = 1 << 4;      // 封禁
    pub const MANAGE_ROLES: u32 = 1 << 5;    // 管理角色
    pub const MANAGE_SERVER: u32 = 1 << 6;   // 管理服务器
    pub const SEND_MESSAGE: u32 = 1 << 7;    // 发言

    /// 所有权限
    pub const ALL: u32 = MANAGE_TOPICS | APPROVE_JOIN | MUTE_MEMBER | KICK_MEMBER
        | BAN_MEMBER | MANAGE_ROLES | MANAGE_SERVER | SEND_MESSAGE;
}

/// 自定义角色（RBAC，P2）
#[derive(Debug, Clone)]
pub struct RoleInfo {
    pub role_id: String,
    pub name: String,
    pub permissions: u32, // 权限位掩码
}

/// 话题类型
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TopicType {
    Text = 0,
    Announcement = 1,
    Av = 2,  // 音视频话题（LiveKit）
}

impl TopicType {
    pub fn as_i64(self) -> i64 {
        self as i64
    }
    pub fn from_i64(v: i64) -> Self {
        match v {
            1 => TopicType::Announcement,
            2 => TopicType::Av,
            _ => TopicType::Text,
        }
    }
}

/// 话题权限
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TopicPermission {
    Public = 0,
    Readonly = 1,
}

impl TopicPermission {
    pub fn as_i64(self) -> i64 {
        self as i64
    }
    pub fn from_i64(v: i64) -> Self {
        match v {
            1 => TopicPermission::Readonly,
            _ => TopicPermission::Public,
        }
    }
}

/// 加入状态
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JoinStatus {
    Pending = 0,
    Approved = 1,
    Rejected = 2,
    Ignored = 3,
}

impl JoinStatus {
    pub fn as_i64(self) -> i64 {
        self as i64
    }
    pub fn from_i64(v: i64) -> Self {
        match v {
            1 => JoinStatus::Approved,
            2 => JoinStatus::Rejected,
            3 => JoinStatus::Ignored,
            _ => JoinStatus::Pending,
        }
    }
}

/// 加入策略
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum JoinStrategy {
    Approval = 0,
    Open = 1,
    InviteOnly = 2,
}

impl JoinStrategy {
    pub fn as_i64(self) -> i64 {
        self as i64
    }
    pub fn from_i64(v: i64) -> Self {
        match v {
            1 => JoinStrategy::Open,
            2 => JoinStrategy::InviteOnly,
            _ => JoinStrategy::Approval,
        }
    }
}

/// 成员（服务器内）
#[derive(Debug, Clone)]
pub struct Member {
    pub user_id: String,
    pub display_name: String, // 全局默认昵称
    pub avatar_seed: String,  // 全局默认头像种子
    pub role: MemberRole,
    pub muted: bool,
    pub banned: bool,
    pub server_nickname: Option<String>, // 服务器内覆盖昵称
    pub server_avatar: Option<String>,   // 服务器内覆盖头像种子
    pub push_service_url: String,        // 该成员登记的推送服务地址（M4）
    pub is_bot: bool,                    // 是否机器人（M6）
    pub joined_at: i64,
    /// 身份主公钥（Ed25519，32 字节；吊销证明验签所需，F-DEV-4）
    pub master_pubkey: Vec<u8>,
}

impl Member {
    /// 是否 Owner（兼容 M1 的 is_owner 语义）
    pub fn is_owner(&self) -> bool {
        self.role == MemberRole::Owner
    }

    /// 服务器内展示昵称（覆盖 > 全局默认）
    pub fn effective_name(&self) -> &str {
        self.server_nickname
            .as_deref()
            .filter(|s| !s.is_empty())
            .unwrap_or(&self.display_name)
    }

    /// 服务器内展示头像种子（覆盖 > 全局默认）
    pub fn effective_avatar(&self) -> &str {
        self.server_avatar
            .as_deref()
            .filter(|s| !s.is_empty())
            .unwrap_or(&self.avatar_seed)
    }
}

/// 话题
#[derive(Debug, Clone)]
pub struct Topic {
    pub topic_id: String,
    pub name: String,
    pub description: String,
    pub topic_type: TopicType,
    pub permission: TopicPermission,
    pub sort_order: i32,
    /// 话题推送开关：开启后该话题新消息推送给服务器下所有客户端（F-PUSH-8）
    pub push_enabled: bool,
}

/// 加入申请
#[derive(Debug, Clone)]
pub struct JoinRequest {
    pub request_id: String,
    pub user_id: String,
    pub display_name: String,
    pub reason: String,
    pub push_service_url: String,
    pub status: JoinStatus,
    pub created_at: i64,
}

/// 已存储消息（含服务器分配的全局序号）
#[derive(Debug, Clone)]
pub struct StoredMessage {
    pub seq: u64,
    pub topic_id: String,
    pub msg_id: String,
    pub author_id: String,
    pub device_id: String,
    pub author_name: String,
    pub server_ts: i64,
    pub content_text: String,
    pub edited: bool,
    pub deleted: bool,
    pub mentions: String, // @提及（JSON 数组字符串，M2 基础版）
    pub reply_to: String, // 被回复消息的 msg_id（F-MSG-6，空则无）
    pub attachment_json: String, // 附件元数据（JSON，F-MEDIA-8；空则无附件）
}

/// 服务器元数据
#[derive(Debug, Clone)]
pub struct ServerMeta {
    pub server_id: String,
    pub name: String,
    pub description: String,
    pub strategy: JoinStrategy,
    pub migration_target_address: String,      // 迁移目标地址（空则无迁移）
    pub migration_target_fingerprint: String,  // 迁移目标指纹
    pub migration_signature: String,           // 迁移公告签名（服务器私钥签名，F-JOIN-8）
    pub rate_limit_per_minute: u32,            // 发言频率限制（0 表示不限）
    pub max_attachment_size: u64,              // 附件大小上限（0 表示不限；生效值不超过累计配额）
    pub attachment_quota: u64,                 // 已弃用：单成员附件总配额（已取消限制，字段保留兼容）
    pub mention_read_enabled: bool,            // @提及已读上报开关（默认关闭，P2）
    pub livekit_url: String,                   // LiveKit 服务地址（空则未启用音视频）
    pub livekit_api_key: String,               // LiveKit API Key
    pub livekit_api_secret: String,            // LiveKit API Secret（不暴露给客户端）
    pub icon: String,                          // 服务器图标版本标识（"ext:ts"，空则未设置，F-PERM-2）
}

/// 设备记录（多设备，M3）
#[derive(Debug, Clone)]
pub struct DeviceRecord {
    pub user_id: String,
    pub device_id: String,
    pub device_name: String,
    pub platform: String,
    pub pubkey: Vec<u8>,
    pub last_active: i64,
}

/// 邀请令牌记录（F-JOIN-5）
#[derive(Debug, Clone)]
pub struct InviteTokenRecord {
    pub token: String,
    pub created_by: String,
    pub created_at: i64,
    pub used: bool,
    pub revoked: bool,
}

/// Bot 记录（F-BOT）
#[derive(Debug, Clone)]
pub struct BotRecord {
    pub bot_id: String,
    pub name: String,
    pub token_hash: String, // SHA-256 哈希（明文 Token 仅签发时返回一次）
    pub events: String,     // 订阅事件（JSON 数组：message/member/join/system；空 = 全部）
    pub created_at: i64,
    pub revoked: bool,
}

/// 附件记录（媒体，M5）
#[derive(Debug, Clone)]
pub struct AttachmentRecord {
    pub attachment_id: String,
    pub msg_id: String,           // 关联消息
    pub kind: String,             // image / video / audio / file
    pub size: u64,
    pub mime: String,
    pub path: String,             // 原文件相对路径
    pub thumbnail_path: Option<String>,
    pub width: u32,
    pub height: u32,
    pub duration: u32,
    pub author_id: String,        // 上传者 user_id（配额统计）
    pub created_at: i64,
    pub filename: String,         // 原始文件名（含后缀，F-MEDIA-10）
}

/// 存储抽象接口
#[async_trait]
pub trait Storage: Send + Sync {
    /// 追加消息，返回分配的全局序号。若 (author_id, msg_id) 已存在，返回 DuplicateMessage。
    async fn append_message(&self, msg: &StoredMessage) -> Result<u64, StorageError>;

    /// 按序号区间拉取某话题的增量消息（after_seq 之后，最多 limit 条，升序）。
    async fn get_messages_since(
        &self,
        topic_id: &str,
        after_seq: u64,
        limit: u32,
    ) -> Result<Vec<StoredMessage>, StorageError>;

    /// 按序号区间向前翻页（before_seq 之前，最多 limit 条，降序，供历史分页）。
    async fn get_messages_before(
        &self,
        topic_id: &str,
        before_seq: u64,
        limit: u32,
    ) -> Result<Vec<StoredMessage>, StorageError>;

    /// 当前某话题的最大序号。
    async fn latest_seq(&self, topic_id: &str) -> Result<u64, StorageError>;

    /// 按 msg_id 查找消息（用于编辑/删除权限校验）。
    async fn get_message_by_id(
        &self,
        topic_id: &str,
        msg_id: &str,
    ) -> Result<Option<StoredMessage>, StorageError>;

    /// 编辑消息（删旧行 + 新序号事件行，edited=1，F-MSG-13）。
    /// 返回新事件行（新 seq）。
    async fn edit_message(
        &self,
        topic_id: &str,
        msg_id: &str,
        new_text: &str,
    ) -> Result<StoredMessage, StorageError>;

    /// 删除消息（硬删原行 + 新序号删除事件行，F-MSG-14）。
    /// 返回删除事件行（新 seq，deleted=1，内容清空）。
    async fn delete_message(
        &self,
        topic_id: &str,
        msg_id: &str,
    ) -> Result<StoredMessage, StorageError>;

    /// 添加成员（已存在则更新资料）。若带 role，保留现有角色优先级。
    async fn upsert_member(&self, member: &Member) -> Result<(), StorageError>;

    /// 列出所有成员。
    async fn list_members(&self) -> Result<Vec<Member>, StorageError>;

    /// 查询某成员。
    async fn get_member(&self, user_id: &str) -> Result<Option<Member>, StorageError>;

    /// 补录成员主公钥（仅在未记录时写入；Hello 握手时调用）。
    async fn set_member_master_pubkey(
        &self,
        user_id: &str,
        master_pubkey: &[u8],
    ) -> Result<(), StorageError>;

    /// 更新成员角色。
    async fn set_member_role(&self, user_id: &str, role: MemberRole) -> Result<(), StorageError>;

    /// 设置成员禁言。
    async fn set_member_muted(&self, user_id: &str, muted: bool) -> Result<(), StorageError>;

    /// 设置成员封禁。
    async fn set_member_banned(&self, user_id: &str, banned: bool) -> Result<(), StorageError>;

    /// 移除成员（踢出）。
    async fn remove_member(&self, user_id: &str) -> Result<(), StorageError>;

    /// 更新成员服务器内资料覆盖。
    async fn update_server_profile(
        &self,
        user_id: &str,
        nickname: Option<&str>,
        avatar: Option<&str>,
    ) -> Result<(), StorageError>;

    /// 写入服务器元数据。
    async fn set_server_meta(&self, meta: &ServerMeta) -> Result<(), StorageError>;

    /// 读取服务器元数据。
    async fn get_server_meta(&self) -> Result<Option<ServerMeta>, StorageError>;

    /// 读取 TLS 证书路径配置；返回 (cert_path, key_path)，未配置均为空串。
    async fn get_tls_config(&self) -> Result<(String, String), StorageError>;

    /// 保存 TLS 证书路径（server_meta 表 tls_cert_path / tls_key_path）。
    async fn set_tls_config(&self, cert_path: &str, key_path: &str) -> Result<(), StorageError>;

    /// 写入 Owner 认领码哈希（F-PERM-1）。
    async fn set_owner_claim_hash(&self, hash: &str) -> Result<(), StorageError>;

    /// 读取 Owner 认领码哈希（不存在返回 None）。
    async fn get_owner_claim_hash(&self) -> Result<Option<String>, StorageError>;

    /// 清除 Owner 认领码哈希（认领成功后销毁，认领码随即失效）。
    async fn clear_owner_claim_hash(&self) -> Result<(), StorageError>;

    // ---- 仅邀请模式一次性邀请令牌（F-JOIN-5） ----

    /// 创建一次性邀请令牌，返回令牌明文。
    async fn create_invite(&self, created_by: &str) -> Result<String, StorageError>;

    /// 列出全部邀请令牌（token/created_by/created_at/used/revoked）。
    async fn list_invites(&self) -> Result<Vec<InviteTokenRecord>, StorageError>;

    /// 撤销邀请令牌（未使用的令牌立即失效）。
    async fn revoke_invite(&self, token: &str) -> Result<(), StorageError>;

    /// 消费邀请令牌：有效未用未撤销则标记使用并返回 true。
    async fn consume_invite(&self, token: &str) -> Result<bool, StorageError>;

    // ---- Bot 管理（F-BOT） ----

    /// 注册 Bot（token 存哈希），返回明文 Token（仅此一次可见）。
    async fn create_bot(&self, bot_id: &str, name: &str, token_hash: &str)
        -> Result<(), StorageError>;

    /// 按 Token 哈希查找有效（未撤销）Bot。
    async fn find_bot_by_token(&self, token_hash: &str)
        -> Result<Option<BotRecord>, StorageError>;

    /// 列出全部 Bot。
    async fn list_bots(&self) -> Result<Vec<BotRecord>, StorageError>;

    /// 撤销 Bot。
    async fn revoke_bot(&self, bot_id: &str) -> Result<(), StorageError>;

    /// 更新 Bot 事件订阅（JSON 数组字符串）。
    async fn set_bot_events(&self, bot_id: &str, events: &str)
        -> Result<(), StorageError>;

    /// 确保话题存在（不存在则创建）。
    async fn ensure_topic(&self, topic_id: &str, name: &str, description: &str) -> Result<(), StorageError>;

    /// 创建话题。
    async fn create_topic(&self, topic: &Topic) -> Result<(), StorageError>;

    /// 更新话题。
    async fn update_topic(&self, topic: &Topic) -> Result<(), StorageError>;

    /// 删除话题。
    async fn delete_topic(&self, topic_id: &str) -> Result<(), StorageError>;

    /// 话题排序（按给定顺序重排 sort_order）。
    async fn reorder_topics(&self, topic_ids: &[String]) -> Result<(), StorageError>;

    /// 列出所有话题。
    async fn list_topics(&self) -> Result<Vec<Topic>, StorageError>;

    /// 查询单个话题。
    async fn get_topic(&self, topic_id: &str) -> Result<Option<Topic>, StorageError>;

    /// 创建加入申请。
    async fn create_join_request(&self, req: &JoinRequest) -> Result<(), StorageError>;

    /// 查询某用户待审批的申请。
    async fn get_pending_request(&self, user_id: &str) -> Result<Option<JoinRequest>, StorageError>;

    /// 列出待审批申请。
    async fn list_join_requests(&self) -> Result<Vec<JoinRequest>, StorageError>;

    /// 更新申请状态。
    async fn set_join_request_status(
        &self,
        request_id: &str,
        status: JoinStatus,
    ) -> Result<(), StorageError>;

    /// 按 ID 查询申请。
    async fn get_join_request(&self, request_id: &str) -> Result<Option<JoinRequest>, StorageError>;

    // ---- 多设备（M3） ----

    /// 注册/更新设备（按 (user_id, device_id) 维度）。
    async fn upsert_device(&self, device: &DeviceRecord) -> Result<(), StorageError>;

    /// 列出某用户的所有设备。
    async fn list_devices(&self, user_id: &str) -> Result<Vec<DeviceRecord>, StorageError>;

    /// 查询某用户的某个设备。
    async fn get_device(
        &self,
        user_id: &str,
        device_id: &str,
    ) -> Result<Option<DeviceRecord>, StorageError>;

    /// 删除设备（撤销）。
    async fn remove_device(&self, user_id: &str, device_id: &str) -> Result<(), StorageError>;

    /// 更新设备最近活跃时间。
    async fn touch_device(&self, user_id: &str, device_id: &str) -> Result<(), StorageError>;

    /// 添加吊销条目（(user_id, device_pubkey)）。
    async fn add_revocation(
        &self,
        user_id: &str,
        device_pubkey: &[u8],
        revoked_at: i64,
    ) -> Result<(), StorageError>;

    /// 检查设备公钥是否已被吊销。
    async fn is_revoked(&self, user_id: &str, device_pubkey: &[u8]) -> Result<bool, StorageError>;

    // ---- 附件（M5） ----

    /// 插入附件记录。
    async fn insert_attachment(&self, att: &AttachmentRecord) -> Result<(), StorageError>;

    /// 查询附件记录。
    async fn get_attachment(&self, attachment_id: &str) -> Result<Option<AttachmentRecord>, StorageError>;

    /// 列出某消息的附件。
    async fn list_attachments_for_message(&self, msg_id: &str) -> Result<Vec<AttachmentRecord>, StorageError>;

    /// 删除附件记录。
    async fn delete_attachment(&self, attachment_id: &str) -> Result<(), StorageError>;

    /// 删除某消息的所有附件（级联）。
    async fn delete_attachments_for_message(&self, msg_id: &str) -> Result<Vec<AttachmentRecord>, StorageError>;

    /// 某成员附件总大小（已弃用：配额检查已取消，方法保留备用）。
    async fn total_attachment_size(&self, user_id: &str) -> Result<u64, StorageError>;

    /// 列出全部附件记录（数据导出 zip 打包用，F-PERM-2a）。
    async fn list_all_attachments(&self) -> Result<Vec<AttachmentRecord>, StorageError>;

    // ---- Reaction（M5） ----

    /// 添加 Reaction（幂等：同 (msg_id, user_id, emoji) 去重）。
    async fn add_reaction(
        &self,
        topic_id: &str,
        msg_id: &str,
        user_id: &str,
        emoji: &str,
    ) -> Result<(), StorageError>;

    /// 移除 Reaction。
    async fn remove_reaction(
        &self,
        topic_id: &str,
        msg_id: &str,
        user_id: &str,
        emoji: &str,
    ) -> Result<(), StorageError>;

    /// 获取某消息的所有 Reaction（聚合为 (emoji, Vec<user_id>)）。
    async fn get_reactions(&self, msg_id: &str) -> Result<Vec<(String, Vec<String>)>, StorageError>;

    // ---- 预密钥（M6 E2EE） ----

    /// 上传预密钥束（SPK + 若干 OPK）。
    async fn upload_pre_keys(
        &self,
        user_id: &str,
        identity_key: &[u8],
        signed_pre_key: &[u8],
        signed_pre_key_sig: &[u8],
        one_time_pre_keys: &[Vec<u8>],
    ) -> Result<(), StorageError>;

    /// 拉取某用户的预密钥束（含一个 OPK，取用后删除）。
    async fn fetch_pre_keys(
        &self,
        user_id: &str,
    ) -> Result<Option<(Vec<u8>, Vec<u8>, Vec<u8>, Vec<u8>)>, StorageError>;

    // ---- RBAC 自定义角色（P2） ----

    /// 创建/更新自定义角色。
    async fn upsert_role(&self, role: &RoleInfo) -> Result<(), StorageError>;

    /// 删除自定义角色。
    async fn delete_role(&self, role_id: &str) -> Result<(), StorageError>;

    /// 列出所有自定义角色。
    async fn list_roles(&self) -> Result<Vec<RoleInfo>, StorageError>;

    /// 查询角色权限位掩码。
    async fn get_role_permissions(&self, role_id: &str) -> Result<Option<u32>, StorageError>;

    /// 给成员分配自定义角色。
    async fn assign_role(&self, user_id: &str, role_id: &str) -> Result<(), StorageError>;

    /// 移除成员的自定义角色。
    async fn unassign_role(&self, user_id: &str, role_id: &str) -> Result<(), StorageError>;

    /// 获取成员的所有自定义角色权限位（并集）。
    async fn get_member_permissions(&self, user_id: &str) -> Result<u32, StorageError>;

    // ---- @提及已读回执（P2） ----

    /// 标记某消息的 @提及已读（幂等）。
    async fn mark_mention_read(&self, msg_id: &str, user_id: &str) -> Result<(), StorageError>;

    /// 查询某消息的已读用户列表。
    async fn list_mention_reads(&self, msg_id: &str) -> Result<Vec<String>, StorageError>;

    // ---- 数据导出/清除（P1） ----

    /// 列出全部消息（导出用，按 seq 升序）。
    async fn list_all_messages(&self) -> Result<Vec<StoredMessage>, StorageError>;

    /// 按话题删除所有消息，返回删除的消息（用于级联清附件）。
    async fn delete_messages_by_topic(&self, topic_id: &str) -> Result<Vec<StoredMessage>, StorageError>;

    /// 按时间段删除消息（server_ts 在 [start, end] 内）。
    async fn delete_messages_in_range(&self, start: i64, end: i64) -> Result<Vec<StoredMessage>, StorageError>;

    /// 删除某成员的全部消息。
    async fn delete_messages_by_user(&self, user_id: &str) -> Result<Vec<StoredMessage>, StorageError>;

    /// 清空全部消息。
    async fn clear_all_messages(&self) -> Result<Vec<StoredMessage>, StorageError>;
}

/// SQLite 实现
pub struct SqliteStorage {
    pool: SqlitePool,
}

impl SqliteStorage {
    /// 打开（或创建）SQLite 数据库并执行迁移。
    pub async fn open(path: &str) -> Result<Arc<Self>, StorageError> {
        let options = sqlx::sqlite::SqliteConnectOptions::new()
            .filename(path)
            .create_if_missing(true);
        let pool = SqlitePool::connect_with(options).await?;
        let storage = Arc::new(Self { pool });
        storage.migrate().await?;
        Ok(storage)
    }

    /// 内存数据库（测试用）。
    pub async fn open_in_memory() -> Result<Arc<Self>, StorageError> {
        let pool = SqlitePool::connect("sqlite::memory:").await?;
        let storage = Arc::new(Self { pool });
        storage.migrate().await?;
        Ok(storage)
    }

    async fn migrate(&self) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS messages (
                seq         INTEGER PRIMARY KEY AUTOINCREMENT,
                topic_id    TEXT NOT NULL,
                msg_id      TEXT NOT NULL,
                author_id   TEXT NOT NULL,
                device_id   TEXT NOT NULL,
                author_name TEXT NOT NULL,
                server_ts   INTEGER NOT NULL,
                content_text TEXT NOT NULL,
                edited      INTEGER NOT NULL DEFAULT 0,
                deleted     INTEGER NOT NULL DEFAULT 0,
                mentions    TEXT NOT NULL DEFAULT '',
                reply_to    TEXT NOT NULL DEFAULT '',
                attachment_json TEXT NOT NULL DEFAULT ''
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 幂等去重：同一作者同一消息 ID 只允许一条
        sqlx::query(
            r#"
            CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_author_msg
                ON messages (author_id, msg_id);
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 按话题+序号的范围查询索引
        sqlx::query(
            r#"
            CREATE INDEX IF NOT EXISTS idx_messages_topic_seq
                ON messages (topic_id, seq);
            "#,
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS members (
                user_id        TEXT PRIMARY KEY,
                display_name   TEXT NOT NULL,
                avatar_seed    TEXT NOT NULL,
                role           INTEGER NOT NULL DEFAULT 0,
                muted          INTEGER NOT NULL DEFAULT 0,
                banned         INTEGER NOT NULL DEFAULT 0,
                server_nickname TEXT,
                server_avatar  TEXT,
                push_service_url TEXT NOT NULL DEFAULT '',
                is_bot         INTEGER NOT NULL DEFAULT 0,
                joined_at      INTEGER NOT NULL
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS server_meta (
                key   TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS topics (
                topic_id    TEXT PRIMARY KEY,
                name        TEXT NOT NULL,
                description TEXT NOT NULL,
                topic_type  INTEGER NOT NULL DEFAULT 0,
                permission  INTEGER NOT NULL DEFAULT 0,
                sort_order  INTEGER NOT NULL DEFAULT 0,
                push_enabled INTEGER NOT NULL DEFAULT 0
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 兼容旧库：为已存在的 topics 表补充 push_enabled 列（话题推送开关）
        let has_push = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(*) FROM pragma_table_info('topics') WHERE name = 'push_enabled'",
        )
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);
        if has_push == 0 {
            let _ = sqlx::query("ALTER TABLE topics ADD COLUMN push_enabled INTEGER NOT NULL DEFAULT 0")
                .execute(&self.pool)
                .await;
        }

        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS join_requests (
                request_id       TEXT PRIMARY KEY,
                user_id          TEXT NOT NULL,
                display_name     TEXT NOT NULL,
                reason           TEXT NOT NULL,
                push_service_url TEXT NOT NULL,
                status           INTEGER NOT NULL DEFAULT 0,
                created_at       INTEGER NOT NULL
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 设备表（M3）：(user_id, device_id) 联合主键
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS devices (
                user_id     TEXT NOT NULL,
                device_id   TEXT NOT NULL,
                device_name TEXT NOT NULL,
                platform    TEXT NOT NULL,
                pubkey      BLOB NOT NULL,
                last_active INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (user_id, device_id)
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            r#"
            CREATE INDEX IF NOT EXISTS idx_devices_user
                ON devices (user_id);
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 吊销列表（M3）：(user_id, device_pubkey) 联合主键
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS revocations (
                user_id      TEXT NOT NULL,
                device_pubkey BLOB NOT NULL,
                revoked_at   INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (user_id, device_pubkey)
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 附件表（M5）
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS attachments (
                attachment_id  TEXT PRIMARY KEY,
                msg_id         TEXT NOT NULL,
                kind           TEXT NOT NULL,
                size           INTEGER NOT NULL,
                mime           TEXT NOT NULL,
                path           TEXT NOT NULL,
                thumbnail_path TEXT,
                width          INTEGER NOT NULL DEFAULT 0,
                height         INTEGER NOT NULL DEFAULT 0,
                duration       INTEGER NOT NULL DEFAULT 0,
                author_id      TEXT NOT NULL DEFAULT '',
                created_at     INTEGER NOT NULL,
                filename       TEXT NOT NULL DEFAULT ''
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            r#"
            CREATE INDEX IF NOT EXISTS idx_attachments_msg
                ON attachments (msg_id);
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 附件表列迁移（旧库无 filename 列，CREATE TABLE IF NOT EXISTS 不会补列）
        // ALTER TABLE ADD COLUMN 不支持 IF NOT EXISTS，用 try 忽略已存在错误
        sqlx::query("ALTER TABLE attachments ADD COLUMN filename TEXT NOT NULL DEFAULT ''")
            .execute(&self.pool)
            .await
            .ok(); // 列已存在则忽略

        // Reaction 表（M5）
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS reactions (
                topic_id  TEXT NOT NULL,
                msg_id    TEXT NOT NULL,
                user_id   TEXT NOT NULL,
                emoji     TEXT NOT NULL,
                PRIMARY KEY (msg_id, user_id, emoji)
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 预密钥表（M6 E2EE）
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS pre_keys (
                user_id           TEXT NOT NULL,
                identity_key      BLOB NOT NULL,
                signed_pre_key    BLOB NOT NULL,
                signed_pre_key_sig BLOB NOT NULL,
                one_time_pre_key  BLOB,
                PRIMARY KEY (user_id, one_time_pre_key)
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 自定义角色表（RBAC，P2）
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS roles (
                role_id     TEXT PRIMARY KEY,
                name        TEXT NOT NULL,
                permissions INTEGER NOT NULL DEFAULT 0
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 成员-角色关联表（RBAC，P2）
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS member_roles (
                user_id TEXT NOT NULL,
                role_id TEXT NOT NULL,
                PRIMARY KEY (user_id, role_id)
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 仅邀请模式的一次性邀请令牌（F-JOIN-5）
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS invite_tokens (
                token      TEXT PRIMARY KEY,
                created_by TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                used_at    INTEGER,             -- NULL = 未使用
                revoked    INTEGER NOT NULL DEFAULT 0
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // Bot 注册表（F-BOT：管理员签发，Token 存哈希）
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS bots (
                bot_id     TEXT PRIMARY KEY,
                name       TEXT NOT NULL,
                token_hash TEXT NOT NULL UNIQUE,
                events     TEXT NOT NULL DEFAULT '',
                created_at INTEGER NOT NULL,
                revoked    INTEGER NOT NULL DEFAULT 0
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // @提及已读回执表（P2）
        sqlx::query(
            r#"
            CREATE TABLE IF NOT EXISTS mention_reads (
                msg_id   TEXT NOT NULL,
                user_id  TEXT NOT NULL,
                read_at  INTEGER NOT NULL,
                PRIMARY KEY (msg_id, user_id)
            );
            "#,
        )
        .execute(&self.pool)
        .await?;

        // 兼容 M1 旧数据：members 表若无 role 列（旧库），用 ALTER 补齐。
        // 由于 SQLite 的 CREATE TABLE IF NOT EXISTS 不会为已存在的旧表补列，
        // 这里对可能缺失的新列做 ALTER TABLE 兜底（忽略"列已存在"错误）。
        for (col, ddl) in [
            ("role", "ALTER TABLE members ADD COLUMN role INTEGER NOT NULL DEFAULT 0"),
            ("muted", "ALTER TABLE members ADD COLUMN muted INTEGER NOT NULL DEFAULT 0"),
            ("banned", "ALTER TABLE members ADD COLUMN banned INTEGER NOT NULL DEFAULT 0"),
            ("server_nickname", "ALTER TABLE members ADD COLUMN server_nickname TEXT"),
            ("server_avatar", "ALTER TABLE members ADD COLUMN server_avatar TEXT"),
            ("push_service_url", "ALTER TABLE members ADD COLUMN push_service_url TEXT NOT NULL DEFAULT ''"),
            ("is_bot", "ALTER TABLE members ADD COLUMN is_bot INTEGER NOT NULL DEFAULT 0"),
            ("master_pubkey", "ALTER TABLE members ADD COLUMN master_pubkey BLOB NOT NULL DEFAULT X''"),
        ] {
            if !self.column_exists("members", col).await? {
                sqlx::query(ddl).execute(&self.pool).await?;
            }
        }
        for (col, ddl) in [
            ("edited", "ALTER TABLE messages ADD COLUMN edited INTEGER NOT NULL DEFAULT 0"),
            ("deleted", "ALTER TABLE messages ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0"),
            ("mentions", "ALTER TABLE messages ADD COLUMN mentions TEXT NOT NULL DEFAULT ''"),
            ("reply_to", "ALTER TABLE messages ADD COLUMN reply_to TEXT NOT NULL DEFAULT ''"),
            ("attachment_json", "ALTER TABLE messages ADD COLUMN attachment_json TEXT NOT NULL DEFAULT ''"),
        ] {
            if !self.column_exists("messages", col).await? {
                sqlx::query(ddl).execute(&self.pool).await?;
            }
        }
        for (col, ddl) in [
            ("topic_type", "ALTER TABLE topics ADD COLUMN topic_type INTEGER NOT NULL DEFAULT 0"),
            ("permission", "ALTER TABLE topics ADD COLUMN permission INTEGER NOT NULL DEFAULT 0"),
        ] {
            if !self.column_exists("topics", col).await? {
                sqlx::query(ddl).execute(&self.pool).await?;
            }
        }

        Ok(())
    }

    /// 检查表是否存在某列（用于无损迁移）。
    async fn column_exists(&self, table: &str, column: &str) -> Result<bool, StorageError> {
        let sql = format!("PRAGMA table_info({})", table);
        let rows = sqlx::query(&sql).fetch_all(&self.pool).await?;
        Ok(rows.iter().any(|r| {
            let name: String = r.get("name");
            name == column
        }))
    }
}

#[async_trait]
impl Storage for SqliteStorage {
    async fn append_message(&self, msg: &StoredMessage) -> Result<u64, StorageError> {
        // 先查幂等：若 (author_id, msg_id) 已存在，返回重复。
        let existing: Option<i64> = sqlx::query_scalar(
            "SELECT seq FROM messages WHERE author_id = ? AND msg_id = ?",
        )
        .bind(&msg.author_id)
        .bind(&msg.msg_id)
        .fetch_optional(&self.pool)
        .await?;

        if existing.is_some() {
            return Err(StorageError::DuplicateMessage);
        }

        let result = sqlx::query(
            r#"
            INSERT INTO messages
                (topic_id, msg_id, author_id, device_id, author_name, server_ts,
                 content_text, edited, deleted, mentions, reply_to, attachment_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&msg.topic_id)
        .bind(&msg.msg_id)
        .bind(&msg.author_id)
        .bind(&msg.device_id)
        .bind(&msg.author_name)
        .bind(msg.server_ts)
        .bind(&msg.content_text)
        .bind(msg.edited as i64)
        .bind(msg.deleted as i64)
        .bind(&msg.mentions)
        .bind(&msg.reply_to)
        .bind(&msg.attachment_json)
        .execute(&self.pool)
        .await?;

        Ok(result.last_insert_rowid() as u64)
    }

    async fn get_messages_since(
        &self,
        topic_id: &str,
        after_seq: u64,
        limit: u32,
    ) -> Result<Vec<StoredMessage>, StorageError> {
        let rows = sqlx::query(
            r#"
            SELECT seq, topic_id, msg_id, author_id, device_id, author_name, server_ts,
                   content_text, edited, deleted, mentions, reply_to, attachment_json
            FROM messages
            WHERE topic_id = ? AND seq > ?
            ORDER BY seq ASC
            LIMIT ?
            "#,
        )
        .bind(topic_id)
        .bind(after_seq as i64)
        .bind(limit as i64)
        .fetch_all(&self.pool)
        .await?;

        Ok(rows.into_iter().map(row_to_message).collect())
    }

    async fn get_messages_before(
        &self,
        topic_id: &str,
        before_seq: u64,
        limit: u32,
    ) -> Result<Vec<StoredMessage>, StorageError> {
        let rows = sqlx::query(
            r#"
            SELECT seq, topic_id, msg_id, author_id, device_id, author_name, server_ts,
                   content_text, edited, deleted, mentions, reply_to, attachment_json
            FROM messages
            WHERE topic_id = ? AND seq < ?
            ORDER BY seq DESC
            LIMIT ?
            "#,
        )
        .bind(topic_id)
        .bind(before_seq as i64)
        .bind(limit as i64)
        .fetch_all(&self.pool)
        .await?;

        // 转为升序返回（保持展示顺序一致）
        let mut msgs: Vec<StoredMessage> = rows.into_iter().map(row_to_message).collect();
        msgs.reverse();
        Ok(msgs)
    }

    async fn latest_seq(&self, topic_id: &str) -> Result<u64, StorageError> {
        let seq: Option<i64> = sqlx::query_scalar(
            "SELECT MAX(seq) FROM messages WHERE topic_id = ?",
        )
        .bind(topic_id)
        .fetch_one(&self.pool)
        .await?;

        Ok(seq.unwrap_or(0) as u64)
    }

    async fn get_message_by_id(
        &self,
        topic_id: &str,
        msg_id: &str,
    ) -> Result<Option<StoredMessage>, StorageError> {
        let row = sqlx::query(
            r#"
            SELECT seq, topic_id, msg_id, author_id, device_id, author_name, server_ts,
                   content_text, edited, deleted, mentions, reply_to, attachment_json
            FROM messages
            WHERE topic_id = ? AND msg_id = ?
            ORDER BY seq DESC LIMIT 1
            "#,
        )
        .bind(topic_id)
        .bind(msg_id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(row_to_message))
    }

    async fn edit_message(
        &self,
        topic_id: &str,
        msg_id: &str,
        new_text: &str,
    ) -> Result<StoredMessage, StorageError> {
        let existing = self
            .get_message_by_id(topic_id, msg_id)
            .await?
            .ok_or(StorageError::NotFound)?;
        if existing.deleted {
            return Err(StorageError::NotFound);
        }

        let mut tx = self.pool.begin().await?;
        sqlx::query("DELETE FROM messages WHERE topic_id = ? AND msg_id = ?")
            .bind(topic_id)
            .bind(msg_id)
            .execute(&mut *tx)
            .await?;

        let edited_row = StoredMessage {
            seq: 0,
            topic_id: existing.topic_id.clone(),
            msg_id: existing.msg_id.clone(),
            author_id: existing.author_id.clone(),
            device_id: existing.device_id.clone(),
            author_name: existing.author_name.clone(),
            server_ts: lonisle_core::device::current_unix_time(),
            content_text: new_text.to_string(),
            edited: true,
            deleted: false,
            mentions: existing.mentions.clone(),
            reply_to: existing.reply_to.clone(),
            attachment_json: existing.attachment_json.clone(),
        };
        let seq = insert_message_tx(&mut tx, &edited_row).await?;
        tx.commit().await?;

        Ok(StoredMessage { seq, ..edited_row })
    }

    async fn delete_message(
        &self,
        topic_id: &str,
        msg_id: &str,
    ) -> Result<StoredMessage, StorageError> {
        let existing = self
            .get_message_by_id(topic_id, msg_id)
            .await?
            .ok_or(StorageError::NotFound)?;

        let mut tx = self.pool.begin().await?;
        // 硬删原行（F-MSG-14：服务端硬删除）
        sqlx::query("DELETE FROM messages WHERE topic_id = ? AND msg_id = ?")
            .bind(topic_id)
            .bind(msg_id)
            .execute(&mut *tx)
            .await?;
        // 删除该消息的提及已读记录
        sqlx::query("DELETE FROM mention_reads WHERE msg_id = ?")
            .bind(msg_id)
            .execute(&mut *tx)
            .await?;

        // 新序号删除事件行（F-MSG-13/14：仅保留"该序号处存在删除事件"的记录）
        let tombstone = StoredMessage {
            seq: 0,
            topic_id: existing.topic_id.clone(),
            msg_id: existing.msg_id.clone(),
            author_id: existing.author_id.clone(),
            device_id: existing.device_id.clone(),
            author_name: existing.author_name.clone(),
            server_ts: lonisle_core::device::current_unix_time(),
            content_text: String::new(),
            edited: false,
            deleted: true,
            mentions: String::new(),
            reply_to: String::new(),
            attachment_json: String::new(),
        };
        let seq = insert_message_tx(&mut tx, &tombstone).await?;
        tx.commit().await?;

        Ok(StoredMessage { seq, ..tombstone })
    }

    async fn upsert_member(&self, member: &Member) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            INSERT INTO members (user_id, display_name, avatar_seed, role, muted, banned,
                                 server_nickname, server_avatar, push_service_url, is_bot, joined_at, master_pubkey)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                display_name = excluded.display_name,
                avatar_seed = excluded.avatar_seed,
                push_service_url = excluded.push_service_url,
                is_bot = excluded.is_bot,
                joined_at = excluded.joined_at,
                master_pubkey = CASE WHEN length(excluded.master_pubkey) = 32
                                     THEN excluded.master_pubkey
                                     ELSE members.master_pubkey END
            "#,
        )
        .bind(&member.user_id)
        .bind(&member.display_name)
        .bind(&member.avatar_seed)
        .bind(member.role.as_i64())
        .bind(member.muted as i64)
        .bind(member.banned as i64)
        .bind(&member.server_nickname)
        .bind(&member.server_avatar)
        .bind(&member.push_service_url)
        .bind(member.is_bot as i64)
        .bind(member.joined_at)
        .bind(&member.master_pubkey)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn list_members(&self) -> Result<Vec<Member>, StorageError> {
        let rows = sqlx::query(
            "SELECT user_id, display_name, avatar_seed, role, muted, banned, server_nickname, server_avatar, push_service_url, is_bot, joined_at, master_pubkey FROM members ORDER BY joined_at ASC",
        )
        .fetch_all(&self.pool)
        .await?;

        Ok(rows.into_iter().map(row_to_member).collect())
    }

    async fn get_member(&self, user_id: &str) -> Result<Option<Member>, StorageError> {
        let row = sqlx::query(
            "SELECT user_id, display_name, avatar_seed, role, muted, banned, server_nickname, server_avatar, push_service_url, is_bot, joined_at, master_pubkey FROM members WHERE user_id = ?",
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(row_to_member))
    }

    /// 补录成员主公钥（仅在未记录时写入；Hello 握手时调用）。
    async fn set_member_master_pubkey(
        &self,
        user_id: &str,
        master_pubkey: &[u8],
    ) -> Result<(), StorageError> {
        if master_pubkey.len() != 32 {
            return Ok(());
        }
        sqlx::query(
            "UPDATE members SET master_pubkey = ? WHERE user_id = ? AND length(master_pubkey) != 32",
        )
        .bind(master_pubkey)
        .bind(user_id)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn set_member_role(&self, user_id: &str, role: MemberRole) -> Result<(), StorageError> {
        sqlx::query("UPDATE members SET role = ? WHERE user_id = ?")
            .bind(role.as_i64())
            .bind(user_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn set_member_muted(&self, user_id: &str, muted: bool) -> Result<(), StorageError> {
        sqlx::query("UPDATE members SET muted = ? WHERE user_id = ?")
            .bind(muted as i64)
            .bind(user_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn set_member_banned(&self, user_id: &str, banned: bool) -> Result<(), StorageError> {
        sqlx::query("UPDATE members SET banned = ? WHERE user_id = ?")
            .bind(banned as i64)
            .bind(user_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn remove_member(&self, user_id: &str) -> Result<(), StorageError> {
        sqlx::query("DELETE FROM members WHERE user_id = ?")
            .bind(user_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn update_server_profile(
        &self,
        user_id: &str,
        nickname: Option<&str>,
        avatar: Option<&str>,
    ) -> Result<(), StorageError> {
        // 按字段独立更新：None = 不动该列，Some("") = 清除覆盖（存 NULL）。
        // 此前一条 UPDATE 同时写两列，改昵称会清空头像、改头像会清空昵称。
        if let Some(n) = nickname {
            let value = if n.is_empty() { None } else { Some(n) };
            sqlx::query("UPDATE members SET server_nickname = ? WHERE user_id = ?")
                .bind(value)
                .bind(user_id)
                .execute(&self.pool)
                .await?;
        }
        if let Some(a) = avatar {
            let value = if a.is_empty() { None } else { Some(a) };
            sqlx::query("UPDATE members SET server_avatar = ? WHERE user_id = ?")
                .bind(value)
                .bind(user_id)
                .execute(&self.pool)
                .await?;
        }
        Ok(())
    }

    async fn set_server_meta(&self, meta: &ServerMeta) -> Result<(), StorageError> {
        let kv = [
            ("server_id", meta.server_id.clone()),
            ("name", meta.name.clone()),
            ("description", meta.description.clone()),
            ("strategy", meta.strategy.as_i64().to_string()),
            ("migration_target_address", meta.migration_target_address.clone()),
            ("migration_target_fingerprint", meta.migration_target_fingerprint.clone()),
            ("migration_signature", meta.migration_signature.clone()),
            ("rate_limit_per_minute", meta.rate_limit_per_minute.to_string()),
            ("max_attachment_size", meta.max_attachment_size.to_string()),
            ("attachment_quota", meta.attachment_quota.to_string()),
            ("mention_read_enabled", meta.mention_read_enabled.to_string()),
            ("livekit_url", meta.livekit_url.clone()),
            ("livekit_api_key", meta.livekit_api_key.clone()),
            ("livekit_api_secret", meta.livekit_api_secret.clone()),
            ("icon", meta.icon.clone()),
        ];
        for (key, value) in kv {
            sqlx::query(
                "INSERT INTO server_meta (key, value) VALUES (?, ?)
                 ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            )
            .bind(key)
            .bind(value)
            .execute(&self.pool)
            .await?;
        }
        Ok(())
    }

    async fn get_server_meta(&self) -> Result<Option<ServerMeta>, StorageError> {
        let rows = sqlx::query("SELECT key, value FROM server_meta")
            .fetch_all(&self.pool)
            .await?;

        if rows.is_empty() {
            return Ok(None);
        }

        let mut server_id = String::new();
        let mut name = String::new();
        let mut description = String::new();
        let mut strategy = JoinStrategy::Approval;
        let mut migration_target_address = String::new();
        let mut migration_target_fingerprint = String::new();
        let mut migration_signature = String::new();
        let mut rate_limit_per_minute = 0u32;
        let mut max_attachment_size = 0u64;
        let mut attachment_quota = 0u64;
        let mut mention_read_enabled = false;
        let mut livekit_url = String::new();
        let mut livekit_api_key = String::new();
        let mut livekit_api_secret = String::new();
        let mut icon = String::new();
        for r in rows {
            let key: String = r.get("key");
            let value: String = r.get("value");
            match key.as_str() {
                "server_id" => server_id = value,
                "name" => name = value,
                "description" => description = value,
                "strategy" => {
                    strategy = JoinStrategy::from_i64(value.parse().unwrap_or(0))
                }
                "migration_target_address" => migration_target_address = value,
                "migration_target_fingerprint" => migration_target_fingerprint = value,
                "migration_signature" => migration_signature = value,
                "rate_limit_per_minute" => {
                    rate_limit_per_minute = value.parse().unwrap_or(0)
                }
                "max_attachment_size" => {
                    max_attachment_size = value.parse().unwrap_or(0)
                }
                "attachment_quota" => {
                    attachment_quota = value.parse().unwrap_or(0)
                }
                "mention_read_enabled" => {
                    mention_read_enabled = value.parse().unwrap_or(false)
                }
                "livekit_url" => livekit_url = value,
                "livekit_api_key" => livekit_api_key = value,
                "livekit_api_secret" => livekit_api_secret = value,
                "icon" => icon = value,
                _ => {}
            }
        }

        Ok(Some(ServerMeta {
            server_id,
            name,
            description,
            strategy,
            migration_target_address,
            migration_target_fingerprint,
            migration_signature,
            rate_limit_per_minute,
            max_attachment_size,
            attachment_quota,
            mention_read_enabled,
            livekit_url,
            livekit_api_key,
            livekit_api_secret,
            icon,
        }))
    }

    async fn get_tls_config(&self) -> Result<(String, String), StorageError> {
        let rows = sqlx::query(
            "SELECT key, value FROM server_meta WHERE key IN ('tls_cert_path','tls_key_path')",
        )
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
        for (key, value) in kv {
            sqlx::query(
                "INSERT INTO server_meta (key, value) VALUES (?, ?)
                 ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            )
            .bind(key)
            .bind(value)
            .execute(&self.pool)
            .await?;
        }
        Ok(())
    }

    async fn set_owner_claim_hash(&self, hash: &str) -> Result<(), StorageError> {
        sqlx::query(
            "INSERT INTO server_meta (key, value) VALUES ('owner_claim_hash', ?)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        )
        .bind(hash)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn get_owner_claim_hash(&self) -> Result<Option<String>, StorageError> {
        let row = sqlx::query("SELECT value FROM server_meta WHERE key = 'owner_claim_hash'")
            .fetch_optional(&self.pool)
            .await?;
        Ok(row.map(|r| r.get("value")))
    }

    // ---- 邀请令牌（F-JOIN-5） ----

    async fn create_invite(&self, created_by: &str) -> Result<String, StorageError> {
        // 令牌 128bit 随机（不可猜测）
        let mut bytes = [0u8; 16];
        use rand::RngCore;
        rand::rngs::OsRng.fill_bytes(&mut bytes);
        let token = bytes.iter().map(|b| format!("{b:02x}")).collect::<String>();
        sqlx::query(
            "INSERT INTO invite_tokens (token, created_by, created_at, revoked) VALUES (?, ?, ?, 0)",
        )
        .bind(&token)
        .bind(created_by)
        .bind(lonisle_core::device::current_unix_time())
        .execute(&self.pool)
        .await?;
        Ok(token)
    }

    async fn list_invites(&self) -> Result<Vec<InviteTokenRecord>, StorageError> {
        let rows = sqlx::query(
            "SELECT token, created_by, created_at, used_at, revoked FROM invite_tokens ORDER BY created_at DESC",
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(rows
            .into_iter()
            .map(|r| InviteTokenRecord {
                token: r.get("token"),
                created_by: r.get("created_by"),
                created_at: r.get("created_at"),
                used: r.get::<Option<i64>, _>("used_at").is_some(),
                revoked: r.get::<i64, _>("revoked") != 0,
            })
            .collect())
    }

    async fn revoke_invite(&self, token: &str) -> Result<(), StorageError> {
        sqlx::query("UPDATE invite_tokens SET revoked = 1 WHERE token = ?")
            .bind(token)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn consume_invite(&self, token: &str) -> Result<bool, StorageError> {
        let result = sqlx::query(
            "UPDATE invite_tokens SET used_at = ? WHERE token = ? AND used_at IS NULL AND revoked = 0",
        )
        .bind(lonisle_core::device::current_unix_time())
        .bind(token)
        .execute(&self.pool)
        .await?;
        Ok(result.rows_affected() == 1)
    }

    // ---- Bot（F-BOT） ----

    async fn create_bot(
        &self,
        bot_id: &str,
        name: &str,
        token_hash: &str,
    ) -> Result<(), StorageError> {
        sqlx::query(
            "INSERT INTO bots (bot_id, name, token_hash, events, created_at, revoked) VALUES (?, ?, ?, '', ?, 0)",
        )
        .bind(bot_id)
        .bind(name)
        .bind(token_hash)
        .bind(lonisle_core::device::current_unix_time())
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn find_bot_by_token(&self, token_hash: &str) -> Result<Option<BotRecord>, StorageError> {
        let row = sqlx::query(
            "SELECT * FROM bots WHERE token_hash = ? AND revoked = 0",
        )
        .bind(token_hash)
        .fetch_optional(&self.pool)
        .await?;
        Ok(row.map(row_to_bot))
    }

    async fn list_bots(&self) -> Result<Vec<BotRecord>, StorageError> {
        let rows = sqlx::query("SELECT * FROM bots ORDER BY created_at DESC")
            .fetch_all(&self.pool)
            .await?;
        Ok(rows.into_iter().map(row_to_bot).collect())
    }

    async fn revoke_bot(&self, bot_id: &str) -> Result<(), StorageError> {
        sqlx::query("UPDATE bots SET revoked = 1 WHERE bot_id = ?")
            .bind(bot_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn set_bot_events(&self, bot_id: &str, events: &str) -> Result<(), StorageError> {
        sqlx::query("UPDATE bots SET events = ? WHERE bot_id = ?")
            .bind(events)
            .bind(bot_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn clear_owner_claim_hash(&self) -> Result<(), StorageError> {
        sqlx::query("DELETE FROM server_meta WHERE key = 'owner_claim_hash'")
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn ensure_topic(
        &self,
        topic_id: &str,
        name: &str,
        description: &str,
    ) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            INSERT INTO topics (topic_id, name, description, topic_type, permission, sort_order)
            VALUES (?, ?, ?, 0, 0, 0)
            ON CONFLICT(topic_id) DO NOTHING
            "#,
        )
        .bind(topic_id)
        .bind(name)
        .bind(description)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn create_topic(&self, topic: &Topic) -> Result<(), StorageError> {
        // sort_order 取当前最大值 + 1
        let max_order: Option<i64> =
            sqlx::query_scalar("SELECT MAX(sort_order) FROM topics").fetch_one(&self.pool).await?;
        let sort_order = max_order.unwrap_or(-1) + 1;

        sqlx::query(
            r#"
            INSERT INTO topics (topic_id, name, description, topic_type, permission, sort_order, push_enabled)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&topic.topic_id)
        .bind(&topic.name)
        .bind(&topic.description)
        .bind(topic.topic_type.as_i64())
        .bind(topic.permission.as_i64())
        .bind(sort_order)
        .bind(topic.push_enabled as i64)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn update_topic(&self, topic: &Topic) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            UPDATE topics SET name = ?, description = ?, topic_type = ?, permission = ?, push_enabled = ?
            WHERE topic_id = ?
            "#,
        )
        .bind(&topic.name)
        .bind(&topic.description)
        .bind(topic.topic_type.as_i64())
        .bind(topic.permission.as_i64())
        .bind(topic.push_enabled as i64)
        .bind(&topic.topic_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn delete_topic(&self, topic_id: &str) -> Result<(), StorageError> {
        sqlx::query("DELETE FROM topics WHERE topic_id = ?")
            .bind(topic_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn reorder_topics(&self, topic_ids: &[String]) -> Result<(), StorageError> {
        for (i, id) in topic_ids.iter().enumerate() {
            sqlx::query("UPDATE topics SET sort_order = ? WHERE topic_id = ?")
                .bind(i as i64)
                .bind(id)
                .execute(&self.pool)
                .await?;
        }
        Ok(())
    }

    async fn list_topics(&self) -> Result<Vec<Topic>, StorageError> {
        let rows = sqlx::query(
            "SELECT topic_id, name, description, topic_type, permission, sort_order, push_enabled FROM topics ORDER BY sort_order ASC",
        )
        .fetch_all(&self.pool)
        .await?;

        Ok(rows.into_iter().map(row_to_topic).collect())
    }

    async fn get_topic(&self, topic_id: &str) -> Result<Option<Topic>, StorageError> {
        let row = sqlx::query(
            "SELECT topic_id, name, description, topic_type, permission, sort_order, push_enabled FROM topics WHERE topic_id = ?",
        )
        .bind(topic_id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(row_to_topic))
    }

    async fn create_join_request(&self, req: &JoinRequest) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            INSERT INTO join_requests (request_id, user_id, display_name, reason, push_service_url, status, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&req.request_id)
        .bind(&req.user_id)
        .bind(&req.display_name)
        .bind(&req.reason)
        .bind(&req.push_service_url)
        .bind(req.status.as_i64())
        .bind(req.created_at)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn get_pending_request(&self, user_id: &str) -> Result<Option<JoinRequest>, StorageError> {
        let row = sqlx::query(
            "SELECT request_id, user_id, display_name, reason, push_service_url, status, created_at FROM join_requests WHERE user_id = ? AND status = 0 ORDER BY created_at DESC LIMIT 1",
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(row_to_join_request))
    }

    async fn list_join_requests(&self) -> Result<Vec<JoinRequest>, StorageError> {
        let rows = sqlx::query(
            "SELECT request_id, user_id, display_name, reason, push_service_url, status, created_at FROM join_requests WHERE status = 0 ORDER BY created_at ASC",
        )
        .fetch_all(&self.pool)
        .await?;

        Ok(rows.into_iter().map(row_to_join_request).collect())
    }

    async fn set_join_request_status(
        &self,
        request_id: &str,
        status: JoinStatus,
    ) -> Result<(), StorageError> {
        sqlx::query("UPDATE join_requests SET status = ? WHERE request_id = ?")
            .bind(status.as_i64())
            .bind(request_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn get_join_request(&self, request_id: &str) -> Result<Option<JoinRequest>, StorageError> {
        let row = sqlx::query(
            "SELECT request_id, user_id, display_name, reason, push_service_url, status, created_at FROM join_requests WHERE request_id = ?",
        )
        .bind(request_id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(row_to_join_request))
    }

    // ---- 多设备（M3） ----

    async fn upsert_device(&self, device: &DeviceRecord) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            INSERT INTO devices (user_id, device_id, device_name, platform, pubkey, last_active)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(user_id, device_id) DO UPDATE SET
                device_name = excluded.device_name,
                platform = excluded.platform,
                pubkey = excluded.pubkey,
                last_active = excluded.last_active
            "#,
        )
        .bind(&device.user_id)
        .bind(&device.device_id)
        .bind(&device.device_name)
        .bind(&device.platform)
        .bind(&device.pubkey)
        .bind(device.last_active)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn list_devices(&self, user_id: &str) -> Result<Vec<DeviceRecord>, StorageError> {
        let rows = sqlx::query(
            "SELECT user_id, device_id, device_name, platform, pubkey, last_active FROM devices WHERE user_id = ? ORDER BY last_active DESC",
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?;
        Ok(rows.into_iter().map(row_to_device).collect())
    }

    async fn get_device(
        &self,
        user_id: &str,
        device_id: &str,
    ) -> Result<Option<DeviceRecord>, StorageError> {
        let row = sqlx::query(
            "SELECT user_id, device_id, device_name, platform, pubkey, last_active FROM devices WHERE user_id = ? AND device_id = ?",
        )
        .bind(user_id)
        .bind(device_id)
        .fetch_optional(&self.pool)
        .await?;
        Ok(row.map(row_to_device))
    }

    async fn remove_device(&self, user_id: &str, device_id: &str) -> Result<(), StorageError> {
        sqlx::query("DELETE FROM devices WHERE user_id = ? AND device_id = ?")
            .bind(user_id)
            .bind(device_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn touch_device(&self, user_id: &str, device_id: &str) -> Result<(), StorageError> {
        sqlx::query(
            "UPDATE devices SET last_active = ? WHERE user_id = ? AND device_id = ?",
        )
        .bind(lonisle_core::device::current_unix_time())
        .bind(user_id)
        .bind(device_id)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn add_revocation(
        &self,
        user_id: &str,
        device_pubkey: &[u8],
        revoked_at: i64,
    ) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            INSERT INTO revocations (user_id, device_pubkey, revoked_at)
            VALUES (?, ?, ?)
            ON CONFLICT(user_id, device_pubkey) DO NOTHING
            "#,
        )
        .bind(user_id)
        .bind(device_pubkey)
        .bind(revoked_at)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn is_revoked(&self, user_id: &str, device_pubkey: &[u8]) -> Result<bool, StorageError> {
        let count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM revocations WHERE user_id = ? AND device_pubkey = ?",
        )
        .bind(user_id)
        .bind(device_pubkey)
        .fetch_one(&self.pool)
        .await?;
        Ok(count > 0)
    }

    // ---- 附件（M5） ----

    async fn insert_attachment(&self, att: &AttachmentRecord) -> Result<(), StorageError> {
        sqlx::query(
            r#"
            INSERT INTO attachments (attachment_id, msg_id, kind, size, mime, path,
                                     thumbnail_path, width, height, duration, author_id, created_at, filename)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )
        .bind(&att.attachment_id)
        .bind(&att.msg_id)
        .bind(&att.kind)
        .bind(att.size as i64)
        .bind(&att.mime)
        .bind(&att.path)
        .bind(&att.thumbnail_path)
        .bind(att.width as i64)
        .bind(att.height as i64)
        .bind(att.duration as i64)
        .bind(&att.author_id)
        .bind(att.created_at)
        .bind(&att.filename)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn get_attachment(&self, attachment_id: &str) -> Result<Option<AttachmentRecord>, StorageError> {
        let row = sqlx::query(
            "SELECT attachment_id, msg_id, kind, size, mime, path, thumbnail_path, width, height, duration, author_id, created_at, filename FROM attachments WHERE attachment_id = ?",
        )
        .bind(attachment_id)
        .fetch_optional(&self.pool)
        .await?;
        Ok(row.map(row_to_attachment))
    }

    async fn list_attachments_for_message(&self, msg_id: &str) -> Result<Vec<AttachmentRecord>, StorageError> {
        let rows = sqlx::query(
            "SELECT attachment_id, msg_id, kind, size, mime, path, thumbnail_path, width, height, duration, author_id, created_at, filename FROM attachments WHERE msg_id = ?",
        )
        .bind(msg_id)
        .fetch_all(&self.pool)
        .await?;
        Ok(rows.into_iter().map(row_to_attachment).collect())
    }

    async fn delete_attachment(&self, attachment_id: &str) -> Result<(), StorageError> {
        sqlx::query("DELETE FROM attachments WHERE attachment_id = ?")
            .bind(attachment_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn delete_attachments_for_message(&self, msg_id: &str) -> Result<Vec<AttachmentRecord>, StorageError> {
        let records = self.list_attachments_for_message(msg_id).await?;
        sqlx::query("DELETE FROM attachments WHERE msg_id = ?")
            .bind(msg_id)
            .execute(&self.pool)
            .await?;
        Ok(records)
    }

    async fn total_attachment_size(&self, user_id: &str) -> Result<u64, StorageError> {
        let total: i64 = sqlx::query_scalar(
            "SELECT COALESCE(SUM(size), 0) FROM attachments WHERE author_id = ?",
        )
        .bind(user_id)
        .fetch_one(&self.pool)
        .await?;
        Ok(total as u64)
    }

    async fn list_all_attachments(&self) -> Result<Vec<AttachmentRecord>, StorageError> {
        let rows = sqlx::query("SELECT * FROM attachments ORDER BY created_at ASC")
            .fetch_all(&self.pool)
            .await?;
        Ok(rows.into_iter().map(row_to_attachment).collect())
    }

    // ---- Reaction（M5） ----

    async fn add_reaction(
        &self,
        topic_id: &str,
        msg_id: &str,
        user_id: &str,
        emoji: &str,
    ) -> Result<(), StorageError> {
        sqlx::query(
            "INSERT OR IGNORE INTO reactions (topic_id, msg_id, user_id, emoji) VALUES (?, ?, ?, ?)",
        )
        .bind(topic_id)
        .bind(msg_id)
        .bind(user_id)
        .bind(emoji)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn remove_reaction(
        &self,
        _topic_id: &str,
        msg_id: &str,
        user_id: &str,
        emoji: &str,
    ) -> Result<(), StorageError> {
        sqlx::query("DELETE FROM reactions WHERE msg_id = ? AND user_id = ? AND emoji = ?")
            .bind(msg_id)
            .bind(user_id)
            .bind(emoji)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn get_reactions(&self, msg_id: &str) -> Result<Vec<(String, Vec<String>)>, StorageError> {
        let rows = sqlx::query(
            "SELECT emoji, user_id FROM reactions WHERE msg_id = ? ORDER BY emoji",
        )
        .bind(msg_id)
        .fetch_all(&self.pool)
        .await?;

        let mut map: std::collections::BTreeMap<String, Vec<String>> = std::collections::BTreeMap::new();
        for row in rows {
            let emoji: String = row.get("emoji");
            let user_id: String = row.get("user_id");
            map.entry(emoji).or_default().push(user_id);
        }
        Ok(map.into_iter().collect())
    }

    // ---- 预密钥（M6 E2EE） ----

    async fn upload_pre_keys(
        &self,
        user_id: &str,
        identity_key: &[u8],
        signed_pre_key: &[u8],
        signed_pre_key_sig: &[u8],
        one_time_pre_keys: &[Vec<u8>],
    ) -> Result<(), StorageError> {
        // 先删除旧预密钥
        sqlx::query("DELETE FROM pre_keys WHERE user_id = ?")
            .bind(user_id)
            .execute(&self.pool)
            .await?;

        for opk in one_time_pre_keys {
            sqlx::query(
                "INSERT INTO pre_keys (user_id, identity_key, signed_pre_key, signed_pre_key_sig, one_time_pre_key) VALUES (?, ?, ?, ?, ?)",
            )
            .bind(user_id)
            .bind(identity_key)
            .bind(signed_pre_key)
            .bind(signed_pre_key_sig)
            .bind(opk)
            .execute(&self.pool)
            .await?;
        }
        Ok(())
    }

    async fn fetch_pre_keys(
        &self,
        user_id: &str,
    ) -> Result<Option<(Vec<u8>, Vec<u8>, Vec<u8>, Vec<u8>)>, StorageError> {
        // 取一个 OPK（任意）
        let row = sqlx::query(
            "SELECT identity_key, signed_pre_key, signed_pre_key_sig, one_time_pre_key FROM pre_keys WHERE user_id = ? AND one_time_pre_key IS NOT NULL LIMIT 1",
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?;

        if let Some(r) = row {
            let identity_key: Vec<u8> = r.get("identity_key");
            let signed_pre_key: Vec<u8> = r.get("signed_pre_key");
            let signed_pre_key_sig: Vec<u8> = r.get("signed_pre_key_sig");
            let opk: Vec<u8> = r.get("one_time_pre_key");
            // 删除已使用的 OPK
            sqlx::query("DELETE FROM pre_keys WHERE user_id = ? AND one_time_pre_key = ?")
                .bind(user_id)
                .bind(&opk)
                .execute(&self.pool)
                .await?;
            Ok(Some((identity_key, signed_pre_key, signed_pre_key_sig, opk)))
        } else {
            Ok(None)
        }
    }

    // ---- RBAC 自定义角色（P2） ----

    async fn upsert_role(&self, role: &RoleInfo) -> Result<(), StorageError> {
        sqlx::query(
            "INSERT INTO roles (role_id, name, permissions) VALUES (?, ?, ?) ON CONFLICT(role_id) DO UPDATE SET name = excluded.name, permissions = excluded.permissions",
        )
        .bind(&role.role_id)
        .bind(&role.name)
        .bind(role.permissions as i64)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn delete_role(&self, role_id: &str) -> Result<(), StorageError> {
        sqlx::query("DELETE FROM roles WHERE role_id = ?")
            .bind(role_id)
            .execute(&self.pool)
            .await?;
        // 清理关联
        sqlx::query("DELETE FROM member_roles WHERE role_id = ?")
            .bind(role_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn list_roles(&self) -> Result<Vec<RoleInfo>, StorageError> {
        let rows = sqlx::query("SELECT role_id, name, permissions FROM roles ORDER BY role_id")
            .fetch_all(&self.pool)
            .await?;
        Ok(rows.into_iter().map(row_to_role).collect())
    }

    async fn get_role_permissions(&self, role_id: &str) -> Result<Option<u32>, StorageError> {
        let permissions: Option<i64> = sqlx::query_scalar(
            "SELECT permissions FROM roles WHERE role_id = ?",
        )
        .bind(role_id)
        .fetch_optional(&self.pool)
        .await?;
        Ok(permissions.map(|p| p as u32))
    }

    async fn assign_role(&self, user_id: &str, role_id: &str) -> Result<(), StorageError> {
        sqlx::query("INSERT OR IGNORE INTO member_roles (user_id, role_id) VALUES (?, ?)")
            .bind(user_id)
            .bind(role_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn unassign_role(&self, user_id: &str, role_id: &str) -> Result<(), StorageError> {
        sqlx::query("DELETE FROM member_roles WHERE user_id = ? AND role_id = ?")
            .bind(user_id)
            .bind(role_id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    async fn get_member_permissions(&self, user_id: &str) -> Result<u32, StorageError> {
        let rows = sqlx::query(
            "SELECT r.permissions FROM member_roles mr JOIN roles r ON mr.role_id = r.role_id WHERE mr.user_id = ?",
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?;
        let mut perms: u32 = 0;
        for row in rows {
            let p: i64 = row.get("permissions");
            perms |= p as u32;
        }
        Ok(perms)
    }

    // ---- @提及已读回执（P2） ----

    async fn mark_mention_read(&self, msg_id: &str, user_id: &str) -> Result<(), StorageError> {
        sqlx::query(
            "INSERT OR IGNORE INTO mention_reads (msg_id, user_id, read_at) VALUES (?, ?, ?)",
        )
        .bind(msg_id)
        .bind(user_id)
        .bind(lonisle_core::device::current_unix_time())
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    async fn list_mention_reads(&self, msg_id: &str) -> Result<Vec<String>, StorageError> {
        let rows = sqlx::query(
            "SELECT user_id FROM mention_reads WHERE msg_id = ? ORDER BY read_at ASC",
        )
        .bind(msg_id)
        .fetch_all(&self.pool)
        .await?;
        Ok(rows.into_iter().map(|r| r.get("user_id")).collect())
    }

    // ---- 数据导出/清除（P1） ----

    async fn list_all_messages(&self) -> Result<Vec<StoredMessage>, StorageError> {
        let rows = sqlx::query(
            "SELECT seq, topic_id, msg_id, author_id, device_id, author_name, server_ts, content_text, edited, deleted, mentions, reply_to, attachment_json FROM messages ORDER BY seq ASC",
        )
        .fetch_all(&self.pool)
        .await?;
        Ok(rows.into_iter().map(row_to_message).collect())
    }

    async fn delete_messages_by_topic(&self, topic_id: &str) -> Result<Vec<StoredMessage>, StorageError> {
        let rows = sqlx::query(
            "SELECT seq, topic_id, msg_id, author_id, device_id, author_name, server_ts, content_text, edited, deleted, mentions, reply_to, attachment_json FROM messages WHERE topic_id = ?",
        )
        .bind(topic_id)
        .fetch_all(&self.pool)
        .await?;
        let records: Vec<StoredMessage> = rows.into_iter().map(row_to_message).collect();

        sqlx::query("DELETE FROM messages WHERE topic_id = ?")
            .bind(topic_id)
            .execute(&self.pool)
            .await?;
        Ok(records)
    }

    async fn delete_messages_in_range(&self, start: i64, end: i64) -> Result<Vec<StoredMessage>, StorageError> {
        let rows = sqlx::query(
            "SELECT seq, topic_id, msg_id, author_id, device_id, author_name, server_ts, content_text, edited, deleted, mentions, reply_to, attachment_json FROM messages WHERE server_ts >= ? AND server_ts <= ?",
        )
        .bind(start)
        .bind(end)
        .fetch_all(&self.pool)
        .await?;
        let records: Vec<StoredMessage> = rows.into_iter().map(row_to_message).collect();

        sqlx::query("DELETE FROM messages WHERE server_ts >= ? AND server_ts <= ?")
            .bind(start)
            .bind(end)
            .execute(&self.pool)
            .await?;
        Ok(records)
    }

    async fn delete_messages_by_user(&self, user_id: &str) -> Result<Vec<StoredMessage>, StorageError> {
        let rows = sqlx::query(
            "SELECT seq, topic_id, msg_id, author_id, device_id, author_name, server_ts, content_text, edited, deleted, mentions, reply_to, attachment_json FROM messages WHERE author_id = ?",
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?;
        let records: Vec<StoredMessage> = rows.into_iter().map(row_to_message).collect();

        sqlx::query("DELETE FROM messages WHERE author_id = ?")
            .bind(user_id)
            .execute(&self.pool)
            .await?;
        Ok(records)
    }

    async fn clear_all_messages(&self) -> Result<Vec<StoredMessage>, StorageError> {
        let records = self.list_all_messages().await?;
        sqlx::query("DELETE FROM messages")
            .execute(&self.pool)
            .await?;
        Ok(records)
    }
}

// ---- 行映射辅助 ----

fn row_to_device(r: sqlx::sqlite::SqliteRow) -> DeviceRecord {
    DeviceRecord {
        user_id: r.get("user_id"),
        device_id: r.get("device_id"),
        device_name: r.get("device_name"),
        platform: r.get("platform"),
        pubkey: r.get("pubkey"),
        last_active: r.get("last_active"),
    }
}

fn row_to_attachment(r: sqlx::sqlite::SqliteRow) -> AttachmentRecord {
    AttachmentRecord {
        attachment_id: r.get("attachment_id"),
        msg_id: r.get("msg_id"),
        kind: r.get("kind"),
        size: r.get::<i64, _>("size") as u64,
        mime: r.get("mime"),
        path: r.get("path"),
        thumbnail_path: r.get("thumbnail_path"),
        width: r.get::<i64, _>("width") as u32,
        height: r.get::<i64, _>("height") as u32,
        duration: r.get::<i64, _>("duration") as u32,
        author_id: r.get("author_id"),
        created_at: r.get("created_at"),
        filename: r.get("filename"),
    }
}

fn row_to_role(r: sqlx::sqlite::SqliteRow) -> RoleInfo {
    RoleInfo {
        role_id: r.get("role_id"),
        name: r.get("name"),
        permissions: r.get::<i64, _>("permissions") as u32,
    }
}

/// 事务内插入消息行（编辑/删除事件复用，分配新序号）。
async fn insert_message_tx(
    tx: &mut sqlx::sqlite::SqliteConnection,
    msg: &StoredMessage,
) -> Result<u64, StorageError> {
    let result = sqlx::query(
        r#"
        INSERT INTO messages
            (topic_id, msg_id, author_id, device_id, author_name, server_ts,
             content_text, edited, deleted, mentions, reply_to, attachment_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        "#,
    )
    .bind(&msg.topic_id)
    .bind(&msg.msg_id)
    .bind(&msg.author_id)
    .bind(&msg.device_id)
    .bind(&msg.author_name)
    .bind(msg.server_ts)
    .bind(&msg.content_text)
    .bind(msg.edited as i64)
    .bind(msg.deleted as i64)
    .bind(&msg.mentions)
    .bind(&msg.reply_to)
    .bind(&msg.attachment_json)
    .execute(&mut *tx)
    .await?;
    Ok(result.last_insert_rowid() as u64)
}

/// 附件元数据 JSON 序列化/反序列化（proto::Attachment ↔ JSON 列，F-MEDIA-8）。
pub fn attachment_to_json(a: &lonisle_core::proto::Attachment) -> String {
    serde_json::json!({
        "id": a.attachment_id,
        "kind": a.kind,
        "size": a.size,
        "mime": a.mime,
        "width": a.width,
        "height": a.height,
        "duration": a.duration,
        "thumbnail_id": a.thumbnail_id,
        "filename": a.filename,
    })
    .to_string()
}

/// 从 JSON 列还原附件元数据（空串/损坏返回 None）。
pub fn attachment_from_json(s: &str) -> Option<lonisle_core::proto::Attachment> {
    if s.is_empty() {
        return None;
    }
    let v: serde_json::Value = serde_json::from_str(s).ok()?;
    Some(lonisle_core::proto::Attachment {
        attachment_id: v["id"].as_str().unwrap_or_default().to_string(),
        kind: v["kind"].as_str().unwrap_or_default().to_string(),
        size: v["size"].as_u64().unwrap_or_default(),
        mime: v["mime"].as_str().unwrap_or_default().to_string(),
        width: v["width"].as_u64().unwrap_or_default() as u32,
        height: v["height"].as_u64().unwrap_or_default() as u32,
        duration: v["duration"].as_u64().unwrap_or_default() as u32,
        thumbnail_id: v["thumbnail_id"].as_str().unwrap_or_default().to_string(),
        filename: v["filename"].as_str().unwrap_or_default().to_string(),
    })
}

fn row_to_bot(r: sqlx::sqlite::SqliteRow) -> BotRecord {
    BotRecord {
        bot_id: r.get("bot_id"),
        name: r.get("name"),
        token_hash: r.get("token_hash"),
        events: r.get("events"),
        created_at: r.get("created_at"),
        revoked: r.get::<i64, _>("revoked") != 0,
    }
}

fn row_to_message(r: sqlx::sqlite::SqliteRow) -> StoredMessage {
    StoredMessage {
        seq: r.get::<i64, _>("seq") as u64,
        topic_id: r.get("topic_id"),
        msg_id: r.get("msg_id"),
        author_id: r.get("author_id"),
        device_id: r.get("device_id"),
        author_name: r.get("author_name"),
        server_ts: r.get("server_ts"),
        content_text: r.get("content_text"),
        edited: r.get::<i64, _>("edited") != 0,
        deleted: r.get::<i64, _>("deleted") != 0,
        mentions: r.get("mentions"),
        reply_to: r.get("reply_to"),
        attachment_json: r.get("attachment_json"),
    }
}

fn row_to_member(r: sqlx::sqlite::SqliteRow) -> Member {
    Member {
        user_id: r.get("user_id"),
        display_name: r.get("display_name"),
        avatar_seed: r.get("avatar_seed"),
        role: MemberRole::from_i64(r.get("role")),
        muted: r.get::<i64, _>("muted") != 0,
        banned: r.get::<i64, _>("banned") != 0,
        server_nickname: r.get("server_nickname"),
        server_avatar: r.get("server_avatar"),
        push_service_url: r.get("push_service_url"),
        is_bot: r.get::<i64, _>("is_bot") != 0,
        joined_at: r.get("joined_at"),
        master_pubkey: r.get("master_pubkey"),
    }
}

fn row_to_topic(r: sqlx::sqlite::SqliteRow) -> Topic {
    Topic {
        topic_id: r.get("topic_id"),
        name: r.get("name"),
        description: r.get("description"),
        topic_type: TopicType::from_i64(r.get("topic_type")),
        permission: TopicPermission::from_i64(r.get("permission")),
        sort_order: r.get("sort_order"),
        push_enabled: r.get::<i64, _>("push_enabled") != 0,
    }
}

fn row_to_join_request(r: sqlx::sqlite::SqliteRow) -> JoinRequest {
    JoinRequest {
        request_id: r.get("request_id"),
        user_id: r.get("user_id"),
        display_name: r.get("display_name"),
        reason: r.get("reason"),
        push_service_url: r.get("push_service_url"),
        status: JoinStatus::from_i64(r.get("status")),
        created_at: r.get("created_at"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_msg(seq_hint: &str) -> StoredMessage {
        StoredMessage {
            seq: 0,
            topic_id: "topic1".into(),
            msg_id: format!("msg-{}", seq_hint),
            author_id: format!("author-{}", seq_hint),
            device_id: "dev1".into(),
            author_name: "Alice".into(),
            server_ts: 1700000000,
            content_text: "hello".into(),
            edited: false,
            deleted: false,
            mentions: String::new(),
            reply_to: String::new(),
            attachment_json: String::new(),
        }
    }

    #[tokio::test]
    async fn append_and_sync() {
        let storage = SqliteStorage::open_in_memory().await.unwrap();

        let seq1 = storage.append_message(&sample_msg("1")).await.unwrap();
        let seq2 = storage.append_message(&sample_msg("2")).await.unwrap();
        assert_eq!(seq1, 1);
        assert_eq!(seq2, 2);

        let msgs = storage.get_messages_since("topic1", 0, 100).await.unwrap();
        assert_eq!(msgs.len(), 2);
        assert_eq!(msgs[0].seq, 1);
        assert_eq!(msgs[1].seq, 2);

        // 增量：从 1 之后
        let msgs = storage.get_messages_since("topic1", 1, 100).await.unwrap();
        assert_eq!(msgs.len(), 1);
        assert_eq!(msgs[0].seq, 2);

        assert_eq!(storage.latest_seq("topic1").await.unwrap(), 2);
    }

    #[tokio::test]
    async fn duplicate_message_rejected() {
        let storage = SqliteStorage::open_in_memory().await.unwrap();
        let msg = sample_msg("dup");
        storage.append_message(&msg).await.unwrap();
        let err = storage.append_message(&msg).await.unwrap_err();
        assert!(matches!(err, StorageError::DuplicateMessage));
    }

    #[tokio::test]
    async fn member_upsert() {
        let storage = SqliteStorage::open_in_memory().await.unwrap();
        let member = Member {
            user_id: "u1".into(),
            display_name: "Alice#abc".into(),
            avatar_seed: "seed".into(),
            role: MemberRole::Owner,
            muted: false,
            banned: false,
            server_nickname: None,
            server_avatar: None,
            push_service_url: String::new(),
            is_bot: false,
            joined_at: 1700000000,
            master_pubkey: vec![1u8; 32],
        };
        storage.upsert_member(&member).await.unwrap();
        let got = storage.get_member("u1").await.unwrap().unwrap();
        assert!(got.is_owner());

        let members = storage.list_members().await.unwrap();
        assert_eq!(members.len(), 1);
    }
}
