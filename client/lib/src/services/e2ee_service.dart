import 'dart:convert';

import '../rust/api.dart' as rust;

/// E2EE 会话（双棘轮，M6）：状态在 Rust 侧推进，Dart 持有状态 hex。
///
/// 会话状态可持久化（shared_preferences/local store），
/// 支持乱序消息与断线重连后继续（状态含跳过密钥缓存）。
class E2eeSession {
  final String peerUserId;
  String _stateHex;

  E2eeSession({required this.peerUserId, required String stateHex})
      : _stateHex = stateHex;

  String get stateHex => _stateHex;

  /// 加密明文（UTF-8 文本），返回密文 hex（含 header）。
  String encrypt(String plaintext) {
    final out = rust.e2EeSessionEncrypt(
      stateHex: _stateHex,
      plaintextHex: hexEncode(utf8.encode(plaintext)),
    );
    _stateHex = out.newStateHex;
    return out.payloadHex;
  }

  /// 解密密文 hex，返回明文（UTF-8 文本）。支持乱序。
  String decrypt(String ciphertextHex) {
    final out = rust.e2EeSessionDecrypt(
      stateHex: _stateHex,
      ciphertextHex: ciphertextHex,
    );
    _stateHex = out.newStateHex;
    return utf8.decode(hexDecodeBytes(out.payloadHex));
  }
}

/// E2EE 服务：管理多个会话 + 密钥协商 + 会话持久化。
class E2eeService {
  E2eeService._();

  static final E2eeService instance = E2eeService._();

  /// 会话缓存：peerUserId -> E2eeSession
  final Map<String, E2eeSession> _sessions = {};

  /// 会话状态持久化 key 前缀（重启恢复）
  static const _persistPrefix = 'e2ee_session_';

  /// 本机 X25519 身份密钥（E2EE 用，与主身份 Ed25519 分离）
  String? _identitySecretHex;
  String? _identityPublicHex;

  Future<void> init() async {
    final bundle = rust.generateX25519();
    _identitySecretHex = bundle.secretHex;
    _identityPublicHex = bundle.publicHex;
  }

  String? get identityPublicHex => _identityPublicHex;

  /// 验证对端预密钥束的 SPK 签名（防中间人替换预密钥）。
  bool verifyPeerSpk({
    required String masterPubkeyHex,
    required String spkPubHex,
    required String signatureHex,
  }) {
    try {
      return rust.verifySpkSignature(
        masterPubkeyHex: masterPubkeyHex,
        spkPubHex: spkPubHex,
        signatureHex: signatureHex,
      );
    } catch (_) {
      return false;
    }
  }

  /// 与对端协商（发起方），建立双棘轮会话。
  E2eeSession establishSession(
    String peerUserId, {
    required String peerIdentityHex,
    required String peerSignedPreKeyHex,
    String? peerOneTimePreKeyHex,
  }) {
    final ek = rust.generateX25519();

    final out = rust.e2EeEstablishInitiator(
      ikSecretHex: _identitySecretHex!,
      ekSecretHex: ek.secretHex,
      peerIkHex: peerIdentityHex,
      peerSpkHex: peerSignedPreKeyHex,
      peerOpkHex: peerOneTimePreKeyHex,
    );

    final session = E2eeSession(
        peerUserId: peerUserId, stateHex: out.newStateHex);
    _sessions[peerUserId] = session;
    return session;
  }

  /// 接受协商（响应方）：收到发起方首条消息时建立会话。
  E2eeSession acceptSession(
    String peerUserId, {
    required String peerIdentityHex,
    required String peerEkHex,
    required String mySpkSecretHex,
    String? myOpkSecretHex,
  }) {
    final out = rust.e2EeEstablishResponder(
      ikSecretHex: _identitySecretHex!,
      spkSecretHex: mySpkSecretHex,
      opkSecretHex: myOpkSecretHex,
      peerIkHex: peerIdentityHex,
      peerEkHex: peerEkHex,
    );
    final session = E2eeSession(
        peerUserId: peerUserId, stateHex: out.newStateHex);
    _sessions[peerUserId] = session;
    return session;
  }

  /// 获取会话（可能不存在）。
  E2eeSession? session(String peerUserId) => _sessions[peerUserId];

  /// 加密发送给某用户的消息。
  String? encryptFor(String peerUserId, String plaintext) {
    return _sessions[peerUserId]?.encrypt(plaintext);
  }

  /// 解密来自某用户的消息。
  String? decryptFrom(String peerUserId, String ciphertextHex) {
    return _sessions[peerUserId]?.decrypt(ciphertextHex);
  }
}

String hexEncode(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> hexDecodeBytes(String hex) {
  final out = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    out.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return out;
}
