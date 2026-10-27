import '../../data/models/personal_ledger_model.dart';

class PersonalLedgerState {
  final List<PersonalLedgerEntry> entries;
  final bool isLoading;
  final String? errorMessage;
  final int pendingSyncCount;

  const PersonalLedgerState({
    this.entries = const [],
    this.isLoading = false,
    this.errorMessage,
    this.pendingSyncCount = 0,
  });

  PersonalLedgerState copyWith({
    List<PersonalLedgerEntry>? entries,
    bool? isLoading,
    String? errorMessage,
    int? pendingSyncCount,
  }) {
    return PersonalLedgerState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
    );
  }

  // Business calculations for personal finances
  List<PersonalLedgerEntry> get unsettledEntries =>
      entries.where((e) => e.status == LedgerStatus.UNSETTLED).toList();

  List<PersonalLedgerEntry> get settledEntries =>
      entries.where((e) => e.status == LedgerStatus.SETTLED).toList();

  /// Total amount other people owe to the specified user
  double totalOwedToMe(String currentUserId) {
    return unsettledEntries
        .where((e) => e.creditorId == currentUserId)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Total amount the specified user owes to others
  double totalIOwe(String currentUserId) {
    return unsettledEntries
        .where((e) => e.debtorId == currentUserId)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Net balance (positive means user is net creditor, negative means user is in debt)
  double netBalance(String currentUserId) {
    return totalOwedToMe(currentUserId) - totalIOwe(currentUserId);
  }
}
