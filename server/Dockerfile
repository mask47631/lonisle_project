# LonIsle 聊天服务器镜像
# 单静态二进制部署，内嵌 Web 管理界面与 SQLite。

# ---- 构建阶段 ----
FROM rust:1.97 AS builder

WORKDIR /build

# 复制整个 workspace（workspace members 含 core/server/push，需全量 COPY）
COPY Cargo.toml Cargo.lock* ./
COPY core ./core
COPY server ./server
COPY push ./push
COPY proto ./proto

# 构建 release 二进制
RUN cargo build --release -p lonisle-server

# ---- 运行阶段 ----
FROM debian:bookworm-slim

# 安装运行时依赖（ca-certificates + wget 用于健康检查）
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制二进制
COPY --from=builder /build/target/release/lonisle-server /app/lonisle-server

# 数据目录
RUN mkdir -p /data
VOLUME ["/data"]

EXPOSE 8080

# 默认监听 0.0.0.0:8080，数据存 /data
ENTRYPOINT ["/app/lonisle-server"]
CMD ["--listen", "0.0.0.0:8080", "--data-dir", "/data"]
