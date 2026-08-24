import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// 发现页：从推送服务拉取服务器目录，浏览/搜索/发起加入
class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _ServerEntry {
  final String serverId;
  final String name;
  final String description;
  final String address;
  final String joinMode;

  const _ServerEntry({
    required this.serverId,
    required this.name,
    required this.description,
    required this.address,
    required this.joinMode,
  });
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  List<_ServerEntry> _servers = [];
  List<_ServerEntry> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('${LonIsleConfig.pushServiceUrl}/directory'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;
      final servers = (data['servers'] as List? ?? [])
          .map((s) => _ServerEntry(
                serverId: s['server_id'] as String,
                name: s['name'] as String,
                description: s['description'] as String? ?? '',
                address: s['address'] as String? ?? '',
                joinMode: s['join_mode'] as String? ?? 'approval',
              ))
          .toList();
      setState(() {
        _servers = servers;
        _filtered = servers;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载目录失败：$e';
        _loading = false;
      });
    }
  }

  void _filter(String query) {
    setState(() {
      _filtered = _servers
          .where((s) =>
              s.name.toLowerCase().contains(query.toLowerCase()) ||
              s.description.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _join(_ServerEntry entry) async {
    // 解析地址 host:port
    final parts = entry.address.split(':');
    if (parts.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无效的服务器地址')),
      );
      return;
    }
    final host = parts[0];
    final port = int.tryParse(parts[1]) ?? 8080;

    try {
      await AppState.instance.connectAndJoin(host, port);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加入失败：$e')),
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
        title: const Text('发现服务器', style: TextStyle(color: LonIsleTheme.textWhite)),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _filter,
              style: const TextStyle(color: LonIsleTheme.textWhite),
              decoration: InputDecoration(
                hintText: '搜索服务器…',
                prefixIcon: const Icon(Icons.search, color: LonIsleTheme.textDim),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: LonIsleTheme.primary),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: const TextStyle(color: LonIsleTheme.red)),
                            const SizedBox(height: 12),
                            TextButton(onPressed: _load, child: const Text('重试')),
                          ],
                        ),
                      )
                    : _filtered.isEmpty
                        ? const Center(
                            child: Text('暂无公开服务器',
                                style: TextStyle(color: LonIsleTheme.textDim)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final s = _filtered[i];
                              return Card(
                                color: LonIsleTheme.bg2,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: const Icon(Icons.dns,
                                      color: LonIsleTheme.textDim),
                                  title: Text(s.name,
                                      style: const TextStyle(
                                          color: LonIsleTheme.textWhite)),
                                  subtitle: Text(
                                    s.description.isNotEmpty
                                        ? s.description
                                        : s.address,
                                    style: const TextStyle(
                                        color: LonIsleTheme.textDim),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () => _join(s),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: LonIsleTheme.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('加入'),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
