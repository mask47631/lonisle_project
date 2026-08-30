import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/av_session.dart';
import '../services/connection_service.dart';
import '../services/identity_service.dart';
import '../services/keepalive_service.dart';
import '../services/local_store.dart';
import '../services/push_service.dart';
import '../services/tofu_http.dart';
import '../theme.dart';
import 'server_connection.dart';

/// 全局 Navigator Key（证书更换确认弹窗等在无页面 context 处使用）
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// 应用全局状态（多服务器聚合）
class AppState extends ChangeNotifier {
  AppState._();

  static final AppState instance = AppState._();

  final _identity = IdentityService.instance;

  /// 服务器 ID -> 连接封装
  final Map<String, ServerConnection> _servers = {};

  /// 当前激活服务器 ID
  String? _activeServerId;

  /// 已连接的服务器列表（保持稳定顺序）
  List<ServerConnection> get servers => _servers.values.toList();

  /// 当前激活服务器
  ServerConnection? get activeServer {
    final id = _activeServerId;
    if (id == null) return null;
    return _servers[id];
  }

  IdentityInfo? identity;
  bool get hasIdentity => identity != null;

  /// 是否已完成 onboarding 引导（跳过添加服务器也进入主界面，持久化）
  bool onboardingDone = false;

  /// 标记 onboarding 完成（用户选择暂不添加服务器）
  Future<void> markOnboardingDone() async {
    onboardingDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    notifyListeners();
  }

  /// 当前音视频会话（全局驻留：退出房间页面也不断线）
  AvSession? avSession;

  /// 加入音视频房间（同房间重复点击忽略；切换房间先退旧房）
  Future<void> joinAv(
      ServerConnection sc, String topicId, String topicName) async {
    final cur = avSession;
    if (cur != null && cur.topicId == topicId && cur.error == null) return;
    if (cur != null) await cur.leave();
    final s = AvSession(sc: sc, topicId: topicId, topicName: topicName);
    avSession = s;
    notifyListeners();
    await s.join();
  }

  /// 离开音视频房间
  Future<void> leaveAv() async {
    final s = avSession;
    avSession = null;
    notifyListeners();
    await s?.leave();
  }

  /// 全局未读总数（所有服务器求和）
  int get totalUnread =>
      servers.fold(0, (sum, s) => sum + s.unread);

  /// 初始化：加载身份 + 恢复已加入的服务器连接
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingDone = prefs.getBool('onboarding_done') ?? false;
    identity = await _identity.loadIdentity();
    if (identity != null) {
      // 前台通知渠道 + FCM onMessage 监听（app 前台也能收到推送通知）
      PushService.instance.initForegroundNotifications();
      // 启动后向推送服务注册设备 Token（F-PUSH-2，异步不阻塞）
      PushService.instance.register();
      // Android 后台保活（用户在设置中开启后，退后台启动前台服务）
      KeepAliveService.instance.init();
      // 恢复已加入的服务器（逐个重连，失败的服务器走断线重连退避）
      await _restoreServers();
    }
    notifyListeners();
  }

  /// 重新加载身份（资料修改后刷新 UI）
  Future<void> reloadIdentity() async {
    identity = await _identity.loadIdentity();
    notifyListeners();
  }

  /// 通知 PushService 当前已加入的服务器（免打扰上报范围，F-RATE-7）
  void _syncPushServerIds() {
    PushService.instance.updateKnownServers(
      _servers.values.map((s) => s.serverId),
    );
  }

  /// 从本地库恢复服务器连接
  Future<void> _restoreServers() async {
    final saved = await LocalStore.instance.listServers();
    for (final row in saved) {
      final serverId = row['server_id'] as String;
      final host = row['host'] as String;
      final port = row['port'] as int;
      if (_servers.containsKey(serverId)) continue;
      try {
        final connection = ConnectionService();
        // 重连时证书更换（TOFU 公钥不匹配）→ 弹窗询问是否信任新证书
        connection.onTofuMismatch =
            (h, p, fp, spki) => confirmRetrust(h, p, fp);
        final sc = ServerConnection(
          serverId: serverId,
          serverName: (row['name'] as String?)?.isNotEmpty == true
              ? row['name'] as String
              : '$host:$port',
          connection: connection,
          host: host,
          port: port,
        );
        // 失败不阻塞其他服务器恢复（连接层有断线重连退避）
        sc.connectAndJoin().catchError((e) {
          // 服务器证书已更换（TOFU 公钥不匹配）：弹窗确认后重新信任并重连
          if (e is TofuMismatchException) {
            final fp = e.actualFingerprint;
            confirmRetrust(host, port, fp).then((ok) async {
              if (ok) {
                await Tofu.unpin(host, port);
                try {
                  await sc.connectAndJoin();
                } catch (_) {}
              }
            });
          }
          return false;
        });
        _servers[serverId] = sc;
      } catch (_) {}
    }
    if (saved.isNotEmpty && _activeServerId == null) {
      _activeServerId = _servers.keys.first;
    }
  }

  /// 首次启动生成身份
  Future<void> createIdentity() async {
    await _identity.createIdentity();
    identity = await _identity.loadIdentity();
    notifyListeners();
  }

  /// 连接并加入一个服务器（返回该服务器连接；若待审批返回 pending 状态）
  Future<ServerConnection> connectAndJoin(
    String host,
    int port, {
    String reason = '',
    String claimCode = '',
    String inviteToken = '',
    String expectedFingerprint = '',
  }) async {
    final connection = ConnectionService();
    // 重连时证书更换（TOFU 公钥不匹配）→ 弹窗询问是否信任新证书
    connection.onTofuMismatch =
        (h, p, fp, spki) => confirmRetrust(h, p, fp);
    final serverId = 'pending-$host-$port'; // 暂用占位，hello 后更新
    final sc = ServerConnection(
      serverId: serverId,
      serverName: '$host:$port',
      connection: connection,
      host: host,
      port: port,
    );

    await sc.connectAndJoin(
      reason: reason,
      claimCode: claimCode,
      inviteToken: inviteToken,
      expectedFingerprint: expectedFingerprint,
    );

    // 以服务器真实 ID 作为 key
    final realId = connection.serverId.isNotEmpty ? connection.serverId : serverId;
    // 纠正连接对象内部的占位 ID，并按真实 ID 重载本地缓存（话题/消息/游标）
    await sc.updateServerId(realId);
    _servers[realId] = sc;
    _activeServerId = realId;

    // 持久化已加入的服务器（待审批的先不持久化，审批通过后再存）
    if (!sc.pendingApproval) {
      await LocalStore.instance.saveServer(
        serverId: realId,
        host: host,
        port: port,
        name: connection.serverName,
      );
    }
    _syncPushServerIds();

    notifyListeners();
    return sc;
  }

  /// 服务器证书已更换（TOFU 公钥不匹配）：弹窗询问是否信任新证书并重连。
  /// 返回 true = 已重新信任并重连成功。
  Future<bool> confirmRetrust(
    String host,
    int port,
    String newFingerprint,
  ) async {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return false;
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (ctx) => AlertDialog(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('服务器证书已更换',
            style: TextStyle(color: LonIsleTheme.textWhite)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('检测到 $host:$port 的证书与已保存的指纹不一致。',
                  style: const TextStyle(color: LonIsleTheme.textDim)),
              const SizedBox(height: 8),
              const Text('可能原因：证书到期自动续期（同公钥会静默更新，无需确认）、'
                  '服务器更换证书/重建、或存在中间人攻击。',
                  style: TextStyle(color: LonIsleTheme.textDim, fontSize: 12)),
              const SizedBox(height: 12),
              const Text('新证书指纹：', style: TextStyle(color: LonIsleTheme.textDim)),
              Text(newFingerprint,
                  style: const TextStyle(
                      color: LonIsleTheme.textMuted,
                      fontSize: 12,
                      fontFamily: 'monospace')),
              const SizedBox(height: 12),
              const Text('确认信任新证书并重新连接？',
                  style: TextStyle(color: LonIsleTheme.textWhite)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('信任并重连',
                style: TextStyle(color: LonIsleTheme.amber)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// 清除某服务器的 TOFU 信任（换证书后重新信任，F-SID-3）
  Future<void> clearServerTrust(String host, int port) async {
    await Tofu.unpin(host, port);
  }

  /// 切换到某个服务器
  void switchServer(String serverId) {
    if (_servers.containsKey(serverId)) {
      _activeServerId = serverId;
      notifyListeners();
    }
  }

  /// 向所有已连接服务器传播吊销证明（F-DEV-8）。
  /// 单个服务器失败不影响其他服务器。
  Future<void> broadcastRevocation(
    String devicePubkeyHex,
    String proofHex,
  ) async {
    for (final sc in _servers.values) {
      try {
        await sc.connection.revokeDevice(
          devicePubkeyHex: devicePubkeyHex,
          proofHex: proofHex,
        );
      } catch (_) {
        // 离线或失败的服务器：注册设备时会携带本地吊销证明中继
      }
    }
  }

  /// 移除服务器（退出）
  Future<void> removeServer(String serverId) async {
    final sc = _servers.remove(serverId);
    sc?.dispose();
    await LocalStore.instance.removeServer(serverId);
    if (_activeServerId == serverId) {
      _activeServerId = _servers.keys.isNotEmpty ? _servers.keys.first : null;
    }
    notifyListeners();
  }

  /// 离开当前服务器
  Future<void> leaveActiveServer() async {
    final sc = activeServer;
    if (sc == null) return;
    await sc.leaveServer();
    await removeServer(_activeServerId!);
  }
}
