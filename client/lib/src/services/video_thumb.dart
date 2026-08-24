import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// 视频缩略图（F-MEDIA-1）：发送视频时抽取首帧作为缩略图。
///
/// - macOS：video_thumbnail 插件不支持，走原生 MethodChannel
///   （AVAssetImageGenerator，见 macos/Runner/MainFlutterWindow.swift）
/// - Android / iOS：video_thumbnail 插件
///
/// 任何失败均返回 null，不阻断发送（退化为图标占位卡片）。
class VideoThumb {
  VideoThumb._();

  static const _channel = MethodChannel('lonisle/video_thumb');

  /// 从 [videoPath] 抽取首帧，最长边 480，JPEG 字节。
  static Future<Uint8List?> generate(String videoPath) async {
    try {
      if (Platform.isMacOS) {
        return await _channel
            .invokeMethod<Uint8List>('thumbnail', {'path': videoPath});
      }
      if (Platform.isAndroid || Platform.isIOS) {
        return await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 480,
          quality: 80,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
