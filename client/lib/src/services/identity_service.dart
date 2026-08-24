import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../rust/api.dart' as rust;

/// 身份与设备服务：调用 Rust 桥接生成密钥，密钥本地持久化。
///
/// 主私钥、设备私钥仅存本地，永不上传（F-ID-3）。
/// 私钥优先存系统安全存储（Keychain/Keystore）；
/// 桌面端 Debug 无代码签名导致安全存储不可用时回退 shared_preferences，
/// 可用时会自动将明文私钥迁入安全存储并清除明文残留。
class IdentityService {
  IdentityService._();

  static final IdentityService instance = IdentityService._();

  /// 当前 user_id 的内存缓存（init 后可用）
  static String? _cachedUserId;
  String? get userId => _cachedUserId;

  /// 获取 SharedPreferences 实例。
  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// 安全存储可用性探测缓存（null=未探测）
  static bool? _secureAvailable;

  static const _kMasterSecret = 'master_secret_hex';
  static const _kMasterPubkey = 'master_pubkey_hex';
  static const _kUserId = 'user_id';
  static const _kDisplayName = 'display_name';
  static const _kAvatarSeed = 'avatar_seed';
  static const _kDeviceSecret = 'device_secret_hex';
  static const _kDevicePubkey = 'device_pubkey_hex';
  static const _kDeviceId = 'device_id';
  static const _kDeviceName = 'device_name';
  static const _kDeviceCert = 'device_cert_hex';

  /// 需要安全存储的敏感键
  static const _secretKeys = [_kMasterSecret, _kDeviceSecret];

  /// 探测系统安全存储是否可用
  Future<bool> _secureOk() async {
    if (_secureAvailable != null) return _secureAvailable!;
    try {
      await _secure.read(key: '__lonisle_probe__');
      _secureAvailable = true;
    } catch (_) {
      _secureAvailable = false;
    }
    return _secureAvailable!;
  }

  /// 读取敏感值：优先安全存储，回退 shared_preferences（含迁移前的旧数据）
  Future<String?> _readSecret(String key) async {
    if (await _secureOk()) {
      try {
        final v = await _secure.read(key: key);
        if (v != null && v.isNotEmpty) return v;
      } catch (_) {}
    }
    return (await _prefs()).getString(key);
  }

  /// 写入敏感值：优先安全存储（并清除明文残留），不可用时回退明文
  Future<void> _writeSecret(String key, String value) async {
    if (await _secureOk()) {
      try {
        await _secure.write(key: key, value: value);
        await (await _prefs()).remove(key);
        return;
      } catch (_) {}
    }
    await (await _prefs()).setString(key, value);
  }

  /// 一次性迁移：shared_preferences 中的私钥迁入系统安全存储（F-ID-3）
  Future<void> migrateToSecureStorage() async {
    if (!await _secureOk()) return;
    final prefs = await _prefs();
    for (final key in _secretKeys) {
      final plain = prefs.getString(key);
      if (plain != null && plain.isNotEmpty) {
        try {
          await _secure.write(key: key, value: plain);
          await prefs.remove(key);
        } catch (_) {}
      }
    }
  }

  /// 当前身份是否已初始化（含被授权设备：无主私钥但有设备证书）
  Future<bool> isInitialized() async {
    await migrateToSecureStorage();
    final secret = await _readSecret(_kMasterSecret);
    if (secret != null && secret.isNotEmpty) return true;
    // 被授权设备：无主私钥，但有设备证书 + user_id
    final cert = (await _prefs()).getString(_kDeviceCert);
    final userId = (await _prefs()).getString(_kUserId);
    return cert != null && cert.isNotEmpty && userId != null && userId.isNotEmpty;
  }

  /// 生成全新身份（首次启动）
  Future<rust.IdentityBundle> createIdentity() async {
    final identity = rust.generateIdentity();

    await _writeSecret(_kMasterSecret, identity.masterSecretHex);
    await (await _prefs()).setString(_kMasterPubkey, identity.masterPubkeyHex);
    await (await _prefs()).setString(_kUserId, identity.userId);
    await (await _prefs()).setString(_kDisplayName, identity.displayName);
    await (await _prefs()).setString(_kAvatarSeed, identity.avatarSeed);

    // 首设备：生成设备密钥对 + 自签设备证书
    await _ensureDevice(identity);

    return identity;
  }

  /// 读取当前身份（不含主私钥）
  Future<IdentityInfo?> loadIdentity() async {
    final userId = (await _prefs()).getString(_kUserId);
    if (userId == null) return null;
    _cachedUserId = userId;
    return IdentityInfo(
      userId: userId,
      displayName: (await _prefs()).getString(_kDisplayName) ?? '',
      avatarSeed: (await _prefs()).getString(_kAvatarSeed) ?? '',
      masterPubkeyHex: (await _prefs()).getString(_kMasterPubkey) ?? '',
    );
  }

  /// 读取主私钥（仅用于签发设备证书等本地敏感操作）
  Future<String?> masterSecret() async => _readSecret(_kMasterSecret);

  /// 更新全局昵称并持久化（F-PROF-2：改名后本地身份同步落地）
  Future<void> setDisplayName(String name) async {
    if (name.trim().isEmpty) return;
    await (await _prefs()).setString(_kDisplayName, name.trim());
  }

  /// 更新头像种子（F-PROF-7：头像标识，本地落地）
  Future<void> setAvatarSeed(String seed) async {
    await (await _prefs()).setString(_kAvatarSeed, seed);
  }

  /// 读取设备私钥（用于消息签名）
  Future<String?> deviceSecret() async => _readSecret(_kDeviceSecret);

  /// 读取设备 ID
  Future<String?> deviceId() async => (await _prefs()).getString(_kDeviceId);

  /// 读取设备证书 hex
  Future<String?> deviceCert() async => (await _prefs()).getString(_kDeviceCert);

  /// 读取设备公钥 hex
  Future<String?> devicePubkey() async => (await _prefs()).getString(_kDevicePubkey);

  /// 读取设备名称
  Future<String?> deviceName() async => (await _prefs()).getString(_kDeviceName);

  /// 确保首设备已生成并自签证书
  Future<void> _ensureDevice(rust.IdentityBundle identity) async {
    final existing = await _readSecret(_kDeviceSecret);
    if (existing != null && existing.isNotEmpty) return;

    final device = rust.generateDevice();
    final deviceName = '我的设备';

    final certHex = rust.issueDeviceCertificate(
      masterSecretHex: identity.masterSecretHex,
      userId: identity.userId,
      devicePubkeyHex: device.devicePubkeyHex,
      deviceName: deviceName,
    );

    await _writeSecret(_kDeviceSecret, device.deviceSecretHex);
    await (await _prefs()).setString(_kDevicePubkey, device.devicePubkeyHex);
    await (await _prefs()).setString(_kDeviceId, device.deviceId);
    await (await _prefs()).setString(_kDeviceName, deviceName);
    await (await _prefs()).setString(_kDeviceCert, certHex);
  }

  // ---- M3：多设备与助记词 ----

  /// 导出主密钥助记词（24 词）。仅已认证设备可调用。
  Future<String> exportMnemonic() async {
    final secret = await _readSecret(_kMasterSecret);
    if (secret == null) {
      throw StateError('主私钥不存在');
    }
    return rust.generateMnemonic(masterSecretHex: secret);
  }

  /// 从助记词恢复主私钥并重建身份（新设备首次登录）。
  Future<rust.IdentityBundle> recoverFromMnemonic(String mnemonic) async {
    if (!rust.validateMnemonic(mnemonic: mnemonic)) {
      throw StateError('助记词无效');
    }
    final secretHex = rust.recoverFromMnemonic(mnemonic: mnemonic);
    final identity = rust.restoreIdentity(masterSecretHex: secretHex);

    await _writeSecret(_kMasterSecret, identity.masterSecretHex);
    await (await _prefs()).setString(_kMasterPubkey, identity.masterPubkeyHex);
    await (await _prefs()).setString(_kUserId, identity.userId);
    await (await _prefs()).setString(_kDisplayName, identity.displayName);
    await (await _prefs()).setString(_kAvatarSeed, identity.avatarSeed);

    // 生成首设备 + 自签证书
    await _ensureDevice(identity);

    return identity;
  }

  /// 生成吊销证明（主私钥对被吊销设备公钥签名），返回 hex。
  Future<String> issueRevocation(String devicePubkeyHex) async {
    final secret = await _readSecret(_kMasterSecret);
    final userId = (await _prefs()).getString(_kUserId);
    if (secret == null || userId == null) {
      throw StateError('身份未初始化');
    }
    return rust.issueRevocation(
      masterSecretHex: secret,
      userId: userId,
      devicePubkeyHex: devicePubkeyHex,
    );
  }

  // ---- F-DEV-2：新设备二维码授权 ----

  /// 准备新设备授权请求：确保本设备密钥对已生成（可无主私钥/证书），
  /// 返回 (devicePubkeyHex, deviceName) 供生成授权请求二维码。
  Future<(String, String)> prepareDeviceAuthRequest() async {
    var pubkey = (await _prefs()).getString(_kDevicePubkey);
    final existingSecret = await _readSecret(_kDeviceSecret);
    if (pubkey == null || existingSecret == null || existingSecret.isEmpty) {
      final device = rust.generateDevice();
      await _writeSecret(_kDeviceSecret, device.deviceSecretHex);
      await (await _prefs()).setString(_kDevicePubkey, device.devicePubkeyHex);
      await (await _prefs()).setString(_kDeviceId, device.deviceId);
      pubkey = device.devicePubkeyHex;
    }
    final name = (await _prefs()).getString(_kDeviceName) ?? '新设备';
    return (pubkey, name);
  }

  /// 安装授权结果（新设备侧）：保存身份字段与设备证书。
  /// 新设备不持有主私钥——仅持有设备私钥与主私钥签发的设备证书。
  Future<void> installAuthorization({
    required String userId,
    required String masterPubkeyHex,
    required String displayName,
    required String avatarSeed,
    required String deviceCertHex,
  }) async {
    final prefs = await _prefs();
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kMasterPubkey, masterPubkeyHex);
    if (displayName.isNotEmpty) await prefs.setString(_kDisplayName, displayName);
    if (avatarSeed.isNotEmpty) await prefs.setString(_kAvatarSeed, avatarSeed);
    await prefs.setString(_kDeviceCert, deviceCertHex);
    _cachedUserId = userId;
  }

  /// 签发新设备授权（已认证设备侧）：用主私钥为新设备公钥签发设备证书，
  /// 返回授权响应数据（证书 + 身份信息，供生成响应二维码）。
  Future<DeviceAuthorization> authorizeDevice({
    required String devicePubkeyHex,
    required String deviceName,
  }) async {
    final secret = await _readSecret(_kMasterSecret);
    final userId = (await _prefs()).getString(_kUserId);
    if (secret == null || userId == null) {
      throw StateError('本设备不持有主私钥，无法授权新设备');
    }
    final certHex = rust.issueDeviceCertificate(
      masterSecretHex: secret,
      userId: userId,
      devicePubkeyHex: devicePubkeyHex,
      deviceName: deviceName,
    );
    final prefs = await _prefs();
    return DeviceAuthorization(
      userId: userId,
      masterPubkeyHex: prefs.getString(_kMasterPubkey) ?? '',
      displayName: prefs.getString(_kDisplayName) ?? '',
      avatarSeed: prefs.getString(_kAvatarSeed) ?? '',
      deviceCertHex: certHex,
    );
  }
}

/// 新设备授权响应数据（已认证设备 → 新设备）
class DeviceAuthorization {
  final String userId;
  final String masterPubkeyHex;
  final String displayName;
  final String avatarSeed;
  final String deviceCertHex;

  const DeviceAuthorization({
    required this.userId,
    required this.masterPubkeyHex,
    required this.displayName,
    required this.avatarSeed,
    required this.deviceCertHex,
  });
}

/// 身份信息（不含私钥）
class IdentityInfo {
  final String userId;
  final String displayName;
  final String avatarSeed;
  final String masterPubkeyHex;

  const IdentityInfo({
    required this.userId,
    required this.displayName,
    required this.avatarSeed,
    required this.masterPubkeyHex,
  });
}
