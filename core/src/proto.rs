//! 由 prost 生成的 Protobuf 代码

pub mod lonisle {
    include!(concat!(env!("OUT_DIR"), "/lonisle.rs"));
}

pub use lonisle::*;
