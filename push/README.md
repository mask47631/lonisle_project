# LonIsle 推送服务

推送服务是 LonIsle 中唯一的「半中心」组件，负责：
1. **厂商推送中继**：代聊天服务器向厂商通道（APNs/FCM/华为/小米）发离线推送唤醒
2. **服务器发现目录**：公开可搜索的聊天服务器目录

推送服务**不接触、不存储任何消息内容**，只做唤醒与目录。

## 快速开始（Docker）

```bash
docker build -t lonisle-push .
docker run -d -p 8081:8081 -v /data/lonisle-push:/data lonisle-push
```

## 快速开始（本机二进制）

```bash
cargo build --release -p lonisle-push
./target/release/lonisle-push --listen 0.0.0.0:8081 --data-dir ./data
```

## 环境变量配置

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `LISTEN` | `0.0.0.0:8081` | 监听地址 |
| `DATA_DIR` | `./data` | 数据目录（SQLite） |
| `RATE_PER_MINUTE` | `2` | 单服务器对单用户每分钟推送上限 |

环境变量优先于命令行参数。也可直接用 `--listen` / `--data-dir` / `--rate-per-minute` 参数。

## HTTP API

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/health` | 健康监测（白名单申请前置校验） |
| POST | `/register` | 客户端注册设备 Token |
| POST | `/push` | 聊天服务器发起推送（验签 + 限速 + 免内容） |
| GET | `/directory` | 服务器目录查询 |
| POST | `/directory/register` | 服务器注册目录 |
| POST | `/directory/update` | 服务器更新目录 |
| POST | `/directory/remove` | 服务器下架目录 |
| POST | `/apply` | 白名单申请（含健康监测前置校验） |
| POST | `/mute` | 用户免打扰 |
| GET | `/admin/*` | 管理界面（白名单审核/限速/目录） |

## 管理界面

访问 `http://<host>:8081/` 打开管理界面，可进行：
- 白名单审核（通过/拒绝，拒绝后 1 个月冷却）
- 限速配置（热更新）
- 目录管理（上架/下架）

## 客户端绑定推送服务地址

客户端在 `client/lib/src/config.dart` 中编译期绑定推送服务地址：

```dart
static const String pushServiceUrl = 'http://127.0.0.1:8081';
```

自建推送服务后，修改此常量并重新编译客户端即可。

## 厂商通道

M4/M5 使用 mock 厂商通道（`MockVendor`，记录日志不真发）。接入真实通道需实现 `VendorPush` trait：

```rust
// push/src/vendor.rs
pub trait VendorPush: Send + Sync {
    fn send_notification(&self, token: &str, title: &str, body: &str);
}
```

分别实现 APNs / FCM / 华为 / 小米 / OPPO / vivo 通道即可。
