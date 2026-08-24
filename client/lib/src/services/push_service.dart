import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'identity_service.dart';

/// 推送服务客户端（F-PUSH-2/F-RATE-7）
///
/// Token 获取：优先 FCM（firebase_messaging），获取失败/未配置时回退 mock。
/// 免打扰：全局开关（bool），开启后向推送服务上报 muted=true，
/// 服务器随后静默丢弃对该用户的推送唤醒（push 侧 is_muted 检查）。
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  static const _dndKey = 'push_dnd_enabled';

  String? _fcmToken;

  /// 当前渠道与 Token（_resolveToken 解析后缓存，供设置页展示）
  String? _vendor;
  String? _token;

  /// 是否已成功注册到推送服务（register 成功后置位）
  bool registered = false;

  /// 获取厂商 Token：FCM 优先，失败回退 mock
  Future<(String vendor, String token)> _resolveToken() async {
    if (_fcmToken != null) return ('fcm', _fcmToken!);
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _fcmToken = token;
        // Token 轮换监听（厂商 Token 会刷新）
        FirebaseMessaging.instance.onTokenRefresh.listen((t) {
          _fcmToken = t;
          register();
        });
        return ('fcm', token);
      }
    } catch (_) {
      // 未配置 Firebase（google-services.json/GoogleService-Info.plist 缺失）
    }
    // mock 回退（开发/桌面端）
    final deviceId = await IdentityService.instance.deviceId();
    final d = deviceId ?? 'unknown';
    return ('mock', 'mock-${d.substring(0, d.length.clamp(0, 16))}');
  }

  /// 当前推送渠道（fcm/mock，未解析时按需解析）
  Future<String> currentVendor() async {
    if (_vendor != null) return _vendor!;
    final (vendor, token) = await _resolveToken();
    _vendor = vendor;
    _token = token;
    return vendor;
  }

  /// 当前推送 Token（可能为空）
  Future<String?> currentToken() async {
    if (_token != null) return _token;
    final (vendor, token) = await _resolveToken();
    _vendor = vendor;
    _token = token;
    return token;
  }

  /// 推送服务器是否在线（GET /health，3 秒超时）
  Future<bool> serverOnline() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 3);
      final request = await client
          .getUrl(Uri.parse('${LonIsleConfig.pushServiceUrl}/health'));
      final response = await request.close();
      final ok = response.statusCode == 200;
      await response.drain();
      client.close();
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// 渠道显示名（设置页展示用）
  static String vendorLabel(String vendor) {
    switch (vendor) {
      case 'fcm':
      case 'google':
        return 'FCM（Google 厂商推送）';
      case 'mock':
        return '模拟渠道（开发环境）';
      default:
        return vendor;
    }
  }

  /// 注册设备 Token（F-PUSH-2）
  Future<void> register() async {
    final identity = await IdentityService.instance.loadIdentity();
    final deviceId = await IdentityService.instance.deviceId();
    if (identity == null || deviceId == null) return;

    final (vendor, token) = await _resolveToken();

    try {
      final client = HttpClient();
      final request = await client.postUrl(
        Uri.parse('${LonIsleConfig.pushServiceUrl}/register'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'user_id': identity.userId,
        'device_id': deviceId,
        'vendor': vendor,
        'token': token,
      }));
      final response = await request.close();
      await response.drain();
      client.close();
      registered = true; // 注册成功
    } catch (e) {
      // 推送服务不可用不影响聊天功能
      // ignore: avoid_print
      print('推送注册失败：$e');
    }
  }

  /// 免打扰状态（本地缓存）
  Future<bool> dndEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dndKey) ?? false;
  }

  /// 设置免打扰并上报推送服务（F-RATE-7：对所有已连接服务器生效）
  Future<void> setDnd(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dndKey, enabled);

    final identity = await IdentityService.instance.loadIdentity();
    if (identity == null) return;

    // 上报：server_id 逐个上报（对每个已加入服务器）
    try {
      final client = HttpClient();
      for (final serverId in _knownServerIds) {
        final request = await client.postUrl(
          Uri.parse('${LonIsleConfig.pushServiceUrl}/mute'),
        );
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({
          'server_id': serverId,
          'user_id': identity.userId,
          'muted': enabled,
        }));
        final response = await request.close();
        await response.drain();
      }
      client.close();
    } catch (_) {
      // 上报失败不影响本地开关（下次设置时重试）
    }
  }

  /// 已知服务器 ID（由 AppState 维护注入，避免循环依赖）
  final Set<String> _knownServerIds = {};
  void updateKnownServers(Iterable<String> ids) {
    _knownServerIds
      ..clear()
      ..addAll(ids);
  }

  /// 前台通知渠道初始化 + FCM 前台消息本地通知
  Future<void> initForegroundNotifications() async {
    try {
      // 请求通知权限（Android 13+ / iOS，FCM 接收必需）
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        const InitializationSettings(
          // 通知小图标：专用白色图标（彩色 launcher 图标在通知栏会渲染成白色块）
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(),
        ),
      );

      // FCM 前台消息 → 本地通知展示（免内容：仅唤醒提示）
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        plugin.show(
          message.hashCode,
          message.notification?.title ?? 'LonIsle',
          message.notification?.body ?? '你有新消息',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'lonisle_wake',
              '消息唤醒',
              channelDescription: '服务器离线消息唤醒通知',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      });
    } catch (_) {
      // 通知初始化失败（未配置 Firebase/权限拒绝）不影响主功能
    }
  }
}
