import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'discovery_screen.dart';

/// 添加服务器页（已登录后添加更多服务器）
class AddServerScreen extends StatefulWidget {
  const AddServerScreen({super.key});

  @override
  State<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends State<AddServerScreen> {
  final _hostController = TextEditingController(text: '127.0.0.1');
  final _portController = TextEditingController(text: '8080');
  final _reasonController = TextEditingController();
  final _claimCodeController = TextEditingController();
  final _inviteController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _fingerprint; // TOFU 指纹（邀请链接携带）

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _reasonController.dispose();
    _claimCodeController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  /// 解析邀请链接：`lonisle://server/host:port#指纹`
  void _parseInvite(String link) {
    final trimmed = link.trim();
    if (!trimmed.startsWith('lonisle://server/')) return;
    final rest = trimmed.substring('lonisle://server/'.length);
    final hashIndex = rest.indexOf('#');
    final addressPart = hashIndex >= 0 ? rest.substring(0, hashIndex) : rest;
    final fingerprint = hashIndex >= 0 ? rest.substring(hashIndex + 1) : '';

    final parts = addressPart.split(':');
    if (parts.length != 2) return;

    setState(() {
      _hostController.text = parts[0];
      _portController.text = parts[1];
      _fingerprint = fingerprint.isNotEmpty ? fingerprint : null;
    });
  }

  Future<void> _connect() async {
    setState(() => _loading = true);
    _error = null;
    try {
      final host = _hostController.text.trim();
      final port = int.parse(_portController.text.trim());
      // 邀请链接指纹在连接前比对（TOFU），不一致由连接层中止并抛出异常
      await AppState.instance.connectAndJoin(
        host,
        port,
        reason: _reasonController.text.trim(),
        claimCode: _claimCodeController.text.trim(),
        expectedFingerprint: _fingerprint ?? '',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('添加服务器', style: TextStyle(color: LonIsleTheme.textWhite)),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiscoveryScreen()),
              );
            },
            icon: const Icon(Icons.public, color: LonIsleTheme.textWhite),
            tooltip: '发现服务器',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _inviteController,
                  onChanged: _parseInvite,
                  decoration: const InputDecoration(
                    labelText: '邀请链接（可选）',
                    hintText: 'lonisle://server/host:port#指纹',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(labelText: '服务器地址', hintText: 'host 或 IP'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _portController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '端口'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: '申请理由（审批加入时需要）'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _claimCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Owner 认领码（可选）',
                    hintText: 'xxxx-xxxx-xxxx-xxxx',
                    helperText: '服务器部署者首次加入时使用，认领后自动成为 Owner',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: LonIsleTheme.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _connect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LonIsleTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('连接并加入'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
