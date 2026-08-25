import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart' show Int64;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../proto/lonisle.pb.dart' as pb;
import '../rust/api.dart' as rust;
import 'identity_service.dart';
import 'tofu_http.dart';

/// 连接状态
enum ConnectionStatus { disconnected, connecting, connected, reconnecting }

/// 连接服务：与单个聊天服务器的 WebSocket 长连接
///
/// 负责 Hello 握手、开放加入、消息收发、广播接收、游标增量同步。
/// protobuf 编解码在 Dart 侧（生成的 proto 类），签名复用 Rust 桥接。
class ConnectionService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  final _requestId = _SeqGen();
  final _pending = <int, Completer<pb.ServerEnvelope>>{};

  /// 连接状态流
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  ConnectionStatus get status => _status;

  /// 收到的广播消息流
  final _broadcastController = StreamController<pb.BroadcastMessage>.broadcast();
  Stream<pb.BroadcastMessage> get broadcastStream => _broadcastController.stream;

  /// 服务器推送通知流（审批结果/成员变更/话题变更）
  final _notifyController = StreamController<pb.ServerEnvelope>.broadcast();
  Stream<pb.ServerEnvelope> get notifyStream => _notifyController.stream;

  /// 成员设备变更事件流（F-MSG-15/F-DEV-8，吊销时携带证明）
  final _deviceChangeController =
      StreamController<pb.MemberDeviceChangeEvent>.broadcast();
  Stream<pb.MemberDeviceChangeEvent> get deviceChangeStream =>
      _deviceChangeController.stream;

  String serverId = '';
  String serverName = '';
  String serverDesc = '';
  String serverFingerprint = '';
  String migrationTarget = '';       // 迁移目标地址（P1）
  String migrationFingerprint = '';  // 迁移目标指纹（P1）
  String migrationSignature = '';    // 迁移公告签名（服务器私钥签名，F-JOIN-8）
  String serverPubkeyHex = '';       // 服务器公钥（验迁移公告签名用）
  String serverIcon = '';            // 服务器图标版本标识（"ext:ts"，空则未设置，F-PERM-2）
  int serverStrategy = 0;            // 加入策略（JoinStrategy 值）
  int rateLimitPerMinute = 0;        // 发言频率限制（0 = 不限）
  int maxAttachmentSize = 0;         // 附件大小上限（字节，0 = 不限）
  bool avEnabled = false;            // 服务器是否启用音视频（LiveKit）
  List<pb.TopicInfo> topics = [];
  bool isOwner = false;

  String _host = '';
  int _port = 0;
  String? _expectedFingerprint; // 邀请链接携带的指纹（F-JOIN-7）

  /// 当前服务器地址（媒体上传/下载等 HTTP 端点用）
  String get host => _host;
  int get port => _port;
  bool _reconnecting = false;
  int _retryDelay = 1; // 指数退避起始秒
  static const _maxRetryDelay = 30;

  // 心跳检测（TCP 半开检测：server 重启时连接不会触发 onDone，靠 PING/PONG 探活）
  Timer? _pingTimer;
  int _missedPings = 0;
  static const _pingInterval = Duration(seconds: 20);
  static const _pingMaxMiss = 3;

  /// 重连成功后的回调（由上层设置，用于重做 Hello/Join/Sync 握手）
  Future<void> Function()? onReconnected;

  /// 证书更换确认回调（重连时遇到 TOFU 公钥不匹配触发，由上层弹窗询问；
  /// 返回 true = 用户信任新证书）。仅连接成功后设置。
  Future<bool> Function(String host, int port, String fingerprint, String? spki)?
      onTofuMismatch;

  Future<void> connect(
    String host,
    int port, {
    String? expectedFingerprint,
  }) async {
    _host = host;
    _port = port;
    _expectedFingerprint = expectedFingerprint;
    await _open();
  }

  Future<void> _open() async {
    _setStatus(ConnectionStatus.connecting);
    final url = 'wss://$_host:$_port/ws';
    // TOFU 指纹校验（F-SID-2/3）：邀请链接指纹连接前比对，不一致中止
    final tofu = await createTofuClient(
      _host,
      _port,
      expectedFingerprint: _expectedFingerprint,
    );
    WebSocketChannel channel;
    try {
      channel = IOWebSocketChannel.connect(
        Uri.parse(url),
        customClient: tofu.client,
      );
      // 等待握手完成（TLS 证书回调在握手期间执行，之后 observedFingerprint /
      // mismatchMessage 才可用）。IOWebSocketChannel.connect 异步立即返回，
      // 若不等待，TOFU pin 会在握手前执行导致指纹永远写不进去。
      await channel.ready;
    } catch (e) {
      _setStatus(ConnectionStatus.disconnected);
      if (tofu.mismatchMessage != null) {
        throw TofuMismatchException(
          tofu.mismatchMessage!,
          tofu.observedFingerprint ?? '',
          tofu.observedSpki,
        );
      }
      rethrow;
    }
    _channel = channel;
    _sub = channel.stream.listen(
      _onData,
      onError: (e) => _onDisconnected(),
      onDone: () => _onDisconnected(),
    );
    _setStatus(ConnectionStatus.connected);
    _retryDelay = 1; // 连接成功重置退避
    _startHeartbeat();

    // TOFU 钉住（握手已完成后 observed 已就绪）：
    // - 首次连接：pin 新指纹（DER + SPKI）
    // - 同公钥续期：静默更新钉住指纹（证书到期自动续期不打扰用户）
    final observed = tofu.observedFingerprint;
    if (observed != null) {
      final existing = await Tofu.pinned(_host, _port);
      if (existing == null || tofu.renewed) {
        await Tofu.pin(_host, _port, observed, tofu.observedSpki);
      }
    }
  }

  void _onDisconnected() {
    _pingTimer?.cancel();
    _setStatus(ConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  /// 启动心跳：每 [_pingInterval] 发 PING，连续 [_pingMaxMiss] 次无响应
  /// （收到任何数据都会重置）判定断线，强制断开连接触发自动重连。
  /// 解决 server 重启时 TCP 半开连接（不触发 onDone/onError）导致客户端不重连的问题。
  void _startHeartbeat() {
    _pingTimer?.cancel();
    _missedPings = 0;
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_status != ConnectionStatus.connected) return;
      _missedPings++;
      if (_missedPings >= _pingMaxMiss) {
        // 判定断线：强制关闭触发 onDone → 自动重连
        _pingTimer?.cancel();
        try {
          _channel?.sink.close();
        } catch (_) {}
        return;
      }
      try {
        final env = pb.ClientEnvelope()
          ..type = pb.ClientEnvelope_MsgType.PING;
        _channel?.sink.add(env.writeToBuffer());
      } catch (_) {}
    });
  }

  /// 断线自动重连（指数退避；重连成功后由上层重做完整握手）
  void _scheduleReconnect() {
    if (_reconnecting) return;
    _reconnecting = true;
    _setStatus(ConnectionStatus.reconnecting);

    Future.delayed(Duration(seconds: _retryDelay), () async {
      _reconnecting = false;
      if (_retryDelay < _maxRetryDelay) _retryDelay *= 2;
      if (_status != ConnectionStatus.disconnected &&
          _status != ConnectionStatus.reconnecting) {
        return;
      }
      try {
        await _open();
        // 重连成功：重做 Hello/Join/Sync 完整握手（否则是未认证会话）
        await onReconnected?.call();
      } catch (e) {
        if (e is TofuMismatchException && onTofuMismatch != null) {
          // 服务器证书更换：询问用户是否信任新证书；确认后清除旧信任立即重连
          final ok = await onTofuMismatch!(
            _host,
            _port,
            e.actualFingerprint,
            e.actualSpki,
          );
          if (ok) {
            await Tofu.unpin(_host, _port);
            _retryDelay = 1;
            _scheduleReconnect();
            return;
          }
        }
        // 失败（或用户拒绝信任）：继续退避重连
        _onDisconnected();
      }
    });
  }

  void _setStatus(ConnectionStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  void _onData(dynamic data) {
    if (data is! List<int>) return;
    // 收到任何数据（PONG/消息/回执）= 连接活着，重置心跳计数
    _missedPings = 0;
    final env = pb.ServerEnvelope.fromBuffer(Uint8List.fromList(data));

    // 广播消息直接分发
    if (env.type == pb.ServerEnvelope_MsgType.BROADCAST) {
      final msg = pb.BroadcastMessage.fromBuffer(env.payload);
      if (!_broadcastController.isClosed) _broadcastController.add(msg);
      return;
    }

    // 推送通知（审批结果/成员变更/话题变更/服务器资料变更）分发
    if (env.type == pb.ServerEnvelope_MsgType.JOIN_REQUEST_UPDATED ||
        env.type == pb.ServerEnvelope_MsgType.MEMBER_UPDATED ||
        env.type == pb.ServerEnvelope_MsgType.TOPIC_UPDATED ||
        env.type == pb.ServerEnvelope_MsgType.SERVER_INFO_UPDATED) {
      if (!_notifyController.isClosed) _notifyController.add(env);
      return;
    }

    // 成员设备变更事件（F-DEV-8，吊销时携带证明供被动学习）
    if (env.type == pb.ServerEnvelope_MsgType.MEMBER_DEVICE_CHANGE) {
      final event = pb.MemberDeviceChangeEvent.fromBuffer(env.payload);
      if (!_deviceChangeController.isClosed) {
        _deviceChangeController.add(event);
      }
      return;
    }

    // 关联 request_id 的回执
    final completer = _pending.remove(env.requestId.toInt());
    if (completer != null && !completer.isCompleted) {
      completer.complete(env);
    }
  }

  /// 发送请求并等待回执
  Future<pb.ServerEnvelope> _request(
    pb.ClientEnvelope_MsgType type,
    Uint8List payload,
  ) async {
    final id = _requestId.next();
    final env = pb.ClientEnvelope()
      ..type = type
      ..requestId = Int64(id)
      ..payload = payload;
    final completer = Completer<pb.ServerEnvelope>();
    _pending[id] = completer;
    _channel!.sink.add(env.writeToBuffer());
    return completer.future.timeout(const Duration(seconds: 10));
  }

  /// Hello 握手
  Future<pb.HelloResponse> hello() async {
    final identity = await IdentityService.instance.loadIdentity();
    final deviceCertHex = await IdentityService.instance.deviceCert();

    // 构造 Identity
    final pbIdentity = pb.Identity()
      ..userId = identity!.userId
      ..masterPubkey = Uint8List.fromList(
        hexDecode(identity.masterPubkeyHex),
      )
      ..displayName = identity.displayName
      ..avatarSeed = identity.avatarSeed;

    // 构造设备证书
    final cert = pb.DeviceCert.fromBuffer(
      Uint8List.fromList(hexDecode(deviceCertHex!)),
    );

    // 设备签名：在 Rust 侧统一构造载荷（与 server 端一致）
    final deviceSecret = await IdentityService.instance.deviceSecret();
    final deviceSig = rust.signHello(
      deviceSecretHex: deviceSecret!,
      protocolVersion: 1,
      userId: identity.userId,
      masterPubkeyHex: identity.masterPubkeyHex,
      displayName: identity.displayName,
      deviceCertHex: deviceCertHex,
    );

    final hello = pb.Hello()
      ..protocolVersion = 1
      ..identity = pbIdentity
      ..deviceCert = cert
      ..deviceSignature = Uint8List.fromList(hexDecode(deviceSig));

    final resp = await _request(
      pb.ClientEnvelope_MsgType.HELLO,
      hello.writeToBuffer(),
    );
    final hr = pb.HelloResponse.fromBuffer(resp.payload);
    serverId = hr.serverId;
    serverName = hr.serverName;
    serverDesc = hr.serverDesc;
    serverFingerprint = hr.serverId;
    migrationTarget = hr.migrationTarget;
    migrationFingerprint = hr.migrationFingerprint;
    migrationSignature = hr.migrationSignature;
    serverPubkeyHex = hr.serverPubkey.isEmpty
        ? ''
        : hr.serverPubkey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    avEnabled = hr.avEnabled;
    return hr;
  }

  /// 加入（支持申请理由、Owner 认领码、邀请令牌）
  Future<pb.JoinResponse> join({
    String reason = '',
    String claimCode = '',
    String inviteToken = '',
  }) async {
    final identity = await IdentityService.instance.loadIdentity();
    final pbIdentity = pb.Identity()
      ..userId = identity!.userId
      ..masterPubkey = Uint8List.fromList(
        hexDecode(identity.masterPubkeyHex),
      )
      ..displayName = identity.displayName
      ..avatarSeed = identity.avatarSeed;

    final req = pb.JoinRequest()
      ..reason = reason
      ..pushServiceUrl = LonIsleConfig.pushServiceUrl
      ..identity = pbIdentity
      ..claimCode = claimCode
      ..inviteToken = inviteToken;
    final resp = await _request(
      pb.ClientEnvelope_MsgType.JOIN,
      req.writeToBuffer(),
    );
    final jr = pb.JoinResponse.fromBuffer(resp.payload);
    isOwner = jr.isOwner;
    topics = jr.topics;
    if (jr.serverInfo.isInitialized()) {
      applyServerInfo(jr.serverInfo);
    }
    return jr;
  }

  /// 应用 ServerInfo 到本地字段（join 与 SERVER_INFO_UPDATED 事件共用）
  void applyServerInfo(pb.ServerInfo info) {
    serverName = info.name;
    serverDesc = info.description;
    serverId = info.serverId;
    serverIcon = info.icon;
    serverStrategy = info.strategy.value;
    rateLimitPerMinute = info.rateLimitPerMinute;
    maxAttachmentSize = info.maxAttachmentSize.toInt();
  }

  /// 发送文本消息
  Future<pb.SendMessageAck> sendText(String topicId, String text,
      {String replyTo = ''}) async {
    final identity = await IdentityService.instance.loadIdentity();
    final deviceId = await IdentityService.instance.deviceId();
    final deviceSecret = await IdentityService.instance.deviceSecret();

    final msgId = _randomHex(16);
    final clientTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 先签名（Rust 桥接；载荷含 reply_to，与 server 一致）
    final sigHex = rust.signSendMessage(
      deviceSecretHex: deviceSecret!,
      topicId: topicId,
      msgId: msgId,
      authorId: identity!.userId,
      deviceId: deviceId!,
      clientTs: clientTs,
      text: text,
      replyTo: replyTo,
    );

    final msg = pb.SendMessage()
      ..topicId = topicId
      ..msgId = msgId
      ..authorId = Uint8List.fromList(utf8.encode(identity.userId))
      ..deviceId = deviceId
      ..clientTs = Int64(clientTs)
      ..content = (pb.MessageContent()..text = text)
      ..signature = Uint8List.fromList(hexDecode(sigHex))
      ..replyTo = replyTo;

    final resp = await _request(
      pb.ClientEnvelope_MsgType.SEND_MESSAGE,
      msg.writeToBuffer(),
    );
    return pb.SendMessageAck.fromBuffer(resp.payload);
  }

  /// 发送附件消息（F-MEDIA-1：上传完成后调用，携带附件元数据）
  Future<pb.SendMessageAck> sendAttachment(
    String topicId,
    String caption,
    pb.Attachment attachment,
  ) async {
    final identity = await IdentityService.instance.loadIdentity();
    final deviceId = await IdentityService.instance.deviceId();
    final deviceSecret = await IdentityService.instance.deviceSecret();

    final msgId = _randomHex(16);
    final clientTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 签名：附件元数据纳入载荷（Rust 侧 sign_send_message_with_attachment）
    final sigHex = rust.signSendMessageWithAttachment(
      deviceSecretHex: deviceSecret!,
      topicId: topicId,
      msgId: msgId,
      authorId: identity!.userId,
      deviceId: deviceId!,
      clientTs: clientTs,
      text: caption,
      attachmentId: attachment.attachmentId,
      kind: attachment.kind,
      size: attachment.size.toInt(),
      mime: attachment.mime,
      width: attachment.width,
      height: attachment.height,
      duration: attachment.duration,
      thumbnailId: attachment.thumbnailId,
      filename: attachment.filename,
    );

    final msg = pb.SendMessage()
      ..topicId = topicId
      ..msgId = msgId
      ..authorId = Uint8List.fromList(utf8.encode(identity.userId))
      ..deviceId = deviceId
      ..clientTs = Int64(clientTs)
      ..content = (pb.MessageContent()
        ..text = caption
        ..attachment = attachment)
      ..signature = Uint8List.fromList(hexDecode(sigHex));

    final resp = await _request(
      pb.ClientEnvelope_MsgType.SEND_MESSAGE,
      msg.writeToBuffer(),
    );
    return pb.SendMessageAck.fromBuffer(resp.payload);
  }

  // ---- E2EE 预密钥束（M6） ----

  /// 上传本机预密钥束（X3DH：X25519 身份公钥 + SPK + OPK 列表）
  Future<void> uploadPreKeys({
    required String identityKeyHex,
    required String spkHex,
    required String spkSigHex,
    List<String> opksHex = const [],
  }) async {
    final bundle = pb.PreKeyBundle()
      ..userId = (await IdentityService.instance.loadIdentity())?.userId ?? ''
      ..identityKey = Uint8List.fromList(hexDecode(identityKeyHex))
      ..signedPreKey = Uint8List.fromList(hexDecode(spkHex))
      ..signedPreKeySig = Uint8List.fromList(hexDecode(spkSigHex))
      ..oneTimePreKeys
          .addAll(opksHex.map((o) => Uint8List.fromList(hexDecode(o))));
    final req = pb.UploadPreKeysRequest()..bundle = bundle;
    await _request(
      pb.ClientEnvelope_MsgType.UPLOAD_PRE_KEYS,
      req.writeToBuffer(),
    );
  }

  /// 拉取某用户的预密钥束
  Future<pb.PreKeyBundle?> fetchPreKeys(String userId) async {
    final req = pb.FetchPreKeysRequest()..userId = userId;
    final resp = await _request(
      pb.ClientEnvelope_MsgType.FETCH_PRE_KEYS,
      req.writeToBuffer(),
    );
    final r = pb.PreKeyBundleResponse.fromBuffer(resp.payload);
    return r.hasBundle() ? r.bundle : null;
  }

  /// 发送加密消息（E2EE，M6）：text 置空，content.encrypted 携带密文。
  Future<pb.SendMessageAck> sendEncrypted(
    String topicId,
    String encryptedHex,
  ) async {
    final identity = await IdentityService.instance.loadIdentity();
    final deviceId = await IdentityService.instance.deviceId();
    final deviceSecret = await IdentityService.instance.deviceSecret();

    final msgId = _randomHex(16);
    final clientTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 签名（text 为空，签名载荷覆盖 encrypted 元数据通过 content 序列化）
    final sigHex = rust.signSendMessage(
      deviceSecretHex: deviceSecret!,
      topicId: topicId,
      msgId: msgId,
      authorId: identity!.userId,
      deviceId: deviceId!,
      clientTs: clientTs,
      text: '', // E2EE：text 空，内容在 encrypted
      replyTo: '',
    );

    final msg = pb.SendMessage()
      ..topicId = topicId
      ..msgId = msgId
      ..authorId = Uint8List.fromList(utf8.encode(identity.userId))
      ..deviceId = deviceId
      ..clientTs = Int64(clientTs)
      ..content = (pb.MessageContent()
        ..encrypted = Uint8List.fromList(hexDecode(encryptedHex)))
      ..signature = Uint8List.fromList(hexDecode(sigHex));

    final resp = await _request(
      pb.ClientEnvelope_MsgType.SEND_MESSAGE,
      msg.writeToBuffer(),
    );
    return pb.SendMessageAck.fromBuffer(resp.payload);
  }

  /// 游标增量同步
  Future<pb.SyncResponse> sync(String topicId, int afterSeq) async {
    final req = pb.SyncRequest()
      ..topicId = topicId
      ..afterSeq = Int64(afterSeq)
      ..limit = 100;
    final resp = await _request(
      pb.ClientEnvelope_MsgType.SYNC,
      req.writeToBuffer(),
    );
    return pb.SyncResponse.fromBuffer(resp.payload);
  }

  /// 历史消息向前翻页（加载更早消息；beforeSeq=0 表示从该话题最新往前）
  Future<pb.HistoryResponse> history(String topicId, int beforeSeq) async {
    final req = pb.HistoryRequest()
      ..topicId = topicId
      ..beforeSeq = Int64(beforeSeq)
      ..limit = 50;
    final resp = await _request(
      pb.ClientEnvelope_MsgType.HISTORY,
      req.writeToBuffer(),
    );
    return pb.HistoryResponse.fromBuffer(resp.payload);
  }

  /// 成员列表
  Future<pb.MemberListResponse> listMembers() async {
    final resp = await _request(
      pb.ClientEnvelope_MsgType.LIST_MEMBERS,
      Uint8List(0),
    );
    return pb.MemberListResponse.fromBuffer(resp.payload);
  }

  // ---- M2：话题管理 ----

  Future<pb.TopicListResponse> listTopics() async {
    final resp = await _request(
      pb.ClientEnvelope_MsgType.LIST_TOPICS,
      Uint8List(0),
    );
    return pb.TopicListResponse.fromBuffer(resp.payload);
  }

  Future<void> createTopic({
    required String name,
    String description = '',
    pb.TopicType type = pb.TopicType.TEXT,
    pb.TopicPermission permission = pb.TopicPermission.PUBLIC,
  }) async {
    final req = pb.CreateTopicRequest()
      ..name = name
      ..description = description
      ..type = type
      ..permission = permission;
    await _request(pb.ClientEnvelope_MsgType.CREATE_TOPIC, req.writeToBuffer());
  }

  Future<void> deleteTopic(String topicId) async {
    final req = pb.DeleteTopicRequest()..topicId = topicId;
    await _request(pb.ClientEnvelope_MsgType.DELETE_TOPIC, req.writeToBuffer());
  }

  // ---- M2：审批 ----

  Future<pb.JoinRequestListResponse> listJoinRequests() async {
    final resp = await _request(
      pb.ClientEnvelope_MsgType.LIST_JOIN_REQUESTS,
      Uint8List(0),
    );
    return pb.JoinRequestListResponse.fromBuffer(resp.payload);
  }

  Future<void> processJoinRequest(String requestId, bool approve) async {
    final req = pb.ProcessJoinRequest()
      ..requestId = requestId
      ..approve = approve;
    await _request(
      pb.ClientEnvelope_MsgType.PROCESS_JOIN_REQUEST,
      req.writeToBuffer(),
    );
  }

  // ---- M2：成员管理 ----

  Future<void> setMemberRole(String userId, pb.MemberRole role) async {
    final req = pb.SetMemberRoleRequest()
      ..userId = userId
      ..role = role;
    await _request(pb.ClientEnvelope_MsgType.SET_MEMBER_ROLE, req.writeToBuffer());
  }

  Future<void> setMute(String userId, bool muted) async {
    final req = pb.SetMuteRequest()
      ..userId = userId
      ..muted = muted;
    await _request(pb.ClientEnvelope_MsgType.SET_MUTE, req.writeToBuffer());
  }

  Future<void> kickMember(String userId) async {
    final req = pb.KickMemberRequest()..userId = userId;
    await _request(pb.ClientEnvelope_MsgType.KICK_MEMBER, req.writeToBuffer());
  }

  Future<void> setBan(String userId, bool banned) async {
    final req = pb.SetBanRequest()
      ..userId = userId
      ..banned = banned;
    await _request(pb.ClientEnvelope_MsgType.SET_BAN, req.writeToBuffer());
  }

  // ---- M2：资料覆盖 ----

  Future<void> updateServerProfile({
    String? nickname,
    String? avatar,
  }) async {
    // optional 字段按需设置 presence：未传的字段服务端不动，
    // 传空字符串表示清除覆盖（防止改昵称清空头像等问题）
    final req = pb.UpdateServerProfileRequest();
    if (nickname != null) req.serverNickname = nickname;
    if (avatar != null) req.serverAvatar = avatar;
    await _request(
      pb.ClientEnvelope_MsgType.UPDATE_SERVER_PROFILE,
      req.writeToBuffer(),
    );
  }

  // ---- M2：服务器设置与退出 ----

  Future<void> updateServerSettings({
    required String name,
    String description = '',
    pb.JoinStrategy strategy = pb.JoinStrategy.APPROVAL,
  }) async {
    final req = pb.UpdateServerSettingsRequest()
      ..name = name
      ..description = description
      ..strategy = strategy;
    await _request(
      pb.ClientEnvelope_MsgType.UPDATE_SERVER_SETTINGS,
      req.writeToBuffer(),
    );
  }

  Future<void> leaveServer() async {
    await _request(
      pb.ClientEnvelope_MsgType.LEAVE_SERVER,
      Uint8List(0),
    );
  }

  // ---- M2：消息编辑/删除 ----

  Future<void> editMessage(String topicId, String msgId, String newText) async {
    // 与 core signature.rs 的 edit_message_signing_payload 字段序一致
    final payload = <int>[
      ...utf8.encode('lonisle-edit-v1'),
      0,
      ...utf8.encode(topicId),
      0,
      ...utf8.encode(msgId),
      0,
      ...utf8.encode(newText),
    ];
    final deviceSecret = await IdentityService.instance.deviceSecret();
    final sigHex = rust.signPayload(
      deviceSecretHex: deviceSecret!,
      payloadHex: _hexEncode(payload),
    );
    final req = pb.EditMessageRequest()
      ..topicId = topicId
      ..msgId = msgId
      ..newText = newText
      ..signature = Uint8List.fromList(hexDecode(sigHex));
    await _request(pb.ClientEnvelope_MsgType.EDIT_MESSAGE, req.writeToBuffer());
  }

  Future<void> deleteMessage(String topicId, String msgId) async {
    // 与 core signature.rs 的 delete_message_signing_payload 字段序一致
    final payload = <int>[
      ...utf8.encode('lonisle-delete-v1'),
      0,
      ...utf8.encode(topicId),
      0,
      ...utf8.encode(msgId),
    ];
    final deviceSecret = await IdentityService.instance.deviceSecret();
    final sigHex = rust.signPayload(
      deviceSecretHex: deviceSecret!,
      payloadHex: _hexEncode(payload),
    );
    final req = pb.DeleteMessageRequest()
      ..topicId = topicId
      ..msgId = msgId
      ..signature = Uint8List.fromList(hexDecode(sigHex));
    await _request(pb.ClientEnvelope_MsgType.DELETE_MESSAGE, req.writeToBuffer());
  }

  // ---- M5：Reaction ----

  /// 添加表情回应
  Future<void> addReaction(String topicId, String msgId, String emoji) async {
    final req = pb.AddReactionRequest()
      ..topicId = topicId
      ..msgId = msgId
      ..emoji = emoji;
    await _request(pb.ClientEnvelope_MsgType.ADD_REACTION, req.writeToBuffer());
  }

  /// 移除表情回应
  Future<void> removeReaction(String topicId, String msgId, String emoji) async {
    final req = pb.RemoveReactionRequest()
      ..topicId = topicId
      ..msgId = msgId
      ..emoji = emoji;
    await _request(pb.ClientEnvelope_MsgType.REMOVE_REACTION, req.writeToBuffer());
  }

  // ---- P2：RBAC 角色管理 ----

  Future<void> upsertRole(String roleId, String name, int permissions) async {
    final req = pb.UpsertRoleRequest()
      ..roleId = roleId
      ..name = name
      ..permissions = permissions;
    await _request(pb.ClientEnvelope_MsgType.UPSERT_ROLE, req.writeToBuffer());
  }

  Future<void> deleteRole(String roleId) async {
    final req = pb.DeleteRoleRequest()..roleId = roleId;
    await _request(pb.ClientEnvelope_MsgType.DELETE_ROLE, req.writeToBuffer());
  }

  Future<pb.RoleListResponse> listRoles() async {
    final resp = await _request(
      pb.ClientEnvelope_MsgType.LIST_ROLES,
      Uint8List(0),
    );
    return pb.RoleListResponse.fromBuffer(resp.payload);
  }

  Future<void> assignRole(String userId, String roleId) async {
    final req = pb.AssignRoleRequest()
      ..userId = userId
      ..roleId = roleId;
    await _request(pb.ClientEnvelope_MsgType.ASSIGN_ROLE, req.writeToBuffer());
  }

  Future<void> unassignRole(String userId, String roleId) async {
    final req = pb.UnassignRoleRequest()
      ..userId = userId
      ..roleId = roleId;
    await _request(pb.ClientEnvelope_MsgType.UNASSIGN_ROLE, req.writeToBuffer());
  }

  // ---- P2：@提及已读回执 ----

  Future<void> markMentionRead(String topicId, String msgId) async {
    final req = pb.MarkMentionReadRequest()
      ..topicId = topicId
      ..msgId = msgId;
    await _request(pb.ClientEnvelope_MsgType.MARK_MENTION_READ, req.writeToBuffer());
  }

  Future<pb.MentionReadListResponse> mentionReadList(String msgId) async {
    final req = pb.MentionReadListRequest()..msgId = msgId;
    final resp = await _request(
      pb.ClientEnvelope_MsgType.MENTION_READ_LIST,
      req.writeToBuffer(),
    );
    return pb.MentionReadListResponse.fromBuffer(resp.payload);
  }

  // ---- 音视频话题（LiveKit） ----

  /// 加入音视频话题，返回 LiveKit 地址与 Token。
  Future<pb.JoinAVResponse> joinAV(String topicId) async {
    final req = pb.JoinAVRequest()..topicId = topicId;
    final resp = await _request(
      pb.ClientEnvelope_MsgType.JOIN_AV,
      req.writeToBuffer(),
    );
    return pb.JoinAVResponse.fromBuffer(resp.payload);
  }

  // ---- M3：设备管理 ----

  /// 注册设备（携带设备信息 + 证书 + 吊销证明）
  Future<void> registerDevice({
    required String deviceId,
    required String deviceName,
    required String platform,
    required String deviceCertHex,
    List<String> revocationHexes = const [],
  }) async {
    final revocations = revocationHexes
        .map((h) => pb.RevocationProof.fromBuffer(Uint8List.fromList(hexDecode(h))))
        .toList();
    final req = pb.RegisterDeviceRequest()
      ..device = (pb.DeviceInfo()
        ..deviceId = deviceId
        ..deviceName = deviceName
        ..platform = platform
        ..lastActive = Int64(0)
        ..isCurrent = true)
      ..deviceCert = Uint8List.fromList(hexDecode(deviceCertHex))
      ..revocations.addAll(revocations);
    await _request(pb.ClientEnvelope_MsgType.REGISTER_DEVICE, req.writeToBuffer());
  }

  /// 列出当前用户的所有设备
  Future<pb.DeviceListResponse> listDevices() async {
    final resp = await _request(
      pb.ClientEnvelope_MsgType.LIST_DEVICES,
      Uint8List(0),
    );
    return pb.DeviceListResponse.fromBuffer(resp.payload);
  }

  /// 撤销设备（携带吊销证明）
  Future<void> revokeDevice({
    required String devicePubkeyHex,
    required String proofHex,
  }) async {
    final req = pb.RevokeDeviceRequest()
      ..devicePubkey = Uint8List.fromList(hexDecode(devicePubkeyHex))
      ..proof = pb.RevocationProof.fromBuffer(
        Uint8List.fromList(hexDecode(proofHex)),
      );
    await _request(pb.ClientEnvelope_MsgType.REVOKE_DEVICE, req.writeToBuffer());
  }

  void dispose() {
    _pingTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _statusController.close();
    _broadcastController.close();
    _notifyController.close();
    _deviceChangeController.close();
  }
}

class _SeqGen {
  int _n = 0;
  int next() => ++_n;
}

String _randomHex(int bytes) {
  // 安全随机（Random.secure）：消息 ID 需不可预测，防碰撞与枚举
  final rng = Random.secure();
  final r =
      List<int>.generate(bytes, (_) => rng.nextInt(256));
  return r.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List hexDecode(String hex) {
  final out = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    out.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(out);
}

String _hexEncode(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
