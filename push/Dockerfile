# LonIsle 推送服务镜像
# 单静态二进制部署，内嵌管理界面与 SQLite。

# ---- 构建阶段 ----
FROM rust:1.97 AS builder

WORKDIR /build

# 复制整个 workspace（workspace members 含 core/server/push，需全量 COPY）
COPY Cargo.toml Cargo.lock* ./
COPY core ./core
COPY server ./server
COPY push ./push
COPY proto ./proto

RUN cargo build --release -p lonisle-push

# ---- 运行阶段 ----
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /build/target/release/lonisle-push /app/lonisle-push

RUN mkdir -p /data
VOLUME ["/data"]

EXPOSE 8081

# 通过环境变量配置（LISTEN/DATA_DIR/RATE_PER_MINUTE）
ENTRYPOINT ["/app/lonisle-push"]
CMD ["--listen", "0.0.0.0:8081", "--data-dir", "/data"]
