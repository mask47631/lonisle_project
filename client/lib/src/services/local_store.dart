import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/message.dart';
import '../proto/lonisle.pb.dart' as pb;
import '../rust/api.dart' as rust;
import 'identity_service.dart';

/// 本地存储：客户端 SQLite 缓存（双端存储的本地端）
///
/// 本地优先渲染：打开话题先渲染本地库，后台按游标增量同步补差。
/// 消息以服务器序号 (seq) 为权威排序。
/// 全库 SQLCipher 加密（F-MSG-8）：密钥由设备私钥经 HKDF 派生，仅内存持有。
class LocalStore {
  LocalStore._();

  static final LocalStore instance = LocalStore._();

  static const _dbName = 'lonisle_client.db';
  static const _dbVersion = 11;

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  /// SQLCipher 密钥：设备私钥 HKDF 派生（F-MSG-8）。
  /// 设备私钥缺失（极早期数据）时回退随机密钥生成全新加密库。
  /// 数据库密钥文件路径（与库同目录，600 权限）。
  /// SQLCipher key 一经生成即固化——keychain 读取间歇失败（macOS
  /// ad-hoc 签名场景 OSStatus 13）不再导致 key 漂移、库被备份重建。
  Future<File> _keyFile() async {
    final dir = await getDatabasesPath();
    return File(p.join(dir, '$_dbName.key'));
  }

  Future<String> _dbPassword() async {
    // 1) 密钥文件命中：稳定复用（重启/重连后同一 key 打开同一库）
    final keyFile = await _keyFile();
    try {
      if (await keyFile.exists()) {
        final k = (await keyFile.readAsString()).trim();
        if (k.isNotEmpty) return k;
      }
    } catch (_) {}

    // 2) 首次：从设备私钥派生（F-MSG-8），成功后写入密钥文件固化
    try {
      final secret = await IdentityService.instance.deviceSecret();
      if (secret != null && secret.isNotEmpty) {
        final key = rust.deriveDbKey(deviceSecretHex: secret);
        await _writeKeyFile(keyFile, key);
        return key;
      }
    } catch (_) {}

    // 3) 无身份/清数据场景：随机生成并固化（下次启动仍是它）
    final ts = DateTime.now().microsecondsSinceEpoch;
    final key = 'gen-$ts-${DateTime.now().toIso8601String()}';
    await _writeKeyFile(keyFile, key);
    return key;
  }

  Future<void> _writeKeyFile(File keyFile, String key) async {
    try {
      await keyFile.writeAsString(key, flush: true);
      // 尽力收紧权限（桌面端明文文件的折衷；真机上 secure storage 优先）
      // ignore: avoid_slow_async_io
    } catch (_) {
      // 密钥文件写失败（只读卷等）：本次会话仍可用该 key
    }
  }

  /// 读取旧版明文库数据（F-MSG-8 切 SQLCipher 的一次性迁移）。
  /// 返回按表名分组的数据；非明文库/不存在返回 null。
  /// 读取成功后删除明文文件（数据在内存，稍后写入加密库）。
  Future<Map<String, List<Map<String, Object?>>>?> _readLegacyPlainDb(
      String plainPath) async {
    final plainFile = File(plainPath);
    if (!plainFile.existsSync()) return null;
    // 加密库文件头为随机盐；明文 SQLite 头恒为 "SQLite format 3\0"（16 字节）
    final header = plainFile.openSync().readSync(16);
    final magic = String.fromCharCodes(header);
    if (!magic.startsWith('SQLite format 3')) return null;

    try {
      final plain = await openDatabase(plainPath, readOnly: true);
      final result = <String, List<Map<String, Object?>>>{};
      for (final table in const [
        'messages',
        'cursors',
        'unread',
        'revocations',
        'servers'
      ]) {
        final exists = await plain.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
            [table]);
        if (exists.isEmpty) continue;
        result[table] = await plain.query(table);
      }
      await plain.close();
      plainFile.deleteSync();
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<Database> _open() async {
    final path = await getDatabasesPath();
    final full = p.join(path, _dbName);
    final password = await _dbPassword();
    // 一次性迁移旧明文库数据（F-MSG-8）
    final legacy = await _readLegacyPlainDb(full);
    Database db;
    try {
      db = await _openEncrypted(full, password);
    } catch (e) {
      // 损坏/口令失配的加密库：改名备份后重建（保证 App 可用，数据可从服务器重新同步）
      final backup = '$full.corrupt-${DateTime.now().millisecondsSinceEpoch}';
      try {
        File(full).renameSync(backup);
        File('$full-wal').renameSync('$backup-wal');
      } catch (_) {}
      // ignore: avoid_print
      print('LocalStore: 加密库打开失败，已备份为 $backup 并重建（原因：$e）');
      db = await _openEncrypted(full, password);
    }
    // 导入旧明文库数据（F-MSG-8 迁移；新库已有数据时跳过）
    if (legacy != null) {
      for (final entry in legacy.entries) {
        final count = sqflite.Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM ${entry.key}')) ??
            0;
        if (count > 0) continue;
        for (final row in entry.value) {
          await db.insert(entry.key, row,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    }
    return db;
  }

  Future<Database> _openEncrypted(String full, String password) {
    return openDatabase(
      full,
      password: password,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            seq INTEGER NOT NULL,
            server_id TEXT NOT NULL,
            topic_id TEXT NOT NULL,
            msg_id TEXT NOT NULL,
            author_id TEXT NOT NULL,
            author_name TEXT NOT NULL,
            server_ts INTEGER NOT NULL,
            content TEXT NOT NULL,
            pending INTEGER NOT NULL DEFAULT 0,
            failed INTEGER NOT NULL DEFAULT 0,
            edited INTEGER NOT NULL DEFAULT 0,
            deleted INTEGER NOT NULL DEFAULT 0,
            mentions TEXT NOT NULL DEFAULT '',
            reply_to TEXT NOT NULL DEFAULT '',
            reactions TEXT NOT NULL DEFAULT '',
            attachment TEXT NOT NULL DEFAULT '',
            UNIQUE(server_id, topic_id, seq),
            UNIQUE(server_id, author_id, msg_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE cursors (
            server_id TEXT NOT NULL,
            topic_id TEXT NOT NULL,
            last_seq INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (server_id, topic_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE unread (
            server_id TEXT NOT NULL,
            topic_id TEXT NOT NULL,
            unread_count INTEGER NOT NULL DEFAULT 0,
            last_read_seq INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (server_id, topic_id)
          )
        ''');
        // FTS5 全文索引（本地搜索，M5）；content_rowid 对应 messages.id
        await db.execute('''
          CREATE VIRTUAL TABLE messages_fts USING fts5(
            content,
            author_name,
            content='messages',
            content_rowid='id'
          )
        ''');
        // 吊销证明（跨成员被动学习，F-DEV-8；跨服务器中继用）
        await db.execute('''
          CREATE TABLE revocations (
            user_id TEXT NOT NULL,
            device_pubkey_hex TEXT NOT NULL,
            proof_hex TEXT NOT NULL,
            revoked_at INTEGER NOT NULL,
            PRIMARY KEY (user_id, device_pubkey_hex)
          )
        ''');
        // 已加入服务器列表（启动恢复用）
        await db.execute('''
          CREATE TABLE servers (
            server_id TEXT PRIMARY KEY,
            host TEXT NOT NULL,
            port INTEGER NOT NULL,
            name TEXT NOT NULL DEFAULT ''
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE messages ADD COLUMN edited INTEGER NOT NULL DEFAULT 0");
          await db.execute("ALTER TABLE messages ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0");
        }
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE messages ADD COLUMN server_id TEXT NOT NULL DEFAULT ''");
          await db.execute('''
            CREATE TABLE IF NOT EXISTS unread (
              server_id TEXT NOT NULL,
              topic_id TEXT NOT NULL,
              unread_count INTEGER NOT NULL DEFAULT 0,
              last_read_seq INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (server_id, topic_id)
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
              content,
              author_name,
              content='messages',
              content_rowid='seq'
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS revocations (
              user_id TEXT NOT NULL,
              device_pubkey_hex TEXT NOT NULL,
              proof_hex TEXT NOT NULL,
              revoked_at INTEGER NOT NULL,
              PRIMARY KEY (user_id, device_pubkey_hex)
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS servers (
              server_id TEXT PRIMARY KEY,
              host TEXT NOT NULL,
              port INTEGER NOT NULL,
              name TEXT NOT NULL DEFAULT ''
            )
          ''');
        }
        if (oldVersion < 7) {
          await db.execute(
              "ALTER TABLE messages ADD COLUMN mentions TEXT NOT NULL DEFAULT ''");
          await db.execute(
              "ALTER TABLE messages ADD COLUMN reply_to TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 8) {
          await db.execute(
              "ALTER TABLE messages ADD COLUMN reactions TEXT NOT NULL DEFAULT ''");
        }
        if (oldVersion < 9) {
          await db.execute(
              "ALTER TABLE messages ADD COLUMN attachment TEXT NOT NULL DEFAULT ''");
          // 清空游标触发全量重同步：旧消息的附件元数据此前未持久化，
          // 需从服务端重新拉取补齐（upsert 幂等，消息不重复）
          await db.delete('cursors');
        }
        if (oldVersion < 10) {
          // 修复两个丢消息根因：
          // 1) 服务端 seq 按话题独立递增，但 messages 表用 seq 作全局主键，
          //    不同话题相同 seq 会互相覆盖 → 重建为自增 id 主键 + (server_id,topic_id,seq) 复合唯一
          // 2) 游标按 server_id 全局单值，跨话题污染导致增量同步跳过消息
          //    → 重建为 (server_id, topic_id) 复合主键，游标按话题独立
          await db.execute('ALTER TABLE messages RENAME TO messages_old');
          await db.execute('''
            CREATE TABLE messages (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              seq INTEGER NOT NULL,
              server_id TEXT NOT NULL,
              topic_id TEXT NOT NULL,
              msg_id TEXT NOT NULL,
              author_id TEXT NOT NULL,
              author_name TEXT NOT NULL,
              server_ts INTEGER NOT NULL,
              content TEXT NOT NULL,
              pending INTEGER NOT NULL DEFAULT 0,
              edited INTEGER NOT NULL DEFAULT 0,
              deleted INTEGER NOT NULL DEFAULT 0,
              mentions TEXT NOT NULL DEFAULT '',
              reply_to TEXT NOT NULL DEFAULT '',
              reactions TEXT NOT NULL DEFAULT '',
              attachment TEXT NOT NULL DEFAULT '',
              UNIQUE(server_id, topic_id, seq),
              UNIQUE(server_id, author_id, msg_id)
            )
          ''');
          await db.execute('''
            INSERT INTO messages
              (seq, server_id, topic_id, msg_id, author_id, author_name,
               server_ts, content, pending, edited, deleted,
               mentions, reply_to, reactions, attachment)
            SELECT seq, server_id, topic_id, msg_id, author_id, author_name,
               server_ts, content, pending, edited, deleted,
               mentions, reply_to, reactions, attachment
            FROM messages_old
          ''');
          await db.execute('DROP TABLE messages_old');
          // FTS 重建（content_rowid 由 seq 改为 id）
          await db.execute('DROP TABLE messages_fts');
          await db.execute('''
            CREATE VIRTUAL TABLE messages_fts USING fts5(
              content,
              author_name,
              content='messages',
              content_rowid='id'
            )
          ''');
          await db.execute(
              "INSERT INTO messages_fts(messages_fts) VALUES('rebuild')");
          // 游标重建：按 (server_id, topic_id)（旧全局游标可能被污染，作废）
          await db.execute('DROP TABLE cursors');
          await db.execute('''
            CREATE TABLE cursors (
              server_id TEXT NOT NULL,
              topic_id TEXT NOT NULL,
              last_seq INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (server_id, topic_id)
            )
          ''');
        }
        if (oldVersion < 11) {
          // 上一轮「发送失败提示」在 ChatMessage.toRow 输出 failed 列，
          // 但建表未加该列导致所有消息落库失败（no column named failed）→ 补列
          await db.execute(
              "ALTER TABLE messages ADD COLUMN failed INTEGER NOT NULL DEFAULT 0");
        }
      },
    );
  }

  /// 本地优先渲染：读取某服务器某话题的全部消息（按序号升序）
  Future<List<ChatMessage>> loadMessages(String serverId, String topicId) async {
    final d = await db;
    final rows = await d.query(
      'messages',
      where: 'server_id = ? AND topic_id = ?',
      whereArgs: [serverId, topicId],
      orderBy: 'seq ASC',
    );
    return rows.map(ChatMessage.fromRow).toList();
  }

  /// 批量 upsert 消息（去重）
  Future<void> upsertMessages(List<ChatMessage> messages) async {
    final d = await db;
    final batch = d.batch();
    for (final m in messages) {
      batch.insert(
        'messages',
        m.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// 写入单条消息
  Future<void> upsertMessage(ChatMessage m) async {
    final d = await db;
    await d.insert(
      'messages',
      m.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 本地是否已有某消息（F-MSG-14：删除事件对无原消息的设备不可见）
  Future<bool> hasMessage(String serverId, String msgId) async {
    final d = await db;
    final rows = await d.query(
      'messages',
      columns: ['seq'],
      where: 'server_id = ? AND msg_id = ?',
      whereArgs: [serverId, msgId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// 更新某消息的 Reaction 聚合（事件广播）
  Future<void> upsertReactions(
      String serverId, String msgId, List<pb.Reaction> reactions) async {
    final d = await db;
    final encoded = reactions
        .map((r) =>
            '${r.emoji}:${r.userId.join(',')}')
        .join('|');
    await d.update(
      'messages',
      {'reactions': encoded},
      where: 'server_id = ? AND msg_id = ?',
      whereArgs: [serverId, msgId],
    );
  }

  // ---- 吊销证明（F-DEV-8） ----

  /// 保存吊销证明（幂等）。
  Future<void> saveRevocation({
    required String userId,
    required String devicePubkeyHex,
    required String proofHex,
    required int revokedAt,
  }) async {
    final d = await db;
    await d.insert(
      'revocations',
      {
        'user_id': userId,
        'device_pubkey_hex': devicePubkeyHex,
        'proof_hex': proofHex,
        'revoked_at': revokedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 读取全部吊销证明（跨服务器中继用）。
  Future<List<Map<String, Object?>>> loadRevocations() async {
    final d = await db;
    return d.query('revocations');
  }

  // ---- 已加入服务器列表（启动恢复） ----

  /// 保存/更新服务器记录。
  Future<void> saveServer({
    required String serverId,
    required String host,
    required int port,
    String name = '',
  }) async {
    final d = await db;
    await d.insert(
      'servers',
      {'server_id': serverId, 'host': host, 'port': port, 'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 删除服务器记录（退出服务器时）。
  Future<void> removeServer(String serverId) async {
    final d = await db;
    await d.delete('servers', where: 'server_id = ?', whereArgs: [serverId]);
  }

  /// 读取全部已加入服务器。
  Future<List<Map<String, Object?>>> listServers() async {
    final d = await db;
    return d.query('servers');
  }

  /// 删除某服务器的全部本地数据（F-MSG-12：消息/未读/游标/服务器记录）。
  Future<void> deleteServerData(String serverId) async {
    final d = await db;
    final batch = d.batch();
    batch.delete('messages', where: 'server_id = ?', whereArgs: [serverId]);
    batch.delete('servers', where: 'server_id = ?', whereArgs: [serverId]);
    batch.delete('cursors', where: 'server_id = ?', whereArgs: [serverId]);
    batch.delete('unread',
        where: 'server_id = ?', whereArgs: [serverId]);
    await batch.commit(noResult: true);
  }

  /// 归档某服务器（保留消息只读，移出活跃列表；F-MSG-11）。
  Future<void> archiveServer(String serverId) async {
    final d = await db;
    await d.delete('servers', where: 'server_id = ?', whereArgs: [serverId]);
    // messages 表保留（只读浏览）
  }

  /// 已归档服务器的 server_id 集合（有消息但不在活跃列表，F-MSG-11）。
  Future<List<String>> listArchivedServers() async {
    final d = await db;
    final active = (await d.query('servers', columns: ['server_id']))
        .map((r) => r['server_id'] as String)
        .toSet();
    final rows = await d.rawQuery(
        'SELECT DISTINCT server_id, MAX(server_ts) as last_ts FROM messages GROUP BY server_id ORDER BY last_ts DESC');
    return rows
        .map((r) => r['server_id'] as String)
        .where((id) => !active.contains(id))
        .toList();
  }

  /// 读取某服务器某话题的同步游标（游标按话题独立，F-SYNC）
  Future<int> readCursor(String serverId, String topicId) async {
    final d = await db;
    final rows = await d.query(
      'cursors',
      where: 'server_id = ? AND topic_id = ?',
      whereArgs: [serverId, topicId],
    );
    if (rows.isEmpty) return 0;
    return rows.first['last_seq'] as int;
  }

  /// 更新某服务器某话题的同步游标
  Future<void> writeCursor(String serverId, String topicId, int lastSeq) async {
    final d = await db;
    await d.insert(
      'cursors',
      {'server_id': serverId, 'topic_id': topicId, 'last_seq': lastSeq},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 标记消息为已编辑（更新内容）
  Future<void> markEdited(String serverId, String msgId, String newContent) async {
    final d = await db;
    await d.update(
      'messages',
      {'content': newContent, 'edited': 1},
      where: 'server_id = ? AND msg_id = ?',
      whereArgs: [serverId, msgId],
    );
  }

  /// 标记消息为已删除（清空内容 + 占位）
  Future<void> markDeleted(String serverId, String msgId) async {
    final d = await db;
    await d.update(
      'messages',
      {'deleted': 1, 'content': ''},
      where: 'server_id = ? AND msg_id = ?',
      whereArgs: [serverId, msgId],
    );
  }

  // ---- 未读计数 ----

  /// 读取某服务器某话题的未读计数
  Future<int> readUnread(String serverId, String topicId) async {
    final d = await db;
    final rows = await d.query(
      'unread',
      where: 'server_id = ? AND topic_id = ?',
      whereArgs: [serverId, topicId],
    );
    if (rows.isEmpty) return 0;
    return rows.first['unread_count'] as int;
  }

  /// 增加某服务器某话题的未读计数
  Future<void> incrementUnread(String serverId, String topicId) async {
    final d = await db;
    await d.rawInsert('''
      INSERT INTO unread (server_id, topic_id, unread_count, last_read_seq)
      VALUES (?, ?, 1, 0)
      ON CONFLICT(server_id, topic_id) DO UPDATE SET
        unread_count = unread_count + 1
    ''', [serverId, topicId]);
  }

  /// 清零某服务器某话题的未读计数（已读）
  Future<void> clearUnread(String serverId, String topicId) async {
    final d = await db;
    await d.update(
      'unread',
      {'unread_count': 0},
      where: 'server_id = ? AND topic_id = ?',
      whereArgs: [serverId, topicId],
    );
  }

  /// 读取某服务器的总未读计数
  /// 读取某服务器各话题未读数（F-UI-4 话题级角标）
  Future<Map<String, int>> readTopicUnreads(String serverId) async {
    final d = await db;
    final rows = await d.query('unread',
        where: 'server_id = ?', whereArgs: [serverId]);
    return {
      for (final r in rows)
        r['topic_id'] as String: r['unread_count'] as int? ?? 0,
    };
  }

  Future<int> readServerUnread(String serverId) async {
    final d = await db;
    final result = await d.rawQuery(
      'SELECT COALESCE(SUM(unread_count), 0) AS total FROM unread WHERE server_id = ?',
      [serverId],
    );
    if (result.isEmpty) return 0;
    return result.first['total'] as int;
  }

  // ---- 本地全文搜索（M5，FTS5） ----

  /// 全文搜索消息（按内容/作者名），返回匹配的消息（按 seq 降序）。
  Future<List<ChatMessage>> searchMessages(String query) async {
    final d = await db;
    final rows = await d.rawQuery('''
      SELECT m.* FROM messages_fts fts
      JOIN messages m ON m.id = fts.rowid
      WHERE messages_fts MATCH ?
      ORDER BY m.seq DESC
      LIMIT 100
    ''', [query]);
    return rows.map(ChatMessage.fromRow).toList();
  }
}
