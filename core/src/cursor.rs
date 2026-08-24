//! 消息序号与游标模型
//!
//! 每个服务器内维护全局单调递增消息序号（编辑/删除亦为序号事件，M1 仅消息）；
//! 客户端每设备按 server_id 维度独立维护游标，增量同步按游标拉取后续序号区间。

use serde::{Deserialize, Serialize};

/// 客户端某服务器上的同步游标。
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Cursor {
    pub server_id: String,
    /// 已同步到的最大服务器序号（0 表示尚未同步任何消息）。
    pub last_seq: u64,
}

impl Cursor {
    pub fn new(server_id: impl Into<String>) -> Self {
        Self {
            server_id: server_id.into(),
            last_seq: 0,
        }
    }

    /// 推进游标到 `seq`（仅当 seq 更大时推进，保证单调）。
    pub fn advance(&mut self, seq: u64) {
        if seq > self.last_seq {
            self.last_seq = seq;
        }
    }
}

/// 增量同步区间：拉取 (after_seq, after_seq + limit] 的消息。
#[derive(Debug, Clone)]
pub struct SyncRange {
    pub after_seq: u64,
    pub limit: u32,
}

impl SyncRange {
    pub fn new(after_seq: u64, limit: u32) -> Self {
        Self { after_seq, limit }
    }
}

/// 默认单次增量同步上限。
pub const DEFAULT_SYNC_LIMIT: u32 = 100;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cursor_advances_monotonically() {
        let mut c = Cursor::new("srv1");
        assert_eq!(c.last_seq, 0);
        c.advance(5);
        assert_eq!(c.last_seq, 5);
        c.advance(3); // 不回退
        assert_eq!(c.last_seq, 5);
        c.advance(10);
        assert_eq!(c.last_seq, 10);
    }
}
