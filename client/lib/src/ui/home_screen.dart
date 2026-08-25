import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/voice_recorder.dart';
import 'package:video_player/video_player.dart';

import '../models/message.dart';
import '../services/identity_service.dart';
import '../services/media_service.dart';
import '../services/av_session.dart';
import '../services/video_thumb.dart';
import 'archive_screen.dart';
import 'notification_center.dart';
import '../proto/lonisle.pb.dart' as pb;
import '../services/connection_service.dart';
import '../state/app_state.dart';
import '../state/server_connection.dart';
import '../theme.dart';
import 'add_server_screen.dart';
import 'av_room.dart';
import 'device_screen.dart';
import 'media_viewer.dart';
import 'role_manager.dart';
import 'search_screen.dart';
import 'sticker_panel.dart';
import 'settings_screen.dart';
import 'voice_player.dart';
import 'inline_voice_player.dart';

/// 主界面：类 Discord 三栏布局
/// 左：多服务器栏 | 中：话题/成员栏 | 右：消息区
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// 回复请求流：消息菜单 → 主界面回复状态（F-MSG-6）
  static final StreamController<ChatMessage> replyRequest =
      StreamController<ChatMessage>.broadcast();

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _inputController = TextEditingController();
  bool _showMembers = false;
  ChatMessage? _replyTo; // 当前正在回复的消息（F-MSG-6）
  StreamSubscription<ChatMessage>? _replySub;

  @override
  void initState() {
    super.initState();
    _replySub = HomeScreen.replyRequest.stream.listen((m) {
      setState(() => _replyTo = m);
    });
  }

  @override
  void dispose() {
    _replySub?.cancel();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text;
    if (text.trim().isEmpty) return;
    _inputController.clear();
    final sc = AppState.instance.activeServer;
    if (sc != null) {
      final ok = await sc.sendText(text, replyTo: _replyTo?.msgId ?? '');
      if (!ok && mounted) {
        // 发送失败：恢复输入框内容（便于修改重发）+ 明确提示
        _inputController.text = text;
        _inputController.selection = TextSelection.collapsed(offset: text.length);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('消息发送失败，已恢复输入（可点击失败消息重试）')),
        );
      }
    }
    if (_replyTo != null) setState(() => _replyTo = null);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final sc = state.activeServer;
    // 尚未添加服务器：显示空状态引导页（可添加服务器或进入设置）
    if (sc == null) return const _EmptyHome();

    // 移动端窄屏：单栏布局（Drawer 切服务器 + AppBar 切话题）
    if (MediaQuery.of(context).size.width < 600) {
      return ListenableBuilder(
        listenable: sc,
        builder: (context, _) => _buildMobile(context, sc),
      );
    }

    // 监听 ServerConnection 变化（消息/成员/话题/状态更新时重建）
    return ListenableBuilder(
      listenable: sc,
      builder: (context, _) => Scaffold(
        body: Row(
          children: [
            // 不能加 const：const 会让 diff 时 identical 直接跳过 build，
            // 服务器图标/未读变化永远刷不出来
            _ServerRail(),
            _TopicPanel(
              sc: sc,
              showMembers: _showMembers,
              onToggleMembers: () => setState(() => _showMembers = !_showMembers),
            ),
            Expanded(
              child: Column(
                children: [
                  if (sc.expelled)
                    _ExpelledBanner(sc: sc)
                  else if (sc.connection.migrationTarget.isNotEmpty)
                    _MigrationBanner(sc: sc),
                  _MessageHeader(sc: sc),
                  Expanded(
                    child: _MessageList(sc: sc, messages: sc.messages),
                  ),
                  // 音视频会话控制条（驻留：在房间内也能浏览/发言其他话题）
                  ListenableBuilder(
                    listenable: state,
                    builder: (context, _) {
                      final session = state.avSession;
                      if (session == null) return const SizedBox.shrink();
                      return ListenableBuilder(
                        listenable: session,
                        builder: (context, _) => _AvBar(session: session),
                      );
                    },
                  ),
                  // 公告话题普通成员禁言（F-TOPIC-4：仅管理员可发）
                  sc.currentTopicAnnouncement && !sc.isAdmin
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: LonIsleTheme.bg2,
                          child: const Text(
                            '📢 公告话题：仅管理员可发言',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: LonIsleTheme.textDim, fontSize: 13),
                          ),
                        )
                      : _MessageInput(
                          controller: _inputController,
                          onSend: _send,
                          replyTo: _replyTo,
                          onCancelReply: () =>
                              setState(() => _replyTo = null),
                          members: sc.members,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 移动端单栏布局（窄屏适配）：Drawer 切服务器 + 顶部横向话题栏
  Widget _buildMobile(BuildContext context, ServerConnection sc) {
    final state = AppState.instance;
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      drawer: Drawer(
        backgroundColor: LonIsleTheme.bg,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 个人资料入口（F-PROF：昵称/头像/设备管理等，复用桌面服务器菜单）
              Builder(builder: (drawerCtx) {
                final self = sc.selfMember;
                final myName = self?.serverNickname.isNotEmpty == true
                    ? self!.serverNickname
                    : AppState.instance.identity?.displayName ?? '未命名';
                return ListTile(
                  leading: _Avatar(
                    seed: self?.userId ?? 'u',
                    size: 38,
                    avatarRef: self?.avatarSeed ?? '',
                    serverAddress: '${sc.host}:${sc.port}',
                  ),
                  title: Text(
                    myName,
                    style: const TextStyle(
                        color: LonIsleTheme.textWhite,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text(
                    '个人信息 · 服务器管理',
                    style: TextStyle(
                        color: LonIsleTheme.textDim, fontSize: 11),
                  ),
                  onTap: () {
                    // 关闭抽屉用 drawerCtx，后续弹窗必须用页面级 context
                    //（drawer 关闭后其 context 失效，桌面端菜单在此之上叠加弹窗）
                    Navigator.pop(drawerCtx);
                    // 移动端：底部弹层（大尺寸 ListTile，手机易点击）；
                    // 桌面端：沿用 SimpleDialog（紧凑，鼠标操作方便）
                    if (MediaQuery.of(context).size.width < 600) {
                      _showMobileServerMenu(context, sc);
                    } else {
                      _showServerMenu(context, sc);
                    }
                  },
                );
              }),
              const Divider(height: 1, color: LonIsleTheme.bg2),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  '服务器',
                  style: TextStyle(color: LonIsleTheme.textDim, fontSize: 12),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final s in state.servers)
                      ListTile(
                        leading: s.serverIcon.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: FutureBuilder<String?>(
                                  future: MediaService.instance.downloadServerIcon(
                                      '${s.host}:${s.port}', s.serverIcon),
                                  builder: (context, snap) =>
                                      snap.hasData && snap.data != null
                                          ? Image.file(File(snap.data!),
                                              width: 32,
                                              height: 32,
                                              fit: BoxFit.cover)
                                          : _serverIconLetter(s.serverName,
                                              size: 32),
                                ),
                              )
                            : _serverIconLetter(s.serverName, size: 32),
                        title: Text(
                          s.serverName.isEmpty
                              ? '${s.host}:${s.port}'
                              : s.serverName,
                          style: const TextStyle(color: LonIsleTheme.textWhite),
                        ),
                        selected: s == sc,
                        selectedTileColor: LonIsleTheme.bg2,
                        onTap: () {
                          Navigator.pop(context);
                          state.switchServer(s.serverId);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: LonIsleTheme.bg2),
              ListTile(
                leading: Icon(Icons.add, color: LonIsleTheme.textDim),
                title: const Text('添加服务器',
                    style: TextStyle(color: LonIsleTheme.textWhite)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddServerScreen()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.settings, color: LonIsleTheme.textDim),
                title: const Text('设置',
                    style: TextStyle(color: LonIsleTheme.textWhite)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
        title: InkWell(
          onTap: () => _showServerInfo(context, sc),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              // 服务器图标（未设置回退首字母），点击查看服务器信息
              if (sc.serverIcon.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: FutureBuilder<String?>(
                    future: MediaService.instance.downloadServerIcon(
                        '${sc.host}:${sc.port}', sc.serverIcon),
                    builder: (context, snap) => snap.hasData &&
                            snap.data != null
                        ? Image.file(File(snap.data!),
                            width: 28, height: 28, fit: BoxFit.cover)
                        : _serverIconLetter(sc.serverName, size: 28),
                  ),
                )
              else
                _serverIconLetter(sc.serverName, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sc.serverName.isEmpty ? 'LonIsle' : sc.serverName,
                  style: const TextStyle(
                      color: LonIsleTheme.textWhite, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // 横向话题栏：未读角标一目了然（F-UI-4），AV 话题点击进入房间
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: sc.topics.length,
              separatorBuilder: (context, index) => const SizedBox(width: 4),
              itemBuilder: (ctx, i) {
                final t = sc.topics[i];
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: _TopicItem(
                    sc: sc,
                    topic: t,
                    active: t.topicId == sc.currentTopicId,
                  ),
                );
              },
            ),
          ),
          if (sc.expelled) _ExpelledBanner(sc: sc),
          _MessageHeader(sc: sc),
          Expanded(
            child: _MessageList(sc: sc, messages: sc.messages),
          ),
          // 音视频会话驻留
          ListenableBuilder(
            listenable: state,
            builder: (ctx, _) {
              final session = state.avSession;
              if (session == null) return const SizedBox.shrink();
              return ListenableBuilder(
                listenable: session,
                builder: (ctx, _) => _AvBar(session: session),
              );
            },
          ),
          // 公告话题普通成员禁言
          sc.currentTopicAnnouncement && !sc.isAdmin
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: LonIsleTheme.bg2,
                  child: const Text(
                    '📢 公告话题：仅管理员可发言',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: LonIsleTheme.textDim, fontSize: 13),
                  ),
                )
              : _MessageInput(
                  controller: _inputController,
                  onSend: _send,
                  replyTo: _replyTo,
                  onCancelReply: () => setState(() => _replyTo = null),
                  members: sc.members,
                ),
        ],
      ),
    );
  }
}

/// 无服务器时的空状态引导页（跳过 onboarding 后的落点）
class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset('assets/logo.png', width: 72, height: 72),
            ),
            const SizedBox(height: 20),
            const Text(
              '尚未添加服务器',
              style: TextStyle(
                color: LonIsleTheme.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '添加一个服务器即可开始聊天，也可以先逛逛设置。',
              style: TextStyle(color: LonIsleTheme.textDim, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddServerScreen()),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加服务器'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LonIsleTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('设置'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LonIsleTheme.textWhite,
                    side: const BorderSide(color: LonIsleTheme.textDim),
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

/// 左侧多服务器栏（窄竖栏）
class _ServerRail extends StatelessWidget {
  const _ServerRail();

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final active = state.activeServer;
    return Container(
      width: 72,
      color: LonIsleTheme.bg,
      child: Column(
        children: [
          const SizedBox(height: 16),
          const _RailLogo(),
          const SizedBox(height: 16),
          // 服务器列表
          Expanded(
            child: ListView(
              children: [
                for (final sc in state.servers)
                  _ServerAvatar(
                    name: sc.serverName,
                    active: sc == active,
                    unread: sc.unread,
                    iconVersion: sc.serverIcon,
                    serverAddress: '${sc.host}:${sc.port}',
                    onTap: () => state.switchServer(_serverKey(state, sc)),
                  ),
                // 添加服务器按钮
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddServerScreen()),
                    );
                  },
                  icon: const Icon(Icons.add, color: LonIsleTheme.textDim),
                  tooltip: '添加服务器',
                ),
              ],
            ),
          ),
          // 通知中心入口（F-UI-3，带全局未读角标 F-UI-4）
          ListenableBuilder(
            listenable: state,
            builder: (context, _) {
              final total = state.totalUnread;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationCenterScreen()),
                      );
                    },
                    icon: const Icon(Icons.notifications_outlined,
                        color: LonIsleTheme.textDim),
                    tooltip: '通知中心',
                  ),
                  if (total > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: LonIsleTheme.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        child: Text(
                          total > 99 ? '99+' : '$total',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: Colors.white, fontSize: 9),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
            icon: const Icon(Icons.search, color: LonIsleTheme.textDim),
            tooltip: '搜索',
          ),
          IconButton(
            onPressed: () => _showServerMenu(context, active),
            icon: const Icon(Icons.settings, color: LonIsleTheme.textDim),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _serverKey(AppState state, ServerConnection sc) {
    for (final e in state.servers) {
      if (identical(e, sc)) return sc.serverId;
    }
    return sc.serverId;
  }
}

/// 服务器菜单（设备管理/助记词导出/退出）
Future<void> _showServerMenu(BuildContext context, ServerConnection? sc) async {
  if (sc == null) return;
  showDialog(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: LonIsleTheme.bg2,
      children: [
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DeviceScreen(sc: sc)),
            );
          },
          child: const Text('设备管理', style: TextStyle(color: LonIsleTheme.textWhite)),
        ),
        // 角色管理（管理员可见）
        if (sc.isAdmin)
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoleManagerScreen(sc: sc)),
              );
            },
            child: const Text('角色管理', style: TextStyle(color: LonIsleTheme.textWhite)),
          ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            _showGlobalProfileEditor(context);
          },
          child: const Text('修改全局昵称', style: TextStyle(color: LonIsleTheme.textWhite)),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            _changeGlobalAvatar(context);
          },
          child: const Text('修改全局头像', style: TextStyle(color: LonIsleTheme.textWhite)),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            _changeServerAvatar(context, sc);
          },
          child: const Text('设置本服务器头像', style: TextStyle(color: LonIsleTheme.textWhite)),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            _showServerProfileEditor(context, sc);
          },
          child: const Text('设置本服务器昵称', style: TextStyle(color: LonIsleTheme.textWhite)),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArchiveScreen()),
            );
          },
          child: const Text('归档服务器', style: TextStyle(color: LonIsleTheme.textWhite)),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
          child: const Text('设置', style: TextStyle(color: LonIsleTheme.textWhite)),
        ),
        // 迁移提示（P1）
        if (sc.connection.migrationTarget.isNotEmpty)
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmMigration(context, sc);
            },
            child: const Text('服务器已迁移（点击转移）', style: TextStyle(color: LonIsleTheme.amber)),
          ),
        SimpleDialogOption(
          onPressed: () async {
            await AppState.instance.leaveActiveServer();
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('退出服务器', style: TextStyle(color: LonIsleTheme.red)),
        ),
      ],
    ),
  );
}

/// 移动端服务器菜单（底部弹层，大尺寸 ListTile 易点击）
Future<void> _showMobileServerMenu(BuildContext context, ServerConnection sc) async {
  // 通用动作：先关闭弹层，再执行业务（Navigator.pop 用 sheet 自己的 ctx）
  void run(VoidCallback action, BuildContext sheetCtx) {
    Navigator.pop(sheetCtx);
    action();
  }

  await showModalBottomSheet(
    context: context,
    backgroundColor: LonIsleTheme.bg2,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽条
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: LonIsleTheme.textDim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.devices, color: LonIsleTheme.textDim),
            title: const Text('设备管理', style: TextStyle(color: LonIsleTheme.textWhite)),
            onTap: () => run(
              () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => DeviceScreen(sc: sc))),
              sheetCtx,
            ),
          ),
          if (sc.isAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: LonIsleTheme.textDim),
              title: const Text('角色管理', style: TextStyle(color: LonIsleTheme.textWhite)),
              onTap: () => run(
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => RoleManagerScreen(sc: sc))),
                sheetCtx,
              ),
            ),
          const Divider(height: 1, color: LonIsleTheme.bg3),
          ListTile(
            leading: const Icon(Icons.badge, color: LonIsleTheme.textDim),
            title: const Text('修改全局昵称', style: TextStyle(color: LonIsleTheme.textWhite)),
            onTap: () => run(() => _showGlobalProfileEditor(context), sheetCtx),
          ),
          ListTile(
            leading: const Icon(Icons.face, color: LonIsleTheme.textDim),
            title: const Text('修改全局头像', style: TextStyle(color: LonIsleTheme.textWhite)),
            onTap: () => run(() => _changeGlobalAvatar(context), sheetCtx),
          ),
          ListTile(
            leading: const Icon(Icons.image, color: LonIsleTheme.textDim),
            title: const Text('设置本服务器头像', style: TextStyle(color: LonIsleTheme.textWhite)),
            onTap: () => run(() => _changeServerAvatar(context, sc), sheetCtx),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note, color: LonIsleTheme.textDim),
            title: const Text('设置本服务器昵称', style: TextStyle(color: LonIsleTheme.textWhite)),
            onTap: () => run(() => _showServerProfileEditor(context, sc), sheetCtx),
          ),
          const Divider(height: 1, color: LonIsleTheme.bg3),
          ListTile(
            leading: const Icon(Icons.archive, color: LonIsleTheme.textDim),
            title: const Text('归档服务器', style: TextStyle(color: LonIsleTheme.textWhite)),
            onTap: () => run(
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchiveScreen())),
              sheetCtx,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: LonIsleTheme.textDim),
            title: const Text('设置', style: TextStyle(color: LonIsleTheme.textWhite)),
            onTap: () => run(
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              sheetCtx,
            ),
          ),
          if (sc.connection.migrationTarget.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: LonIsleTheme.amber),
              title: const Text('服务器已迁移（点击转移）',
                  style: TextStyle(color: LonIsleTheme.amber)),
              onTap: () => run(() => _confirmMigration(context, sc), sheetCtx),
            ),
          ListTile(
            leading: const Icon(Icons.logout, color: LonIsleTheme.red),
            title: const Text('退出服务器', style: TextStyle(color: LonIsleTheme.red)),
            onTap: () async {
              Navigator.pop(sheetCtx);
              await AppState.instance.leaveActiveServer();
            },
          ),
        ],
      ),
    ),
  );
}

/// 全局资料编辑器：修改后弹窗勾选要同步的服务器（F-PROF-6）。
Future<void> _showGlobalProfileEditor(BuildContext context) async {
  final state = AppState.instance;
  final controller = TextEditingController(text: state.identity?.displayName ?? '');
  final newName = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: LonIsleTheme.bg2,
      title: const Text('全局昵称', style: TextStyle(color: LonIsleTheme.textWhite)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: LonIsleTheme.textWhite),
        decoration: const InputDecoration(hintText: '新的全局昵称'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('下一步'),
        ),
      ],
    ),
  );
  if (newName == null || newName.trim().isEmpty) return;
  if (!context.mounted) return;

  // 弹窗勾选要同步的服务器
  final servers = state.servers;
  final selected = <ServerConnection>{};
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('同步到哪些服务器？', style: TextStyle(color: LonIsleTheme.textWhite)),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final s in servers)
                CheckboxListTile(
                  title: Text(s.serverName, style: const TextStyle(color: LonIsleTheme.textWhite)),
                  value: selected.contains(s),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        selected.add(s);
                      } else {
                        selected.remove(s);
                      }
                    });
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认同步')),
        ],
      ),
    ),
  );
  if (confirmed != true) return;

  // 全局资料本地落地（F-PROF-2）
  await IdentityService.instance.setDisplayName(newName.trim());
  await AppState.instance.reloadIdentity();

  // 逐一向勾选的服务器同步资料覆盖
  for (final s in selected) {
    await s.updateServerProfile(nickname: newName.trim());
  }
}

/// 选择头像图片（压缩到 512 内），选中取消返回 null
Future<({Uint8List data, String name})?> _pickAvatarImage() async {
  final picker = ImagePicker();
  final xfile = await picker.pickImage(
      source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
  if (xfile == null) return null;
  return (data: await xfile.readAsBytes(), name: xfile.name);
}

/// 上传头像附件并返回 'att:<id>' 引用（F-PROF-7：头像存服务器）
Future<String> _uploadAvatarRef(
    ServerConnection sc, Uint8List data, String name) async {
  final id = await IdentityService.instance.loadIdentity();
  if (id == null) throw StateError('身份未加载');
  final att = await MediaService.instance.upload(
    data: data,
    filename: name,
    msgId: 'avatar-${DateTime.now().microsecondsSinceEpoch}',
    kind: 'avatar',
    userId: id.userId,
    serverAddress: '${sc.connection.host}:${sc.connection.port}',
  );
  return 'att:${att.attachmentId}';
}

/// 设置本服务器头像（F-PROF-3：服务器内覆盖）
Future<void> _changeServerAvatar(BuildContext context, ServerConnection sc) async {
  final picked = await _pickAvatarImage();
  if (picked == null) return;
  try {
    final ref = await _uploadAvatarRef(sc, picked.data, picked.name);
    await sc.updateServerProfile(avatar: ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本服务器头像已更新')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('头像设置失败：$e')),
      );
    }
  }
}

/// 修改全局头像（F-PROF-2/6）：选图 → 勾选服务器 → 逐服务器上传并推送覆盖。
/// 附件 ID 是服务器局部资源，必须逐服务器上传（F-PROF-7）。
Future<void> _changeGlobalAvatar(BuildContext context) async {
  final state = AppState.instance;
  final picked = await _pickAvatarImage();
  if (picked == null || !context.mounted) return;

  // 弹窗勾选要同步的服务器（与全局昵称一致，F-PROF-6）
  final servers = state.servers;
  final selected = <ServerConnection>{};
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('同步到哪些服务器？', style: TextStyle(color: LonIsleTheme.textWhite)),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final s in servers)
                CheckboxListTile(
                  title: Text(s.serverName, style: const TextStyle(color: LonIsleTheme.textWhite)),
                  value: selected.contains(s),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        selected.add(s);
                      } else {
                        selected.remove(s);
                      }
                    });
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认同步')),
        ],
      ),
    ),
  );
  if (confirmed != true || selected.isEmpty) return;

  var okCount = 0;
  String? firstRef;
  for (final s in selected) {
    try {
      final ref = await _uploadAvatarRef(s, picked.data, picked.name);
      firstRef ??= ref;
      await s.updateServerProfile(avatar: ref);
      okCount++;
    } catch (_) {}
  }

  // 本地全局头像标识（F-PROF-2）：att 引用仅在上传过的服务器可解析，
  // 其余服务器/场景自动回退 Identicon
  if (firstRef != null) {
    await IdentityService.instance.setAvatarSeed(firstRef);
    await AppState.instance.reloadIdentity();
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('全局头像已同步到 $okCount/${selected.length} 个服务器')),
    );
  }
}

/// 本服务器昵称编辑器（F-PROF-3：per-server 覆盖，不影响其他服务器与全局）。
Future<void> _showServerProfileEditor(
    BuildContext context, ServerConnection sc) async {
  final controller = TextEditingController(
      text: sc.selfMember?.serverNickname.isNotEmpty == true
          ? sc.selfMember!.serverNickname
          : sc.selfMember?.displayName ?? '');
  final newName = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: LonIsleTheme.bg2,
      title: Text('在「${sc.serverName}」的昵称',
          style: const TextStyle(color: LonIsleTheme.textWhite, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: LonIsleTheme.textWhite),
            decoration: const InputDecoration(hintText: '本服务器显示的昵称'),
          ),
          const SizedBox(height: 8),
          const Text(
            '仅在该服务器生效，不影响其他服务器与全局昵称。',
            style: TextStyle(color: LonIsleTheme.textDim, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('保存', style: TextStyle(color: LonIsleTheme.primary)),
        ),
      ],
    ),
  );
  if (newName == null || newName.trim().isEmpty || !context.mounted) return;
  await sc.updateServerProfile(nickname: newName.trim());
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('本服务器昵称已更新')),
    );
  }
}

/// 迁移确认：用户确认后转移到新服务器并归档旧服务器（F-JOIN-8）。
Future<void> _confirmMigration(BuildContext context, ServerConnection sc) async {
  final target = sc.connection.migrationTarget;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: LonIsleTheme.bg2,
      title: const Text('服务器迁移', style: TextStyle(color: LonIsleTheme.textWhite)),
      content: Text(
        '该服务器已迁移到：$target\n\n点击确认后将连接新服务器并归档当前服务器。',
        style: const TextStyle(color: LonIsleTheme.textDim),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认迁移')),
      ],
    ),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;

  // 解析新地址并连接
  final parts = target.split(':');
  if (parts.length == 2) {
    final host = parts[0];
    final port = int.tryParse(parts[1]) ?? 8080;
    try {
      await AppState.instance.connectAndJoin(host, port);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('迁移失败：$e')),
        );
      }
    }
  }
}

/// 社区介绍卡（点击社区名称弹出）：名称/图标/简介/策略/人数/状态/限额
void _showServerInfo(BuildContext context, ServerConnection sc) {
  final conn = sc.connection;
  final total = sc.members.length;
  final online = sc.members.where((m) => m.isOnline).length;
  final addr = '${sc.host}:${sc.port}';

  final statusLabel = switch (sc.status) {
    ConnectionStatus.connected => '已连接',
    ConnectionStatus.connecting => '连接中…',
    ConnectionStatus.reconnecting => '重连中…',
    ConnectionStatus.disconnected => '已断开',
  };
  final strategyLabel = switch (conn.serverStrategy) {
    1 => '审批加入',
    2 => '开放加入',
    3 => '仅邀请',
    _ => '未知',
  };
  String mb(int bytes) {
    final mbVal = bytes / 1024 / 1024;
    if (mbVal >= 1024) {
      return '${(mbVal / 1024).toStringAsFixed(1)} GB';
    }
    return '${mbVal.toStringAsFixed(mbVal == mbVal.roundToDouble() ? 0 : 1)} MB';
  }
  final rate = conn.rateLimitPerMinute <= 0
      ? '不限'
      : '${conn.rateLimitPerMinute} 条/分钟';
  final maxAtt = conn.maxAttachmentSize <= 0 ? '不限' : mb(conn.maxAttachmentSize);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: LonIsleTheme.bg2,
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标（未设置回退首字母）
            if (conn.serverIcon.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: FutureBuilder<String?>(
                  future: MediaService.instance
                      .downloadServerIcon(addr, conn.serverIcon),
                  builder: (context, snap) => snap.hasData && snap.data != null
                      ? Image.file(File(snap.data!),
                          width: 64, height: 64, fit: BoxFit.cover)
                      : _serverIconLetter(sc.serverName),
                ),
              )
            else
              _serverIconLetter(sc.serverName),
            const SizedBox(height: 12),
            Text(
              sc.serverName.isEmpty ? '服务器' : sc.serverName,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: LonIsleTheme.textWhite),
            ),
            const SizedBox(height: 6),
            Text(
              conn.serverDesc.isEmpty ? '暂无简介' : conn.serverDesc,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: LonIsleTheme.textDim),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0x0DFFFFFF)),
            const SizedBox(height: 8),
            _infoRow('加入策略', strategyLabel),
            _infoRow('成员', '$online 在线 / $total 人'),
            _infoRow('服务器状态', statusLabel),
            _infoRow('服务端版本', conn.serverVersion.isEmpty ? '未知' : conn.serverVersion),
            _infoRow('发言限速', rate),
            _infoRow('附件上限', maxAtt),
            _infoRow('地址', addr),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

/// 信息行（标签 + 值）
Widget _infoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: LonIsleTheme.textDim)),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 13, color: LonIsleTheme.textWhite)),
        ),
      ],
    ),
  );
}

/// 社区图标占位（首字母）
Widget _serverIconLetter(String name, {double size = 64}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: LonIsleTheme.bg3,
      borderRadius: BorderRadius.circular(size * 0.28),
    ),
    child: Center(
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : 'S',
        style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w700,
            color: LonIsleTheme.textWhite),
      ),
    ),
  );
}

class _RailLogo extends StatelessWidget {
  const _RailLogo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        'assets/logo.png',
        width: 48,
        height: 48,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _ServerAvatar extends StatelessWidget {
  final String name;
  final bool active;
  final int unread;
  final VoidCallback onTap;

  /// 服务器图标版本标识（"ext:ts"，空则显示首字母）与服务器地址
  final String iconVersion;
  final String serverAddress;

  const _ServerAvatar({
    required this.name,
    required this.active,
    required this.unread,
    required this.onTap,
    this.iconVersion = '',
    this.serverAddress = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        // Stack 默认 topStart 对齐会使 48px 方块在 72px 栏中靠左，
        // 这里用 Center 居中；角标挂在 48px 方块上（clipBehavior.none 防裁切）
        child: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                color: LonIsleTheme.bg3,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? LonIsleTheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              // 已设置图标：下载渲染（失败回退首字母）
              child: iconVersion.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: FutureBuilder<String?>(
                        future: MediaService.instance.downloadServerIcon(
                            serverAddress, iconVersion),
                        builder: (context, snap) {
                          if (snap.hasData && snap.data != null) {
                            return Image.file(
                              File(snap.data!),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _letterMark(),
                            );
                          }
                          return _letterMark();
                        },
                      ),
                    )
                  : _letterMark(),
            ),
            // 未读角标
            if (unread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: LonIsleTheme.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 首字母占位（未设置图标或图标加载失败时）
  Widget _letterMark() {
    return Center(
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : 'S',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: LonIsleTheme.textWhite,
        ),
      ),
    );
  }
}

/// 中间话题/成员栏
class _TopicPanel extends StatelessWidget {
  final ServerConnection sc;
  final bool showMembers;
  final VoidCallback onToggleMembers;

  const _TopicPanel({
    required this.sc,
    required this.showMembers,
    required this.onToggleMembers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: LonIsleTheme.bg2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 社区名称：点击弹出社区介绍卡（名称/图标/简介/策略/人数/状态/限额）
          InkWell(
            onTap: () => _showServerInfo(context, sc),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sc.serverName.isEmpty ? '服务器' : sc.serverName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: LonIsleTheme.textWhite,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.info_outline,
                      size: 14, color: LonIsleTheme.textDim),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0x0DFFFFFF)),
          Row(
            children: [
              _TabButton(
                label: '话题',
                active: !showMembers,
                onTap: onToggleMembers,
              ),
              _TabButton(
                label: '成员',
                active: showMembers,
                onTap: onToggleMembers,
              ),
            ],
          ),
          Expanded(
            child: showMembers
                ? _MemberList(sc: sc, members: sc.members)
                : _TopicList(sc: sc, topics: sc.topics, current: sc.currentTopicId),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? LonIsleTheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? LonIsleTheme.textWhite : LonIsleTheme.textDim,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicList extends StatelessWidget {
  final ServerConnection sc;
  final List<pb.TopicInfo> topics;
  final String current;

  const _TopicList({required this.sc, required this.topics, required this.current});

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return const Center(
        child: Text('暂无话题', style: TextStyle(color: LonIsleTheme.textDim)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: topics.map((t) {
        final active = t.topicId == current;
        return _TopicItem(sc: sc, topic: t, active: active);
      }).toList(),
    );
  }
}

class _TopicItem extends StatelessWidget {
  final ServerConnection sc;
  final pb.TopicInfo topic;
  final bool active;

  const _TopicItem({required this.sc, required this.topic, required this.active});

  @override
  Widget build(BuildContext context) {
    final isAnnouncement = topic.type == pb.TopicType.ANNOUNCEMENT;
    final isAV = topic.type == pb.TopicType.AV;
    // 话题级未读角标（F-UI-4）
    final unread = sc.unreadOf(topic.topicId);
    return InkWell(
      onTap: () {
        if (isAV) {
          // 音视频话题：加入驻留会话（底部控制条），不阻断其他话题发言
          AppState.instance.joinAv(sc, topic.topicId, topic.name);
        } else {
          sc.switchTopic(topic.topicId);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? LonIsleTheme.bg3 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isAnnouncement
                  ? Icons.campaign
                  : isAV
                      ? Icons.headset_mic
                      : Icons.tag,
              size: 16,
              color: active ? LonIsleTheme.textWhite : LonIsleTheme.textDim,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                topic.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? LonIsleTheme.textWhite : LonIsleTheme.textDim,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isAnnouncement)
              const Icon(Icons.star, size: 14, color: LonIsleTheme.amber),
            // 话题级未读角标（F-UI-4）
            if (unread > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: LonIsleTheme.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  final ServerConnection sc;
  final List<pb.MemberInfo> members;

  const _MemberList({required this.sc, required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const Center(
        child: Text('暂无成员', style: TextStyle(color: LonIsleTheme.textDim)),
      );
    }
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, i) {
        final m = members[i];
        return ListTile(
          dense: true,
          leading: Stack(
            children: [
              // 服务端已按 覆盖>全局 回填有效头像（effective_avatar）
              _Avatar(
                seed: m.userId,
                size: 32,
                avatarRef: m.avatarSeed,
                serverAddress:
                    '${sc.connection.host}:${sc.connection.port}',
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: m.isOnline ? LonIsleTheme.green : LonIsleTheme.textDim,
                    shape: BoxShape.circle,
                    border: Border.all(color: LonIsleTheme.bg2, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  m.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: LonIsleTheme.textWhite),
                ),
              ),
              if (m.role == pb.MemberRole.OWNER) ...[
                const SizedBox(width: 4),
                const Icon(Icons.star, color: LonIsleTheme.amber, size: 14),
              ] else if (m.role == pb.MemberRole.ADMIN) ...[
                const SizedBox(width: 4),
                const Icon(Icons.shield, color: LonIsleTheme.accentBlue, size: 14),
              ],
              if (m.muted) ...[
                const SizedBox(width: 4),
                const Icon(Icons.volume_off, color: LonIsleTheme.red, size: 14),
              ],
            ],
          ),
          trailing: (sc.isAdmin && m.userId != sc.selfMember?.userId)
              ? _MemberActions(sc: sc, member: m)
              : null,
        );
      },
    );
  }
}

/// 成员操作按钮（管理员）
class _MemberActions extends StatelessWidget {
  final ServerConnection sc;
  final pb.MemberInfo member;

  const _MemberActions({required this.sc, required this.member});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: LonIsleTheme.textDim, size: 18),
      onSelected: (v) async {
        switch (v) {
          case 'admin':
            await sc.setMemberRole(member.userId, pb.MemberRole.ADMIN);
            break;
          case 'member':
            await sc.setMemberRole(member.userId, pb.MemberRole.MEMBER);
            break;
          case 'mute':
            await sc.setMute(member.userId, !member.muted);
            break;
          case 'ban':
            await sc.setBan(member.userId, !member.banned);
            break;
          case 'kick':
            await sc.kickMember(member.userId);
            break;
        }
      },
      itemBuilder: (context) => [
        if (member.role == pb.MemberRole.MEMBER)
          const PopupMenuItem(value: 'admin', child: Text('设为管理员')),
        if (member.role == pb.MemberRole.ADMIN)
          const PopupMenuItem(value: 'member', child: Text('降为成员')),
        PopupMenuItem(
          value: 'mute',
          child: Text(member.muted ? '解除禁言' : '禁言'),
        ),
        PopupMenuItem(
          value: 'ban',
          child: Text(member.banned ? '解除封禁' : '封禁'),
        ),
        const PopupMenuItem(value: 'kick', child: Text('踢出')),
      ],
    );
  }
}

/// 消息区头部
class _MessageHeader extends StatelessWidget {
  final ServerConnection sc;

  const _MessageHeader({required this.sc});

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (sc.status) {
      ConnectionStatus.connected => '已连接',
      ConnectionStatus.connecting => '连接中…',
      ConnectionStatus.reconnecting => '重连中…',
      ConnectionStatus.disconnected => '已断开',
    };
    final statusColor = switch (sc.status) {
      ConnectionStatus.connected => LonIsleTheme.green,
      ConnectionStatus.connecting || ConnectionStatus.reconnecting =>
        LonIsleTheme.amber,
      ConnectionStatus.disconnected => LonIsleTheme.red,
    };

    String topicName = '话题';
    for (final t in sc.topics) {
      if (t.topicId == sc.currentTopicId) {
        topicName = t.name;
        break;
      }
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: LonIsleTheme.bg2,
      child: Row(
        children: [
          const Icon(Icons.tag, size: 20, color: LonIsleTheme.textDim),
          const SizedBox(width: 8),
          Text(
            topicName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: LonIsleTheme.textWhite,
            ),
          ),
          const Spacer(),
          _StatusDot(color: statusColor, label: statusLabel),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color, blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: LonIsleTheme.textDim),
        ),
      ],
    );
  }
}

/// 消息列表
class _MessageList extends StatelessWidget {
  final ServerConnection sc;
  final List<ChatMessage> messages;

  const _MessageList({required this.sc, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: LonIsleTheme.textDim),
            SizedBox(height: 12),
            Text('还没有消息，来打个招呼吧',
                style: TextStyle(color: LonIsleTheme.textDim)),
          ],
        ),
      );
    }
    // reverse: true 让列表从底部开始，新消息（在列表末尾）自动显示在底部
    final reversed = messages.reversed.toList();
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // 滚动到顶部（视觉最旧消息，reverse 时 pixels 接近 maxScrollExtent）
        // → 触发加载更早历史（F-MSG 历史翻页）
        if (n.metrics.axis == Axis.vertical &&
            n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
            sc.hasMoreHistory &&
            !sc.historyLoading) {
          sc.loadMoreHistory();
        }
        return false;
      },
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: reversed.length,
        itemBuilder: (context, i) =>
            _MessageBubble(sc: sc, message: reversed[i]),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ServerConnection sc;
  final ChatMessage message;

  const _MessageBubble({required this.sc, required this.message});

  @override
  Widget build(BuildContext context) {
    final isSelf = message.authorId == sc.selfMember?.userId;
    // 消息时间：今天→时分；今年（非今天）→月日时分；往年→年月日时分
    final time =
        DateTime.fromMillisecondsSinceEpoch(message.serverTs * 1000).toLocal();
    final now = DateTime.now();
    final hm =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final timeStr = time.year == now.year &&
            time.month == now.month &&
            time.day == now.day
        ? hm
        : time.year == now.year
            ? '${time.month}月${time.day}日 $hm'
            : '${time.year}年${time.month}月${time.day}日 $hm';

    // 作者有效头像（服务器内覆盖 > 全局；服务端已回填 effective_avatar）
    String authorAvatar = '';
    for (final m in sc.members) {
      if (m.userId == message.authorId) {
        authorAvatar = m.avatarSeed;
        break;
      }
    }
    final serverAddr = '${sc.connection.host}:${sc.connection.port}';

    if (message.deleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            _Avatar(
              seed: message.authorId,
              size: 40,
              avatarRef: authorAvatar,
              serverAddress: serverAddr,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(
                    message.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: LonIsleTheme.textWhite,
                    ),
                  ),
                  // 自己发言标识（重名时可区分）
                  if (isSelf) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: LonIsleTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('我',
                          style: TextStyle(
                              fontSize: 10,
                              color: LonIsleTheme.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                  const SizedBox(width: 8),
                  const Text(
                    '消息已删除',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: LonIsleTheme.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            seed: message.authorId,
            size: 40,
            avatarRef: authorAvatar,
            serverAddress: serverAddr,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 回复引用条（F-MSG-6）
                if (message.replyTo.isNotEmpty) ...[
                  _ReplyQuote(sc: sc, message: message),
                  const SizedBox(height: 2),
                ],
                Row(
                  children: [
                    Text(
                      message.authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: LonIsleTheme.textWhite,
                      ),
                    ),
                    // 自己发言标识（重名时可区分）
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: LonIsleTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('我',
                            style: TextStyle(
                                fontSize: 10,
                                color: LonIsleTheme.primary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 12, color: LonIsleTheme.textDim),
                    ),
                    if (message.edited) ...[
                      const SizedBox(width: 8),
                      const Text('(已编辑)',
                          style: TextStyle(fontSize: 11, color: LonIsleTheme.textDim)),
                    ],
                    if (message.pending && !message.failed) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.schedule, size: 12, color: LonIsleTheme.textDim),
                    ],
                    if (message.failed) ...[
                      const SizedBox(width: 8),
                      const Text('发送失败',
                          style: TextStyle(fontSize: 11, color: LonIsleTheme.red)),
                    ],
                    if (isSelf && (!message.pending || message.failed)) ...[
                      const Spacer(),
                      _MessageOps(sc: sc, message: message),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (message.content.isNotEmpty)
                  _RichContent(message: message),
                // 附件展示（缩略图占位，点击下载）
                if (message.attachment != null) ...[
                  const SizedBox(height: 8),
                  _AttachmentPreview(
                    attachment: message.attachment!,
                    serverAddress:
                        '${sc.connection.host}:${sc.connection.port}',
                  ),
                ],
                // Reaction 展示
                if (message.reactions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _ReactionBar(sc: sc, message: message),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 回复引用条：显示被回复消息的作者与内容摘要
/// 被踢出/封禁横幅（F-JOIN-6）：本账号被移出服务器时只读提示
class _ExpelledBanner extends StatelessWidget {
  final ServerConnection sc;

  const _ExpelledBanner({required this.sc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: LonIsleTheme.red.withOpacity(0.15),
      child: Row(
        children: [
          const Icon(Icons.block, color: LonIsleTheme.red, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '你已被移出该服务器，历史消息只读保留',
              style: TextStyle(color: LonIsleTheme.red, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => AppState.instance.removeServer(sc.serverId),
            child:
                const Text('移除', style: TextStyle(color: LonIsleTheme.red)),
          ),
        ],
      ),
    );
  }
}

/// 迁移公告横幅（F-JOIN-8）：验签后展示目标地址，确认后归档旧服
class _MigrationBanner extends StatelessWidget {
  final ServerConnection sc;

  const _MigrationBanner({required this.sc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: LonIsleTheme.primary.withOpacity(0.12),
      child: Row(
        children: [
          const Icon(Icons.move_up, color: LonIsleTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '本服务器公告：即将迁移至 ${sc.connection.migrationTarget}',
              style:
                  const TextStyle(color: LonIsleTheme.primary, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => _confirmMigration(context),
            child: const Text('查看迁移',
                style: TextStyle(color: LonIsleTheme.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmMigration(BuildContext context) async {
    // 先验签（F-JOIN-8：防中间人替换迁移目标）
    final error = await sc.verifyMigrationSignature();
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠ $error，为安全起见请勿迁移')),
      );
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('确认服务器迁移',
            style: TextStyle(color: LonIsleTheme.textWhite)),
        content: Text(
          '迁移目标：${sc.connection.migrationTarget}\n'
          '目标指纹：${sc.connection.migrationFingerprint}\n\n'
          '签名验证通过。迁移后本服务器将被归档（历史消息只读保留）。',
          style: const TextStyle(color: LonIsleTheme.textDim, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('暂不迁移')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认迁移',
                  style: TextStyle(color: LonIsleTheme.primary))),
        ],
      ),
    );
    if (go == true) {
      await sc.archiveAfterMigration();
      await AppState.instance.removeServer(sc.serverId);
    }
  }
}

class _ReplyQuote extends StatelessWidget {
  final ServerConnection sc;
  final ChatMessage message;

  const _ReplyQuote({required this.sc, required this.message});

  @override
  Widget build(BuildContext context) {
    final replied = sc.messages
        .where((m) => m.msgId == message.replyTo)
        .cast<ChatMessage?>()
        .firstWhere((_) => true, orElse: () => null);
    final author = replied?.authorName ?? '原消息';
    final summary = replied == null
        ? '内容不可用'
        : (replied.deleted
            ? '消息已删除'
            : (replied.content.isEmpty ? '[附件]' : replied.content));
    final shown = summary.length > 36 ? '${summary.substring(0, 36)}…' : summary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LonIsleTheme.bg,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: LonIsleTheme.primary, width: 2),
        ),
      ),
      child: Text(
        '$author：$shown',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: LonIsleTheme.textDim, fontSize: 12),
      ),
    );
  }
}

/// 富文本内容：@提及高亮
class _RichContent extends StatelessWidget {
  final ChatMessage message;

  const _RichContent({required this.message});

  @override
  Widget build(BuildContext context) {
    final text = message.content;
    final spans = <TextSpan>[];
    final regex = RegExp(r'@[^\s，。！？]+');
    var last = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: LonIsleTheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ));
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return Text.rich(
      TextSpan(
        style: const TextStyle(color: LonIsleTheme.textMuted),
        children: spans,
      ),
    );
  }
}

/// 秒 → mm:ss 时长文案
String _fmtDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 附件缩略图（F-MEDIA-1/2/3）：图片显缩略图，点击流式下载（带进度）后查看
class _AttachmentPreview extends StatefulWidget {
  final pb.Attachment attachment;

  /// 所属服务器地址（host:port，缩略图/附件下载路由到正确服务器）
  final String? serverAddress;

  const _AttachmentPreview({required this.attachment, this.serverAddress});

  @override
  State<_AttachmentPreview> createState() => _AttachmentPreviewState();
}

class _AttachmentPreviewState extends State<_AttachmentPreview> {
  double _progress = -1; // -1 未下载，0~1 下载中/完成

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final size = attachment.size.toInt();
    final sizeLabel = size < 1024
        ? '$size B'
        : size < 1024 * 1024
            ? '${(size / 1024).toStringAsFixed(1)} KB'
            : '${(size / 1024 / 1024).toStringAsFixed(1)} MB';

    // 语音：微信式内联播放（不跳页面）+ 下载按钮
    if (attachment.kind == 'audio') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: LonIsleTheme.bg3,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InlineVoicePlayer(
              attachment: attachment,
              serverAddress: widget.serverAddress ?? '',
            ),
            const SizedBox(width: 6),
            _downloadButton(),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LonIsleTheme.bg3,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachment.kind == 'image')
              // 图片：优先显示缩略图（F-MEDIA-2）；
              // 旧消息的缩略图 ID 失效时回退下载原图（cacheWidth 限内存）
              // 宽高比自适应（附件元数据），消息流内约束最大 220×300
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 220,
                  maxHeight: 300,
                ),
                child: FutureBuilder<String?>(
                future: () async {
                  // GIF 动态图跳过缩略图（缩略图是静态帧），直接用原图保留动画
                  final isGif =
                      attachment.mime.toLowerCase().contains('gif');
                  if (!isGif && attachment.thumbnailId.isNotEmpty) {
                    final thumb = await MediaService.instance
                        .downloadThumbnail(attachment.thumbnailId,
                            serverAddress: widget.serverAddress)
                        .catchError((_) => null);
                    if (thumb != null) return thumb;
                  }
                  try {
                    return await MediaService.instance
                        .download(attachment.attachmentId,
                            serverAddress: widget.serverAddress);
                  } catch (_) {
                    return null;
                  }
                }(),
                builder: (context, snap) {
                  if (snap.hasData) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AspectRatio(
                            // 用附件元数据的真实宽高比（缺失时按 1:1），
                            // 消息流最大宽 220、最大高 300，不裁切不变形
                            aspectRatio:
                                attachment.width > 0 && attachment.height > 0
                                    ? attachment.width / attachment.height
                                    : 1.0,
                            child: Image.file(
                              File(snap.data!),
                              fit: BoxFit.cover,
                              // GIF 等动态图不做缩放解码（cacheWidth 会让动画变静态帧），
                              // 全尺寸解码以保留动画效果
                              cacheWidth: attachment.mime
                                      .toLowerCase()
                                      .contains('gif')
                                  ? null
                                  : 440,
                              errorBuilder: (_, __, ___) => _iconRow(sizeLabel),
                            ),
                          ),
                        ),
                        // 消息流不显示下载按钮（点击进入全屏查看器后下载）
                      ],
                    );
                  }
                  return _iconRow(sizeLabel);
                },
                ),
              )
            else if (attachment.kind == 'video' &&
                attachment.thumbnailId.isNotEmpty)
              // 视频：首帧缩略图占位 + 播放角标（F-MEDIA-2），点击下载后播放
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 220,
                  maxHeight: 300,
                ),
                child: FutureBuilder<String?>(
                  future: MediaService.instance
                      .downloadThumbnail(attachment.thumbnailId,
                          serverAddress: widget.serverAddress)
                      .catchError((_) => null),
                  builder: (context, snap) {
                    if (!snap.hasData) return _iconRow(sizeLabel);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AspectRatio(
                        aspectRatio:
                            attachment.width > 0 && attachment.height > 0
                                ? attachment.width / attachment.height
                                : 16 / 9,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(snap.data!),
                              fit: BoxFit.cover,
                              cacheWidth: 440,
                              errorBuilder: (_, __, ___) =>
                                  _iconRow(sizeLabel),
                            ),
                            // 中央播放按钮
                            const Center(
                              child: Icon(Icons.play_circle_fill,
                                  size: 44, color: Colors.white70),
                            ),
                            // 右下时长角标
                            if (attachment.duration > 0)
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _fmtDuration(attachment.duration),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 10),
                                  ),
                                ),
                              ),
                            // 消息流不显示下载按钮（点击进入全屏查看器后下载）
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              _iconRow(sizeLabel),
            // 下载进度（F-MEDIA-3）
            if (_progress >= 0 && _progress < 1.0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 3,
                  backgroundColor: LonIsleTheme.bg,
                  color: LonIsleTheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _iconRow(String sizeLabel) {
    final attachment = widget.attachment;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          attachment.kind == 'image'
              ? Icons.image
              : attachment.kind == 'video'
                  ? Icons.videocam
                  : attachment.kind == 'audio'
                      ? Icons.audiotrack
                      : Icons.insert_drive_file,
          color: LonIsleTheme.textDim,
          size: 32,
        ),
        const SizedBox(width: 12),
        // 文件名弹性宽度：短文件名保持卡片紧凑，长文件名占满剩余
        // 空间后省略号截断；窗口拖窄时随之收缩，不再溢出。
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                attachment.filename.isNotEmpty
                    ? attachment.filename
                    : '${attachment.kind} 附件',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: LonIsleTheme.textWhite, fontSize: 13),
              ),
              Text(
                attachment.duration > 0
                    ? '$sizeLabel · ${_fmtDuration(attachment.duration)}'
                    : sizeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: LonIsleTheme.textDim, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _downloadButton(),
      ],
    );
  }

  /// 下载按钮（文件/语音卡片内联样式）
  Widget _downloadButton() {
    return IconButton(
      icon: const Icon(Icons.download, size: 18, color: LonIsleTheme.textDim),
      tooltip: '下载',
      onPressed: _saveAs,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
    );
  }

  /// 下载按钮行为：流式下载（进度条复用 _progress）→ 系统「另存为」
  /// 对话框（预填原始文件名，F-MEDIA-10）→ 复制到用户选择的位置。
  Future<void> _saveAs() async {
    final attachment = widget.attachment;
    try {
      setState(() => _progress = 0);
      final path = await MediaService.instance.downloadWithProgress(
        attachment.attachmentId,
        (p) {
          if (mounted) setState(() => _progress = p);
        },
        serverAddress: widget.serverAddress,
      );
      if (!mounted) return;
      setState(() => _progress = -1);
      // 原始文件名优先；缺失时用缓存文件名（已按魔数补扩展名）
      var defaultName = attachment.filename.isNotEmpty
          ? attachment.filename
          : p.basename(path);
      // 旧消息/引用发送（如表情）filename 可能无扩展名 → 优先用缓存文件名
      // （按魔数嗅探过，如 .gif/.png），再按 mime 兜底
      if (!defaultName.contains('.')) {
        final base = p.basename(path);
        if (base.contains('.')) {
          defaultName = base;
        } else {
          final ext = _extForMime(attachment.mime);
          if (ext.isNotEmpty) defaultName = '$defaultName.$ext';
        }
      }
      // iOS/Android：file_picker 必须传 bytes（系统 SAF/文档选择器直接写内容）；
      // macOS/桌面：不支持 bytes，返回目标路径后自行复制
      String? savePath;
      if (Platform.isIOS || Platform.isAndroid) {
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: '保存附件',
          fileName: defaultName,
          bytes: await File(path).readAsBytes(),
        );
      } else {
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: '保存附件',
          fileName: defaultName,
        );
        if (savePath != null) await File(path).copy(savePath);
      }
      if (savePath == null) return; // 用户取消
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _progress = -1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$e')),
        );
      }
    }
  }

  /// 保存附件：按 mime 补扩展名（下载文件名兜底，F-MEDIA-10）
  static String _extForMime(String mime) {
    final m = mime.toLowerCase();
    if (m.contains('gif')) return 'gif';
    if (m.contains('png')) return 'png';
    if (m.contains('jpeg') || m.contains('jpg')) return 'jpg';
    if (m.contains('webp')) return 'webp';
    if (m.contains('mp4')) return 'mp4';
    if (m.contains('webm')) return 'webm';
    if (m.contains('mpeg')) return 'mp3';
    if (m.contains('wav')) return 'wav';
    if (m.contains('ogg')) return 'ogg';
    if (m.contains('pdf')) return 'pdf';
    if (m.contains('zip')) return 'zip';
    return '';
  }

  /// 点击：流式下载（进度）→ 打开查看器
  Future<void> _open() async {
    final attachment = widget.attachment;
    try {
      setState(() => _progress = 0);
      final path = await MediaService.instance.downloadWithProgress(
        attachment.attachmentId,
        (p) {
          if (mounted) setState(() => _progress = p);
        },
        serverAddress: widget.serverAddress,
      );
      if (!mounted) return;
      final Widget target = attachment.kind == 'audio'
          ? VoicePlayer(attachment: attachment, localPath: path)
          : MediaViewer(attachment: attachment, localPath: path);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => target),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：$e')),
        );
        setState(() => _progress = -1);
      }
    }
  }
}

/// Reaction 展示栏（点击添加/移除）
class _ReactionBar extends StatelessWidget {
  final ServerConnection sc;
  final ChatMessage message;

  const _ReactionBar({required this.sc, required this.message});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: [
        for (final r in message.reactions)
          InkWell(
            onTap: () => sc.connection.removeReaction(
              message.topicId,
              message.msgId,
              r.emoji,
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: LonIsleTheme.bg3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${r.emoji} ${r.userId.length}',
                style: const TextStyle(fontSize: 12, color: LonIsleTheme.textWhite),
              ),
            ),
          ),
        // 添加 Reaction 按钮
        InkWell(
          onTap: () => _pickReaction(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: LonIsleTheme.bg3,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_reaction, size: 14, color: LonIsleTheme.textDim),
          ),
        ),
      ],
    );
  }

  Future<void> _pickReaction(BuildContext context) async {
    const emojis = ['👍', '❤️', '😂', '🎉', '👀', '🔥'];
    final emoji = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: LonIsleTheme.bg2,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final e in emojis)
                InkWell(
                  onTap: () => Navigator.pop(ctx, e),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    if (emoji != null) {
      await sc.connection.addReaction(message.topicId, message.msgId, emoji);
    }
  }
}

/// 消息操作（编辑/删除）
class _MessageOps extends StatelessWidget {
  final ServerConnection sc;
  final ChatMessage message;

  const _MessageOps({required this.sc, required this.message});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: LonIsleTheme.textDim, size: 16),
      onSelected: (v) async {
        if (v == 'edit') {
          final controller = TextEditingController(text: message.content);
          final newText = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: LonIsleTheme.bg2,
              title: const Text('编辑消息', style: TextStyle(color: LonIsleTheme.textWhite)),
              content: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: LonIsleTheme.textWhite),
                decoration: const InputDecoration(hintText: '新内容'),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, controller.text),
                  child: const Text('保存'),
                ),
              ],
            ),
          );
          if (newText != null && newText.trim().isNotEmpty) {
            await sc.editMessage(message.msgId, newText.trim());
          }
        } else if (v == 'delete') {
          await sc.deleteMessage(message.msgId);
        } else if (v == 'reply') {
          // 回复引用：设置主界面回复状态（经 HomeScreen 的 ValueNotifier 中转）
          HomeScreen.replyRequest.add(message);
        } else if (v == 'reads') {
          // 查看已读列表（P2）
          final reads = await sc.mentionReadList(message.msgId);
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: LonIsleTheme.bg2,
                title: const Text('已读列表', style: TextStyle(color: LonIsleTheme.textWhite)),
                content: SizedBox(
                  width: 300,
                  child: reads.userId.isEmpty
                      ? const Text('暂无已读', style: TextStyle(color: LonIsleTheme.textDim))
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final uid in reads.userId)
                              Text(uid, style: const TextStyle(color: LonIsleTheme.textMuted)),
                          ],
                        ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
                ],
              ),
            );
          }
        } else if (v == 'retry') {
          // 重试发送失败的本地消息
          final ok = await sc.retryFailedMessage(message);
          if (context.mounted && !ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('重试发送失败，请检查网络后重试')),
            );
          }
        } else if (v == 'discard') {
          // 删除本地失败的乐观消息
          sc.removeFailedMessage(message);
        }
      },
      itemBuilder: (context) => [
        if (message.failed) ...[
          const PopupMenuItem(value: 'retry', child: Text('重试发送')),
          const PopupMenuItem(value: 'discard', child: Text('丢弃消息')),
        ] else ...[
          const PopupMenuItem(value: 'reply', child: Text('回复')),
          const PopupMenuItem(value: 'edit', child: Text('编辑')),
          const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
        // 自己的消息且服务端解析出 @提及时可查看已读（F-MSG-10）
        if (message.authorId == sc.selfMember?.userId && message.mentions.isNotEmpty)
          const PopupMenuItem(value: 'reads', child: Text('查看已读')),
      ],
    );
  }
}

/// 成员头像：avatarRef 为 'att:<附件ID>' 时渲染上传的图片头像（F-PROF-7），
/// 否则按种子渲染 Identicon 字母头像（F-PROF-1）
class _Avatar extends StatelessWidget {
  final String seed;
  final double size;

  /// 头像引用：空或种子字符串 → Identicon；'att:<id>' → 服务器上的图片附件
  final String avatarRef;
  final String? serverAddress;

  const _Avatar({
    required this.seed,
    required this.size,
    this.avatarRef = '',
    this.serverAddress,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarRef.startsWith('att:')) {
      final attachmentId = avatarRef.substring(4);
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 3),
        child: FutureBuilder<String?>(
          future: () async {
            try {
              return await MediaService.instance
                  .download(attachmentId, serverAddress: serverAddress);
            } catch (_) {
              return null;
            }
          }(),
          builder: (context, snap) {
            if (snap.hasData && snap.data != null) {
              return Image.file(
                File(snap.data!),
                width: size,
                height: size,
                fit: BoxFit.cover,
                // 引用在其他服务器不可解析等失败场景：回退 Identicon
                errorBuilder: (_, __, ___) => _identicon(),
              );
            }
            return _identicon();
          },
        ),
      );
    }
    return _identicon();
  }

  /// Identicon 字母头像（种子派生颜色 + 首字符）
  Widget _identicon() {
    final colors = [
      LonIsleTheme.primary,
      LonIsleTheme.accentBlue,
      LonIsleTheme.green,
      LonIsleTheme.amber,
      LonIsleTheme.primaryDark,
    ];
    final hash = seed.hashCode.abs();
    final color = colors[hash % colors.length];
    final letter = seed.isNotEmpty ? seed.characters.first.toUpperCase() : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 音视频会话底部控制条（驻留）：显示房间名 + 静音/摄像头/展开/离开
class _AvBar extends StatelessWidget {
  final AvSession session;

  const _AvBar({required this.session});

  void _showError(BuildContext context, String? err) {
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: LonIsleTheme.bg3,
      child: Row(
        children: [
          Icon(
            s.error != null ? Icons.error_outline : Icons.headset_mic,
            size: 16,
            color: s.error != null ? LonIsleTheme.red : LonIsleTheme.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.error != null
                  ? '房间连接失败'
                  : s.joining
                      ? '正在加入 ${s.topicName}…'
                      : '${s.topicName} · ${s.participants.length} 人在线',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: LonIsleTheme.textWhite, fontSize: 12),
            ),
          ),
          IconButton(
            icon: Icon(s.muted ? Icons.mic_off : Icons.mic,
                size: 18, color: LonIsleTheme.textWhite),
            tooltip: s.muted ? '取消静音' : '静音',
            onPressed: () async => _showError(context, await s.toggleMute()),
          ),
          IconButton(
            icon: Icon(
                s.cameraOff ? Icons.videocam_off : Icons.videocam,
                size: 18, color: LonIsleTheme.textWhite),
            tooltip: s.cameraOff ? '开启摄像头' : '关闭摄像头',
            onPressed: () async => _showError(context, await s.toggleCamera()),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_full,
                size: 18, color: LonIsleTheme.textWhite),
            tooltip: '展开房间',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AVRoomScreen(
                    session: s,
                    onLeave: () => AppState.instance.leaveAv(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_end,
                size: 18, color: LonIsleTheme.red),
            tooltip: '离开房间',
            onPressed: () => AppState.instance.leaveAv(),
          ),
        ],
      ),
    );
  }
}

/// 消息输入区（含 @提及补全与回复引用条，F-MSG-6）
class _MessageInput extends StatefulWidget {
  final TextEditingController controller;
  final Future<void> Function() onSend;
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;
  final List<pb.MemberInfo> members;

  const _MessageInput({
    required this.controller,
    required this.onSend,
    this.replyTo,
    this.onCancelReply,
    this.members = const [],
  });

  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> {
  List<pb.MemberInfo> _mentionMatches = [];
  String _mentionQuery = '';

  // 语音录制状态（F-MEDIA-7，录制器封装见 VoiceRecorder）
  Timer? _recordTimer;
  bool _recording = false;
  int _recordSeconds = 0;
  String? _recordPath;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  /// 检测光标前的 @提及片段（@ 后最多到空白/中文标点）
  void _onTextChanged() {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      _setMatches([], '');
      return;
    }
    final before = text.substring(0, cursor);
    final at = before.lastIndexOf('@');
    if (at < 0 || at > 0 && !RegExp(r'[\s，。！？]').hasMatch(before[at - 1])) {
      // @ 不在词首（前一个字符非空白）→ 非提及
      _setMatches([], '');
      return;
    }
    final query = before.substring(at + 1);
    if (query.contains(RegExp(r'\s')) || query.length > 24) {
      _setMatches([], '');
      return;
    }
    final q = query.toLowerCase();
    final matches = widget.members
        .where((m) =>
            !m.banned &&
            (m.displayName.toLowerCase().contains(q) ||
                m.userId.toLowerCase().startsWith(q)))
        .take(6)
        .toList();
    _setMatches(matches, query);
  }

  void _setMatches(List<pb.MemberInfo> matches, String query) {
    if (_mentionMatches.length != matches.length || query != _mentionQuery) {
      setState(() {
        _mentionMatches = matches;
        _mentionQuery = query;
      });
    }
  }

  /// 打开表情包面板（F-STICKER：底部弹层；emoji 插入输入框，图片表情直接发送）
  void _openStickerPanel() {
    final sc = AppState.instance.activeServer;
    if (sc == null) return;
    showStickerPanel(
      context,
      sc: sc,
      onEmoji: (emoji) {
        final ctrl = widget.controller;
        final text = ctrl.text;
        final sel = ctrl.selection;
        final start = sel.isValid ? sel.start : text.length;
        final end = sel.isValid ? sel.end : start;
        final newText = text.replaceRange(start, end, emoji);
        ctrl.text = newText;
        ctrl.selection =
            TextSelection.collapsed(offset: start + emoji.length);
      },
      onImage: (attRef) async {
        try {
          await sc.sendStickerImage(attRef);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('发送失败：$e')),
            );
          }
        }
      },
    );
  }

  /// 选择并发送附件（F-MEDIA-1）
  Future<void> _pickAndSend(String kind) async {
    try {
      final sc = AppState.instance.activeServer;
      if (sc == null) return;

      if (kind == 'image') {
        // 图片：用 file_picker 拿原始文件 —— image_picker 的 imageQuality
        // 会把 GIF 等动态图重编码成静态帧，动态图必须原样上传
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );
        if (result == null || result.files.single.path == null) return;
        final path = result.files.single.path!;
        final data = await File(path).readAsBytes();
        await _sendWithProgress(context, (onUpload) => sc.sendAttachment(
            data: data,
            filename: result.files.single.name,
            kind: 'image',
            onUpload: onUpload));
      } else if (kind == 'video' || kind == 'audio') {
        // 视频/音频：带类型过滤选择，读取时长元数据（F-MEDIA-8）
        final result = await FilePicker.platform.pickFiles(
          type: kind == 'video' ? FileType.video : FileType.audio,
        );
        if (result == null || result.files.single.path == null) return;
        final path = result.files.single.path!;
        final data = await File(path).readAsBytes();
        if (kind == 'video') {
          // 视频：探测时长与画面尺寸 + 抽取首帧缩略图（F-MEDIA-1/8）
          final meta = await _probeVideoMeta(path);
          final thumb = await VideoThumb.generate(path);
          await _sendWithProgress(context, (onUpload) => sc.sendAttachment(
            data: data,
            filename: result.files.single.name,
            kind: 'video',
            durationSec: meta.$1,
            width: meta.$2,
            height: meta.$3,
            thumbnail: thumb,
            onUpload: onUpload,
          ));
        } else {
          final duration = await _probeAudioDuration(path);
          await _sendWithProgress(context, (onUpload) => sc.sendAttachment(
            data: data,
            filename: result.files.single.name,
            kind: 'audio',
            durationSec: duration,
            onUpload: onUpload,
          ));
        }
      } else {
        final result = await FilePicker.platform.pickFiles();
        if (result == null || result.files.single.path == null) return;
        final file = File(result.files.single.path!);
        final data = await file.readAsBytes();
        await _sendWithProgress(context, (onUpload) => sc.sendAttachment(
            data: data,
            filename: file.uri.pathSegments.last,
            kind: 'file',
            onUpload: onUpload));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$e')),
        );
      }
    }
  }

  /// 带上传进度对话框发送附件（F-MEDIA 上传：indeterminate 进度条，传输完成后自动关闭）
  Future<void> _sendWithProgress(
    BuildContext context,
    Future<void> Function(void Function()? onUpload) send,
  ) async {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: LonIsleTheme.bg2,
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('正在上传…',
                style: TextStyle(color: LonIsleTheme.textWhite)),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                minHeight: 6,
                backgroundColor: LonIsleTheme.bg3,
                color: LonIsleTheme.primary,
              ),
            ),
            SizedBox(height: 8),
            Text('传输完成前请勿关闭',
                style: TextStyle(color: LonIsleTheme.textDim, fontSize: 12)),
          ],
        ),
      ),
    );
    try {
      await send(() {
        // no-op：当前用 indeterminate（传输中转圈），保留 hook 便于后续切真实百分比
      });
      if (navigator.mounted) navigator.pop();
    } catch (e) {
      if (navigator.mounted) navigator.pop();
      rethrow;
    }
  }

  /// 读取视频元数据（时长秒、宽、高；失败返回全 0，不阻断发送）
  Future<(int, int, int)> _probeVideoMeta(String path) async {
    VideoPlayerController? controller;
    try {
      controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      final size = controller.value.size;
      return (
        controller.value.duration.inSeconds,
        size.width.round(),
        size.height.round(),
      );
    } catch (_) {
      return (0, 0, 0);
    } finally {
      await controller?.dispose();
    }
  }

  /// 读取音频时长（秒；失败返回 0，不阻断发送）
  Future<int> _probeAudioDuration(String path) async {
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(path);
      return duration?.inSeconds ?? 0;
    } catch (_) {
      return 0;
    } finally {
      await player.dispose();
    }
  }

  /// 开始录音（F-MEDIA-7）
  Future<void> _startRecording() async {
    if (AppState.instance.activeServer == null) return;
    try {
      if (!await VoiceRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未获得麦克风权限，请在系统设置中开启')),
          );
        }
        return;
      }
      // macOS：临时录音文件放应用容器 Caches 目录（App Sandbox 下 T 目录
      // 归属父进程，原生 AVAudioRecorder 写入会失败）
      final dir = Platform.isMacOS
          ? await getApplicationSupportDirectory()
          : await getTemporaryDirectory();
      final path = p.join(dir.path,
          'voice_${DateTime.now().millisecondsSinceEpoch}.${VoiceRecorder.fileExt}');
      await VoiceRecorder.start(path);
      setState(() {
        _recording = true;
        _recordSeconds = 0;
        _recordPath = path;
      });
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      debugPrint('[Voice] 录音启动失败: $e');
      if (mounted) {
        // PlatformException.details 携带 TCC 状态等原生诊断，一并展示
        final detail = e is PlatformException && e.details != null
            ? '\n${e.details}'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音启动失败：$e$detail')),
        );
      }
    }
  }

  /// 取消录音：停止并删除临时文件
  /// 取消录音：先复位 UI 再停录制器（stop 挂起不能卡住界面）
  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    final path = _recordPath;
    setState(() {
      _recording = false;
      _recordSeconds = 0;
      _recordPath = null;
    });
    try {
      await VoiceRecorder.cancel();
    } catch (_) {}
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  /// 停止录制器（异常返回 null，由调用方提示）
  Future<String?> _stopRecorderSafely() async {
    try {
      return await VoiceRecorder.stop();
    } catch (e) {
      debugPrint('[Voice] stop 异常: $e');
      return null;
    }
  }

  /// 完成录音并发送语音消息
  Future<void> _finishRecording() async {
    _recordTimer?.cancel();
    final sc = AppState.instance.activeServer;
    final seconds = _recordSeconds;
    // 先复位 UI（录音条立即消失），再异步停止与上传
    setState(() {
      _recording = false;
      _recordSeconds = 0;
      _recordPath = null;
    });
    final path = await _stopRecorderSafely();
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('录音失败，请重试')),
        );
      }
      return;
    }
    final file = File(path);
    try {
      if (sc == null || seconds < 1) {
        if (mounted && seconds < 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('录音太短，未发送')),
          );
        }
        return;
      }
      final data = await file.readAsBytes();
      await sc.sendAttachment(
        data: data,
        filename: p.basename(path),
        kind: 'audio',
        durationSec: seconds,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音发送失败：$e')),
        );
      }
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// 选中成员：把光标前的 @query 替换为 "@名字 "
  /// 名字取 server 昵称（优先）或全局展示名的 # 前部分，与服务端提及匹配规则一致
  void _pickMention(pb.MemberInfo m) {
    final nick = m.serverNickname.isNotEmpty
        ? m.serverNickname
        : m.displayName.split('#').first;
    final controller = widget.controller;
    final text = controller.text;
    final cursor = controller.selection.baseOffset;
    final before = text.substring(0, cursor);
    final at = before.lastIndexOf('@');
    if (at < 0) return;
    final after = text.substring(cursor);
    final insert = '@$nick ';
    controller.text = '${before.substring(0, at)}$insert$after';
    controller.selection = TextSelection.collapsed(
        offset: at + insert.length);
    _setMatches([], '');
  }

  @override
  Widget build(BuildContext context) {
    final reply = widget.replyTo;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      color: LonIsleTheme.bg2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 回复引用条
          if (reply != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: LonIsleTheme.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(color: LonIsleTheme.primary, width: 3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: LonIsleTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '回复 ${reply.authorName}：${reply.content.length > 40 ? '${reply.content.substring(0, 40)}…' : reply.content}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: LonIsleTheme.textDim, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 16, color: LonIsleTheme.textDim),
                    onPressed: widget.onCancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // @补全面板
          if (_mentionMatches.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: LonIsleTheme.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: LonIsleTheme.bg),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _mentionMatches.length,
                itemBuilder: (context, i) {
                  final m = _mentionMatches[i];
                  return ListTile(
                    dense: true,
                    title: Text(m.displayName,
                        style: const TextStyle(
                            color: LonIsleTheme.textWhite, fontSize: 14)),
                    subtitle: Text(
                      '#${m.userId.length > 12 ? m.userId.substring(0, 12) : m.userId}',
                      style: const TextStyle(
                          color: LonIsleTheme.textDim, fontSize: 11),
                    ),
                    onTap: () => _pickMention(m),
                  );
                },
              ),
            ),
          // 录音中：输入框替换为录音条（F-MEDIA-7）
          if (_recording)
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: LonIsleTheme.bg3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fiber_manual_record,
                      color: LonIsleTheme.red, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    '录音中 ${_fmtDuration(_recordSeconds)}',
                    style: const TextStyle(
                        color: LonIsleTheme.textWhite, fontSize: 14),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _cancelRecording,
                    child: const Text('取消',
                        style: TextStyle(color: LonIsleTheme.textDim)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _finishRecording,
                    style: IconButton.styleFrom(
                      backgroundColor: LonIsleTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check),
                    tooltip: '发送语音',
                  ),
                ],
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 工具条（输入框上方）：表情 / 图片 / 视频 / 音频 / 文件 / 语音
                Row(
                  children: [
                    // 表情包（F-STICKER：底部弹层，本地 + 服务器）
                    IconButton(
                      onPressed: _openStickerPanel,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.emoji_emotions_outlined,
                          size: 22, color: LonIsleTheme.textDim),
                      tooltip: '表情',
                    ),
                    // 附件：图片/视频/音频/文件（F-MEDIA-1，直接按钮）
                    IconButton(
                      onPressed: () => _pickAndSend('image'),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.image_outlined,
                          size: 22, color: LonIsleTheme.textDim),
                      tooltip: '发送图片',
                    ),
                    IconButton(
                      onPressed: () => _pickAndSend('video'),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.video_library_outlined,
                          size: 22, color: LonIsleTheme.textDim),
                      tooltip: '发送视频',
                    ),
                    IconButton(
                      onPressed: () => _pickAndSend('audio'),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.audio_file_outlined,
                          size: 22, color: LonIsleTheme.textDim),
                      tooltip: '发送音频',
                    ),
                    IconButton(
                      onPressed: () => _pickAndSend('file'),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.insert_drive_file_outlined,
                          size: 22, color: LonIsleTheme.textDim),
                      tooltip: '发送文件',
                    ),
                    // 语音消息
                    IconButton(
                      onPressed: _startRecording,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.mic_none,
                          size: 22, color: LonIsleTheme.textDim),
                      tooltip: '语音消息',
                    ),
                    const Spacer(),
                  ],
                ),
                // 输入行：输入框（多行自动换行）+ 发送
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        onSubmitted: (_) => widget.onSend(),
                        style:
                            const TextStyle(color: LonIsleTheme.textWhite),
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: '发送消息…（@ 提及成员）',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: widget.onSend,
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: LonIsleTheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(40, 40),
                      ),
                      icon: const Icon(Icons.send, size: 20),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
