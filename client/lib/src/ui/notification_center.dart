import 'package:flutter/material.dart';

import '../proto/lonisle.pb.dart' as pb;
import '../state/app_state.dart';
import '../state/server_connection.dart';
import '../theme.dart';

/// 通知中心条目模型（F-UI-3：跨服务器聚合）
class NotificationItem {
  final String serverId;
  final String serverName;
  final String kind; // mention / approval / system
  final String title;
  final String body;
  final DateTime time;

  const NotificationItem({
    required this.serverId,
    required this.serverName,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
  });
}

/// 跨服务器通知中心（F-UI-3）：
/// 聚合各服务器的 @提及、审批结果、系统通知（迁移/被踢等）。
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  List<NotificationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _collect();
    // 订阅各服务器通知流
    for (final sc in AppState.instance.servers) {
      sc.notificationStream.listen((_) => _collect());
    }
  }

  /// 从各服务器收集最近通知（@我 / 审批 / 系统）
  Future<void> _collect() async {
    final selfId = AppState.instance.identity?.userId;
    final items = <NotificationItem>[];

    for (final sc in AppState.instance.servers) {
      // 1) @我的最近消息
      if (selfId != null) {
        final mentions = sc.messages
            .where((m) =>
                !m.deleted && m.mentionsUser(selfId) && m.authorId != selfId)
            .toList()
            .reversed
            .take(20);
        for (final m in mentions) {
          items.add(NotificationItem(
            serverId: sc.serverId,
            serverName: sc.serverName,
            kind: 'mention',
            title: '${m.authorName} @了你',
            body: m.content.length > 50
                ? '${m.content.substring(0, 50)}…'
                : m.content,
            time: DateTime.fromMillisecondsSinceEpoch(m.serverTs * 1000),
          ));
        }
      }

      // 2) 系统：被踢/封禁/迁移
      if (sc.expelled) {
        items.add(NotificationItem(
          serverId: sc.serverId,
          serverName: sc.serverName,
          kind: 'system',
          title: '你已被移出「${sc.serverName}」',
          body: '历史消息已归档只读',
          time: DateTime.now(),
        ));
      }
      if (sc.connection.migrationTarget.isNotEmpty) {
        items.add(NotificationItem(
          serverId: sc.serverId,
          serverName: sc.serverName,
          kind: 'system',
          title: '「${sc.serverName}」即将迁移',
          body: '新地址：${sc.connection.migrationTarget}',
          time: DateTime.now(),
        ));
      }
    }

    items.sort((a, b) => b.time.compareTo(a.time));
    if (mounted) setState(() => _items = items.take(100).toList());
  }

  IconData _iconOf(String kind) => switch (kind) {
        'mention' => Icons.alternate_email,
        'approval' => Icons.how_to_reg,
        _ => Icons.info_outline,
      };

  Color _colorOf(String kind) => switch (kind) {
        'mention' => LonIsleTheme.primary,
        'approval' => LonIsleTheme.green,
        _ => LonIsleTheme.amber,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('通知中心',
            style: TextStyle(color: LonIsleTheme.textWhite)),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
      ),
      body: _items.isEmpty
          ? const Center(
              child: Text('暂无通知',
                  style: TextStyle(color: LonIsleTheme.textDim)),
            )
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                return ListTile(
                  leading: Icon(_iconOf(item.kind),
                      color: _colorOf(item.kind), size: 22),
                  title: Text(item.title,
                      style: const TextStyle(
                          color: LonIsleTheme.textWhite, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: LonIsleTheme.textDim, fontSize: 12)),
                      Text(
                        '[${item.serverName}] '
                        '${item.time.month}/${item.time.day} ${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            color: LonIsleTheme.textDim, fontSize: 10),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                );
              },
            ),
    );
  }
}
