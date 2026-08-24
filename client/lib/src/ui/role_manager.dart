import 'package:flutter/material.dart';

import '../proto/lonisle.pb.dart' as pb;
import '../state/server_connection.dart';
import '../theme.dart';

/// 权限位常量（与 server 端 storage::perm 一致）
class Perm {
  static const int manageTopics = 1 << 0;
  static const int approveJoin = 1 << 1;
  static const int muteMember = 1 << 2;
  static const int kickMember = 1 << 3;
  static const int banMember = 1 << 4;
  static const int manageRoles = 1 << 5;
  static const int manageServer = 1 << 6;
  static const int sendMessage = 1 << 7;

  static const Map<int, String> labels = {
    manageTopics: '管理话题',
    approveJoin: '审批加入',
    muteMember: '禁言成员',
    kickMember: '踢出成员',
    banMember: '封禁成员',
    manageRoles: '管理角色',
    manageServer: '管理服务器',
    sendMessage: '发言',
  };
}

/// 角色管理页（RBAC，P2）
class RoleManagerScreen extends StatefulWidget {
  final ServerConnection sc;

  const RoleManagerScreen({super.key, required this.sc});

  @override
  State<RoleManagerScreen> createState() => _RoleManagerScreenState();
}

class _RoleManagerScreenState extends State<RoleManagerScreen> {
  List<pb.RoleInfo> _roles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final resp = await widget.sc.connection.listRoles();
    setState(() {
      _roles = resp.roles;
      _loading = false;
    });
  }

  Future<void> _createRole() async {
    final nameController = TextEditingController();
    final idController = TextEditingController();
    var permissions = 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: LonIsleTheme.bg2,
          title: const Text('创建角色', style: TextStyle(color: LonIsleTheme.textWhite)),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: LonIsleTheme.textWhite),
                  decoration: const InputDecoration(labelText: '角色名称'),
                ),
                TextField(
                  controller: idController,
                  style: const TextStyle(color: LonIsleTheme.textWhite),
                  decoration: const InputDecoration(labelText: '角色 ID（英文）'),
                ),
                const SizedBox(height: 12),
                const Text('权限', style: TextStyle(color: LonIsleTheme.textDim)),
                for (final entry in Perm.labels.entries)
                  CheckboxListTile(
                    dense: true,
                    title: Text(entry.value, style: const TextStyle(color: LonIsleTheme.textWhite)),
                    value: permissions & entry.key != 0,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          permissions |= entry.key;
                        } else {
                          permissions &= ~entry.key;
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
          ],
        ),
      ),
    );

    if (confirmed == true && nameController.text.isNotEmpty && idController.text.isNotEmpty) {
      await widget.sc.connection.upsertRole(
        idController.text.trim(),
        nameController.text.trim(),
        permissions,
      );
      _load();
    }
  }

  Future<void> _deleteRole(String roleId) async {
    await widget.sc.connection.deleteRole(roleId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LonIsleTheme.bg,
      appBar: AppBar(
        backgroundColor: LonIsleTheme.bg2,
        title: const Text('角色管理', style: TextStyle(color: LonIsleTheme.textWhite)),
        iconTheme: const IconThemeData(color: LonIsleTheme.textWhite),
        actions: [
          IconButton(
            onPressed: _createRole,
            icon: const Icon(Icons.add, color: LonIsleTheme.textWhite),
            tooltip: '创建角色',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: LonIsleTheme.primary))
          : _roles.isEmpty
              ? const Center(
                  child: Text('暂无自定义角色', style: TextStyle(color: LonIsleTheme.textDim)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _roles.length,
                  itemBuilder: (context, i) {
                    final r = _roles[i];
                    final permLabels = Perm.labels.entries
                        .where((e) => r.permissions & e.key != 0)
                        .map((e) => e.value)
                        .join('、');
                    return Card(
                      color: LonIsleTheme.bg2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(r.name, style: const TextStyle(color: LonIsleTheme.textWhite)),
                        subtitle: Text(
                          permLabels.isEmpty ? '无权限' : permLabels,
                          style: const TextStyle(color: LonIsleTheme.textDim),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: LonIsleTheme.red),
                          onPressed: () => _deleteRole(r.roleId),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
