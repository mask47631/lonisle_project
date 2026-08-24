import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/local_store.dart';
import '../theme.dart';

/// 本地全文搜索页（基于客户端本地库 FTS5）
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<ChatMessage> _results = [];
  bool _searched = false;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    final results = await LocalStore.instance.searchMessages(query.trim());
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onSubmitted: _search,
          style: const TextStyle(color: LonIsleTheme.textWhite),
          decoration: const InputDecoration(
            hintText: '搜索消息…',
            border: InputBorder.none,
          ),
        ),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: LonIsleTheme.primary))
          : !_searched
              ? const Center(
                  child: Text('输入关键词搜索本地消息',
                      style: TextStyle(color: LonIsleTheme.textDim)),
                )
              : _results.isEmpty
                  ? const Center(
                      child: Text('无匹配消息',
                          style: TextStyle(color: LonIsleTheme.textDim)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final m = _results[i];
                        return Card(
                          color: LonIsleTheme.bg2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(m.authorName,
                                style: const TextStyle(
                                    color: LonIsleTheme.textWhite, fontSize: 13)),
                            subtitle: Text(
                              m.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: LonIsleTheme.textMuted),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
