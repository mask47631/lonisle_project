import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/local_store.dart';
import '../services/media_service.dart';
import '../services/identity_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// 本地表情包管理页（F-STICKER）：包增删改名排序 + 包内表情增删排序。
/// 新加入的表情默认排在最前（sort 递减），用户可手动上移/下移调整。
class StickerManageScreen extends StatefulWidget {
  const StickerManageScreen({super.key});

  @override
  State<StickerManageScreen> createState() => _StickerManageScreenState();
}

class _StickerManageScreenState extends State<StickerManageScreen> {
  List<LocalStickerPack> _packs = [];
  final _nameCtrl = TextEditingController();
  String? _activePackId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final packs = await LocalStore.instance.listLocalStickerPacks();
    if (!mounted) return;
    setState(() {
      _packs = packs;
      if (_activePackId != null &&
          !packs.any((p) => p.id == _activePackId)) {
        _activePackId = null;
      }
    });
  }

  Future<void> _createPack() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入包名')));
      return;
    }
    await LocalStore.instance.saveLocalStickerPack(id: '', name: name, icon: '📦');
    _nameCtrl.clear();
    await _load();
  }

  Future<void> _renamePack(LocalStickerPack pack) async {
    final ctrl = TextEditingController(text: pack.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('重命名表情包',
            style: TextStyle(color: LonIsleTheme.textWhite)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: LonIsleTheme.textWhite),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('保存',
                  style: TextStyle(color: LonIsleTheme.primary))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await LocalStore.instance
          .saveLocalStickerPack(id: pack.id, name: name, icon: pack.icon);
      await _load();
    }
  }

  Future<void> _movePack(int idx, int dir) async {
    final j = idx + dir;
    if (j < 0 || j >= _packs.length) return;
    final ids = _packs.map((p) => p.id).toList();
    final t = ids[idx];
    ids[idx] = ids[j];
    ids[j] = t;
    await LocalStore.instance.reorderLocal(ids: ids);
    await _load();
  }

  /// 从相册选图片/GIF 作为表情：上传当前服务器附件（自动去重）→ 存 att:xxx 引用。
  /// 用 file_picker 拿原始文件（image_picker 会重编码导致 GIF 变静态帧）。
  Future<void> _addImage(String packId) async {
    final sc = AppState.instance.activeServer;
    if (sc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未连接服务器，无法上传图片表情')));
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final data = await File(path).readAsBytes();
    final addr = '${sc.connection.host}:${sc.connection.port}';
    final id = await IdentityService.instance.loadIdentity();
    if (id == null) return;
    try {
      final att = await MediaService.instance.upload(
        data: data,
        filename: result.files.single.name,
        msgId: 'sticker-${DateTime.now().microsecondsSinceEpoch}',
        kind: 'image',
        userId: id.userId,
        serverAddress: addr,
      );
      await LocalStore.instance.addLocalSticker(
          packId: packId, type: 'image', content: 'att:${att.attachmentId}');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('图片上传失败：$e')));
      }
    }
  }

  Future<void> _moveSticker(String packId, int idx, int dir) async {
    final pack = _packs.firstWhere((p) => p.id == packId);
    final j = idx + dir;
    if (j < 0 || j >= pack.stickers.length) return;
    final ids = pack.stickers.map((s) => s.id).toList();
    final t = ids[idx];
    ids[idx] = ids[j];
    ids[j] = t;
    await LocalStore.instance.reorderLocal(packId: packId, ids: ids);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('本地表情包',
            style: TextStyle(color: LonIsleTheme.textWhite, fontSize: 16)),
      ),
      body: Column(
        children: [
          // 新建包
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: LonIsleTheme.textWhite),
                    decoration: InputDecoration(
                      hintText: '新包名（如：我的表情）',
                      hintStyle:
                          const TextStyle(color: LonIsleTheme.textDim),
                      filled: true,
                      fillColor: LonIsleTheme.bg2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _createPack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LonIsleTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('创建'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: LonIsleTheme.bg3),
          Expanded(
            child: _packs.isEmpty
                ? const Center(
                    child: Text('还没有表情包，先创建一个吧',
                        style: TextStyle(color: LonIsleTheme.textDim)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _packs.length,
                    itemBuilder: (context, i) =>
                        _buildPackCard(_packs[i], i),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackCard(LocalStickerPack pack, int idx) {
    final active = pack.id == _activePackId;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LonIsleTheme.bg2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 包头部：名称 + 操作
          Row(
            children: [
              Expanded(
                child: Text(pack.name,
                    style: const TextStyle(
                        color: LonIsleTheme.textWhite,
                        fontWeight: FontWeight.w500,
                        fontSize: 15)),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_upward,
                    size: 16, color: LonIsleTheme.textDim),
                onPressed: () => _movePack(idx, -1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_downward,
                    size: 16, color: LonIsleTheme.textDim),
                onPressed: () => _movePack(idx, 1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined,
                    size: 16, color: LonIsleTheme.textDim),
                onPressed: () => _renamePack(pack),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline,
                    size: 16, color: LonIsleTheme.red),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: LonIsleTheme.bg2,
                      title: const Text('删除表情包？',
                          style:
                              TextStyle(color: LonIsleTheme.textWhite)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('删除',
                                style: TextStyle(
                                    color: LonIsleTheme.red))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await LocalStore.instance
                        .deleteLocalStickerPack(pack.id);
                    await _load();
                  }
                },
              ),
            ],
          ),
          // 表情列表（平铺）
          if (pack.stickers.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.start,
              runAlignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                for (var j = 0; j < pack.stickers.length; j++)
                  _stickerChip(pack, j),
              ],
            ),
          // 加表情（仅图片/GIF 上传）
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addImage(pack.id),
              icon: const Icon(Icons.add_photo_alternate_outlined,
                  size: 16, color: LonIsleTheme.primary),
              label: const Text('相册图片/GIF',
                  style: TextStyle(
                      fontSize: 13, color: LonIsleTheme.primary)),
            ),
          ),
          if (!active)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _activePackId = pack.id),
                child: const Text('收起',
                    style: TextStyle(
                        fontSize: 12, color: LonIsleTheme.textDim)),
              ),
            ),
        ],
      ),
    );
  }

  /// 单个表情 chip：内容（emoji 或图片缩略图）+ 上移/下移/删除
  Widget _stickerChip(LocalStickerPack pack, int idx) {
    final s = pack.stickers[idx];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LonIsleTheme.bg3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.type == 'image')
            _thumb(s.content)
          else
            Text(s.content, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 4),
          _chipAction(
            icon: Icons.arrow_upward,
            color: LonIsleTheme.textDim,
            onTap: () => _moveSticker(pack.id, idx, -1),
          ),
          _chipAction(
            icon: Icons.arrow_downward,
            color: LonIsleTheme.textDim,
            onTap: () => _moveSticker(pack.id, idx, 1),
          ),
          _chipAction(
            icon: Icons.delete_outline,
            color: LonIsleTheme.red,
            onTap: () async {
              await LocalStore.instance.deleteLocalSticker(s.id);
              await _load();
            },
          ),
        ],
      ),
    );
  }

  /// 表情 chip 内的圆形操作按钮（28×28 可点区域 + 18px 图标）
  Widget _chipAction(
      {required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  /// 图片表情缩略图（按真实宽高比展示，高度固定 40，宽度按比例）
  Widget _thumb(String attRef) {
    return FutureBuilder<String?>(
      future: MediaService.instance
          .download(attRef.replaceFirst('att:', ''))
          .catchError((_) => null as String?),
      builder: (context, snap) {
        final path = snap.data;
        if (path == null) {
          return const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.image, size: 18, color: LonIsleTheme.textDim),
          );
        }
        return FutureBuilder<Size?>(
          future: _decodeImageSize(File(path)),
          builder: (context, sizeSnap) {
            final size = sizeSnap.data;
            if (size == null || size.width <= 0 || size.height <= 0) {
              return SizedBox(
                width: 40,
                height: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(File(path),
                      fit: BoxFit.cover, width: 40, height: 40),
                ),
              );
            }
            // 按真实比例：高度 40，宽度 = 40 × 宽高比（最长边上限 120 防过宽）
            final ratio = size.width / size.height;
            final w = (40 * ratio).clamp(20.0, 120.0);
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.file(File(path),
                  width: w, height: 40, fit: BoxFit.cover),
            );
          },
        );
      },
    );
  }

  /// 解码图片真实尺寸（dart:ui，不解码全图）
  Future<Size?> _decodeImageSize(File f) async {
    try {
      final bytes = await f.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }
}
