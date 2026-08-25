import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fixnum/fixnum.dart' show Int64;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../proto/lonisle.pb.dart' as pb;
import 'tofu_http.dart';

/// 媒体服务：附件上传/下载/缩略图/自动下载（F-MEDIA-1~5）
///
/// 上传走 multipart（图片附带缩略图），下载支持流式进度。
/// 自动下载：按类型阈值 + 网络类型判定（Wi-Fi 全量阈值，蜂窝仅小文件）。
class MediaService {
  MediaService._();

  static final MediaService instance = MediaService._();

  /// 服务器地址（host:port，活跃服务器连接时自动同步）
  String _serverAddress = '';
  String _host = '';
  int _port = 0;

  /// 带 TOFU 校验的 HTTPS Client（F-SID-2/3）
  /// [serverAddress] 为 "host:port"；缺省用最近一次 setServer 的地址。
  Future<http.Client> _client([String? serverAddress]) async {
    var host = _host;
    var port = _port;
    if (serverAddress != null && serverAddress.contains(':')) {
      final parts = serverAddress.split(':');
      host = parts.first;
      port = int.tryParse(parts.last) ?? port;
    }
    if (host.isEmpty || port == 0) {
      throw Exception('媒体服务未初始化（服务器地址未知）');
    }
    final tofu = await createTofuClient(host, port);
    return IOClient(tofu.client);
  }

  /// 归一化地址（参数优先，兜底单例状态）
  String _addr(String? serverAddress) {
    final addr = serverAddress ?? _serverAddress;
    if (addr.isEmpty || !addr.contains(':')) {
      throw Exception('媒体服务未初始化（服务器地址未知）');
    }
    return addr;
  }

  /// 自动下载阈值（MB）：image / video / audio，0 表示不自动下载
  final Map<String, double> _autoDownloadThresholds = {
    'image': 0,
    'video': 0,
    'audio': 0,
  };

  /// 蜂窝网络下允许自动下载的最大尺寸（MB，超过则等 Wi-Fi/手动）
  static const _cellularCapMb = 5.0;

  void setServer(String host, int port) {
    _serverAddress = '$host:$port';
    _host = host;
    _port = port;
  }

  /// 加载自动下载阈值配置。
  Future<void> loadThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    _autoDownloadThresholds['image'] =
        prefs.getDouble('auto_download_image') ?? 0;
    _autoDownloadThresholds['video'] =
        prefs.getDouble('auto_download_video') ?? 0;
    _autoDownloadThresholds['audio'] =
        prefs.getDouble('auto_download_audio') ?? 0;
  }

  /// 保存某类型的自动下载阈值（MB）。
  Future<void> saveThreshold(String kind, double thresholdMb) async {
    _autoDownloadThresholds[kind] = thresholdMb;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('auto_download_$kind', thresholdMb);
  }

  /// 获取某类型的自动下载阈值（MB）。
  double threshold(String kind) => _autoDownloadThresholds[kind] ?? 0;

  /// 当前是否 Wi-Fi（F-MEDIA-5）
  Future<bool> isWifi() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
    } catch (_) {
      // 桌面端可能不支持：默认按 Wi-Fi 处理
      return true;
    }
  }

  /// 判断附件是否应自动下载（F-MEDIA-4/5）。
  /// [onWifi] 为 null 时内部查询网络类型。
  Future<bool> shouldAutoDownload(pb.Attachment attachment,
      {bool? onWifi}) async {
    final thresholdMb = _autoDownloadThresholds[attachment.kind] ?? 0;
    if (thresholdMb <= 0) return false;
    final sizeMb = attachment.size.toInt() / (1024 * 1024);
    if (sizeMb >= thresholdMb) return false;
    // 蜂窝网络：超过蜂窝上限的不自动（F-MEDIA-5）
    final wifi = onWifi ?? await isWifi();
    if (!wifi && sizeMb >= _cellularCapMb) return false;
    return true;
  }

  /// 生成图片缩略图（dart:ui 解码重编码，最长边 480px 等比缩放，PNG）。
  /// 非图片或失败返回 null。
  Future<Uint8List?> generateImageThumbnail(Uint8List data) async {
    try {
      // 先按原始尺寸解码（只取头信息，targetWidth/Height 同时指定会拉伸变形）
      final probe = await ui.instantiateImageCodec(data);
      final frame0 = await probe.getNextFrame();
      final srcW = frame0.image.width;
      final srcH = frame0.image.height;
      frame0.image.dispose();
      probe.dispose();
      if (srcW <= 0 || srcH <= 0) return null;

      // 最长边 480 等比缩放；小于阈值的图不放大
      const maxSide = 480;
      final scale =
          math.max(srcW, srcH) > maxSide ? maxSide / math.max(srcW, srcH) : 1.0;
      final dstW = (srcW * scale).round();
      final dstH = (srcH * scale).round();

      final codec = await ui.instantiateImageCodec(
        data,
        targetWidth: dstW,
        targetHeight: dstH,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;

      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      codec.dispose();
      if (bytes == null) return null;
      return bytes.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// 读取图片宽高（用于附件元数据，F-MEDIA-8）
  Future<(int, int)?> imageSize(Uint8List data) async {
    try {
      final image = await decodeImageFromList(data);
      return (image.width, image.height);
    } catch (_) {
      return null;
    }
  }

  /// 上传附件（图片自动附带缩略图与宽高），返回 attachment 元数据。
  /// [durationSec] 为音视频时长（秒，F-MEDIA-8），非音视频传 0。
  /// [width]/[height] 为媒体尺寸（视频由 video_player 探测），
  /// [thumbnail] 为外部生成的缩略图字节（视频首帧，F-MEDIA-1）。
  Future<pb.Attachment> upload({
    required Uint8List data,
    required String filename,
    required String msgId,
    required String kind,
    required String userId,
    String mime = 'application/octet-stream',
    int durationSec = 0,
    int width = 0,
    int height = 0,
    Uint8List? thumbnail,
    String? serverAddress,
  }) async {
    final addr = _addr(serverAddress);
    final client = await _client(addr);
    // 调用方未指定 MIME 时按文件名后缀推断（缺省 octet-stream 会让
    // 附件元数据丢失类型信息）
    final effectiveMime =
        mime == 'application/octet-stream' ? _guessMime(filename) : mime;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://$addr/attachments/upload'),
    );
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      data,
      filename: filename,
    ));
    request.fields['msg_id'] = msgId;
    request.fields['kind'] = kind;
    request.fields['user_id'] = userId;

    final response = await client.send(request);
    final body = await response.stream.bytesToString();
    if (response.statusCode != 200) {
      // 透传服务端错误文案（如「附件超过大小上限」），
      // 否则用户无法分辨撞的是哪条限制
      final errMatch = RegExp(r'"error"\s*:\s*"([^"]*)"').firstMatch(body);
      final reason = errMatch?.group(1) ?? '';
      throw Exception(reason.isNotEmpty
          ? '上传失败：$reason'
          : '上传失败：HTTP ${response.statusCode}');
    }

    final idMatch = RegExp(r'"attachment_id"\s*:\s*"([^"]+)"').firstMatch(body);
    final attachmentId = idMatch?.group(1) ?? '';

    var attachment = pb.Attachment()
      ..attachmentId = attachmentId
      ..kind = kind
      ..size = Int64(data.length)
      ..mime = effectiveMime
      ..width = width
      ..height = height
      ..duration = durationSec
      ..filename = filename;

    // 图片：生成缩略图上传 + 读取宽高（F-MEDIA-1/8）
    if (kind == 'image') {
      final dims = await imageSize(data);
      if (dims != null) {
        attachment.width = dims.$1;
        attachment.height = dims.$2;
      }
      // GIF 等动态图不生成缩略图（缩略图是静态帧，会丢失动画），
      // 直接使用原图展示
      final isGif = _isGif(data, filename);
      if (!isGif) {
        thumbnail ??= await generateImageThumbnail(data);
      }
    }
    // 统一上传缩略图（图片自动生成；视频取帧由调用方传入）
    if (thumbnail != null) {
      // 用服务端返回的真实附件 ID（服务端生成随机 att-xxx，
      // 不能本地拼造 thumb-xxx —— 那样下载必 404）
      final thumbId =
          await _uploadThumbnail(client, attachmentId, thumbnail, addr);
      if (thumbId != null) {
        attachment.thumbnailId = thumbId;
      }
    }
    return attachment;
  }

  /// 是否为 GIF 动态图（按内容魔数 + 扩展名判断）。
  /// GIF 不做缩略图/缩放，保留动画直接使用原图。
  static bool _isGif(Uint8List data, String filename) {
    if (filename.toLowerCase().endsWith('.gif')) return true;
    if (data.length >= 6) {
      final head = String.fromCharCodes(data.sublist(0, 6));
      if (head == 'GIF87a' || head == 'GIF89a') return true;
    }
    return false;
  }

  /// 上传缩略图（复用上传端点）。成功返回服务端生成的真实附件 ID。
  Future<String?> _uploadThumbnail(
      http.Client client, String attachmentId, Uint8List thumb, String addr) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://$addr/attachments/upload'),
      );
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        thumb,
        filename: 'thumb.png',
      ));
      request.fields['msg_id'] = 'thumb-$attachmentId';
      request.fields['kind'] = 'thumbnail';
      request.fields['user_id'] = 'system';
      final response = await client.send(request);
      if (response.statusCode != 200) return null;
      final body = await response.stream.bytesToString();
      final idMatch =
          RegExp(r'"attachment_id"\s*:\s*"([^"]+)"').firstMatch(body);
      return idMatch?.group(1);
    } catch (_) {
      // 缩略图失败不阻断主附件
      return null;
    }
  }

  /// 下载附件到本地缓存，返回本地文件路径。
  Future<String> download(String attachmentId,
      {String? serverAddress, String? filename}) async {
    final cacheDir = await _cacheDir();
    // 优先用原始文件名（含后缀）保存，无则回退附件 ID
    final saveName = (filename != null && filename.isNotEmpty)
        ? _sanitizeFilename(filename, attachmentId)
        : attachmentId;
    final target = p.join(cacheDir.path, saveName);

    // 已缓存则直接返回（旧的无扩展名缓存会嗅探补扩展名）
    final cached = await _findCached(cacheDir, attachmentId);
    if (cached != null) {
      return cached;
    }

    final addr = _addr(serverAddress);
    final client = await _client(addr);
    final response = await client.get(
      Uri.parse('https://$addr/attachments/$attachmentId'),
    );
    if (response.statusCode != 200) {
      throw Exception('下载失败：${response.statusCode}');
    }

    final file = File(target);
    await file.writeAsBytes(response.bodyBytes);
    return _ensureExtension(target);
  }

  /// 文件名安全化：去掉路径穿越/非法字符，空名回退附件 ID
  String _sanitizeFilename(String name, String fallbackId) {
    final clean = p.basename(name).replaceAll(RegExp(r'[^\w.\-]'), '_');
    return clean.isEmpty ? fallbackId : clean;
  }

  /// 流式下载（带进度回调，F-MEDIA-3）。
  /// [onProgress] 收到 0.0~1.0。已缓存直接回调 1.0 并返回路径。
  Future<String> downloadWithProgress(
    String attachmentId,
    void Function(double progress) onProgress, {
    String? serverAddress,
  }) async {
    final cacheDir = await _cacheDir();
    final target = p.join(cacheDir.path, attachmentId);

    final cached = await _findCached(cacheDir, attachmentId);
    if (cached != null) {
      onProgress(1.0);
      return cached;
    }

    final addr = _addr(serverAddress);
    final client = await _client(addr);
    final request = http.Request(
        'GET', Uri.parse('https://$addr/attachments/$attachmentId'));
    final response = await client.send(request);
    if (response.statusCode != 200) {
      throw Exception('下载失败：${response.statusCode}');
    }

    final total = response.contentLength ?? 0;
    final file = File(target);
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      await sink.close();
      // 失败清理半成品
      try {
        file.deleteSync();
      } catch (_) {}
      rethrow;
    }
    onProgress(1.0);
    return _ensureExtension(target);
  }

  /// 下载服务器图标（F-PERM-2）。
  /// [version] 为 ServerInfo.icon（"ext:ts"），版本变化才重新下载；
  /// 返回本地缓存路径，未设置/失败返回 null。
  Future<String?> downloadServerIcon(String serverAddress, String version) async {
    if (version.isEmpty) return null;
    try {
      final ext = version.split(':').first;
      final cacheDir = await _cacheDir();
      final key = 'server_icon_${serverAddress.replaceAll(':', '_')}.$ext';
      final target = p.join(cacheDir.path, key);

      final prefs = await SharedPreferences.getInstance();
      final verKey = 'server_icon_ver_$serverAddress';
      if (File(target).existsSync() && prefs.getString(verKey) == version) {
        return target;
      }

      final client = await _client(serverAddress);
      final response =
          await client.get(Uri.parse('https://$serverAddress/icon'));
      if (response.statusCode != 200) {
        // ignore: avoid_print
        print('[ServerIcon] 下载失败 HTTP ${response.statusCode}');
        return null;
      }
      await File(target).writeAsBytes(response.bodyBytes);
      await prefs.setString(verKey, version);
      return target;
    } catch (e) {
      // ignore: avoid_print
      print('[ServerIcon] 异常: $e');
      return null;
    }
  }

  /// 下载缩略图（无进度版）
  Future<String?> downloadThumbnail(String thumbnailId,
      {String? serverAddress}) async {
    if (thumbnailId.isEmpty) return null;
    return download(thumbnailId, serverAddress: serverAddress);
  }

  /// 缓存查找：优先无扩展名旧缓存（嗅探补扩展名），其次带扩展名的新缓存。
  Future<String?> _findCached(Directory dir, String attachmentId) async {
    final plain = p.join(dir.path, attachmentId);
    if (File(plain).existsSync()) {
      return _ensureExtension(plain);
    }
    try {
      await for (final entity in dir.list()) {
        if (entity is File &&
            p.basename(entity.path).startsWith('$attachmentId.')) {
          return entity.path;
        }
      }
    } catch (_) {}
    return null;
  }

  /// 无扩展名的缓存文件按魔数嗅探补扩展名。
  /// AVPlayer / just_audio 依赖扩展名（UTI）识别容器格式，
  /// 裸 att-xxx 文件名会报 OSStatus -12847「格式不支持」。
  String _ensureExtension(String path) {
    try {
      if (p.extension(path).isNotEmpty) return path;
      final file = File(path);
      final raf = file.openSync();
      final header = raf.readSync(16);
      raf.closeSync();
      final ext = _sniffExt(header);
      if (ext == null) return path;
      final renamed = '$path.$ext';
      file.renameSync(renamed);
      return renamed;
    } catch (_) {
      return path;
    }
  }

  /// 按文件名后缀推断 MIME（附件元数据用）
  static String _guessMime(String filename) {
    switch (p.extension(filename).toLowerCase().replaceFirst('.', '')) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'flac':
        return 'audio/flac';
      default:
        return 'application/octet-stream';
    }
  }

  /// 常见媒体格式的魔数嗅探，返回扩展名（不含点）；未知返回 null。
  static String? _sniffExt(Uint8List b) {
    bool eq(int off, String s) {
      if (b.length < off + s.length) return false;
      for (var i = 0; i < s.length; i++) {
        if (b[off + i] != s.codeUnitAt(i)) return false;
      }
      return true;
    }

    // ISO-BMFF 家族：offset 4 固定为 'ftyp'，主品牌区分 mp4/mov/m4a/m4v
    if (eq(4, 'ftyp')) {
      if (eq(8, 'qt')) return 'mov';
      if (eq(8, 'M4A')) return 'm4a';
      if (eq(8, 'M4V')) return 'm4v';
      return 'mp4';
    }
    if (b.length >= 4 &&
        b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) {
      return 'webm';
    }
    if (eq(0, 'RIFF') && eq(8, 'WAVE')) return 'wav';
    if (eq(0, 'RIFF') && eq(8, 'WEBP')) return 'webp';
    if (eq(0, 'OggS')) return 'ogg';
    if (eq(0, 'fLaC')) return 'flac';
    if (eq(0, 'ID3') ||
        (b.length >= 2 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0)) {
      return 'mp3';
    }
    if (b.length >= 4 &&
        b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
      return 'png';
    }
    if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xD8) return 'jpg';
    if (eq(0, 'GIF8')) return 'gif';
    return null;
  }

  Future<Directory> _cacheDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'media_cache'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }
}
