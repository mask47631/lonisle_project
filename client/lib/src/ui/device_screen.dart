import 'package:flutter/material.dart';

import '../proto/lonisle.pb.dart' as pb;
import '../services/identity_service.dart';
import '../services/local_store.dart';
import '../state/app_state.dart';
import '../state/server_connection.dart';
import '../theme.dart';
import 'device_pairing_screen.dart';

/// 设备列表管理页：查看设备、吊销设备、导出助记词
class DeviceScreen extends StatefulWidget {
  final ServerConnection sc;

  const DeviceScreen({super.key, required this.sc});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  List<pb.DeviceInfo> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final resp = await widget.sc.listDevices();
    setState(() {
      _devices = resp.devices;
      _loading = false;
    });
  }

  Future<void> _exportMnemonic() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('导出助记词', style: TextStyle(color: LonIsleTheme.textWhite)),
        content: const Text(
          '助记词等同于主密钥权限，请确保周围无人窥屏，仅在可信设备上操作。',
          style: TextStyle(color: LonIsleTheme.textDim),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('继续')),
        ],
      ),
    );
    if (confirmed != true) return;

    final mnemonic = await IdentityService.instance.exportMnemonic();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('你的助记词', style: TextStyle(color: LonIsleTheme.textWhite)),
        content: SelectableText(
          mnemonic,
          style: const TextStyle(color: LonIsleTheme.textMuted, fontSize: 16),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('我已备份')),
        ],
      ),
    );
  }

  Future<void> _revokeDevice(pb.DeviceInfo device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('撤销设备', style: TextStyle(color: LonIsleTheme.textWhite)),
        content: Text(
          '确定撤销设备「${device.deviceName}」？该设备将立即失效。',
          style: const TextStyle(color: LonIsleTheme.textDim),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('撤销', style: TextStyle(color: LonIsleTheme.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    try {
      final pubkeyHex =
          device.devicePubkey.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (pubkeyHex.length != 64) {
        throw StateError('设备公钥缺失，无法吊销');
      }
      // 主私钥签发吊销证明（F-DEV-4）
      final proofHex = await IdentityService.instance.issueRevocation(pubkeyHex);
      final userId = IdentityService.instance.userId ?? '';

      // 本地持久化（跨服务器中继用）
      await LocalStore.instance.saveRevocation(
        userId: userId,
        devicePubkeyHex: pubkeyHex,
        proofHex: proofHex,
        revokedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      // 向所有已连接服务器传播吊销证明
      await AppState.instance.broadcastRevocation(pubkeyHex, proofHex);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已撤销，吊销证明已广播')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('撤销失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('设备管理', style: TextStyle(color: LonIsleTheme.textWhite)),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DevicePairingScreen(asNewDevice: false),
                ),
              );
            },
            icon: const Icon(Icons.qr_code, color: LonIsleTheme.textWhite),
            tooltip: '授权新设备',
          ),
          IconButton(
            onPressed: _exportMnemonic,
            icon: const Icon(Icons.key, color: LonIsleTheme.textWhite),
            tooltip: '导出助记词',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: LonIsleTheme.primary))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _devices.length,
              itemBuilder: (context, i) {
                final d = _devices[i];
                return Card(
                  color: LonIsleTheme.bg2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.devices, color: LonIsleTheme.textDim),
                    title: Text(d.deviceName,
                        style: const TextStyle(color: LonIsleTheme.textWhite)),
                    subtitle: Text(
                      d.platform,
                      style: const TextStyle(color: LonIsleTheme.textDim),
                    ),
                    trailing: d.isCurrent
                        ? const Text('当前设备',
                            style: TextStyle(color: LonIsleTheme.green, fontSize: 12))
                        : IconButton(
                            icon: const Icon(Icons.delete, color: LonIsleTheme.red),
                            onPressed: () => _revokeDevice(d),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
