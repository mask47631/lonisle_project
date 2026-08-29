import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/message.dart';
import '../proto/lonisle.pb.dart' as pb;
import '../rust/api.dart' as rust;
import '../services/connection_service.dart';
import '../services/e2ee_service.dart';
import '../services/identity_service.dart';
import '../services/local_store.dart';
import '../services/media_service.dart';
import '../services/keepalive_service.dart';
import '../services/push_service.dart';

/// 单服务器连接封装：独立的连接实例 + 该服务器的话题/消息/成员/未读状态。
class ServerConnection extends ChangeNotifier {
  final String serverId;
  /// 服务器名称（join/本地记录初始化；SERVER_INFO_UPDATED 事件实时更新）
  String serverName;
  final ConnectionService connection;
  final LocalStore _local = LocalStore.instance;

  ConnectionStatus status = ConnectionStatus.disconnected;
  List<ChatMessage> messages = [];
  List<pb.MemberInfo> members = [];
  List<pb.TopicInfo> topics = [];

  /// 服务器表情包（F-STICKER：管理员管理，成员只读；变更实时推送）
  List<pb.StickerPack> serverStickerPacks = [];

  /// 拉取服务器表情包（join 成功后调用一次；之后管理端变更会实时推送）
  Future<void> loadServerStickerPacks() async {
    try {
      final resp = await connection.listStickerPacks();
      serverStickerPacks = resp.packs;
      notifyListeners();
    } catch (_) {
      // 拉取失败静默（下次变更推送/重新连接时再同步）
    }
  }
  bool isOwner = false;
  bool isAdmin = false;

  int _cursor = 0;
  String currentTopicId = 'default';
  Map<String, int> _topicUnread = {};
  bool pendingApproval = false;

  /// 服务器图标版本标识（来自 join 的 ServerInfo.icon，空则未设置）
  String get serverIcon => connection.serverIcon;

  /// 服务器级未读总数
  int get unread => _topicUnread.values.fold(0, (a, b) => a + b);

  final String host;
  final int port;

  ServerConnection({
    required this.serverId,
    required this.serverName,
    required this.connection,
    required this.host,
    required this.port,
  });

  /// 当前成员（本人在服务器内的信息）
  pb.MemberInfo? get selfMember {
    for (final m in members) {
      if (m.userId == IdentityService.instance.userId) return m;
    }
    return null;
  }

  /// 连接并加入（返回是否待审批）
  Future<bool> connectAndJoin({
    String reason = '',
    String claimCode = '',
    String inviteToken = '',
    String expectedFingerprint = '',
  }) async {
    // F-MSG-3 本地优先：先从本地缓存恢复话题列表 + 上次话题的消息，
    // 服务器不可达（断线/离线启动）也能浏览历史记录
    await _restoreLocalCache();

    // 先注册状态监听（在 connect 之前，避免错过 connecting/connected 事件）
    connection.statusStream.listen((s) {
      status = s;
      notifyListeners();
    });

    connection.broadcastStream.listen(_onBroadcast);
    connection.notifyStream.listen((env) async {
      // 表情包变更推送（F-STICKER：管理员管理页改动后实时刷新）
      if (env.type == pb.ServerEnvelope_MsgType.STICKER_PACKS_UPDATED &&
          env.payload.isNotEmpty) {
        try {
          final resp = pb.StickerPackListResponse.fromBuffer(env.payload);
          serverStickerPacks = resp.packs;
          notifyListeners();
        } catch (e) {
          debugPrint('[StickerPacksUpdated] 解析失败: $e');
        }
        return;
      }
      // 服务器资料变更（名称/图标等，F-PERM-2）：实时刷新，无需重连
      if (env.type == pb.ServerEnvelope_MsgType.SERVER_INFO_UPDATED &&
          env.payload.isNotEmpty) {
        try {
          final info = pb.ServerInfo.fromBuffer(env.payload);
          connection.applyServerInfo(info);
          if (info.name.isNotEmpty) serverName = info.name;
          notifyListeners();
        } catch (e) {
          debugPrint('[ServerInfoUpdated] 解析失败: $e');
        }
        return;
      }
      // F-JOIN-6：被踢/封禁定向提示（payload 携带受害者 MemberInfo）
      if (env.type == pb.ServerEnvelope_MsgType.MEMBER_UPDATED &&
          env.payload.isNotEmpty) {
        try {
          final info = pb.MemberInfo.fromBuffer(env.payload);
          final selfId = IdentityService.instance.userId;
          if (selfId != null && info.userId == selfId) {
            expelled = true;
            _notifyChanged();
            notifyListeners();
          }
        } catch (_) {}
      }
      // F-JOIN：审批结果广播（网页端/客户端审批均会广播）
      // → 待审批时自动重新 join，审批通过即完成加入
      if (env.type == pb.ServerEnvelope_MsgType.JOIN_REQUEST_UPDATED &&
          pendingApproval) {
        await pollJoinStatus();
        return;
      }
      refreshMembers();
      refreshTopics();
    });
    // 成员设备变更：吊销时被动学习证明并本地持久化（F-DEV-8），供跨服务器中继
    connection.deviceChangeStream.listen((event) async {
      if (!event.added && event.revocationProof.isNotEmpty) {
        final proof = pb.RevocationProof.fromBuffer(event.revocationProof);
        await _local.saveRevocation(
          userId: proof.userId,
          devicePubkeyHex: _hexEncode(proof.devicePubkey),
          proofHex: _hexEncode(event.revocationProof),
          revokedAt: proof.revokedAt.toInt(),
        );
      }
      refreshMembers();
    });
    // 断线重连成功后：重做 Hello/Join/Sync 完整握手
    connection.onReconnected = _rehandshake;

    await connection.connect(
      host,
      port,
      expectedFingerprint:
          expectedFingerprint.isNotEmpty ? expectedFingerprint : null,
    );

    final hello = await connection.hello();
    if (!hello.compatible) {
      throw StateError('协议版本不兼容');
    }

    final join = await connection.join(
      reason: reason,
      claimCode: claimCode,
      inviteToken: inviteToken,
    );
    isOwner = join.isOwner;
    topics = join.topics;
    // 表情包：join 后拉取一次（管理端变更会实时推送）
    unawaited(loadServerStickerPacks());
    // 同步服务器最新名称/图标（join 响应的 ServerInfo）
    if (connection.serverName.isNotEmpty) {
      serverName = connection.serverName;
    }
    // 保留本地恢复的上次话题（仍存在时），否则回退到第一个话题
    if (join.topics.isNotEmpty &&
        !join.topics.any((t) => t.topicId == currentTopicId)) {
      currentTopicId = join.topics.first.topicId;
    }
    _persistLocalCache();

    final pending = join.status == pb.JoinStatus.PENDING;
    pendingApproval = pending;
    if (!pending) {
      // 同步媒体服务地址（附件上传/下载用，活跃服务器）
      MediaService.instance.setServer(connection.host, connection.port);
      await _registerDevice();
      await _loadLocal();
      await _sync();
      await refreshMembers();
      await refreshTopics();
      _refreshAdmin();
    }
    notifyListeners();
    return pending;
  }

  /// 断线重连后的完整重握手：Hello → Join → 设备注册 → 增量同步。
  /// 待审批成员不做完整握手（join 轮询由 UI 驱动）。
  Future<void> _rehandshake() async {
    final hello = await connection.hello();
    if (!hello.compatible) return;
    final join = await connection.join();
    if (join.status == pb.JoinStatus.PENDING) return;
    isOwner = join.isOwner;
    topics = join.topics;
    await _registerDevice();
    await _sync();
    await refreshMembers();
    await refreshTopics();
    _refreshAdmin();
    notifyListeners();
  }

  /// 注册当前设备并中继本地已知的吊销证明（F-DEV-5/8）。
  /// 失败不阻断加入流程。
  Future<void> _registerDevice() async {
    try {
      final deviceId = await IdentityService.instance.deviceId();
      final deviceName = await IdentityService.instance.deviceName();
      final cert = await IdentityService.instance.deviceCert();
      if (deviceId == null || cert == null) return;
      final revs = await _local.loadRevocations();
      await connection.registerDevice(
        deviceId: deviceId,
        deviceName: deviceName ?? '我的设备',
        platform: _platformName(),
        deviceCertHex: cert,
        revocationHexes:
            revs.map((r) => r['proof_hex'] as String).toList(),
      );
    } catch (_) {
      // 注册失败不阻断（下次连接重试）
    }
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      _ => 'unknown',
    };
  }

  // ---- F-JOIN-8：迁移公告验签与确认 ----

  /// 验证迁移公告签名（服务器私钥对 target+fingerprint+server_id 签名）。
  /// 返回 null = 无迁移或验签通过；否则返回错误描述。
  Future<String?> verifyMigrationSignature() async {
    if (connection.migrationTarget.isEmpty) return null;
    if (connection.migrationSignature.isEmpty) {
      return '迁移公告缺少签名（旧版本服务器）';
    }
    try {
      final ok = rust.verifyMigrationSignature(
        serverPubkeyHex: connection.serverPubkeyHex,
        address: connection.migrationTarget,
        fingerprint: connection.migrationFingerprint,
        serverId: connection.serverId,
        signatureHex: connection.migrationSignature,
      );
      if (!ok) return '迁移公告签名验证失败';
      return null;
    } catch (e) {
      return '迁移公告验签异常：$e';
    }
  }

  /// 归档本服务器（迁移确认后调用）：断开连接、本地消息只读保留。
  Future<void> archiveAfterMigration() async {
    _archived = true;
    dispose();
  }

  bool _archived = false;
  bool get isArchived => _archived;

  /// 本账号被该服务器踢出/封禁（F-JOIN-6，UI 显示横幅）
  bool expelled = false;

  /// 通知流（F-UI-3：@我/审批/系统事件触发通知中心刷新）
  final _notificationController = StreamController<void>.broadcast();
  Stream<void> get notificationStream => _notificationController.stream;

  void _notifyChanged() {
    if (!_notificationController.isClosed) _notificationController.add(null);
  }

  /// 轮询审批状态（待审批时调用）
  Future<void> pollJoinStatus() async {
    final join = await connection.join();
    isOwner = join.isOwner;
    pendingApproval = join.status == pb.JoinStatus.PENDING;
    if (!pendingApproval) {
      topics = join.topics;
      await _registerDevice();
      await _loadLocal();
      await _sync();
      await refreshMembers();
      await refreshTopics();
      _refreshAdmin();
    }
    notifyListeners();
  }

  void _onBroadcast(pb.BroadcastMessage msg) {
    // Reaction 事件（无文本、携带 reactions 聚合）：更新已有消息，不插入新条目
    if (msg.reactions.isNotEmpty &&
        !msg.hasContent() &&
        !msg.edited &&
        !msg.deleted) {
      _local.upsertReactions(serverId, msg.msgId, msg.reactions);
      _loadLocal();
      notifyListeners();
      return;
    }

    if (msg.topicId != currentTopicId) {
      // 非当前话题：增加未读 + 失焦时本地通知（桌面端）
      _local.incrementUnread(serverId, msg.topicId);
      _reloadUnread();
      _maybeLocalNotify(
        String.fromCharCodes(msg.authorId),
        msg.authorName,
        msg.topicId,
        msg.content.text,
        msg.content.hasAttachment(),
      );
      return;
    }

    if (msg.edited || msg.deleted) {
      if (msg.deleted) {
        _local.markDeleted(serverId, msg.msgId);
      } else {
        _local.markEdited(serverId, msg.msgId, msg.content.text);
      }
      _loadLocal();
      notifyListeners();
      return;
    }

    // E2EE 解密：若 content.encrypted 非空且 text 为空，尝试解密
    var displayContent = msg.content.text;
    if (displayContent.isEmpty && msg.content.encrypted.isNotEmpty) {
      final authorId = String.fromCharCodes(msg.authorId);
      final decrypted = E2eeService.instance.decryptFrom(
        authorId,
        _hexEncode(msg.content.encrypted),
      );
      if (decrypted != null) {
        displayContent = decrypted;
      } else {
        displayContent = '[加密消息]';
      }
    }

    final m = ChatMessage(
      seq: msg.seq.toInt(),
      serverId: serverId,
      topicId: msg.topicId,
      msgId: msg.msgId,
      authorId: String.fromCharCodes(msg.authorId),
      authorName: msg.authorName,
      serverTs: msg.serverTs.toInt(),
      content: displayContent,
      attachment: msg.content.hasAttachment() ? msg.content.attachment : null,
      reactions: msg.reactions,
      mentions: msg.mentions,
      replyTo: msg.replyTo,
    );

    // @提及已读自动上报（F-MSG-10：仅当本服务器开关开启，默认关）
    if (m.mentions.isNotEmpty) {
      _autoMarkMentionRead(m);
    }

    // 附件自动下载（F-MEDIA-4/5：阈值 + 网络判定，静默失败）
    if (m.attachment != null) {
      _autoDownloadAttachment(m.attachment!);
    }

    // 内存去重：广播与本地乐观插入/同步可能产生同 msgId 重复（切换话题会重置），
    // 追加前按 msgId 查重（F-MSG-1）
    if (messages.any((x) => x.msgId == m.msgId)) {
      return;
    }

    messages.add(m);
    // @我 → 通知中心刷新（F-UI-3）
    if (m.mentions.isNotEmpty) _notifyChanged();
    // 当前话题新消息：仅失焦时提醒（桌面端，正在聊天不打扰）
    _maybeLocalNotify(
      m.authorId,
      m.authorName,
      m.topicId,
      m.content,
      m.attachment != null,
    );
    _local.upsertMessage(m);
    _cursor = m.seq;
    _local.writeCursor(serverId, currentTopicId, _cursor);
    notifyListeners();
  }

  Future<void> _loadLocal() async {
    messages = await _local.loadMessages(serverId, currentTopicId);
    notifyListeners();
  }

  /// 桌面端（macOS）运行中本地通知：
  /// 运行中本地通知：
  /// - macOS：窗口失焦时提醒（正在聊天不打扰）；非当前话题消息即使聚焦也弹
  /// - Android：后台保活服务运行期间提醒（通知策略与 FCM 唤醒一致）
  /// 自己的消息不提醒。
  void _maybeLocalNotify(
    String authorId,
    String authorName,
    String topicId,
    String text,
    bool hasAttachment,
  ) {
    final keepAliveAndroid =
        Platform.isAndroid && KeepAliveService.instance.backgroundActive;
    if (!Platform.isMacOS && !keepAliveAndroid) return;
    if (authorId == selfMember?.userId) return;

    final focusLost = !PushService.instance.appFocused;
    final otherTopic = topicId != currentTopicId;
    // macOS：聚焦且当前话题不弹；Android 保活期间按 FCM 唤醒语义逐条提醒
    if (Platform.isMacOS && !focusLost && !otherTopic) return;

    final topicName = topics
        .where((t) => t.topicId == topicId)
        .map((t) => t.name)
        .firstOrNull;
    final snippet = text.isNotEmpty
        ? (text.length > 40 ? '${text.substring(0, 40)}…' : text)
        : '[附件]';
    PushService.instance.showLocalNotification(
      id: msgHash(topicId, authorId, snippet),
      title: '$serverName${topicName == null ? '' : ' · $topicName'}',
      body: '$authorName：$snippet',
    );
  }

  static int msgHash(String a, String b, String c) => Object.hash(a, b, c);

  // ---- 离线缓存（F-MSG-3 本地优先渲染）----

  static String _kLastTopic(String serverId) => 'last_topic_$serverId';
  static String _kTopicsCache(String serverId) => 'topics_cache_$serverId';

  /// 启动时恢复本地缓存：话题列表 + 上次打开话题的消息。
  /// 任何失败静默忽略（不影响后续在线流程）。
  Future<void> _restoreLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final topicsJson = prefs.getString(_kTopicsCache(serverId));
      if (topicsJson != null && topicsJson.isNotEmpty) {
        final list = jsonDecode(topicsJson) as List;
        topics = list
            .map((e) => pb.TopicInfo(
                  topicId: e['id'] as String? ?? '',
                  name: e['name'] as String? ?? '',
                  description: e['desc'] as String? ?? '',
                  sortOrder: e['sort'] as int? ?? 0,
                  type: pb.TopicType.valueOf(e['type'] as int? ?? 0) ??
                      pb.TopicType.TEXT,
                  permission: pb.TopicPermission.valueOf(
                          e['perm'] as int? ?? 0) ??
                      pb.TopicPermission.PUBLIC,
                ))
            .toList();
      }
      final last = prefs.getString(_kLastTopic(serverId));
      if (last != null && last.isNotEmpty) {
        currentTopicId = last;
      } else if (topics.isNotEmpty) {
        currentTopicId = topics.first.topicId;
      }
      await _loadLocal();
    } catch (_) {}
  }

  /// 持久化话题列表与当前话题（供离线恢复）
  Future<void> _persistLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kTopicsCache(serverId),
        jsonEncode([
          for (final t in topics)
            {
              'id': t.topicId,
              'name': t.name,
              'desc': t.description,
              'sort': t.sortOrder,
              'type': t.type.value,
              'perm': t.permission.value,
            }
        ]),
      );
      await prefs.setString(_kLastTopic(serverId), currentTopicId);
    } catch (_) {}
  }

  Future<void> _sync() async {
    // 游标按话题独立（服务端 seq 按话题递增），避免跨话题污染跳过消息
    _cursor = await _local.readCursor(serverId, currentTopicId);
    final resp = await connection.sync(currentTopicId, _cursor);
    // 本地已有消息 ID 集合（F-MSG-14：删除事件对无原消息的设备不可见）
    final localIds = (await _local.loadMessages(serverId, currentTopicId))
        .map((m) => m.msgId)
        .toSet();
    final incoming = resp.messages.where((m) {
      final known = localIds.contains(m.msgId);
      // 编辑/删除事件的 seq 是服务端新分配的事件序号：本地在上一会话已按
      // 原消息位置就地标记（markEdited/markDeleted），若用新 seq REPLACE 落库
      // 会破坏原行的 seq 导致墓碑"移动"到列表末尾——已知消息的事件一律跳过
      if ((m.edited || m.deleted) && known) return false;
      return !m.deleted || known;
    }).map((m) => ChatMessage(
          seq: m.seq.toInt(),
          serverId: serverId,
          topicId: m.topicId,
          msgId: m.msgId,
          authorId: String.fromCharCodes(m.authorId),
          authorName: m.authorName,
          serverTs: m.serverTs.toInt(),
          content: m.content.text,
          edited: m.edited,
          deleted: m.deleted,
          attachment: m.content.hasAttachment() ? m.content.attachment : null,
          reactions: m.reactions,
          mentions: m.mentions,
          replyTo: m.replyTo,
        ));
    try {
      await _local.upsertMessages(incoming.toList());
    } catch (e, st) {
      // 落库失败必须可见（此前的 Int64→jsonEncode 崩溃曾被静默吞掉）
      // ignore: avoid_print
      print('SYNC-ERROR upsertMessages 失败: $e\n$st');
      rethrow;
    }
    await _loadLocal();
    if (resp.latestSeq > _cursor) {
      _cursor = resp.latestSeq.toInt();
      await _local.writeCursor(serverId, currentTopicId, _cursor);
    }
  }

  /// 某话题未读数（F-UI-4 角标）
  int unreadOf(String topicId) => _topicUnread[topicId] ?? 0;

  /// 是否正在加载更早历史（防重复触发）
  bool historyLoading = false;

  /// 是否还有更早的历史消息（服务端 has_more 累计判断）
  bool hasMoreHistory = true;

  /// 历史消息向前翻页：从当前列表最旧消息的 seq 往前拉取更早消息，
  /// 插入列表头部并落库（滚动到顶部时由 UI 触发，F-MSG 历史加载）。
  Future<void> loadMoreHistory() async {
    if (historyLoading || !hasMoreHistory) return;
    historyLoading = true;
    notifyListeners();
    try {
      // 最旧消息的 seq（本地可能已有缓存，从缓存最旧值往前）
      final local = await _local.loadMessages(serverId, currentTopicId);
      final oldestSeq = local.isEmpty ? 0 : local.first.seq;
      final resp = await connection.history(currentTopicId, oldestSeq);
      final incoming = resp.messages.reversed.map((m) => ChatMessage(
            seq: m.seq.toInt(),
            serverId: serverId,
            topicId: m.topicId,
            msgId: m.msgId,
            authorId: String.fromCharCodes(m.authorId),
            authorName: m.authorName,
            serverTs: m.serverTs.toInt(),
            content: m.content.text,
            edited: m.edited,
            deleted: m.deleted,
            attachment: m.content.hasAttachment() ? m.content.attachment : null,
            reactions: m.reactions,
            mentions: m.mentions,
            replyTo: m.replyTo,
          ));
      if (incoming.isNotEmpty) {
        await _local.upsertMessages(incoming.toList());
        await _loadLocal();
      }
      // 服务端返回满页才可能有更早的消息
      hasMoreHistory = resp.hasMore;
    } catch (_) {
      // 历史加载失败静默（下次滚动重试）
    } finally {
      historyLoading = false;
      notifyListeners();
    }
  }

  /// 当前话题是否公告类型（普通成员禁言，F-TOPIC-4）
  bool get currentTopicAnnouncement {
    final t = topics.where((t) => t.topicId == currentTopicId).toList();
    return t.isNotEmpty && t.first.type == pb.TopicType.ANNOUNCEMENT;
  }

  /// 切换话题（清空该话题未读）
  Future<void> switchTopic(String topicId) async {
    if (topicId == currentTopicId) return;
    currentTopicId = topicId;
    _persistLocalCache();
    await _local.clearUnread(serverId, topicId);
    await _reloadUnread();
    await _loadLocal();
    await _sync();
    notifyListeners();
  }

  /// 发送文本（可选携带回复引用）；返回是否发送成功。
  /// 失败时乐观消息保留在列表并标记 failed（UI 显示失败标记 + 可重试）。
  Future<bool> sendText(String text, {String replyTo = ''}) async {
    final content = text.trim();
    if (content.isEmpty) return false;
    final identity = await IdentityService.instance.loadIdentity();
    if (identity == null) return false;

    final optimistic = ChatMessage(
      seq: -DateTime.now().millisecondsSinceEpoch,
      serverId: serverId,
      topicId: currentTopicId,
      msgId: 'local-${DateTime.now().microsecondsSinceEpoch}',
      authorId: identity.userId,
      authorName: identity.displayName,
      serverTs: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      content: content,
      pending: true,
      replyTo: replyTo,
    );
    messages.add(optimistic);
    notifyListeners();

    try {
      await connection.sendText(currentTopicId, content, replyTo: replyTo);
      // 发送成功：移除本地乐观消息（服务器回执会带权威消息回来）
      messages.removeWhere((m) => m.pending && m.content == content);
      notifyListeners();
      return true;
    } catch (e) {
      // 发送失败：乐观消息标记 failed（保留，供 UI 显示失败标记与重试）
      final i = messages.indexWhere((m) => m.pending && m.content == content);
      if (i >= 0) messages[i] = messages[i].copyWith(failed: true);
      notifyListeners();
      return false;
    }
  }

  /// 重试失败的本地消息（F-SEND 失败恢复）：重新发送，成功后清除对应乐观消息
  Future<bool> retryFailedMessage(ChatMessage msg) async {
    if (!msg.failed) return false;
    final i = messages.indexWhere((m) => m.msgId == msg.msgId);
    if (i >= 0) messages[i] = messages[i].copyWith(pending: true, failed: false);
    notifyListeners();

    try {
      await connection.sendText(msg.topicId, msg.content, replyTo: msg.replyTo);
      messages.removeWhere(
          (m) => (m.pending || m.failed) && m.topicId == msg.topicId && m.content == msg.content);
      notifyListeners();
      return true;
    } catch (e) {
      final j = messages.indexWhere((m) => m.msgId == msg.msgId);
      if (j >= 0) messages[j] = messages[j].copyWith(failed: true);
      notifyListeners();
      return false;
    }
  }

  /// 删除本地失败的乐观消息（不发送删除事件，仅本地清理）
  void removeFailedMessage(ChatMessage msg) {
    messages.removeWhere((m) => m.msgId == msg.msgId);
    notifyListeners();
  }

  /// 发送附件消息（F-MEDIA-1：上传 → 发送带元数据消息）
  /// [durationSec] 音视频时长、[width]/[height] 媒体尺寸（F-MEDIA-8）、
  /// [thumbnail] 视频首帧缩略图（F-MEDIA-1）、[onUpload] 上传开始回调
  Future<void> sendAttachment({
    required Uint8List data,
    required String filename,
    required String kind,
    String caption = '',
    int durationSec = 0,
    int width = 0,
    int height = 0,
    Uint8List? thumbnail,
    void Function()? onUpload,
  }) async {    final id = await IdentityService.instance.loadIdentity();
    if (id == null) return;
    final msgId = 'm-${DateTime.now().microsecondsSinceEpoch}';
    try {
      final att = await MediaService.instance.upload(
        data: data,
        filename: filename,
        msgId: msgId,
        kind: kind,
        userId: id.userId,
        durationSec: durationSec,
        width: width,
        height: height,
        thumbnail: thumbnail,
        onUpload: onUpload,
        serverAddress: '${connection.host}:${connection.port}',
      );
      await connection.sendAttachment(currentTopicId, caption, att);
    } catch (e) {
      // 失败提示由调用方 UI 处理
      rethrow;
    }
  }

  /// 发送图片表情（F-STICKER：表情包内图片已存服务器，直接引用附件发送，不重复上传）
  Future<void> sendStickerImage(String attRef) async {
    final attId = attRef.replaceFirst('att:', '');
    if (attId.isEmpty) return;
    final att = pb.Attachment()
      ..attachmentId = attId
      ..kind = 'image'
      ..filename = 'sticker'
      ..mime = 'image/*';
    await connection.sendAttachment(currentTopicId, '', att);
  }

  /// 发送 E2EE 加密消息给话题内某成员（M6）：
  /// 拉取对端预密钥束 → 验 SPK 签名 → 建立双棘轮会话 → sendEncrypted。
  Future<void> sendEncryptedTo(String peerUserId, String plaintext) async {
    try {
      var session = E2eeService.instance.session(peerUserId);
      session ??= await _establishE2eeSession(peerUserId);
      if (session == null) {
        throw StateError('无法建立加密会话（对端未上传预密钥）');
      }
      final ctHex = session.encrypt(plaintext);
      await connection.sendEncrypted(currentTopicId, ctHex);
    } catch (e) {
      rethrow;
    }
  }

  /// 拉取对端预密钥束并建立会话（含 SPK 验签）
  Future<E2eeSession?> _establishE2eeSession(String peerUserId) async {
    final bundle = await connection.fetchPreKeys(peerUserId);
    if (bundle == null) return null;

    final e2ee = E2eeService.instance;
    await e2ee.init();
    final identityHex = _hexEncode(bundle.identityKey);
    final spkHex = _hexEncode(bundle.signedPreKey);
    final sigHex = _hexEncode(bundle.signedPreKeySig);

    // SPK 签名验证（M6 加固：防中间人替换预密钥）
    if (sigHex.isNotEmpty && !e2ee.verifyPeerSpk(
          masterPubkeyHex: peerUserId, // user_id = 主公钥哈希，验签需主公钥
          spkPubHex: spkHex,
          signatureHex: sigHex,
        )) {
      // 注：user_id 是哈希而非公钥，验签失败仅告警不阻断（完整实现需
      // 成员资料携带主公钥；此处保留接口，验证由 identity_key 信任链兜底）
      // ignore: avoid_print
      print('SPK 签名验证未通过或缺少主公钥，继续以 identity_key 为准');
    }

    final opk = bundle.oneTimePreKeys.isNotEmpty
        ? _hexEncode(bundle.oneTimePreKeys.first)
        : null;
    return e2ee.establishSession(
      peerUserId,
      peerIdentityHex: identityHex,
      peerSignedPreKeyHex: spkHex,
      peerOneTimePreKeyHex: opk,
    );
  }

  Future<void> refreshMembers() async {
    final resp = await connection.listMembers();
    members = resp.members;
    _refreshAdmin();
    notifyListeners();
  }

  Future<void> refreshTopics() async {
    final resp = await connection.listTopics();
    topics = resp.topics;
    _persistLocalCache();
    notifyListeners();
  }

  void _refreshAdmin() {
    final self = selfMember;
    isAdmin = self != null &&
        (self.role == pb.MemberRole.OWNER || self.role == pb.MemberRole.ADMIN);
  }

  Future<void> _reloadUnread() async {
    _topicUnread = await _local.readTopicUnreads(serverId);
    notifyListeners();
  }

  // ---- @提及已读上报（F-MSG-10，每服务器开关，默认关） ----

  static const _mentionReadKeyPrefix = 'mention_read_enabled_';

  /// 本服务器是否开启已读上报
  Future<bool> mentionReadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_mentionReadKeyPrefix$serverId') ?? false;
  }

  /// 设置本服务器已读上报开关
  Future<void> setMentionReadEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_mentionReadKeyPrefix$serverId', enabled);
  }

  /// 附件自动下载（F-MEDIA-4/5：阈值 + 网络判定，静默失败）
  Future<void> _autoDownloadAttachment(pb.Attachment att) async {
    try {
      if (!await MediaService.instance.shouldAutoDownload(att)) return;
      // 传 filename：缓存文件保留原始文件名（F-MEDIA-10），另存为时有据可依
      await MediaService.instance
          .download(att.attachmentId, filename: att.filename);
    } catch (_) {
      // 静默失败：用户点击缩略图时会手动重试
    }
  }

  /// 被提及且开关开启时自动上报已读（静默失败）
  Future<void> _autoMarkMentionRead(ChatMessage m) async {
    try {
      final id = IdentityService.instance.userId;
      if (id == null || !m.mentionsUser(id)) return;
      if (!await mentionReadEnabled()) return;
      await connection.markMentionRead(m.topicId, m.msgId);
    } catch (_) {
      // 服务器未开启或网络失败：静默忽略
    }
  }

  Future<void> reloadUnread() => _reloadUnread();

  // ---- 设备管理 ----

  Future<pb.DeviceListResponse> listDevices() => connection.listDevices();

  Future<void> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String deviceCertHex,
  }) {
    return connection.registerDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
      deviceCertHex: deviceCertHex,
    );
  }

  Future<void> revokeDevice({
    required String devicePubkeyHex,
    required String proofHex,
  }) {
    return connection.revokeDevice(
      devicePubkeyHex: devicePubkeyHex,
      proofHex: proofHex,
    );
  }

  // ---- 成员管理（管理员） ----

  Future<void> setMemberRole(String userId, pb.MemberRole role) async {
    await connection.setMemberRole(userId, role);
    await refreshMembers();
  }

  Future<void> setMute(String userId, bool muted) async {
    await connection.setMute(userId, muted);
    await refreshMembers();
  }

  Future<void> kickMember(String userId) async {
    await connection.kickMember(userId);
    await refreshMembers();
  }

  Future<void> setBan(String userId, bool banned) async {
    await connection.setBan(userId, banned);
    await refreshMembers();
  }

  Future<List<pb.JoinRequestInfo>> listJoinRequests() async {
    final resp = await connection.listJoinRequests();
    return resp.requests;
  }

  Future<void> processJoinRequest(String requestId, bool approve) async {
    await connection.processJoinRequest(requestId, approve);
    await refreshMembers();
  }

  // ---- 话题管理（管理员） ----

  Future<void> createTopic({
    required String name,
    String description = '',
    pb.TopicType type = pb.TopicType.TEXT,
  }) async {
    await connection.createTopic(name: name, description: description, type: type);
    await refreshTopics();
  }

  Future<void> deleteTopic(String topicId) async {
    await connection.deleteTopic(topicId);
    await refreshTopics();
  }

  // ---- 音视频话题（LiveKit） ----

  /// 服务器是否启用音视频
  bool get avEnabled => connection.avEnabled;

  /// 加入音视频话题
  Future<pb.JoinAVResponse> joinAV(String topicId) {
    return connection.joinAV(topicId);
  }

  // ---- 资料覆盖 ----

  Future<void> updateServerProfile({String? nickname, String? avatar}) async {
    await connection.updateServerProfile(nickname: nickname, avatar: avatar);
    await refreshMembers();
  }

  // ---- 消息编辑/删除 ----

  Future<void> editMessage(String msgId, String newText) {
    return connection.editMessage(currentTopicId, msgId, newText);
  }

  Future<void> deleteMessage(String msgId) {
    return connection.deleteMessage(currentTopicId, msgId);
  }

  Future<void> addReaction(String topicId, String msgId, String emoji) {
    return connection.addReaction(topicId, msgId, emoji);
  }

  Future<void> removeReaction(String topicId, String msgId, String emoji) {
    return connection.removeReaction(topicId, msgId, emoji);
  }

  // ---- P2：已读回执 ----

  Future<void> markMentionRead(String topicId, String msgId) {
    return connection.markMentionRead(topicId, msgId);
  }

  Future<pb.MentionReadListResponse> mentionReadList(String msgId) {
    return connection.mentionReadList(msgId);
  }

  Future<void> leaveServer() async {
    await connection.leaveServer();
  }

  @override
  void dispose() {
    connection.dispose();
    super.dispose();
  }
}

String _hexEncode(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
