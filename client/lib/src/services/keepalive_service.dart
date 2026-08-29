import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'push_service.dart';

/// Android 后台保活（无 FCM 设备的离线接收方案，F-PUSH-7 补充）。
///
/// 用户在设置中主动开启（默认关闭）后：应用退到后台时启动前台服务
/// （常驻通知）保活进程，使 WebSocket 长连接持续收消息；开启后无论
/// FCM 是否可用均以本地通知替代 FCM 唤醒（通知策略与 FCM 唤醒一致）。
class KeepAliveService with WidgetsBindingObserver {
  KeepAliveService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final KeepAliveService instance = KeepAliveService._();

  static const _channel = MethodChannel('lonisle/keepalive');
  static const _enabledKey = 'keepalive_enabled';

  /// 用户是否开启（持久化，默认关闭）
  bool _enabled = false;
  bool get enabled => _enabled;

  /// 前台服务是否运行中（后台期间为 true，用于通知判定）
  bool backgroundActive = false;

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    if (_enabled) {
      try {
        await _channel.invokeMethod('start');
        backgroundActive = true;
      } catch (_) {
        // 服务启动失败不影响主功能
      }
    }
  }

  /// 设置页开关：开启即启动服务（无论 FCM 可用性），关闭即停止
  Future<void> setEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, v);
    _enabled = v;
    if (!Platform.isAndroid) return;
    try {
      if (v) {
        // 开启后先申请电池优化豁免（国产 ROM 不豁免大概率被杀）
        try {
          await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
        } catch (_) {}
        await _channel.invokeMethod('start');
        backgroundActive = true;
      } else {
        await _channel.invokeMethod('stop');
        backgroundActive = false;
      }
    } catch (_) {}
  }

  /// 电池优化豁免状态（设置页展示提示用）
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod('isIgnoringBatteryOptimizations') ??
          true;
    } catch (_) {
      return true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isAndroid || !_enabled) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // 退后台：启动前台服务保活，长连接继续收消息
      _channel.invokeMethod('start').then((_) {
        backgroundActive = true;
      }).catchError((_) {});
    } else if (state == AppLifecycleState.resumed) {
      // 回前台：停掉常驻通知，用户正在使用应用
      _channel.invokeMethod('stop').then((_) {
        backgroundActive = false;
      }).catchError((_) {});
      // 前台期间 FCM onMessage 与套接字消息不弹本地通知
      PushService.instance.appFocused = true;
    }
  }
}
