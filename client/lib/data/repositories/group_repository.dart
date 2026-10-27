import 'package:sqflite/sqflite.dart';

import '../../core/database/local_database.dart';
import '../../core/database/sync_queue_service.dart';
import '../models/group_model.dart';

class GroupRepository {
  final SyncQueueService _syncQueue;

  GroupRepository({SyncQueueService? syncQueue})
      : _syncQueue = syncQueue ?? SyncQueueService();

  Future<List<GroupModel>> getAllGroups() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'cached_groups',
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => GroupModel.fromMap(r)).toList();
  }

  Future<GroupModel?> getGroupById(String groupId) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'cached_groups',
      where: 'id = ?',
      whereArgs: [groupId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return GroupModel.fromMap(rows.first);
    }
    return null;
  }

  Future<void> saveGroup(GroupModel group) async {
    final db = await LocalDatabase.instance.database;
    await db.insert(
      'cached_groups',
      group.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Queue creation for offline-first sync
    await _syncQueue.enqueue(
      tempId: group.id,
      itemType: SyncItemType.GROUP,
      action: SyncAction.CREATE,
      endpoint: '/groups',
      payload: group.toMap(),
    );
  }

  Future<void> deleteGroup(String groupId) async {
    final db = await LocalDatabase.instance.database;
    await db.transaction((txn) async {
      // 1. Delete group record
      await txn.delete(
        'cached_groups',
        where: 'id = ?',
        whereArgs: [groupId],
      );

      // 2. Cascade delete cached expenses in that group
      await txn.delete(
        'cached_expenses',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
    });

    // Queue deletion for sync
    await _syncQueue.enqueue(
      tempId: groupId,
      itemType: SyncItemType.GROUP,
      action: SyncAction.CANCEL,
      endpoint: '/groups/$groupId',
      payload: {'id': groupId},
    );
  }
}
