import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TOFU 指纹不匹配异常（F-SID-3：指纹不一致时中止连接）。
class TofuMismatchException implements Exception {
  final String message;
  final String actualFingerprint;

  TofuMismatchException(this.message, this.actualFingerprint);

  @override
  String toString() => message;
}

/// TOFU（Trust On First Use）证书指纹钉住。
///
/// - 首次连接：信任并钉住服务器 TLS 证书指纹（SHA256 DER，hex）
/// - 后续连接：指纹必须匹配，否则拒绝
/// - 邀请链接携带指纹（F-JOIN-7）：连接前比对，不一致直接中止
class Tofu {
  static String _key(String host, int port) => 'tofu_fp_${host}_$port';

  /// 计算证书指纹（SHA256(DER) 的 hex 编码，与 server tls.rs 一致）。
  static String fingerprintOf(X509Certificate cert) =>
      sha256.convert(cert.der).toString();

  /// 读取已钉住的指纹（无则返回 null）。
  static Future<String?> pinned(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(host, port));
  }

  /// 钉住指纹。
  static Future<void> pin(String host, int port, String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(host, port), fingerprint);
  }

  /// 清除钉住（重新信任，如服务器重置后）。
  static Future<void> unpin(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(host, port));
  }
}

/// TOFU HttpClient 构造结果：client + 观测到的指纹 + 不匹配信息。
class TofuClient {
  final HttpClient client;
  String? observedFingerprint;
  String? mismatchMessage;

  TofuClient(this.client);
}

/// 创建带 TOFU 校验的 HttpClient。
///
/// [expectedFingerprint] 为邀请链接携带的指纹：提供时必须匹配（连接前比对）。
/// 已钉住指纹不匹配 → 拒绝。未钉住且无期望指纹 → 首次信任（TOFU）。
/// 证书回调中观测到的指纹记录在返回值的 [TofuClient.observedFingerprint]。
Future<TofuClient> createTofuClient(
  String host,
  int port, {
  String? expectedFingerprint,
}) async {
  final pinnedFp = await Tofu.pinned(host, port);
  final expected =
      (expectedFingerprint != null && expectedFingerprint.isNotEmpty)
          ? expectedFingerprint.toLowerCase()
          : null;

  final holder = TofuClient(HttpClient());
  holder.client.badCertificateCallback = (cert, h, p) {
    if (h != host || p != port) return false;
    final fp = Tofu.fingerprintOf(cert).toLowerCase();
    holder.observedFingerprint = fp;

    // 邀请链接指纹：连接前比对，不一致中止（F-SID-3/F-JOIN-7）
    if (expected != null) {
      if (fp != expected) {
        holder.mismatchMessage =
            '证书指纹与邀请链接不符，可能存在中间人攻击，已中止连接';
        return false;
      }
      return true;
    }

    // 已钉住：必须匹配
    if (pinnedFp != null) {
      if (fp != pinnedFp.toLowerCase()) {
        holder.mismatchMessage = '服务器证书指纹已变更，可能存在中间人攻击，已中止连接';
        return false;
      }
      return true;
    }

    // 首次连接：信任（TOFU），由调用方在连接成功后钉住
    return true;
  };
  return holder;
}
