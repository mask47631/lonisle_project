/// 编译期配置（F-PUSH-1：客户端编译时绑定推送服务地址）
///
/// 默认值为开发环境。正式发布前通过 --dart-define-from-file 注入私有配置：
///
///   1. cp local_config.json.example local_config.json （client 目录下，该文件已 gitignore）
///   2. 修改其中的 LONISLE_PUSH_URL 为你的推送服务地址
///   3. flutter build apk --release --dart-define-from-file=local_config.json
class LonIsleConfig {
  LonIsleConfig._();

  /// 推送服务地址（可经 local_config.json 覆盖；推送服务启用 HTTPS 后需使用 https://）
  static const String pushServiceUrl = String.fromEnvironment(
    'LONISLE_PUSH_URL',
    defaultValue: 'https://127.0.0.1:8081',
  );
}
