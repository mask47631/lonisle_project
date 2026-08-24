# LonIsle 客户端（Flutter）

跨端客户端：macOS / Windows / Linux / Android / iOS，经 flutter_rust_bridge 调用 `core/` Rust 共享库。

## 功能概览

- 自主身份（Ed25519 主密钥 + 设备证书链）、多设备授权/撤销
- 多服务器聚合三栏 UI（服务器栏 / 话题栏 / 消息区）
- 消息：文本、回复引用、@提及、Reaction、编辑/删除
- 媒体消息（F-MEDIA）：
  - **图片**：选择发送，自动缩略图 + 宽高元数据
  - **视频**：FilePicker 选择发送，自动读取时长元数据，点击下载后 video_player 播放
  - **语音**：输入栏麦克风按钮录音（AAC/m4a，计时/取消/发送），或选择音频文件；接收端 VoicePlayer 播放（倍速/进度拖拽）
  - 附件菜单：发送图片 / 发送视频 / 发送音频 / 发送文件
- 自动下载阈值（按图片/视频/语音分别配置，区分 Wi-Fi/蜂窝）
- LiveKit 音视频话题、E2EE、服务器发现页

## 品牌资源

- UI 内 logo 使用 `assets/logo.png`（源自仓库 `LOGO/logo（透明底）.png`）
- 各平台应用图标由 `scripts/gen_app_icons.py` 从 LOGO 生成（渐变底 + 白色线条），
  logo 更新后重跑该脚本即可：`python3 scripts/gen_app_icons.py`

## 构建

```bash
flutter pub get
flutter_rust_bridge_codegen generate   # 桥接代码变更时
flutter build macos --debug
```

## 平台权限

- macOS：`Info.plist` 已声明 `NSMicrophoneUsageDescription` / `NSCameraUsageDescription`（语音消息、音视频通话）
- Android：`RECORD_AUDIO` / `CAMERA` 等权限已在 AndroidManifest 声明
- iOS：麦克风/相机用途说明已在 Info.plist 声明
