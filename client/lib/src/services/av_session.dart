import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

import '../state/server_connection.dart';

/// 音视频会话（F-TOPIC-8/9，全局驻留）
///
/// 由 AppState 持有，与房间页面解耦：进房后退出全屏页面也不断线，
/// 可继续浏览/发言其他话题；底部控制条/房间页面都只是会话的视图。
class AvSession extends ChangeNotifier {
  final ServerConnection sc;
  final String topicId;
  final String topicName;

  Room? room;
  LocalParticipant? me;

  bool joining = true;
  String? error;

  bool muted = false;
  bool cameraOff = true;
  bool screenSharing = false;

  final List<Participant> participants = [];

  AvSession({
    required this.sc,
    required this.topicId,
    required this.topicName,
  });

  /// 加入房间：joinAV 取 token → 连接 LiveKit → 发布轨道（独立降级）
  Future<void> join() async {
    joining = true;
    error = null;
    notifyListeners();
    try {
      final resp = await sc.joinAV(topicId);
      final r = Room();
      room = r;
      r.addListener(_refreshParticipants);
      await r.connect(
        resp.url,
        resp.token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultCameraCaptureOptions: CameraCaptureOptions(),
          defaultAudioCaptureOptions: AudioCaptureOptions(),
        ),
      );
      me = r.localParticipant;

      // 进房默认闭麦关摄像头（隐私优先），由用户手动开启
      muted = true;
      cameraOff = true;
      joining = false;
      _refreshParticipants();
    } catch (e) {
      error = '加入失败：$e';
      joining = false;
      notifyListeners();
    }
  }

  /// 离开房间并释放资源
  Future<void> leave() async {
    try {
      room?.removeListener(_refreshParticipants);
      await room?.disconnect();
      await room?.dispose();
    } catch (_) {}
    room = null;
    me = null;
  }

  /// 轨道开关，返回错误文案（null 为成功），由视图层弹出提示
  Future<String?> toggleMute() async {
    final p = me;
    if (p == null) return null;
    try {
      await p.setMicrophoneEnabled(muted);
      muted = !muted;
      notifyListeners();
      return null;
    } catch (e) {
      return '麦克风操作失败：$e（请检查系统麦克风权限）';
    }
  }

  Future<String?> toggleCamera() async {
    final p = me;
    if (p == null) return null;
    try {
      await p.setCameraEnabled(cameraOff);
      cameraOff = !cameraOff;
      notifyListeners();
      return null;
    } catch (e) {
      return '摄像头不可用：请在 系统设置 → 隐私与安全性 → 相机 中允许 lonisle_client';
    }
  }

  Future<String?> toggleScreenShare() async {
    final p = me;
    if (p == null) return null;
    try {
      await p.setScreenShareEnabled(!screenSharing);
      screenSharing = !screenSharing;
      notifyListeners();
      return null;
    } catch (e) {
      return '屏幕共享失败：$e';
    }
  }

  void _refreshParticipants() {
    final r = room;
    if (r == null) return;
    participants
      ..clear()
      ..addAll([
        if (r.localParticipant != null) r.localParticipant!,
        ...r.remoteParticipants.values,
      ]);
    notifyListeners();
  }

  @override
  void dispose() {
    leave();
    super.dispose();
  }
}
