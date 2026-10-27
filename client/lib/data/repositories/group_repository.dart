import 'package:sqflite/sqflite.dart';

import '../../core/database/local_database.dart';
import '../models/group_model.dart';
import '../services/auth_service.dart';

class GroupRepository {
  GroupRepository();

  Future<List<GroupModel>> getAllGroups() async {
    final db = await LocalDatabase.instance.database;
    var rows = await db.query(
      'cached_groups',
      orderBy: 'created_at DESC',
    );

    // If local groups empty, attempt to restore from account cloud backup
    if (rows.isEmpty) {
      await AuthService().syncAccountDataFromCloud();
      rows = await db.query(
        'cached_groups',
        orderBy: 'created_at DESC',
      );
    }

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

    // Backup to account cloud storage
    AuthService().syncAccountDataToCloud();
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

    // Backup changes to account cloud storage
    AuthService().syncAccountDataToCloud();
  }
}
