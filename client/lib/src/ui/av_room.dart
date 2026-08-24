import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../services/av_session.dart';
import '../theme.dart';

/// 音视频房间全屏视图（F-TOPIC-8/9）
///
/// 只是 AvSession 的视图：返回上一页不会离开房间，
/// 会话由 AppState 驻留，底部控制条仍在；点「离开」才真正断线。
class AVRoomScreen extends StatelessWidget {
  final AvSession session;

  /// 离开房间回调（由宿主注入：清空 AppState.avSession）
  final VoidCallback onLeave;

  const AVRoomScreen({super.key, required this.session, required this.onLeave});

  void _showError(BuildContext context, String? err) {
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final s = session;
        return Scaffold(
          backgroundColor: LonIsleTheme.bg,
          appBar: AppBar(
            backgroundColor: LonIsleTheme.bg2,
            title: Text(
              '语音房间 · ${s.topicName}',
              style: const TextStyle(color: LonIsleTheme.textWhite),
            ),
            iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
          ),
          body: s.joining
              ? const Center(
                  child:
                      CircularProgressIndicator(color: LonIsleTheme.primary))
              : s.error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.error!,
                              style: const TextStyle(color: LonIsleTheme.red)),
                          const SizedBox(height: 12),
                          TextButton(
                              onPressed: s.join, child: const Text('重试')),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // 视频网格
                        if (!s.cameraOff || s.participants.length > 1)
                          Expanded(
                            flex: 3,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(8),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                              itemCount: s.participants.length,
                              itemBuilder: (context, i) =>
                                  _ParticipantTile(participant: s.participants[i]),
                            ),
                          )
                        else
                          const Expanded(
                            flex: 3,
                            child: Center(
                              child: Icon(Icons.headset_mic,
                                  size: 64, color: LonIsleTheme.primary),
                            ),
                          ),
                        // 参与者列表
                        Expanded(
                          flex: 2,
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: s.participants.length,
                            itemBuilder: (context, i) {
                              final p = s.participants[i];
                              final isMe = p is LocalParticipant;
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  _isMuted(s, p) ? Icons.mic_off : Icons.mic,
                                  color: _isMuted(s, p)
                                      ? LonIsleTheme.red
                                      : LonIsleTheme.textDim,
                                  size: 18,
                                ),
                                title: Text(
                                  isMe
                                      ? '我'
                                      : (p.name.isNotEmpty
                                          ? p.name
                                          : p.identity),
                                  style: const TextStyle(
                                      color: LonIsleTheme.textWhite,
                                      fontSize: 14),
                                ),
                              );
                            },
                          ),
                        ),
                        // 控制栏：静音/摄像头/屏幕共享/离开
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          color: LonIsleTheme.bg2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ControlButton(
                                icon: s.muted ? Icons.mic_off : Icons.mic,
                                active: !s.muted,
                                label: s.muted ? '已静音' : '静音',
                                onTap: () async =>
                                    _showError(context, await s.toggleMute()),
                              ),
                              _ControlButton(
                                icon: s.cameraOff
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                                active: !s.cameraOff,
                                label: s.cameraOff ? '摄像头关' : '摄像头',
                                onTap: () async =>
                                    _showError(context, await s.toggleCamera()),
                              ),
                              _ControlButton(
                                icon: Icons.screen_share,
                                active: s.screenSharing,
                                label: s.screenSharing ? '共享中' : '屏幕共享',
                                onTap: () async => _showError(
                                    context, await s.toggleScreenShare()),
                              ),
                              _ControlButton(
                                icon: Icons.call_end,
                                active: false,
                                label: '离开',
                                danger: true,
                                onTap: () {
                                  onLeave();
                                  Navigator.maybePop(context);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  bool _isMuted(AvSession s, Participant p) {
    if (p is LocalParticipant) return s.muted;
    for (final pub in p.audioTrackPublications) {
      if (pub.track != null) return pub.muted;
    }
    return false;
  }
}

/// 参与者视频瓦片
class _ParticipantTile extends StatelessWidget {
  final Participant participant;

  const _ParticipantTile({required this.participant});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LonIsleTheme.bg3,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (participant.videoTrackPublications.any((p) => p.track != null))
            VideoTrackRenderer(
              participant.videoTrackPublications
                  .firstWhere((p) => p.track != null)
                  .track! as VideoTrack,
            )
          else
            const Center(
              child: Icon(Icons.person,
                  size: 40, color: LonIsleTheme.textDim),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                participant is LocalParticipant
                    ? '我'
                    : (participant.name.isNotEmpty
                        ? participant.name
                        : participant.identity),
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _ControlButton({
    required this.icon,
    required this.active,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: danger
                  ? LonIsleTheme.red
                  : active
                      ? LonIsleTheme.primary
                      : LonIsleTheme.bg3,
              foregroundColor: Colors.white,
            ),
            icon: Icon(icon),
          ),
          Text(
            label,
            style: const TextStyle(color: LonIsleTheme.textDim, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
