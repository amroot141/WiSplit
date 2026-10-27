import '../../core/network/api_client.dart';
import '../models/personal_ledger_model.dart';

abstract class PersonalLedgerService {
  Future<PersonalLedgerEntry> createEntry(PersonalLedgerEntry entry);
  Future<List<PersonalLedgerEntry>> fetchUserLedger(String userId);
  Future<PersonalLedgerEntry> settleEntry(String entryId);
  Future<PersonalLedgerEntry> cancelEntry(String entryId);
}

class PersonalLedgerServiceImpl implements PersonalLedgerService {
  final ApiClient _apiClient;

  PersonalLedgerServiceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<PersonalLedgerEntry> createEntry(PersonalLedgerEntry entry) async {
    final response = await _apiClient.post(
      '/personal-ledger',
      body: entry.toJson(),
    );
    return PersonalLedgerEntry.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<PersonalLedgerEntry>> fetchUserLedger(String userId) async {
    final response = await _apiClient.get(
      '/personal-ledger',
      queryParams: {'user_id': userId},
    );
    return (response as List)
        .map((e) => PersonalLedgerEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PersonalLedgerEntry> settleEntry(String entryId) async {
    final response = await _apiClient.post(
      '/personal-ledger/$entryId/settle',
    );
    return PersonalLedgerEntry.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PersonalLedgerEntry> cancelEntry(String entryId) async {
    final response = await _apiClient.post(
      '/personal-ledger/$entryId/cancel',
    );
    return PersonalLedgerEntry.fromJson(response as Map<String, dynamic>);
  }
}
