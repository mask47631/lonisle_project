import 'package:flutter/material.dart';

import '../services/identity_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'device_pairing_screen.dart';

/// 首次启动：身份初始化 + 连接服务器
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _hostController = TextEditingController(text: '127.0.0.1');
  final _portController = TextEditingController(text: '8080');
  final _reasonController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _submitted = false; // 是否已提交申请（待审批状态）

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _createIdentity() async {
    setState(() => _loading = true);
    await AppState.instance.createIdentity();
    setState(() => _loading = false);
  }

  /// 用助记词恢复身份（F-DEV-7）
  Future<void> _recoverMnemonic() async {
    final controller = TextEditingController();
    final mnemonic = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('用助记词恢复身份', style: TextStyle(color: LonIsleTheme.textWhite)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '输入 24 个助记词，以空格分隔',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('恢复', style: TextStyle(color: LonIsleTheme.primary)),
          ),
        ],
      ),
    );
    if (mnemonic == null || mnemonic.isEmpty || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await IdentityService.instance.recoverFromMnemonic(mnemonic);
      await AppState.instance.init();
    } catch (e) {
      setState(() => _error = '恢复失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    setState(() => _loading = true);
    _error = null;
    try {
      final host = _hostController.text.trim();
      final port = int.parse(_portController.text.trim());
      final sc = await AppState.instance.connectAndJoin(
        host,
        port,
        reason: _reasonController.text.trim(),
      );
      // 若待审批，停留当前页轮询；否则 app.dart 会自动切主界面
      if (sc.pendingApproval) {
        setState(() => _submitted = true);
      }
    } catch (e) {
      setState(() => _error = '连接失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 轮询审批状态
  Future<void> _pollStatus() async {
    setState(() => _loading = true);
    await AppState.instance.activeServer?.pollJoinStatus();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [LonIsleTheme.bg, LonIsleTheme.bg2],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              color: LonIsleTheme.bg2,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Logo(),
                    const SizedBox(height: 24),
                    if (!state.hasIdentity) ...[
                      const Text(
                        '欢迎使用 LonIsle',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: LonIsleTheme.textWhite,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '首次启动将在本地生成你的去中心化身份，无需注册账号。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: LonIsleTheme.textDim),
                      ),
                      const SizedBox(height: 24),
                      _PrimaryButton(
                        label: '生成我的身份',
                        loading: _loading,
                        onTap: _createIdentity,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: _loading ? null : _recoverMnemonic,
                            child: const Text(
                              '用助记词恢复',
                              style: TextStyle(color: LonIsleTheme.primary),
                            ),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DevicePairingScreen(
                                          asNewDevice: true,
                                        ),
                                      ),
                                    );
                                  },
                            child: const Text(
                              '新设备扫码授权',
                              style: TextStyle(color: LonIsleTheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ] else if (_submitted) ...[
                      // 待审批状态
                      const Icon(
                        Icons.hourglass_empty,
                        size: 48,
                        color: LonIsleTheme.amber,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '申请已提交',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: LonIsleTheme.textWhite,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '你的加入申请正在等待管理员审批，请稍后刷新状态。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: LonIsleTheme.textDim),
                      ),
                      const SizedBox(height: 24),
                      _PrimaryButton(
                        label: '刷新状态',
                        loading: _loading,
                        onTap: _pollStatus,
                      ),
                    ] else ...[
                      const Text(
                        '连接服务器',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: LonIsleTheme.textWhite,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '身份：${state.identity?.displayName}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: LonIsleTheme.textDim),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: '服务器地址',
                          hintText: 'host 或 IP',
                        ),
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
                        decoration: const InputDecoration(
                          labelText: '申请理由',
                          hintText: '介绍一下自己（审批加入时需要）',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: LonIsleTheme.red),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _PrimaryButton(
                        label: '连接并加入',
                        loading: _loading,
                        onTap: _connect,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                await AppState.instance.markOnboardingDone();
                              },
                        child: const Text(
                          '暂不连接，稍后添加',
                          style: TextStyle(color: LonIsleTheme.textDim),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          'assets/logo.png',
          width: 64,
          height: 64,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: LonIsleTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}


