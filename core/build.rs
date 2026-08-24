fn main() -> Result<(), Box<dyn std::error::Error>> {
    let proto_dir = std::path::Path::new("../proto");
    println!("cargo:rerun-if-changed=../proto/lonisle.proto");

    prost_build::Config::new()
        .compile_protos(&[proto_dir.join("lonisle.proto")], &[proto_dir])?;

    Ok(())
}
