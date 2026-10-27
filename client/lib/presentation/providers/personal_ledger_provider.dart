import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/sync_queue_service.dart';
import '../../data/models/personal_ledger_model.dart';
import '../../data/repositories/personal_ledger_repository.dart';
import 'personal_ledger_state.dart';

// Dependency Injection Providers
final personalLedgerRepositoryProvider = Provider<PersonalLedgerRepository>((ref) {
  return PersonalLedgerRepositoryImpl();
});

final syncQueueServiceProvider = Provider<SyncQueueService>((ref) {
  return SyncQueueService();
});

// StateNotifier Provider for Personal Ledger
final personalLedgerProvider =
    StateNotifierProvider<PersonalLedgerNotifier, PersonalLedgerState>((ref) {
  final repository = ref.watch(personalLedgerRepositoryProvider);
  final syncQueue = ref.watch(syncQueueServiceProvider);
  return PersonalLedgerNotifier(repository, syncQueue);
});

class PersonalLedgerNotifier extends StateNotifier<PersonalLedgerState> {
  final PersonalLedgerRepository _repository;
  final SyncQueueService _syncQueue;

  PersonalLedgerNotifier(
    this._repository,
    this._syncQueue,
  ) : super(const PersonalLedgerState()) {
    loadLedger();
  }

  /// Loads cached entries and updates sync count
  Future<void> loadLedger({String? userId}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final entries = await _repository.getCachedEntries(userId: userId);
      final pendingCount = await _syncQueue.getPendingCount();
      state = state.copyWith(
        entries: entries,
        isLoading: false,
        pendingSyncCount: pendingCount,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load ledger: ${e.toString()}',
      );
    }
  }

  /// Headless business logic trigger: Records a new 1-on-1 debt outside of groups
  ///
  /// Can be called directly from any headless dialog box or controller:
  /// ```dart
  /// ref.read(personalLedgerProvider.notifier).recordDebt(
  ///   creditorId: 'user_a',
  ///   debtorId: 'user_b',
  ///   amount: 45.0,
  ///   description: 'Movie tickets',
  /// );
  /// ```
  Future<PersonalLedgerEntry?> recordDebt({
    required String creditorId,
    required String debtorId,
    required double amount,
    required String description,
    String currency = 'USD',
  }) async {
    if (amount <= 0) {
      state = state.copyWith(errorMessage: 'Amount must be greater than 0');
      return null;
    }
    if (creditorId == debtorId) {
      state = state.copyWith(errorMessage: 'Creditor and debtor cannot be the same person');
      return null;
    }

    try {
      final newEntry = await _repository.recordDirectDebt(
        creditorId: creditorId,
        debtorId: debtorId,
        amount: amount,
        description: description,
        currency: currency,
      );

      // Optimistically prepend to active state
      final updatedEntries = [newEntry, ...state.entries];
      final pendingCount = await _syncQueue.getPendingCount();

      state = state.copyWith(
        entries: updatedEntries,
        pendingSyncCount: pendingCount,
        errorMessage: null,
      );

      return newEntry;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error recording debt: ${e.toString()}');
      return null;
    }
  }

  /// Headless business logic trigger: Marks an existing debt as settled
  Future<bool> settleDebt(String entryId) async {
    try {
      final updatedEntry = await _repository.settleDebt(entryId);

      final updatedEntries = state.entries.map((e) {
        return e.id == entryId ? updatedEntry : e;
      }).toList();

      final pendingCount = await _syncQueue.getPendingCount();

      state = state.copyWith(
        entries: updatedEntries,
        pendingSyncCount: pendingCount,
        errorMessage: null,
      );

      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error settling debt: ${e.toString()}');
      return false;
    }
  }

  /// Headless business logic trigger: Cancels an erroneous or forgiven debt entry
  Future<bool> cancelDebt(String entryId) async {
    try {
      final updatedEntry = await _repository.cancelDebt(entryId);

      final updatedEntries = state.entries.map((e) {
        return e.id == entryId ? updatedEntry : e;
      }).toList();

      final pendingCount = await _syncQueue.getPendingCount();

      state = state.copyWith(
        entries: updatedEntries,
        pendingSyncCount: pendingCount,
        errorMessage: null,
      );

      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Error cancelling debt: ${e.toString()}');
      return false;
    }
  }

  /// Processes offline queue and synchronizes with Supabase
  Future<void> syncOfflineQueue() async {
    state = state.copyWith(isLoading: true);
    try {
      await _syncQueue.processQueue();
      await loadLedger();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sync failed: ${e.toString()}',
      );
    }
  }
}
