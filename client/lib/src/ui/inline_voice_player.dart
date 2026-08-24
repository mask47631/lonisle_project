import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../proto/lonisle.pb.dart' as pb;
import '../services/media_service.dart';
import '../theme.dart';

/// 内联语音气泡（F-MEDIA-7，微信式）：
/// 消息流内直接渲染，点击播放/暂停，显示时长与播放进度，不跳转新页面。
class InlineVoicePlayer extends StatefulWidget {
  final pb.Attachment attachment;
  final String serverAddress;
  final bool isOwn;

  const InlineVoicePlayer({
    super.key,
    required this.attachment,
    required this.serverAddress,
    this.isOwn = false,
  });

  @override
  State<InlineVoicePlayer> createState() => _InlineVoicePlayerState();
}

class _InlineVoicePlayerState extends State<InlineVoicePlayer> {
  final _player = AudioPlayer();
  bool _loading = false;
  bool _ready = false;
  String? _error;

  Future<void> _toggle() async {
    if (_loading) return;
    if (_ready) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }
    // 首次点击：下载 + 加载
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = await MediaService.instance.download(
        widget.attachment.attachmentId,
        serverAddress: widget.serverAddress,
        filename: widget.attachment.filename,
      );
      await _player.setFilePath(path);
      if (!mounted) return;
      setState(() {
        _ready = true;
        _loading = false;
      });
      await _player.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '语音加载失败';
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = widget.attachment.duration.toInt();
    final textColor =
        widget.isOwn ? Colors.white : LonIsleTheme.textWhite;

    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 播放/暂停/加载态
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snap) {
                if (_loading) {
                  return const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: LonIsleTheme.primary),
                  );
                }
                final playing = snap.data?.playing ?? false;
                return Icon(
                  playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                  color: widget.isOwn ? Colors.white : LonIsleTheme.primary,
                  size: 26,
                );
              },
            ),
            const SizedBox(width: 8),
            // 进度（已加载显示播放位置，未加载显示静态波纹占位）
            SizedBox(
              width: 90,
              child: _ready
                  ? StreamBuilder<Duration>(
                      stream: _player.positionStream,
                      builder: (context, posSnap) {
                        final total = _player.duration ??
                            Duration(seconds: secs);
                        final pos = posSnap.data ?? Duration.zero;
                        final v = total.inMilliseconds > 0
                            ? (pos.inMilliseconds / total.inMilliseconds)
                                .clamp(0.0, 1.0)
                            : 0.0;
                        return LinearProgressIndicator(
                          value: v,
                          minHeight: 3,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.25),
                          valueColor: AlwaysStoppedAnimation(
                              widget.isOwn
                                  ? Colors.white
                                  : LonIsleTheme.primary),
                        );
                      },
                    )
                  : Row(
                      children: List.generate(
                        12,
                        (i) => Expanded(
                          child: Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 1),
                            height: (4 + (i % 4) * 3).toDouble(),
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            // 时长 / 播放位置
            _ready
                ? StreamBuilder<Duration>(
                    stream: _player.positionStream,
                    builder: (context, snap) {
                      final pos = snap.data ?? Duration.zero;
                      return Text(
                        '${pos.inSeconds}"',
                        style: TextStyle(color: textColor, fontSize: 12),
                      );
                    },
                  )
                : Text(
                    '$secs"',
                    style: TextStyle(color: textColor, fontSize: 12),
                  ),
            if (_error != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.error_outline,
                  size: 14, color: LonIsleTheme.red),
            ],
          ],
        ),
      ),
    );
  }
}
