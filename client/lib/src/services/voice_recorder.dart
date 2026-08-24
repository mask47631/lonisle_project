import 'dart:io';

import 'package:flutter/services.dart';
import 'package:record/record.dart';

/// 语音录制统一入口（F-MEDIA-7）
///
/// - macOS：原生 AVAudioRecorder 通道（record 插件 6.2.1 在 macOS 的
///   stop() 永不返回，AAC/WAV 均复现，故走 lonisle/voice_recorder 原生实现）
/// - Android / iOS：record 插件（AAC/m4a）
class VoiceRecorder {
  VoiceRecorder._();

  static const _channel = MethodChannel('lonisle/voice_recorder');
  static AudioRecorder? _plugin;

  static bool get _useNative => Platform.isMacOS;

  /// 录制文件扩展名（两路都是 AAC/m4a）
  static const String fileExt = 'm4a';

  static Future<bool> hasPermission() async {
    if (_useNative) {
      // macOS：走原生通道显式请求 TCC 授权（未决定时弹系统授权框）
      try {
        return await _channel.invokeMethod<bool>('requestPermission') ?? false;
      } catch (_) {
        return false;
      }
    }
    _plugin ??= AudioRecorder();
    return _plugin!.hasPermission();
  }

  static Future<void> start(String path) async {
    if (_useNative) {
      await _channel.invokeMethod('start', {'path': path});
      return;
    }
    _plugin ??= AudioRecorder();
    await _plugin!.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
  }

  /// 停止并返回文件路径；未在录制返回 null
  static Future<String?> stop() async {
    if (_useNative) {
      return _channel.invokeMethod<String>('stop');
    }
    final p = _plugin;
    if (p == null) return null;
    return p.stop().timeout(const Duration(seconds: 3));
  }

  static Future<void> cancel() async {
    if (_useNative) {
      await _channel.invokeMethod('cancel');
      return;
    }
    try {
      await _plugin?.stop().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}
