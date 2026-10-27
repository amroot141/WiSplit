import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/local_database.dart';
import '../../core/database/sync_queue_service.dart';
import '../../core/network/network_info.dart';
import '../models/expense_models.dart';
import '../models/settlement_model.dart';
import '../services/expense_api_service.dart';

abstract class ExpenseRepository {
  Future<Expense> createExpense(String groupId, CreateExpenseRequest request);
  Future<List<Expense>> getCachedGroupExpenses(String groupId);
  Future<List<DebtSettlement>> getSimplifiedDebts(String groupId, {String currency = 'USD'});
  Future<void> syncPendingExpenses();
  Future<void> deleteExpense(String expenseId, String groupId);
}

class ExpenseRepositoryImpl implements ExpenseRepository {
  final ExpenseApiService _apiService;
  final LocalDatabase _localDb;
  final SyncQueueService _syncQueue;
  final NetworkInfo _networkInfo;
  final Uuid _uuid;

  ExpenseRepositoryImpl({
    ExpenseApiService? apiService,
    LocalDatabase? localDb,
    SyncQueueService? syncQueue,
    NetworkInfo? networkInfo,
  })  : _apiService = apiService ?? ExpenseApiServiceImpl(),
        _localDb = localDb ?? LocalDatabase.instance,
        _syncQueue = syncQueue ?? SyncQueueService(),
        _networkInfo = networkInfo ?? NetworkInfoImpl(),
        _uuid = const Uuid();

  @override
  Future<Expense> createExpense(String groupId, CreateExpenseRequest request) async {
    final isOnline = await _networkInfo.isConnected;

    if (isOnline) {
      try {
        final serverExpense = await _apiService.createExpense(groupId, request);
        await _cacheExpense(serverExpense, isSynced: true);
        return serverExpense;
      } catch (_) {
        // Network dropped during request, fallback to offline queue
      }
    }

    // Offline flow: Create locally, store in SQLite, and enqueue for sync
    final tempId = 'temp_${_uuid.v4()}';
    final expenseTimestamp = request.createdAt?.toUtc() ?? DateTime.now().toUtc();
    final offlineExpense = Expense(
      id: tempId,
      groupId: groupId,
      paidBy: request.paidBy,
      amount: request.amount,
      currency: request.currency,
      description: request.description,
      splitType: request.splitType,
      createdAt: expenseTimestamp,
      splits: request.splits
          .map(
            (s) => ExpenseSplit(
              id: _uuid.v4(),
              expenseId: tempId,
              userId: s.userId,
              amount: s.amount ?? (request.amount / request.splits.length),
              percentage: s.percentage,
              shares: s.shares,
              createdAt: expenseTimestamp,
            ),
          )
          .toList(),
      isSynced: false,
    );

    await _cacheExpense(offlineExpense, isSynced: false);

    await _syncQueue.enqueue(
      tempId: tempId,
      itemType: SyncItemType.EXPENSE,
      action: SyncAction.CREATE,
      endpoint: '/groups/$groupId/expenses',
      payload: request.toJson(),
    );

    return offlineExpense;
  }

  @override
  Future<List<Expense>> getCachedGroupExpenses(String groupId) async {
    final db = await _localDb.database;
    final rows = await db.query(
      'cached_expenses',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'created_at DESC',
    );

    return rows.map((r) {
      final splitsList = (jsonDecode(r['splits_json'] as String) as List)
          .map((s) => ExpenseSplit.fromJson(s as Map<String, dynamic>))
          .toList();

      return Expense(
        id: r['id'] as String,
        groupId: r['group_id'] as String,
        paidBy: r['paid_by'] as String,
        amount: (r['amount'] as num).toDouble(),
        currency: r['currency'] as String,
        description: r['description'] as String,
        splitType: SplitType.fromJson(r['split_type'] as String),
        createdAt: DateTime.parse(r['created_at'] as String),
        splits: splitsList,
        isSynced: (r['is_synced'] as int) == 1,
      );
    }).toList();
  }

  @override
  Future<List<DebtSettlement>> getSimplifiedDebts(
    String groupId, {
    String currency = 'USD',
  }) async {
    return await _apiService.fetchSettlements(groupId, currency: currency);
  }

  @override
  Future<void> syncPendingExpenses() async {
    await _syncQueue.processQueue();
  }

  @override
  Future<void> deleteExpense(String expenseId, String groupId) async {
    final db = await _localDb.database;
    await db.delete(
      'cached_expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
    );

    await _syncQueue.enqueue(
      tempId: expenseId,
      itemType: SyncItemType.EXPENSE,
      action: SyncAction.CANCEL,
      endpoint: '/groups/$groupId/expenses/$expenseId',
      payload: {'id': expenseId},
    );
  }

  Future<void> _cacheExpense(Expense expense, {required bool isSynced}) async {
    final db = await _localDb.database;
    await db.insert(
      'cached_expenses',
      {
        'id': expense.id,
        'group_id': expense.groupId,
        'paid_by': expense.paidBy,
        'amount': expense.amount,
        'currency': expense.currency,
        'description': expense.description,
        'split_type': expense.splitType.toJson(),
        'created_at': expense.createdAt.toIso8601String(),
        'splits_json': jsonEncode(expense.splits.map((s) => s.toJson()).toList()),
        'is_synced': isSynced ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
