fn main() -> Result<(), Box<dyn std::error::Error>> {
    let proto_dir = std::path::Path::new("../proto");
    println!("cargo:rerun-if-changed=../proto/lonisle.proto");

    // protoc 由 protoc-bin-vendored 提供（构建时自动下载对应平台二进制），
    // 无需系统安装 protoc，保证 Windows/Linux/macOS 及交叉编译环境一致。
    let mut config = prost_build::Config::new();
    config.protoc_executable(protoc_bin_vendored::protoc_bin_path()?);
    config.compile_protos(&[proto_dir.join("lonisle.proto")], &[proto_dir])?;

    Ok(())
}
