import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/av_session.dart';
import '../services/connection_service.dart';
import '../services/identity_service.dart';
import '../services/local_store.dart';
import '../services/push_service.dart';
import 'server_connection.dart';

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
        sc.connectAndJoin().catchError((_) => false);
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
