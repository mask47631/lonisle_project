import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/identity_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// 新设备二维码授权页（F-DEV-2）。
///
/// 双二维码离线流程：
/// 1. 新设备展示「授权请求码」（设备公钥 + 设备名）
/// 2. 已认证设备扫描 → 主私钥签发设备证书 → 展示「授权证书码」
/// 3. 新设备扫描证书码 → 安装身份与证书 → 即可连接服务器
class DevicePairingScreen extends StatefulWidget {
  /// true = 本机是新设备（展示请求码，等待被授权）
  /// false = 本机是已认证设备（扫码授权其他设备）
  final bool asNewDevice;

  const DevicePairingScreen({super.key, required this.asNewDevice});

  @override
  State<DevicePairingScreen> createState() => _DevicePairingScreenState();
}

class _DevicePairingScreenState extends State<DevicePairingScreen> {
  String? _requestQr; // 授权请求码内容
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.asNewDevice) _prepareRequest();
  }

  Future<void> _prepareRequest() async {
    final (pubkey, name) = await IdentityService.instance.prepareDeviceAuthRequest();
    setState(() {
      _requestQr =
          'lonisle://device-auth?pub=$pubkey&name=${Uri.encodeComponent(name)}';
    });
  }

  // ---- 新设备：扫描授权证书码 ----

  Future<void> _scanCert() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _ScanPage(title: '扫描授权证书码')),
    );
    if (code == null || !mounted) return;
    try {
      final uri = Uri.parse(code);
      if (uri.host != 'device-cert') throw StateError('不是有效的授权证书码');
      await IdentityService.instance.installAuthorization(
        userId: uri.queryParameters['uid'] ?? '',
        masterPubkeyHex: uri.queryParameters['mpk'] ?? '',
        displayName: uri.queryParameters['name'] ?? '',
        avatarSeed: uri.queryParameters['seed'] ?? '',
        deviceCertHex: uri.queryParameters['cert'] ?? '',
      );
      // 身份就绪，重新初始化应用状态
      await AppState.instance.init();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _error = '授权证书无效：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: Text(
          widget.asNewDevice ? '新设备授权' : '授权新设备',
          style: const TextStyle(color: LonIsleTheme.textWhite),
        ),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: widget.asNewDevice ? _buildNewDevice() : _buildAuthorizer(),
          ),
        ),
      ),
    );
  }

  Widget _buildNewDevice() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '第一步：用已认证设备扫描此码',
          style: TextStyle(color: LonIsleTheme.textWhite, fontSize: 16),
        ),
        const SizedBox(height: 24),
        if (_requestQr != null)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: QrImageView(data: _requestQr!, size: 240),
          )
        else
          const CircularProgressIndicator(color: LonIsleTheme.primary),
        const SizedBox(height: 32),
        const Text(
          '第二步：授权完成后，扫描已认证设备上的证书码',
          style: TextStyle(color: LonIsleTheme.textDim, fontSize: 14),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _scanCert,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('扫描授权证书码'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LonIsleTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: LonIsleTheme.red)),
        ],
      ],
    );
  }

  Widget _buildAuthorizer() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '扫描新设备上的授权请求码',
          style: TextStyle(color: LonIsleTheme.textWhite, fontSize: 16),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () async {
              final code = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => const _ScanPage(title: '扫描授权请求码'),
                ),
              );
              if (code == null || !mounted) return;
              await _handleAuthRequest(code);
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('开始扫码'),
            style: ElevatedButton.styleFrom(
              backgroundColor: LonIsleTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: LonIsleTheme.red)),
        ],
      ],
    );
  }

  /// 已认证设备：解析请求 → 确认 → 签发证书 → 展示证书码
  Future<void> _handleAuthRequest(String code) async {
    try {
      final uri = Uri.parse(code);
      if (uri.host != 'device-auth') throw StateError('不是有效的授权请求码');
      final pubkey = uri.queryParameters['pub'] ?? '';
      final name = uri.queryParameters['name'] ?? '新设备';
      if (pubkey.length != 64) throw StateError('设备公钥格式错误');

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: LonIsleTheme.bg2,
          title: const Text('授权新设备', style: TextStyle(color: LonIsleTheme.textWhite)),
          content: Text(
            '确认为设备「$name」签发授权？\n\n该设备将获得与你身份等同的收发权限。请确认请求来自你本人的新设备。',
            style: const TextStyle(color: LonIsleTheme.textDim),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认授权', style: TextStyle(color: LonIsleTheme.primary)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final auth = await IdentityService.instance.authorizeDevice(
        devicePubkeyHex: pubkey,
        deviceName: name,
      );
      final certQr = 'lonisle://device-cert'
          '?cert=${auth.deviceCertHex}'
          '&uid=${auth.userId}'
          '&mpk=${auth.masterPubkeyHex}'
          '&name=${Uri.encodeComponent(auth.displayName)}'
          '&seed=${Uri.encodeComponent(auth.avatarSeed)}';

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => _CertQrPage(qrData: certQr)),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '授权失败：$e');
    }
  }
}

/// 通用扫码页
class _ScanPage extends StatefulWidget {
  final String title;
  const _ScanPage({required this.title});

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: Text(widget.title, style: const TextStyle(color: LonIsleTheme.textWhite)),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;
          final code = capture.barcodes.firstOrNull?.rawValue;
          if (code != null && code.isNotEmpty) {
            _handled = true;
            Navigator.pop(context, code);
          }
        },
      ),
    );
  }
}

/// 授权证书码展示页（已认证设备侧，供新设备扫描）
class _CertQrPage extends StatelessWidget {
  final String qrData;
  const _CertQrPage({required this.qrData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('授权证书码', style: TextStyle(color: LonIsleTheme.textWhite)),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '请用新设备扫描此码完成授权',
              style: TextStyle(color: LonIsleTheme.textWhite, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: QrImageView(data: qrData, size: 260),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '此码包含设备证书，仅显示一次。新设备扫描完成后即可关闭本页。',
                style: TextStyle(color: LonIsleTheme.textDim, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
