import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../proto/lonisle.pb.dart' as pb;
import '../services/media_service.dart';
import '../theme.dart';

/// 媒体查看器：图片（缩放）/ 视频（video_player 播放）/ 其他文件信息（F-MEDIA-6）
class MediaViewer extends StatefulWidget {
  final pb.Attachment attachment;

  /// 已下载的本地路径（可选；为空时先下载）
  final String? localPath;

  const MediaViewer({super.key, required this.attachment, this.localPath});

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  String? _localPath;
  bool _loading = true;
  String? _error;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = widget.localPath ??
          await MediaService.instance
              .download(widget.attachment.attachmentId);
      if (!mounted) return;

      // 视频：初始化播放器
      if (widget.attachment.kind == 'video') {
        final controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        if (!mounted) {
          controller.dispose();
          return;
        }
        controller.setLooping(true);
        // 加载完成自动播放
        await controller.play();
        if (!mounted) {
          controller.dispose();
          return;
        }
        setState(() {
          _videoController = controller;
          _localPath = path;
          _loading = false;
        });
      } else {
        setState(() {
          _localPath = path;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '加载失败：$e';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final att = widget.attachment;
    final sizeLabel = _humanSize(att.size.toInt());

    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: Text(
          '${att.kind} · $sizeLabel',
          style: const TextStyle(color: LonIsleTheme.textWhite),
        ),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
        actions: [
          // 下载（另存为，F-MEDIA-10 保留原始文件名）
          if (_localPath != null)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: '下载',
              onPressed: _saveAs,
            ),
        ],
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: LonIsleTheme.primary)
            : _error != null
                ? Text(_error!,
                    style: const TextStyle(color: LonIsleTheme.red))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final att = widget.attachment;
    // 视频（F-MEDIA-6：自动播放，点击暂停/播放）
    if (att.kind == 'video' && _videoController != null) {
      final controller = _videoController!;
      return Column(
        children: [
          // 画面区：Expanded 限定最大高度，AspectRatio 在约束内取最大尺寸。
          // 竖屏视频若按宽度算高会溢出窗口（BOTTOM OVERFLOWED）挤掉控制条
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
          ),
          // 底部控制条：播放/暂停 + 进度（可拖拽）
          Container(
            color: LonIsleTheme.bg2,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: LonIsleTheme.primary,
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        controller.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
                  ),
                  Expanded(
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      colors: const VideoProgressColors(
                        playedColor: LonIsleTheme.primary,
                        bufferedColor: LonIsleTheme.bg3,
                        backgroundColor: LonIsleTheme.bg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    // 图片（缩放查看）
    if (att.kind == 'image' && _localPath != null) {
      return InteractiveViewer(
        child: Image.file(File(_localPath!)),
      );
    }
    // 其他文件：信息卡片 + 下载按钮
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insert_drive_file,
            color: LonIsleTheme.textDim, size: 56),
        const SizedBox(height: 12),
        // 文件名最长 420，超出省略号（防超长文件名撑破窗口）
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            att.filename.isNotEmpty ? att.filename : '${att.kind} 文件',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: LonIsleTheme.textWhite, fontSize: 15),
          ),
        ),
        if (att.width > 0 && att.height > 0)
          Text(
            '${att.width}×${att.height}',
            style: const TextStyle(
                color: LonIsleTheme.textDim, fontSize: 12),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _saveAs,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('下载'),
          style: ElevatedButton.styleFrom(
            backgroundColor: LonIsleTheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 另存为：系统保存对话框（预填原始文件名）→ 复制已缓存文件。
  Future<void> _saveAs() async {
    final src = _localPath;
    if (src == null) return;
    // 原始文件名优先；缺失时用缓存文件名（已按魔数补扩展名）
    final name = widget.attachment.filename.isNotEmpty
        ? widget.attachment.filename
        : p.basename(src);
    try {
      // iOS/Android：file_picker 必须传 bytes；macOS/桌面：返回路径后自行复制
      String? savePath;
      if (Platform.isIOS || Platform.isAndroid) {
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: '保存附件',
          fileName: name,
          bytes: await File(src).readAsBytes(),
        );
      } else {
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: '保存附件',
          fileName: name,
        );
        if (savePath != null) await File(src).copy(savePath);
      }
      if (savePath == null) return; // 用户取消
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
