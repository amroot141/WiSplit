import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/expense_models.dart';
import '../../data/models/settlement_model.dart';
import '../../data/repositories/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepositoryImpl();
});

// Group Expenses State
class GroupExpensesState {
  final List<Expense> expenses;
  final List<DebtSettlement> settlements;
  final bool isLoading;
  final String? errorMessage;

  const GroupExpensesState({
    this.expenses = const [],
    this.settlements = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  GroupExpensesState copyWith({
    List<Expense>? expenses,
    List<DebtSettlement>? settlements,
    bool? isLoading,
    String? errorMessage,
  }) {
    return GroupExpensesState(
      expenses: expenses ?? this.expenses,
      settlements: settlements ?? this.settlements,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// Family notifier keyed by groupId
final groupExpenseNotifierProvider =
    StateNotifierProvider.family<GroupExpenseNotifier, GroupExpensesState, String>(
  (ref, groupId) {
    final repository = ref.watch(expenseRepositoryProvider);
    return GroupExpenseNotifier(repository, groupId, ref);
  },
);

class GroupExpenseNotifier extends StateNotifier<GroupExpensesState> {
  final ExpenseRepository _repository;
  final String _groupId;
  final Ref? _ref;

  GroupExpenseNotifier(this._repository, this._groupId, [this._ref])
      : super(const GroupExpensesState()) {
    loadCachedExpenses();
  }

  /// Loads locally cached expenses for instant offline rendering
  Future<void> loadCachedExpenses() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final cached = await _repository.getCachedGroupExpenses(_groupId);
      state = state.copyWith(expenses: cached, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load cached expenses: ${e.toString()}',
      );
    }
  }

  /// Creates a new group expense (queues offline if disconnected)
  Future<Expense?> addExpense(CreateExpenseRequest request) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final created = await _repository.createExpense(_groupId, request);
      final updatedList = [created, ...state.expenses];
      state = state.copyWith(expenses: updatedList, isLoading: false);
      _ref?.read(allExpensesProvider.notifier).loadAllExpenses();
      return created;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to add expense: ${e.toString()}',
      );
      return null;
    }
  }

  /// Calls FastAPI cash flow minimization endpoint to get simplified debts
  Future<void> loadSimplifiedDebts({String currency = 'USD'}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final settlements = await _repository.getSimplifiedDebts(
        _groupId,
        currency: currency,
      );
      state = state.copyWith(settlements: settlements, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to calculate settlements: ${e.toString()}',
      );
    }
  }

  /// Batch creates multiple expenses in one atomic SQLite transaction
  Future<List<Expense>> addExpensesBatch(List<CreateExpenseRequest> requests) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final created = await _repository.createExpensesBatch(_groupId, requests);
      final cached = await _repository.getCachedGroupExpenses(_groupId);
      state = state.copyWith(
        expenses: cached,
        isLoading: false,
      );
      _ref?.read(allExpensesProvider.notifier).loadAllExpenses();
      return created;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to batch import expenses: ${e.toString()}',
      );
      return [];
    }
  }

  /// Updates an existing expense and refreshes all expenses feed
  Future<Expense?> updateExpense(String expenseId, CreateExpenseRequest request) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final updated = await _repository.updateExpense(_groupId, expenseId, request);
      final updatedList = state.expenses.map((e) => e.id == expenseId ? updated : e).toList();
      state = state.copyWith(expenses: updatedList, isLoading: false);
      _ref?.read(allExpensesProvider.notifier).loadAllExpenses();
      return updated;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update expense: ${e.toString()}',
      );
      return null;
    }
  }

  /// Deletes an expense from local storage and syncs deletion
  Future<void> deleteExpense(String expenseId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.deleteExpense(expenseId, _groupId);
      final updatedList = state.expenses.where((e) => e.id != expenseId).toList();
      state = state.copyWith(expenses: updatedList, isLoading: false);
      _ref?.read(allExpensesProvider.notifier).loadAllExpenses();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete expense: ${e.toString()}',
      );
    }
  }
}

class AllExpensesNotifier extends StateNotifier<List<Expense>> {
  final ExpenseRepository _repository;

  AllExpensesNotifier(this._repository) : super([]) {
    loadAllExpenses();
  }

  Future<void> loadAllExpenses() async {
    final expenses = await _repository.getAllCachedExpenses();
    state = expenses;
  }
}

final allExpensesProvider =
    StateNotifierProvider<AllExpensesNotifier, List<Expense>>((ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return AllExpensesNotifier(repository);
});
