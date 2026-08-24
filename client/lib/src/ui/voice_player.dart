import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../proto/lonisle.pb.dart' as pb;
import '../services/media_service.dart';
import '../theme.dart';

/// 语音播放器（F-MEDIA-7）：just_audio 真实播放，倍速切换、进度拖拽。
class VoicePlayer extends StatefulWidget {
  final pb.Attachment attachment;

  /// 已下载的本地路径（可选；为空时先下载）
  final String? localPath;

  const VoicePlayer({super.key, required this.attachment, this.localPath});

  @override
  State<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<VoicePlayer> {
  final _player = AudioPlayer();
  double _playbackRate = 1.0;
  bool _ready = false;
  String? _error;

  static const _rates = [0.5, 1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final path = widget.localPath ??
          await MediaService.instance
              .download(widget.attachment.attachmentId);
      final duration = await _player.setFilePath(path);
      if (duration != null && mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '加载失败：$e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Duration(seconds: widget.attachment.duration.toInt());
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text(
          '语音消息',
          style: TextStyle(color: LonIsleTheme.textWhite),
        ),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
      ),
      body: Center(
        child: _error != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: LonIsleTheme.red, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: const TextStyle(color: LonIsleTheme.textDim)),
                ],
              )
            : !_ready
                ? const CircularProgressIndicator(
                    color: LonIsleTheme.primary)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 播放/暂停
                      StreamBuilder<PlayerState>(
                        stream: _player.playerStateStream,
                        builder: (context, snap) {
                          final playing = snap.data?.playing ?? false;
                          return IconButton(
                            onPressed: () {
                              if (playing) {
                                _player.pause();
                              } else {
                                _player.play();
                              }
                            },
                            iconSize: 72,
                            icon: Icon(
                              playing
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: LonIsleTheme.primary,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      // 进度条（可拖拽，F-MEDIA-7）
                      StreamBuilder<Duration?>(
                        stream: _player.durationStream,
                        builder: (context, durSnap) {
                          final total = durSnap.data ?? fallback;
                          return StreamBuilder<Duration>(
                            stream: _player.positionStream,
                            builder: (context, posSnap) {
                              final pos = posSnap.data ?? Duration.zero;
                              final progress = total.inMilliseconds > 0
                                  ? (pos.inMilliseconds /
                                          total.inMilliseconds)
                                      .clamp(0.0, 1.0)
                                  : 0.0;
                              return Column(
                                children: [
                                  Slider(
                                    value: progress,
                                    activeColor: LonIsleTheme.primary,
                                    onChanged: (v) {
                                      _player.seek(Duration(
                                          milliseconds: (v *
                                                  total.inMilliseconds)
                                              .round()));
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 48),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(_formatDuration(pos),
                                            style: const TextStyle(
                                                color: LonIsleTheme.textDim,
                                                fontSize: 12)),
                                        Text(_formatDuration(total),
                                            style: const TextStyle(
                                                color: LonIsleTheme.textDim,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      // 倍速切换
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (final rate in _rates)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: ChoiceChip(
                                label: Text('${rate}x'),
                                selected: _playbackRate == rate,
                                onSelected: (_) {
                                  _player.setSpeed(rate);
                                  setState(() => _playbackRate = rate);
                                },
                                selectedColor: LonIsleTheme.primary,
                                backgroundColor: LonIsleTheme.bg3,
                                labelStyle: TextStyle(
                                  color: _playbackRate == rate
                                      ? Colors.white
                                      : LonIsleTheme.textDim,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }
}
