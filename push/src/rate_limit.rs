//! 令牌桶限速器
//!
//! 按 (server_id, user_id) 维度限速，速率可热更新。
//! 默认 2 条/分钟（F-RATE-2）。

use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Mutex;
use std::time::Instant;

/// 单个令牌桶
struct TokenBucket {
    tokens: f64,
    last_refill: Instant,
}

impl TokenBucket {
    fn new(capacity: f64) -> Self {
        Self {
            tokens: capacity,
            last_refill: Instant::now(),
        }
    }

    /// 尝试获取一个令牌。成功返回 true。
    fn try_acquire(&mut self, rate_per_minute: f64, capacity: f64) -> bool {
        let now = Instant::now();
        let elapsed = now.duration_since(self.last_refill).as_secs_f64();
        // 按速率补充令牌
        self.tokens = (self.tokens + elapsed * rate_per_minute / 60.0).min(capacity);
        self.last_refill = now;

        if self.tokens >= 1.0 {
            self.tokens -= 1.0;
            true
        } else {
            false
        }
    }
}

/// 限速器：维护 (server_id, user_id) -> TokenBucket 映射
pub struct RateLimiter {
    buckets: Mutex<HashMap<(String, String), TokenBucket>>,
    /// 每分钟条数，可热更新
    rate_per_minute: AtomicU32,
    /// 桶容量（突发余量）
    capacity: f64,
    /// 熔断计数：server_id -> 超限次数（P1）
    violations: Mutex<HashMap<String, u32>>,
}

impl RateLimiter {
    pub fn new(rate_per_minute: u32) -> Self {
        Self {
            buckets: Mutex::new(HashMap::new()),
            rate_per_minute: AtomicU32::new(rate_per_minute),
            capacity: rate_per_minute.max(1) as f64,
            violations: Mutex::new(HashMap::new()),
        }
    }

    /// 热更新限速阈值。
    pub fn set_rate(&self, per_minute: u32) {
        self.rate_per_minute.store(per_minute, Ordering::Relaxed);
    }

    /// 获取当前限速阈值。
    pub fn rate(&self) -> u32 {
        self.rate_per_minute.load(Ordering::Relaxed)
    }

    /// 尝试获取令牌。成功返回 true，超限返回 false。
    pub fn try_acquire(&self, server_id: &str, user_id: &str) -> bool {
        let rate = self.rate_per_minute.load(Ordering::Relaxed) as f64;
        let capacity = self.capacity.max(rate.max(1.0));
        let key = (server_id.to_string(), user_id.to_string());

        let mut buckets = self.buckets.lock().unwrap();
        let bucket = buckets
            .entry(key)
            .or_insert_with(|| TokenBucket::new(capacity));
        bucket.try_acquire(rate, capacity)
    }

    /// 清理过期桶（简单：保留，M4 不主动清理，规模小）。
    pub fn _len(&self) -> usize {
        self.buckets.lock().unwrap().len()
    }

    /// 记录一次超限（熔断计数）。
    pub fn record_violation(&self, server_id: &str) {
        let mut violations = self.violations.lock().unwrap();
        *violations.entry(server_id.to_string()).or_insert(0) += 1;
    }

    /// 获取某服务器的累计超限次数。
    pub fn violation_count(&self, server_id: &str) -> u32 {
        self.violations.lock().unwrap().get(server_id).copied().unwrap_or(0)
    }

    /// 重置某服务器的超限计数。
    pub fn reset_violations(&self, server_id: &str) {
        self.violations.lock().unwrap().remove(server_id);
    }
}

/// 确保桶容量随速率更新。
impl Default for RateLimiter {
    fn default() -> Self {
        Self::new(2)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rate_limits_exceeded() {
        let limiter = RateLimiter::new(2); // 2 条/分钟
        // 第一次突发可获取 capacity=2 个令牌
        assert!(limiter.try_acquire("s1", "u1"));
        assert!(limiter.try_acquire("s1", "u1"));
        // 第三个立即超限
        assert!(!limiter.try_acquire("s1", "u1"));
    }

    #[test]
    fn independent_per_user() {
        let limiter = RateLimiter::new(2);
        assert!(limiter.try_acquire("s1", "u1"));
        assert!(limiter.try_acquire("s1", "u2"));
    }

    #[test]
    fn hot_reload_rate() {
        let limiter = RateLimiter::new(5);
        assert_eq!(limiter.rate(), 5);
        limiter.set_rate(10);
        assert_eq!(limiter.rate(), 10);
    }
}
