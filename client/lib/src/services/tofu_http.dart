import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TOFU 指纹不匹配异常（F-SID-3：公钥/证书指纹不一致时中止连接）。
class TofuMismatchException implements Exception {
  final String message;
  final String actualFingerprint; // 观测到的新证书指纹（DER）
  final String? actualSpki; // 观测到的新公钥指纹（SPKI，用于确认后重新信任）

  TofuMismatchException(this.message, this.actualFingerprint, [this.actualSpki]);

  @override
  String toString() => message;
}

/// 已钉住的 TOFU 记录（DER 证书指纹 + SPKI 公钥指纹）。
class TofuPin {
  final String der;
  final String? spki; // 旧版本数据可能没有 spki

  TofuPin(this.der, [this.spki]);

  bool get hasSpki => spki != null && spki!.isNotEmpty;
}

/// TOFU（Trust On First Use）证书指纹钉住。
///
/// - 首次连接：信任并钉住服务器 TLS 证书指纹（SHA256 DER）与公钥指纹（SHA256 SPKI）
/// - 后续连接：证书指纹匹配直接通过；证书指纹变化但**公钥指纹相同**
///   （如 Let's Encrypt 到期续期复用同一私钥）→ 静默更新指纹，不打扰用户；
///   公钥也变化（真正更换证书/私钥）→ 拒绝连接，由 UI 弹窗确认重新信任
/// - 邀请链接携带指纹（F-JOIN-7）：连接前比对，不一致直接中止
class Tofu {
  static String _key(String host, int port) => 'tofu_fp_${host}_$port';

  /// 计算证书指纹（SHA256(DER) 的 hex 编码，与 server tls.rs 一致）。
  static String fingerprintOf(X509Certificate cert) =>
      sha256.convert(cert.der).toString();

  /// 计算公钥指纹（SHA256(SubjectPublicKeyInfo DER) 的 hex 编码）。
  /// 私钥不变（证书到期续期）时 SPKI 不变，用于区分「续期」与「真正换证书」。
  static String? spkiFingerprintOf(X509Certificate cert) {
    try {
      final spki = _extractSubjectPublicKeyInfo(cert.der);
      if (spki.isEmpty) return null;
      return sha256.convert(spki).toString();
    } catch (_) {
      return null; // 解析失败时退化为仅 DER 校验
    }
  }

  /// 从证书 DER 中提取 SubjectPublicKeyInfo 的完整 DER（X.509 ASN.1 解析）。
  /// 结构：Certificate ::= SEQUENCE { tbsCertificate, ... }，
  /// tbsCertificate 内按序：version[0](可选)/serialNumber/signature/issuer/validity/subject/subjectPublicKeyInfo。
  static Uint8List _extractSubjectPublicKeyInfo(List<int> der) {
    final p = _DerReader(der);
    p.expectTag(0x30); // Certificate
    p.readLength();
    p.expectTag(0x30); // tbsCertificate
    p.readLength();
    // 跳过 tbsCertificate 内前 6 个字段（version/serial/signature/issuer/validity/subject）
    for (var i = 0; i < 6; i++) {
      p.skipTlv();
    }
    // 现在指向 subjectPublicKeyInfo（SEQUENCE 0x30）
    final start = p.pos;
    p.skipTlv();
    return Uint8List.fromList(der.sublist(start, p.pos));
  }

  /// 读取已钉住的记录（无则返回 null）。
  static Future<TofuPin?> pinned(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(host, port));
    if (raw == null || raw.isEmpty) return null;
    // 兼容旧版纯 DER 值（无 spki）
    if (!raw.startsWith('{')) return TofuPin(raw);
    try {
      final v = jsonDecode(raw) as Map<String, dynamic>;
      return TofuPin(
        v['der'] as String? ?? '',
        v['spki'] as String?,
      );
    } catch (_) {
      return TofuPin(raw);
    }
  }

  /// 钉住指纹（DER + SPKI）。
  static Future<void> pin(String host, int port, String der, [String? spki]) async {
    final prefs = await SharedPreferences.getInstance();
    if (spki == null || spki.isEmpty) {
      // 无 SPKI（旧调用方）：仅存 DER（保持兼容）
      await prefs.setString(_key(host, port), der);
    } else {
      await prefs.setString(
        _key(host, port),
        jsonEncode({'der': der, 'spki': spki}),
      );
    }
  }

  /// 清除钉住（重新信任，如服务器重置后）。
  static Future<void> unpin(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(host, port));
  }
}

/// 极简 DER（ASN.1）读取器：仅用于定位 X.509 中的 SubjectPublicKeyInfo。
class _DerReader {
  final List<int> data;
  int pos = 0;

  _DerReader(this.data);

  void expectTag(int tag) {
    if (data[pos] != tag) {
      throw const FormatException('DER 结构不符');
    }
    pos++;
  }

  /// 读取长度（支持短/长格式），返回长度值。
  int readLength() {
    final b = data[pos++];
    if (b < 0x80) return b;
    final n = b & 0x7f;
    var len = 0;
    for (var i = 0; i < n; i++) {
      len = (len << 8) | data[pos++];
    }
    return len;
  }

  /// 跳过当前 TLV（tag + length + 内容），pos 移到下一元素。
  void skipTlv() {
    pos++; // tag（DER 均为一字节 tag）
    final len = readLength();
    pos += len;
  }
}

/// TOFU HttpClient 构造结果：client + 观测指纹 + 不匹配信息 + 是否续期自动更新。
class TofuClient {
  final HttpClient client;
  String? observedFingerprint;
  String? observedSpki;
  String? mismatchMessage;
  /// 同公钥续期：证书指纹变化但公钥未变，连接成功后应静默更新钉住指纹
  bool renewed = false;

  TofuClient(this.client);
}

/// 创建带 TOFU 校验的 HttpClient。
///
/// [expectedFingerprint] 为邀请链接携带的指纹：提供时必须匹配（连接前比对）。
/// 已钉住记录不匹配时：
/// - 证书指纹匹配 → 通过
/// - 证书指纹变化但公钥（SPKI）相同 → 视为续期，自动通过并标记 [TofuClient.renewed]
/// - 公钥也变化 → 拒绝并设置 [TofuClient.mismatchMessage]（由 UI 弹窗确认重新信任）
/// 未钉住且无期望指纹 → 首次信任（TOFU）。
Future<TofuClient> createTofuClient(
  String host,
  int port, {
  String? expectedFingerprint,
}) async {
  final pinned = await Tofu.pinned(host, port);
  final expected =
      (expectedFingerprint != null && expectedFingerprint.isNotEmpty)
          ? expectedFingerprint.toLowerCase()
          : null;

  final holder = TofuClient(HttpClient());
  holder.client.badCertificateCallback = (cert, h, p) {
    if (h != host || p != port) return false;
    final fp = Tofu.fingerprintOf(cert).toLowerCase();
    final spki = Tofu.spkiFingerprintOf(cert)?.toLowerCase();
    holder.observedFingerprint = fp;
    holder.observedSpki = spki;

    // 邀请链接指纹：连接前比对，不一致中止（F-SID-3/F-JOIN-7）
    if (expected != null) {
      if (fp != expected) {
        holder.mismatchMessage =
            '证书指纹与邀请链接不符，可能存在中间人攻击，已中止连接';
        return false;
      }
      return true;
    }

    // 已钉住：证书指纹匹配 → 通过；否则按公钥判断续期/换证书
    if (pinned != null) {
      if (fp == pinned.der.toLowerCase()) return true;
      // 证书续期（同公钥）：静默信任，连接成功后由调用方更新钉住指纹
      if (pinned.hasSpki && spki != null && spki == pinned.spki!.toLowerCase()) {
        holder.renewed = true;
        return true;
      }
      holder.mismatchMessage = '服务器证书已更换，可能存在中间人攻击，已中止连接';
      return false;
    }

    // 首次连接：信任（TOFU），由调用方在连接成功后钉住
    return true;
  };
  return holder;
}
