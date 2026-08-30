import 'dart:io';

import 'package:flutter/material.dart';

import '../config.dart';
import '../services/keepalive_service.dart';
import '../services/identity_service.dart';
import '../services/media_service.dart';
import '../services/push_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// 设置页：自动下载阈值 + 每服务器已读回执开关（F-MSG-10）
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _imageThreshold = 0;
  double _videoThreshold = 0;
  double _audioThreshold = 0;
  final Map<String, bool> _mentionRead = {}; // serverId → 开关
  bool _dnd = false; // 免打扰（F-RATE-7）
  bool _keepalive = false; // Android 后台保活
  bool _batteryOk = true; // 是否已豁免电池优化

  // 推送服务信息（F-PUSH-2 展示）
  bool _pushOnline = false;
  bool _pushChecked = false; // 是否已探测（区分「检测中」与「离线」）
  String _pushVendor = 'mock';
  String _pushDeviceId = '';
  String _pushToken = '';
  bool _pushRegistered = false;

  @override
  void initState() {
    super.initState();
    _load();
    // 前台通知初始化（F-PUSH-2）
    PushService.instance.initForegroundNotifications();
  }

  Future<void> _load() async {
    await MediaService.instance.loadThresholds();
    final flags = <String, bool>{};
    for (final sc in AppState.instance.servers) {
      flags[sc.serverId] = await sc.mentionReadEnabled();
    }
    final dnd = await PushService.instance.dndEnabled();
    final keepalive = Platform.isAndroid
        ? KeepAliveService.instance.enabled
        : false;
    final batteryOk = Platform.isAndroid
        ? await KeepAliveService.instance.isIgnoringBatteryOptimizations()
        : true;
    setState(() {
      _imageThreshold = MediaService.instance.threshold('image');
      _videoThreshold = MediaService.instance.threshold('video');
      _audioThreshold = MediaService.instance.threshold('audio');
      _mentionRead.addAll(flags);
      _dnd = dnd;
      _keepalive = keepalive;
      _batteryOk = batteryOk;
    });
    _loadPushInfo();
  }

  /// 加载推送服务信息（在线状态 / 渠道 / Token 等）
  Future<void> _loadPushInfo() async {
    final online = await PushService.instance.serverOnline();
    final vendor = await PushService.instance.currentVendor();
    final token = await PushService.instance.currentToken();
    final deviceId = await IdentityService.instance.deviceId();
    if (!mounted) return;
    setState(() {
      _pushOnline = online;
      _pushChecked = true;
      _pushVendor = vendor;
      _pushToken = token ?? '';
      _pushDeviceId = deviceId ?? '';
      _pushRegistered = PushService.instance.registered;
    });
  }

  Future<void> _saveThreshold(String kind, double value) async {
    await MediaService.instance.saveThreshold(kind, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('设置', style: TextStyle(color: LonIsleTheme.textWhite)),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '自动下载阈值（MB，0 表示不自动下载）',
            style: TextStyle(color: LonIsleTheme.textDim, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _thresholdField(
            label: '图片',
            value: _imageThreshold,
            onChanged: (v) {
              setState(() => _imageThreshold = v);
              _saveThreshold('image', v);
            },
          ),
          _thresholdField(
            label: '视频',
            value: _videoThreshold,
            onChanged: (v) {
              setState(() => _videoThreshold = v);
              _saveThreshold('video', v);
            },
          ),
          _thresholdField(
            label: '语音',
            value: _audioThreshold,
            onChanged: (v) {
              setState(() => _audioThreshold = v);
              _saveThreshold('audio', v);
            },
          ),
          const SizedBox(height: 24),
          const Text(
            '说明：小于阈值的媒体会在消息到达时后台自动下载，'
            '超过阈值的需点击缩略图手动下载。',
            style: TextStyle(color: LonIsleTheme.textDim, fontSize: 12),
          ),
          const SizedBox(height: 24),
          // 推送服务信息（F-PUSH-2）
          const Text(
            '推送服务',
            style: TextStyle(color: LonIsleTheme.textDim, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Card(
            color: LonIsleTheme.bg2,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pushRow('服务器地址', LonIsleConfig.pushServiceUrl),
                  _pushStatusRow(),
                  _pushRow('推送渠道', PushService.vendorLabel(_pushVendor)),
                  _pushRow('设备 ID', _pushDeviceId, wrap: true),
                  _pushRow('推送 Token', _pushToken, wrap: true),
                  _pushRow('注册状态', _pushRegistered ? '已注册' : '未注册'),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _loadPushInfo(),
                      icon: const Icon(Icons.refresh,
                          size: 16, color: LonIsleTheme.textDim),
                      label: const Text('重新检测',
                          style: TextStyle(
                              fontSize: 12, color: LonIsleTheme.textDim)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 免打扰（F-RATE-7）
          Card(
            color: LonIsleTheme.bg2,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: SwitchListTile(
              title: const Text('消息免打扰',
                  style: TextStyle(color: LonIsleTheme.textWhite, fontSize: 14)),
              subtitle: const Text(
                  '开启后服务器将不向本设备推送离线唤醒通知（在线消息不受影响）',
                  style: TextStyle(color: LonIsleTheme.textDim, fontSize: 11)),
              value: _dnd,
              activeThumbColor: LonIsleTheme.primary,
              onChanged: (v) async {
                await PushService.instance.setDnd(v);
                setState(() => _dnd = v);
              },
            ),
          ),
          const SizedBox(height: 24),
          // Android 后台保活（无 FCM 设备的离线接收）
          if (Platform.isAndroid) ...[
            Card(
              color: LonIsleTheme.bg2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: SwitchListTile(
                title: const Text('后台保活接收消息',
                    style:
                        TextStyle(color: LonIsleTheme.textWhite, fontSize: 14)),
                subtitle: Text(
                  _keepalive && !_batteryOk
                      ? '已开启，但未豁免电池优化——部分机型会强制杀后台，建议在系统设置中允许 LonIsle 后台运行'
                      : '开启后通知栏将常驻一条"保持在线"通知，应用在后台也持续接收消息（不受 FCM 影响，耗电略增）',
                  style: const TextStyle(color: LonIsleTheme.textDim, fontSize: 11),
                ),
                value: _keepalive,
                activeThumbColor: LonIsleTheme.primary,
                onChanged: (v) async {
                  await KeepAliveService.instance.setEnabled(v);
                  if (v) {
                    // 首次开启：稍后重查豁免状态（系统弹窗回来后）
                    await Future.delayed(const Duration(seconds: 2));
                  }
                  final batteryOk = Platform.isAndroid
                      ? await KeepAliveService.instance
                          .isIgnoringBatteryOptimizations()
                      : true;
                  setState(() {
                    _keepalive = v;
                    _batteryOk = batteryOk;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          const SizedBox(height: 24),
          // 服务器排序（手动上移/下移，重启保持）
          if (AppState.instance.servers.length > 1) ...[
            const Text('服务器排序（上移/下移，影响侧栏与抽屉顺序）',
                style: TextStyle(color: LonIsleTheme.textDim, fontSize: 13)),
            const SizedBox(height: 8),
            for (var i = 0; i < AppState.instance.servers.length; i++)
              Card(
                color: LonIsleTheme.bg2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: LonIsleTheme.primaryDark,
                    child: Text(
                      AppState.instance.servers[i].serverName.isNotEmpty
                          ? AppState.instance.servers[i].serverName.characters.first
                              .toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: LonIsleTheme.textWhite, fontSize: 13),
                    ),
                  ),
                  title: Text(AppState.instance.servers[i].serverName,
                      style: const TextStyle(
                          color: LonIsleTheme.textWhite, fontSize: 14)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_upward,
                            size: 20, color: LonIsleTheme.textDim),
                        onPressed: i == 0
                            ? null
                            : () async {
                                await AppState.instance.moveServer(
                                    AppState.instance.servers[i].serverId, -1);
                                setState(() {});
                              },
                        tooltip: '上移',
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward,
                            size: 20, color: LonIsleTheme.textDim),
                        onPressed: i == AppState.instance.servers.length - 1
                            ? null
                            : () async {
                                await AppState.instance.moveServer(
                                    AppState.instance.servers[i].serverId, 1);
                                setState(() {});
                              },
                        tooltip: '下移',
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          const Text(
            '@提及已读回执（按服务器独立开关，默认关闭）',
            style: TextStyle(color: LonIsleTheme.textDim, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final sc in AppState.instance.servers)
            Card(
              color: LonIsleTheme.bg2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: SwitchListTile(
                title: Text(sc.serverName,
                    style: const TextStyle(color: LonIsleTheme.textWhite, fontSize: 14)),
                subtitle: const Text('开启后，你查看 @你的消息时向该服务器上报已读',
                    style: TextStyle(color: LonIsleTheme.textDim, fontSize: 11)),
                value: _mentionRead[sc.serverId] ?? false,
                activeThumbColor: LonIsleTheme.primary,
                onChanged: (v) async {
                  await sc.setMentionReadEnabled(v);
                  setState(() => _mentionRead[sc.serverId] = v);
                },
              ),
            ),
          const SizedBox(height: 24),
          const Text(
            '说明：已读回执仅针对 @提及 生效，普通消息不上报。',
            style: TextStyle(color: LonIsleTheme.textDim, fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// 推送信息行（label 左，value 右；wrap=true 时长值换行完整展示并支持复制）
  Widget _pushRow(String label, String value, {bool wrap = false}) {
    if (wrap) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: LonIsleTheme.textDim, fontSize: 13)),
            const SizedBox(height: 3),
            SelectableText(
              value,
              style: const TextStyle(
                  color: LonIsleTheme.textWhite,
                  fontSize: 12,
                  height: 1.4),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: LonIsleTheme.textDim, fontSize: 13)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: LonIsleTheme.textWhite, fontSize: 13)),
        ],
      ),
    );
  }

  /// 推送服务器在线状态行（● 在线 / ● 离线）
  Widget _pushStatusRow() {
    Widget content;
    if (!_pushChecked) {
      content = const Text('检测中…',
          style: TextStyle(color: LonIsleTheme.textDim, fontSize: 13));
    } else {
      final color = _pushOnline ? LonIsleTheme.green : LonIsleTheme.red;
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(_pushOnline ? '在线' : '离线',
              style: TextStyle(color: color, fontSize: 13)),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Text('服务器状态',
              style: TextStyle(color: LonIsleTheme.textDim, fontSize: 13)),
          const Spacer(),
          content,
        ],
      ),
    );
  }

  Widget _thresholdField({
    required String label,
    required double value,
    required void Function(double) onChanged,
  }) {
    return Card(
      color: LonIsleTheme.bg2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: LonIsleTheme.textWhite)),
            const Spacer(),
            SizedBox(
              width: 80,
              child: TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: LonIsleTheme.textWhite),
                decoration: InputDecoration(
                  suffixText: 'MB',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
