// 编译时生成版本号：UTC 时间 YYYYMMDDHHMM（如 202608251533），
// 写入 OUT_DIR/build_version.txt，代码通过 include_str! 读取。
// 纯 Rust 实现，跨平台可用（不依赖 date 命令，Windows 亦可编译）。
fn main() {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("系统时间早于 1970-01-01")
        .as_secs();

    let days = secs / 86_400;
    let rem = secs % 86_400;
    let (hh, mm) = (rem / 3_600, (rem % 3_600) / 60);

    // 公历日期换算（Howard Hinnant civil_from_days 算法，纯整数运算）
    let z = days as i64 + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = if m <= 2 { y + 1 } else { y };

    let ver = format!("{:04}{:02}{:02}{:02}{:02}", y, m, d, hh, mm);
    std::fs::write(
        std::path::Path::new(&std::env::var("OUT_DIR").expect("OUT_DIR 缺失"))
            .join("build_version.txt"),
        ver,
    )
    .expect("写入版本文件失败");
    println!("cargo:rerun-if-changed=build.rs");
}
