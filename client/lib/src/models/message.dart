import 'dart:convert';

import 'package:fixnum/fixnum.dart';

import '../proto/lonisle.pb.dart' as pb;

/// 聊天消息模型（本地缓存 + UI 展示）
class ChatMessage {
  final int seq; // 服务器序号（权威排序；本地乐观消息 seq 暂用负数占位）
  final String serverId;
  final String topicId;
  final String msgId;
  final String authorId;
  final String authorName;
  final int serverTs;
  final String content;
  final bool pending; // 是否本地待发送（乐观显示）
  final bool failed; // 是否发送失败（乐观消息保留在列表，可重试）
  final bool edited; // 是否被编辑过
  final bool deleted; // 是否已删除（占位）
  final pb.Attachment? attachment; // 附件元数据（M5）
  final List<pb.Reaction> reactions; // 表情回应（M5）
  final String mentions; // @提及（JSON 数组字符串，服务端权威解析）
  final String replyTo; // 被回复消息的 msg_id（可空）

  const ChatMessage({
    required this.seq,
    required this.serverId,
    required this.topicId,
    required this.msgId,
    required this.authorId,
    required this.authorName,
    required this.serverTs,
    required this.content,
    this.pending = false,
    this.failed = false,
    this.edited = false,
    this.deleted = false,
    this.attachment,
    this.reactions = const [],
    this.mentions = '',
    this.replyTo = '',
  });

  /// 复制并替换部分字段（乐观消息失败标记等）
  ChatMessage copyWith({
    bool? pending,
    bool? failed,
    bool? edited,
    bool? deleted,
    String? content,
    String? mentions,
  }) =>
      ChatMessage(
        seq: seq,
        serverId: serverId,
        topicId: topicId,
        msgId: msgId,
        authorId: authorId,
        authorName: authorName,
        serverTs: serverTs,
        content: content ?? this.content,
        pending: pending ?? this.pending,
        failed: failed ?? this.failed,
        edited: edited ?? this.edited,
        deleted: deleted ?? this.deleted,
        attachment: attachment,
        reactions: reactions,
        mentions: mentions ?? this.mentions,
        replyTo: replyTo,
      );

  factory ChatMessage.fromRow(Map<String, Object?> row) => ChatMessage(
        seq: row['seq'] as int,
        serverId: row['server_id'] as String,
        topicId: row['topic_id'] as String,
        msgId: row['msg_id'] as String,
        authorId: row['author_id'] as String,
        authorName: row['author_name'] as String,
        serverTs: row['server_ts'] as int,
        content: row['content'] as String,
        pending: (row['pending'] as int? ?? 0) != 0,
        failed: (row['failed'] as int? ?? 0) != 0,
        edited: (row['edited'] as int? ?? 0) != 0,
        deleted: (row['deleted'] as int? ?? 0) != 0,
        mentions: row['mentions'] as String? ?? '',
        replyTo: row['reply_to'] as String? ?? '',
        reactions: _reactionsFromJson(row['reactions'] as String? ?? ''),
        attachment: _attachmentFromJson(row['attachment'] as String? ?? ''),
      );

  Map<String, Object?> toRow() => {
        'seq': seq,
        'server_id': serverId,
        'topic_id': topicId,
        'msg_id': msgId,
        'author_id': authorId,
        'author_name': authorName,
        'server_ts': serverTs,
        'content': content,
        'pending': pending ? 1 : 0,
        'failed': failed ? 1 : 0,
        'edited': edited ? 1 : 0,
        'deleted': deleted ? 1 : 0,
        'mentions': mentions,
        'reply_to': replyTo,
        'reactions': _reactionsToJson(reactions),
        'attachment': _attachmentToJson(attachment),
      };

  /// 附件元数据 JSON 序列化（F-MEDIA-8：本地持久化，切话题后可还原）
  static String _attachmentToJson(pb.Attachment? a) {
    if (a == null) return '';
    // 注意：size 是 Int64（proto uint64），jsonEncode 无法直接序列化 fixnum，
    // 必须 .toInt()，否则整条消息的 toRow 抛 JsonUnsupportedObjectError，
    // 导致批量落库在第一条媒体消息处整体失败（附件永远写不进库）。
    return jsonEncode({
      'id': a.attachmentId,
      'kind': a.kind,
      'size': a.size.toInt(),
      'mime': a.mime,
      'width': a.width,
      'height': a.height,
      'duration': a.duration,
      'thumb': a.thumbnailId,
      'filename': a.filename, // 原始文件名（F-MEDIA-10，切话题后还原展示/下载用）
    });
  }

  static pb.Attachment? _attachmentFromJson(String s) {
    if (s.isEmpty) return null;
    try {
      final v = jsonDecode(s) as Map<String, dynamic>;
      return pb.Attachment()
        ..attachmentId = v['id'] as String? ?? ''
        ..kind = v['kind'] as String? ?? ''
        ..size = Int64((v['size'] as num?)?.toInt() ?? 0)
        ..mime = v['mime'] as String? ?? ''
        ..width = (v['width'] as num?)?.toInt() ?? 0
        ..height = (v['height'] as num?)?.toInt() ?? 0
        ..duration = (v['duration'] as num?)?.toInt() ?? 0
        ..thumbnailId = v['thumb'] as String? ?? ''
        ..filename = v['filename'] as String? ?? '';
    } catch (_) {
      return null;
    }
  }

  /// reactions JSON 编码（紧凑自定义格式，避免依赖 dart:convert 之外的处理）
  static String _reactionsToJson(List<pb.Reaction> reactions) {
    if (reactions.isEmpty) return '';
    return reactions
        .map((r) =>
            '${r.emoji.replaceAll('|', '')}:${r.userId.join(',').replaceAll('|', '')}')
        .join('|');
  }

  static List<pb.Reaction> _reactionsFromJson(String s) {
    if (s.isEmpty) return const [];
    return s.split('|').map((entry) {
      final i = entry.indexOf(':');
      if (i < 0) return pb.Reaction()..emoji = entry;
      return pb.Reaction()
        ..emoji = entry.substring(0, i)
        ..userId.addAll(entry.substring(i + 1).split(',').where((u) => u.isNotEmpty));
    }).toList();
  }

  /// 解析 mentions JSON 数组为用户 ID 列表
  List<String> get mentionedUserIds {
    if (mentions.isEmpty) return const [];
    // 简易 JSON 数组解析（元素均为不含转义的字符串）
    final inner = mentions.substring(1, mentions.length - 1);
    if (inner.isEmpty) return const [];
    return inner.split('","').map((e) => e.replaceAll('"', '')).toList();
  }

  /// 是否提及了指定用户（或 everyone）
  bool mentionsUser(String userId) =>
      mentionedUserIds.contains(userId) ||
      mentionedUserIds.contains('everyone');
}
