import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/local_store.dart';
import '../services/media_service.dart';
import '../state/server_connection.dart';
import '../theme.dart';
import 'sticker_manage_screen.dart';

/// 表情包面板（F-STICKER）：独立底部弹层（微信式）。
///
/// 结构：顶部「我的 / 服务器」分页 → 左侧包列表（图标竖排）→ 右侧表情网格。
/// - 我的：本地包（客户端管理，可进管理页）
/// - 服务器：管理员维护的包（成员只读，管理端变更实时同步）
///
/// [onEmoji] 点击 emoji 表情（插入输入框文本）
/// [onImage] 点击图片表情（发送附件消息，参数为附件引用 att:xxx）
Future<void> showStickerPanel(
  BuildContext context, {
  required ServerConnection sc,
  required void Function(String emoji) onEmoji,
  required void Function(String attRef) onImage,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: LonIsleTheme.bg2,
    isScrollControlled: true,
    // 高度自适应：内容少时面板矮（紧贴输入栏），最多 60% 屏（表情多时可滚）
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.6,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _StickerPanel(sc: sc, onEmoji: onEmoji, onImage: onImage),
  );
}

class _StickerPanel extends StatefulWidget {
  final ServerConnection sc;
  final void Function(String emoji) onEmoji;
  final void Function(String attRef) onImage;

  const _StickerPanel({
    required this.sc,
    required this.onEmoji,
    required this.onImage,
  });

  @override
  State<_StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends State<_StickerPanel> {
  int _tab = 0; // 0=我的 1=服务器
  List<LocalStickerPack> _localPacks = [];
  int _localPackIdx = 0;
  int _serverPackIdx = 0;

  @override
  void initState() {
    super.initState();
    _loadLocal();
    // 监听服务器表情包变更（管理端增删改排序 → STICKER_PACKS_UPDATED 推送 → 实时刷新面板）
    widget.sc.addListener(_onServerChanged);
  }

  @override
  void dispose() {
    widget.sc.removeListener(_onServerChanged);
    super.dispose();
  }

  void _onServerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLocal() async {
    final packs = await LocalStore.instance.listLocalStickerPacks();
    if (!mounted) return;
    setState(() {
      _localPacks = packs;
      if (_localPackIdx >= packs.length) _localPackIdx = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 内容自适应高度：showModalBottomSheet constraints 给 maxHeight，
    // Column mainAxisSize.min 让面板按内容收缩（表情少时紧贴输入栏，多时可达上限滚动）
    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部分页 + 管理入口
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                _tabButton(0, '我的'),
                const SizedBox(width: 12),
                _tabButton(1, '服务器'),
                const Spacer(),
                if (_tab == 0)
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StickerManageScreen(),
                        ),
                      );
                      _loadLocal();
                    },
                    icon: const Icon(Icons.edit_outlined,
                        size: 16, color: LonIsleTheme.primary),
                    label: const Text('管理我的包',
                        style: TextStyle(
                            fontSize: 13, color: LonIsleTheme.primary)),
                  ),
              ],
            ),
          ),
          const Divider(height: 12, color: LonIsleTheme.bg3),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ConstrainedBox(
                  // 限制内容区最大高度（面板过高时表情区可滚）
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: _tab == 0 ? _buildLocal() : _buildServer(),
                ),
              ),
            ),
          ),
        ],
    );
  }

  Widget _tabButton(int idx, String label) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? LonIsleTheme.primary : LonIsleTheme.bg3,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: active ? Colors.white : LonIsleTheme.textDim,
            fontWeight: active ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// 本地包（我的）
  Widget _buildLocal() {
    if (_localPacks.isEmpty) {
      return Center(
        child: Text('还没有本地表情包，点「管理我的包」创建',
            style: const TextStyle(color: LonIsleTheme.textDim, fontSize: 13)),
      );
    }
    final pack = _localPacks[_localPackIdx];
    return _buildPacksLayout(
      names: _localPacks.map((p) => p.name).toList(),
      selected: _localPackIdx,
      onSelect: (i) => setState(() => _localPackIdx = i),
      stickers: pack.stickers
          .map((s) => (type: s.type, content: s.content))
          .toList(),
    );
  }

  /// 服务器包
  Widget _buildServer() {
    final packs = widget.sc.serverStickerPacks;
    if (packs.isEmpty) {
      return Center(
        child: Text('服务器暂无表情包',
            style: const TextStyle(color: LonIsleTheme.textDim, fontSize: 13)),
      );
    }
    if (_serverPackIdx >= packs.length) _serverPackIdx = 0;
    final pack = packs[_serverPackIdx];
    return _buildPacksLayout(
      names: packs.map((p) => p.name).toList(),
      selected: _serverPackIdx,
      onSelect: (i) => setState(() => _serverPackIdx = i),
      stickers: pack.stickers
          .map((s) => (type: s.type, content: s.content))
          .toList(),
    );
  }

  /// 左侧包列表 + 右侧表情网格（微信式布局；左侧显示包名，crossAxisAlignment.start
  /// 防止表情 Wrap 在包列右侧上下居中显示）
  Widget _buildPacksLayout({
    required List<String> names,
    required int selected,
    required ValueChanged<int> onSelect,
    required List<({String type, String content})> stickers,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧包名列
        SizedBox(
          width: 72,
          child: ListView.builder(
            itemCount: names.length,
            itemBuilder: (context, i) {
              final active = i == selected;
              final name = names[i];
              // 包名超过 3 字时截断显示（左侧列空间有限）
              final short = name.characters.length > 3
                  ? name.characters.take(3).toString()
                  : name;
              return GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  height: 48,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? LonIsleTheme.bg3 : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    short.isEmpty ? '表情' : short,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: active
                          ? LonIsleTheme.textWhite
                          : LonIsleTheme.textDim,
                      fontWeight:
                          active ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const VerticalDivider(width: 1, color: LonIsleTheme.bg3),
        // 右侧表情区（图片按真实比例，emoji 固定方格子）
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              runAlignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                for (final s in stickers)
                  if (s.type == 'image')
                    // key 必须唯一：切换分组时强制重建 State（避免复用旧分组已加载的图）
                    _ImageStickerTile(
                      key: ValueKey('img-${s.content}'),
                      attRef: s.content,
                      onImage: widget.onImage,
                    )
                  else
                    GestureDetector(
                      key: ValueKey('emo-${s.content}'),
                      onTap: () => widget.onEmoji(s.content),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                          child: Text(s.content,
                              style: const TextStyle(fontSize: 28)),
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
}

/// 图片表情格子（下载缩略图展示，点击发送附件消息）
class _ImageStickerTile extends StatefulWidget {
  final String attRef;
  final void Function(String attRef) onImage;

  const _ImageStickerTile({
    super.key,
    required this.attRef,
    required this.onImage,
  });

  @override
  State<_ImageStickerTile> createState() => _ImageStickerTileState();
}

class _ImageStickerTileState extends State<_ImageStickerTile> {
  String? _path;
  Size? _size;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final attId = widget.attRef.replaceFirst('att:', '');
    final path = await MediaService.instance
        .download(attId)
        .catchError((_) => null as String?);
    if (path == null || !mounted) return;
    final size = await _decodeImageSize(File(path));
    if (mounted) setState(() {
      _path = path;
      _size = size;
    });
  }

  /// 解码图片真实尺寸（dart:ui，不解码全图）
  Future<Size?> _decodeImageSize(File f) async {
    try {
      final bytes = await f.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size =
          Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    final size = _size;
    return GestureDetector(
      onTap: () => widget.onImage(widget.attRef),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: path != null
            // 按真实比例：高度 56，宽度 = 56 × 宽高比（clamp 24~112 防过宽/过窄）
            ? SizedBox(
                height: 56,
                width: (size != null && size.width > 0 && size.height > 0)
                    ? (56 * size.width / size.height).clamp(24.0, 112.0)
                    : 56,
                child: Image.file(File(path), fit: BoxFit.cover),
              )
            : Container(
                width: 56,
                height: 56,
                color: LonIsleTheme.bg3,
                child: const Icon(Icons.image,
                    size: 20, color: LonIsleTheme.textDim),
              ),
      ),
    );
  }
}
