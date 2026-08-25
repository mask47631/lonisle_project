// 编译时生成版本号：本地时间 YYYYMMDDHHMM（如 202608251509），
// 写入 OUT_DIR/build_version.txt，代码通过 include_str! 读取。
fn main() {
    let out = std::process::Command::new("date")
        .arg("+%Y%m%d%H%M")
        .output()
        .expect("date 命令执行失败（编译版本号生成）");
    let ver = String::from_utf8(out.stdout)
        .expect("date 输出非法")
        .trim()
        .to_string();
    std::fs::write(
        std::path::Path::new(&std::env::var("OUT_DIR").expect("OUT_DIR 缺失"))
            .join("build_version.txt"),
        ver,
    )
    .expect("写入版本文件失败");
    println!("cargo:rerun-if-changed=build.rs");
}
