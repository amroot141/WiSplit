import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import 'local_database.dart';

enum SyncItemType { EXPENSE, PERSONAL_LEDGER, GROUP }
enum SyncAction { CREATE, SETTLE, CANCEL }

class SyncQueueItem {
  final int id;
  final String tempId;
  final SyncItemType itemType;
  final SyncAction action;
  final String endpoint;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final String status;

  const SyncQueueItem({
    required this.id,
    required this.tempId,
    required this.itemType,
    required this.action,
    required this.endpoint,
    required this.payload,
    required this.createdAt,
    required this.retryCount,
    required this.status,
  });

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as int,
      tempId: map['temp_id'] as String,
      itemType: SyncItemType.values.firstWhere(
        (e) => e.name == map['item_type'],
        orElse: () => SyncItemType.EXPENSE,
      ),
      action: SyncAction.values.firstWhere(
        (e) => e.name == map['action'],
        orElse: () => SyncAction.CREATE,
      ),
      endpoint: map['endpoint'] as String,
      payload: jsonDecode(map['payload_json'] as String) as Map<String, dynamic>,
      createdAt: DateTime.parse(map['created_at'] as String),
      retryCount: map['retry_count'] as int,
      status: map['status'] as String,
    );
  }
}

class SyncQueueService {
  final LocalDatabase _localDb;
  final ApiClient _apiClient;
  final NetworkInfo _networkInfo;
  bool _isSyncing = false;

  SyncQueueService({
    LocalDatabase? localDb,
    ApiClient? apiClient,
    NetworkInfo? networkInfo,
  })  : _localDb = localDb ?? LocalDatabase.instance,
        _apiClient = apiClient ?? ApiClient(),
        _networkInfo = networkInfo ?? NetworkInfoImpl();

  Future<int> enqueue({
    required String tempId,
    required SyncItemType itemType,
    required SyncAction action,
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    final db = await _localDb.database;
    return await db.insert(
      'sync_queue',
      {
        'temp_id': tempId,
        'item_type': itemType.name,
        'action': action.name,
        'endpoint': endpoint,
        'payload_json': jsonEncode(payload),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'retry_count': 0,
        'status': 'PENDING',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getPendingCount() async {
    final db = await _localDb.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM sync_queue WHERE status = 'PENDING'",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearQueue() async {
    final db = await _localDb.database;
    await db.delete('sync_queue');
  }

  Future<void> processQueue() async {
    if (_isSyncing) return;
    final isOnline = await _networkInfo.isConnected;
    if (!isOnline) return;

    _isSyncing = true;
    final db = await _localDb.database;

    try {
      final rows = await db.query(
        'sync_queue',
        where: "status = 'PENDING'",
        orderBy: 'id ASC',
      );

      for (final row in rows) {
        final item = SyncQueueItem.fromMap(row);
        try {
          if (item.action == SyncAction.CREATE) {
            final response = await _apiClient.post(item.endpoint, body: item.payload);
            
            // If it's an expense, update cached record with server ID and mark synced
            if (item.itemType == SyncItemType.EXPENSE && response is Map<String, dynamic>) {
              final serverId = response['id'] as String;
              await db.update(
                'cached_expenses',
                {
                  'id': serverId,
                  'is_synced': 1,
                },
                where: 'id = ?',
                whereArgs: [item.tempId],
              );
            }
          }

          // Successfully processed: remove from queue
          await db.delete('sync_queue', where: 'id = ?', whereArgs: [item.id]);
        } catch (e) {
          // If connection failed to obsolete local endpoint, remove so it doesn't block sync
          if (item.endpoint.startsWith('/groups')) {
            await db.delete('sync_queue', where: 'id = ?', whereArgs: [item.id]);
          } else {
            final nextRetry = item.retryCount + 1;
            await db.update(
              'sync_queue',
              {
                'retry_count': nextRetry,
                'status': nextRetry > 2 ? 'FAILED' : 'PENDING',
              },
              where: 'id = ?',
              whereArgs: [item.id],
            );
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }
}
