//! 协议版本协商

/// 当前协议版本（与 proto 中 PROTOCOL_VERSION 常量保持一致）。
pub const PROTOCOL_VERSION: i32 = 1;

/// 服务器支持的协议版本范围。
pub const MIN_SUPPORTED_VERSION: i32 = 1;
pub const MAX_SUPPORTED_VERSION: i32 = 1;

/// 判断客户端协议版本是否与服务器兼容。
pub fn is_compatible(client_version: i32) -> bool {
    client_version >= MIN_SUPPORTED_VERSION && client_version <= MAX_SUPPORTED_VERSION
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_compatible() {
        assert!(is_compatible(1));
        assert!(!is_compatible(0));
        assert!(!is_compatible(2));
    }
}
