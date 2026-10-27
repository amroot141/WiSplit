import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/local_database.dart';
import '../../core/database/sync_queue_service.dart';
import '../../core/network/network_info.dart';
import '../models/personal_ledger_model.dart';
import '../services/personal_ledger_service.dart';

abstract class PersonalLedgerRepository {
  Future<PersonalLedgerEntry> recordDirectDebt({
    required String creditorId,
    required String debtorId,
    required double amount,
    required String description,
    String currency = 'USD',
  });
  Future<PersonalLedgerEntry> settleDebt(String entryId);
  Future<PersonalLedgerEntry> cancelDebt(String entryId);
  Future<PersonalLedgerEntry> updateDebt({
    required String entryId,
    required double amount,
    required String description,
  });
  Future<void> deleteDebt(String entryId);
  Future<List<PersonalLedgerEntry>> getCachedEntries({String? userId});
  Future<void> refreshFromRemote(String userId);
}

class PersonalLedgerRepositoryImpl implements PersonalLedgerRepository {
  final PersonalLedgerService _apiService;
  final LocalDatabase _localDb;
  final SyncQueueService _syncQueue;
  final NetworkInfo _networkInfo;
  final Uuid _uuid;

  PersonalLedgerRepositoryImpl({
    PersonalLedgerService? apiService,
    LocalDatabase? localDb,
    SyncQueueService? syncQueue,
    NetworkInfo? networkInfo,
  })  : _apiService = apiService ?? PersonalLedgerServiceImpl(),
        _localDb = localDb ?? LocalDatabase.instance,
        _syncQueue = syncQueue ?? SyncQueueService(),
        _networkInfo = networkInfo ?? NetworkInfoImpl(),
        _uuid = const Uuid();

  @override
  Future<PersonalLedgerEntry> recordDirectDebt({
    required String creditorId,
    required String debtorId,
    required double amount,
    required String description,
    String currency = 'USD',
  }) async {
    final now = DateTime.now().toUtc();
    final isOnline = await _networkInfo.isConnected;
    final entryId = _uuid.v4();

    final entry = PersonalLedgerEntry(
      id: entryId,
      creditorId: creditorId,
      debtorId: debtorId,
      amount: amount,
      currency: currency,
      description: description,
      status: LedgerStatus.UNSETTLED,
      createdAt: now,
      updatedAt: now,
      isSynced: isOnline,
    );

    // 1. Optimistic write to local database immediately
    final db = await _localDb.database;
    await db.insert(
      'cached_personal_ledger',
      entry.toSqliteMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 2. Network sync or queue
    if (isOnline) {
      try {
        final serverEntry = await _apiService.createEntry(entry);
        await db.update(
          'cached_personal_ledger',
          serverEntry.toSqliteMap(),
          where: 'id = ?',
          whereArgs: [entryId],
        );
        return serverEntry;
      } catch (_) {
        // Fall through to offline queueing if request dropped
      }
    }

    // Queue for sync when connection is restored
    await _syncQueue.enqueue(
      tempId: entryId,
      itemType: SyncItemType.PERSONAL_LEDGER,
      action: SyncAction.CREATE,
      endpoint: '/personal-ledger',
      payload: entry.toJson(),
    );

    return entry;
  }

  @override
  Future<PersonalLedgerEntry> settleDebt(String entryId) async {
    final now = DateTime.now().toUtc();
    final db = await _localDb.database;

    // 1. Optimistic update in SQLite
    await db.update(
      'cached_personal_ledger',
      {
        'status': LedgerStatus.SETTLED.toJson(),
        'settled_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [entryId],
    );

    final updatedMap = (await db.query(
      'cached_personal_ledger',
      where: 'id = ?',
      whereArgs: [entryId],
    )).first;
    final updatedEntry = PersonalLedgerEntry.fromSqliteMap(updatedMap);

    // 2. Dispatch or enqueue
    final isOnline = await _networkInfo.isConnected;
    if (isOnline) {
      try {
        final serverEntry = await _apiService.settleEntry(entryId);
        await db.update(
          'cached_personal_ledger',
          serverEntry.toSqliteMap(),
          where: 'id = ?',
          whereArgs: [entryId],
        );
        return serverEntry;
      } catch (_) {}
    }

    await _syncQueue.enqueue(
      tempId: entryId,
      itemType: SyncItemType.PERSONAL_LEDGER,
      action: SyncAction.SETTLE,
      endpoint: '/personal-ledger/$entryId/settle',
      payload: {'id': entryId},
    );

    return updatedEntry;
  }

  @override
  Future<PersonalLedgerEntry> cancelDebt(String entryId) async {
    final now = DateTime.now().toUtc();
    final db = await _localDb.database;

    // 1. Optimistic update
    await db.update(
      'cached_personal_ledger',
      {
        'status': LedgerStatus.CANCELLED.toJson(),
        'updated_at': now.toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [entryId],
    );

    final updatedMap = (await db.query(
      'cached_personal_ledger',
      where: 'id = ?',
      whereArgs: [entryId],
    )).first;
    final updatedEntry = PersonalLedgerEntry.fromSqliteMap(updatedMap);

    // 2. Dispatch or enqueue
    final isOnline = await _networkInfo.isConnected;
    if (isOnline) {
      try {
        final serverEntry = await _apiService.cancelEntry(entryId);
        await db.update(
          'cached_personal_ledger',
          serverEntry.toSqliteMap(),
          where: 'id = ?',
          whereArgs: [entryId],
        );
        return serverEntry;
      } catch (_) {}
    }

    await _syncQueue.enqueue(
      tempId: entryId,
      itemType: SyncItemType.PERSONAL_LEDGER,
      action: SyncAction.CANCEL,
      endpoint: '/personal-ledger/$entryId/cancel',
      payload: {'id': entryId},
    );

    return updatedEntry;
  }

  @override
  Future<List<PersonalLedgerEntry>> getCachedEntries({String? userId}) async {
    final db = await _localDb.database;
    final List<Map<String, dynamic>> rows;

    if (userId != null) {
      rows = await db.query(
        'cached_personal_ledger',
        where: 'creditor_id = ? OR debtor_id = ?',
        whereArgs: [userId, userId],
        orderBy: 'created_at DESC',
      );
    } else {
      rows = await db.query(
        'cached_personal_ledger',
        orderBy: 'created_at DESC',
      );
    }

    return rows.map(PersonalLedgerEntry.fromSqliteMap).toList();
  }

  @override
  Future<void> refreshFromRemote(String userId) async {
    final isOnline = await _networkInfo.isConnected;
    if (!isOnline) return;

    final remoteEntries = await _apiService.fetchUserLedger(userId);
    final db = await _localDb.database;
    final batch = db.batch();

    for (final entry in remoteEntries) {
      batch.insert(
        'cached_personal_ledger',
        entry.toSqliteMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<PersonalLedgerEntry> updateDebt({
    required String entryId,
    required double amount,
    required String description,
  }) async {
    final now = DateTime.now().toUtc();
    final db = await _localDb.database;

    await db.update(
      'cached_personal_ledger',
      {
        'amount': amount,
        'description': description,
        'updated_at': now.toIso8601String(),
        'is_synced': 1,
      },
      where: 'id = ?',
      whereArgs: [entryId],
    );

    final updatedMap = (await db.query(
      'cached_personal_ledger',
      where: 'id = ?',
      whereArgs: [entryId],
    )).first;
    return PersonalLedgerEntry.fromSqliteMap(updatedMap);
  }

  @override
  Future<void> deleteDebt(String entryId) async {
    final db = await _localDb.database;
    await db.delete(
      'cached_personal_ledger',
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }
}
