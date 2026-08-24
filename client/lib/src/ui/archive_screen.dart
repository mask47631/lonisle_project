import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/local_store.dart';
import '../theme.dart';

/// 归档服务器页（F-MSG-11/12）：
/// 浏览已退出/迁移服务器的历史消息（只读），支持删除本地数据。
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<String> _archived = [];
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final archived = await LocalStore.instance.listArchivedServers();
    final counts = <String, int>{};
    for (final id in archived) {
      final msgs = await LocalStore.instance.loadMessages(id, 'default');
      counts[id] = msgs.length;
    }
    if (mounted) {
      setState(() {
        _archived = archived;
        _counts = counts;
        _loading = false;
      });
    }
  }

  Future<void> _deleteData(String serverId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('删除本地数据',
            style: TextStyle(color: LonIsleTheme.textWhite)),
        content: const Text(
          '将永久删除该服务器的全部本地历史消息，无法恢复。确定删除？',
          style: TextStyle(color: LonIsleTheme.textDim, fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('删除', style: TextStyle(color: LonIsleTheme.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await LocalStore.instance.deleteServerData(serverId);
      _load();
    }
  }

  Future<void> _browse(String serverId) async {
    final msgs = await LocalStore.instance.loadMessages(serverId, 'default');
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ArchiveBrowse(serverId: serverId, messages: msgs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('归档服务器',
            style: TextStyle(color: LonIsleTheme.textWhite)),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: LonIsleTheme.primary))
          : _archived.isEmpty
              ? const Center(
                  child: Text('暂无归档服务器',
                      style: TextStyle(color: LonIsleTheme.textDim)),
                )
              : ListView.builder(
                  itemCount: _archived.length,
                  itemBuilder: (context, i) {
                    final id = _archived[i];
                    return Card(
                      color: LonIsleTheme.bg2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.archive_outlined,
                            color: LonIsleTheme.textDim),
                        title: Text(
                            '服务器 ${id.length > 10 ? id.substring(0, 10) : id}…',
                            style: const TextStyle(
                                color: LonIsleTheme.textWhite, fontSize: 14)),
                        subtitle: Text(
                          '${_counts[id] ?? 0} 条历史消息（只读）',
                          style: const TextStyle(
                              color: LonIsleTheme.textDim, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => _browse(id),
                              child: const Text('浏览',
                                  style:
                                      TextStyle(color: LonIsleTheme.primary)),
                            ),
                            TextButton(
                              onPressed: () => _deleteData(id),
                              child: const Text('删除数据',
                                  style: TextStyle(color: LonIsleTheme.red)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// 归档消息只读浏览（F-MSG-11：退出后仍可查看）
class _ArchiveBrowse extends StatelessWidget {
  final String serverId;
  final List<ChatMessage> messages;

  const _ArchiveBrowse({required this.serverId, required this.messages});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: Text('归档 · $serverId',
            style: const TextStyle(color: LonIsleTheme.textWhite, fontSize: 15)),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
      ),
      body: messages.isEmpty
          ? const Center(
              child:
                  Text('无历史消息', style: TextStyle(color: LonIsleTheme.textDim)))
          : ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                final ts = DateTime.fromMillisecondsSinceEpoch(
                    m.serverTs * 1000);
                return ListTile(
                  dense: true,
                  title: Text(
                    m.deleted ? '消息已删除' : m.content,
                    style: TextStyle(
                      color: m.deleted
                          ? LonIsleTheme.textDim
                          : LonIsleTheme.textMuted,
                      fontStyle: m.deleted ? FontStyle.italic : null,
                    ),
                  ),
                  subtitle: Text(
                    '${m.authorName} · '
                    '${ts.month}/${ts.day} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        color: LonIsleTheme.textDim, fontSize: 11),
                  ),
                );
              },
            ),
    );
  }
}
