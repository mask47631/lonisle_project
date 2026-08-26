//! 日志初始化：stdout + 文件双输出（按天轮转、保留 N 天）
//!
//! server / push 共用：日志文件写入 `{data_dir}/logs/{prefix}.{YYYY-MM-DD}.log`，
//! 级别由 `RUST_LOG` 环境变量控制（默认 `info,tower_http=warn`）。

use std::path::Path;

use tracing_subscriber::layer::SubscriberExt as _;
use tracing_subscriber::util::SubscriberInitExt as _;

/// 初始化全局日志（进程内调用一次）：
/// - stdout：终端 / docker logs
/// - 文件：按天轮转，保留 `retain_days` 天（0 = 不删除旧文件）
pub fn init(prefix: &str, data_dir: &Path, retain_days: u32) -> anyhow::Result<()> {
    let log_dir = data_dir.join("logs");
    std::fs::create_dir_all(&log_dir)?;
    let file_appender = tracing_appender::rolling::Builder::new()
        .rotation(tracing_appender::rolling::Rotation::DAILY)
        .filename_prefix(prefix)
        .filename_suffix("log")
        .max_log_files(retain_days as usize)
        .build(&log_dir)?;
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::fmt::layer()
                .with_writer(file_appender)
                .with_ansi(false),
        )
        .with(tracing_subscriber::fmt::layer().with_writer(std::io::stdout))
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,tower_http=warn".into()),
        )
        .init();
    Ok(())
}

/// 读取日志目录中**最新**日志文件的末尾 N 行（管理界面「日志」页用）。
/// 返回 `(文件名, 内容)`；目录不存在或暂无日志文件时返回 Err。
pub fn read_tail(log_dir: &Path, lines: usize) -> anyhow::Result<(String, String)> {
    // 按修改时间取最新 .log 文件
    let mut newest: Option<(std::time::SystemTime, std::path::PathBuf)> = None;
    for entry in std::fs::read_dir(log_dir)? {
        let entry = entry?;
        if entry.path().extension().and_then(|e| e.to_str()) != Some("log") {
            continue;
        }
        let mtime = entry.metadata()?.modified()?;
        if newest.as_ref().map_or(true, |(t, _)| mtime > *t) {
            newest = Some((mtime, entry.path()));
        }
    }
    let (_, path) = newest.ok_or_else(|| anyhow::anyhow!("暂无日志文件"))?;

    // 防御：超大文件只读尾部 512KB（日志行均短，足够取到 N 行）
    const TAIL_BYTES: u64 = 512 * 1024;
    let meta = std::fs::metadata(&path)?;
    let content = if meta.len() > TAIL_BYTES {
        use std::io::{Read, Seek, SeekFrom};
        let mut f = std::fs::File::open(&path)?;
        f.seek(SeekFrom::End(-(TAIL_BYTES as i64)))?;
        let mut buf = Vec::with_capacity(TAIL_BYTES as usize);
        f.read_to_end(&mut buf)?;
        String::from_utf8_lossy(&buf).into_owned()
    } else {
        std::fs::read_to_string(&path)?
    };

    let tail: Vec<&str> = content.lines().rev().take(lines).collect();
    Ok((
        path.file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .into_owned(),
        tail.iter().rev().cloned().collect::<Vec<_>>().join("\n"),
    ))
}
