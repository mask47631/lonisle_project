/// 编译期配置（F-PUSH-1：客户端编译时绑定推送服务地址）
///
/// 官方默认推送服务地址可在此替换为自建服务并重新编译。
class LonIsleConfig {
  LonIsleConfig._();

  /// 推送服务地址（编译期绑定，可替换为自建服务）
  static const String pushServiceUrl = 'http://127.0.0.1:8081';

  /// 厂商推送 vendor（M4 用 mock，后续接 apns/fcm/huawei/xiaomi）
  static const String vendor = 'mock';
}
