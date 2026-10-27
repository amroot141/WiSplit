import '../../core/network/api_client.dart';
import '../models/expense_models.dart';
import '../models/settlement_model.dart';

abstract class ExpenseApiService {
  Future<Expense> createExpense(String groupId, CreateExpenseRequest request);
  Future<List<DebtSettlement>> fetchSettlements(String groupId, {String currency = 'USD'});
}

class ExpenseApiServiceImpl implements ExpenseApiService {
  final ApiClient _apiClient;

  ExpenseApiServiceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<Expense> createExpense(String groupId, CreateExpenseRequest request) async {
    final response = await _apiClient.post(
      '/groups/$groupId/expenses',
      body: request.toJson(),
    );
    return Expense.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<DebtSettlement>> fetchSettlements(
    String groupId, {
    String currency = 'USD',
  }) async {
    final response = await _apiClient.get(
      '/groups/$groupId/settlements',
      queryParams: {'currency': currency},
    );
    return (response as List)
        .map((item) => DebtSettlement.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
