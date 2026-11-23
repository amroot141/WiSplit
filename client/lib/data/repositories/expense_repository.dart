import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/algorithms/debt_simplifier.dart';
import '../../core/database/local_database.dart';
import '../../core/database/sync_queue_service.dart';
import '../../core/network/network_info.dart';
import '../models/expense_models.dart';
import '../models/settlement_model.dart';
import '../services/auth_service.dart';
import '../services/expense_api_service.dart';
import 'group_repository.dart';

abstract class ExpenseRepository {
  Future<Expense> createExpense(String groupId, CreateExpenseRequest request);
  Future<List<Expense>> createExpensesBatch(String groupId, List<CreateExpenseRequest> requests);
  Future<List<Expense>> getCachedGroupExpenses(String groupId);
  Future<List<Expense>> getAllCachedExpenses();
  Future<List<DebtSettlement>> getSimplifiedDebts(String groupId, {String currency = 'USD'});
  Future<void> syncPendingExpenses();
  Future<Expense> updateExpense(String groupId, String expenseId, CreateExpenseRequest request);
  Future<void> deleteExpense(String expenseId, String groupId);
}

class ExpenseRepositoryImpl implements ExpenseRepository {
  final LocalDatabase _localDb;
  final SyncQueueService _syncQueue;
  final Uuid _uuid;

  ExpenseRepositoryImpl({
    LocalDatabase? localDb,
    SyncQueueService? syncQueue,
    ExpenseApiService? apiService,
    NetworkInfo? networkInfo,
  })  : _localDb = localDb ?? LocalDatabase.instance,
        _syncQueue = syncQueue ?? SyncQueueService(),
        _uuid = const Uuid();

  @override
  Future<Expense> createExpense(String groupId, CreateExpenseRequest request) async {
    // Instant offline-first creation: write directly to SQLite with zero network latency
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
      isSynced: true,
    );

    await _cacheExpense(offlineExpense, isSynced: true);
    
    // Background cloud backup (non-blocking)
    AuthService().syncAccountDataToCloud();

    return offlineExpense;
  }

  @override
  Future<List<Expense>> createExpensesBatch(
    String groupId,
    List<CreateExpenseRequest> requests,
  ) async {
    final db = await _localDb.database;
    final createdList = <Expense>[];

    await db.transaction((txn) async {
      for (final request in requests) {
        final tempId = 'temp_${_uuid.v4()}';
        final expenseTimestamp = request.createdAt?.toUtc() ?? DateTime.now().toUtc();
        final splits = request.splits.map((s) {
          return ExpenseSplit(
            id: _uuid.v4(),
            expenseId: tempId,
            userId: s.userId,
            amount: s.amount ?? (request.amount / request.splits.length),
            percentage: s.percentage,
            shares: s.shares,
            createdAt: expenseTimestamp,
          );
        }).toList();

        final offlineExpense = Expense(
          id: tempId,
          groupId: groupId,
          paidBy: request.paidBy,
          amount: request.amount,
          currency: request.currency,
          description: request.description,
          splitType: request.splitType,
          createdAt: expenseTimestamp,
          splits: splits,
          isSynced: true,
        );

        await txn.insert(
          'cached_expenses',
          {
            'id': offlineExpense.id,
            'group_id': offlineExpense.groupId,
            'paid_by': offlineExpense.paidBy,
            'amount': offlineExpense.amount,
            'currency': offlineExpense.currency,
            'description': offlineExpense.description,
            'split_type': offlineExpense.splitType.toJson(),
            'created_at': offlineExpense.createdAt.toIso8601String(),
            'splits_json': jsonEncode(offlineExpense.splits.map((s) => s.toJson()).toList()),
            'is_synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        createdList.add(offlineExpense);
      }
    });

    // Backup entire updated dataset to account cloud storage
    AuthService().syncAccountDataToCloud();

    return createdList;
  }

  @override
  Future<List<Expense>> getAllCachedExpenses() async {
    final db = await _localDb.database;
    final rows = await db.query(
      'cached_expenses',
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
    final expenses = await getCachedGroupExpenses(groupId);
    final group = await GroupRepository().getGroupById(groupId);
    final members = group?.members ?? [];
    return DebtSimplifier.calculateSimplifiedDebts(
      expenses: expenses,
      allMembers: members,
    );
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

    AuthService().syncAccountDataToCloud();
  }

  @override
  Future<Expense> updateExpense(
    String groupId,
    String expenseId,
    CreateExpenseRequest request,
  ) async {
    final db = await _localDb.database;
    final expenseTimestamp = request.createdAt?.toUtc() ?? DateTime.now().toUtc();
    final splits = request.splits.map((s) {
      return ExpenseSplit(
        id: _uuid.v4(),
        expenseId: expenseId,
        userId: s.userId,
        amount: s.amount ?? (request.amount / request.splits.length),
        percentage: s.percentage,
        shares: s.shares,
        createdAt: expenseTimestamp,
      );
    }).toList();

    final updatedExpense = Expense(
      id: expenseId,
      groupId: groupId,
      paidBy: request.paidBy,
      amount: request.amount,
      currency: request.currency,
      description: request.description,
      splitType: request.splitType,
      createdAt: expenseTimestamp,
      splits: splits,
      isSynced: true,
    );

    await db.update(
      'cached_expenses',
      {
        'paid_by': updatedExpense.paidBy,
        'amount': updatedExpense.amount,
        'currency': updatedExpense.currency,
        'description': updatedExpense.description,
        'split_type': updatedExpense.splitType.toJson(),
        'created_at': updatedExpense.createdAt.toIso8601String(),
        'splits_json': jsonEncode(updatedExpense.splits.map((s) => s.toJson()).toList()),
        'is_synced': 1,
      },
      where: 'id = ?',
      whereArgs: [expenseId],
    );

    AuthService().syncAccountDataToCloud();

    return updatedExpense;
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
