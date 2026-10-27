import '../../data/models/expense_models.dart';
import '../../data/models/settlement_model.dart';

class DebtSimplifier {
  /// Calculates optimal minimal debt settlements from a list of expenses.
  /// Works completely offline with zero server dependencies.
  static List<DebtSettlement> calculateSimplifiedDebts({
    required List<Expense> expenses,
    required List<String> allMembers,
  }) {
    if (expenses.isEmpty) return [];

    // 1. Calculate net balance for each member:
    // Net = Total Paid - Total Share
    final Map<String, double> netBalances = {};
    for (final member in allMembers) {
      netBalances[member] = 0.0;
    }

    for (final expense in expenses) {
      final payer = expense.paidBy;
      netBalances[payer] = (netBalances[payer] ?? 0.0) + expense.amount;

      for (final split in expense.splits) {
        final debtor = split.userId;
        netBalances[debtor] = (netBalances[debtor] ?? 0.0) - split.amount;
      }
    }

    // 2. Separate into debtors and creditors
    // Creditors: net > 0.01 (are owed money)
    // Debtors: net < -0.01 (owe money)
    final List<MapEntry<String, double>> creditors = [];
    final List<MapEntry<String, double>> debtors = [];

    netBalances.forEach((userId, balance) {
      // Round to 2 decimal places to avoid floating point issues
      final rounded = double.parse(balance.toStringAsFixed(2));
      if (rounded > 0.01) {
        creditors.add(MapEntry(userId, rounded));
      } else if (rounded < -0.01) {
        debtors.add(MapEntry(userId, -rounded)); // Store as positive debt
      }
    });

    // Sort descending by amount to minimize transaction count
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final List<DebtSettlement> settlements = [];
    int cIdx = 0;
    int dIdx = 0;

    var credList = creditors.map((e) => MapEntry(e.key, e.value)).toList();
    var debList = debtors.map((e) => MapEntry(e.key, e.value)).toList();

    while (cIdx < credList.length && dIdx < debList.length) {
      final creditor = credList[cIdx];
      final debtor = debList[dIdx];

      final settleAmount = creditor.value < debtor.value ? creditor.value : debtor.value;
      final roundedSettle = double.parse(settleAmount.toStringAsFixed(2));

      if (roundedSettle > 0.009) {
        settlements.add(
          DebtSettlement(
            fromUserId: debtor.key,
            toUserId: creditor.key,
            amount: roundedSettle,
            currency: 'INR',
          ),
        );
      }

      final remCred = double.parse((creditor.value - settleAmount).toStringAsFixed(2));
      final remDeb = double.parse((debtor.value - settleAmount).toStringAsFixed(2));

      if (remCred <= 0.01) {
        cIdx++;
      } else {
        credList[cIdx] = MapEntry(creditor.key, remCred);
      }

      if (remDeb <= 0.01) {
        dIdx++;
      } else {
        debList[dIdx] = MapEntry(debtor.key, remDeb);
      }
    }

    return settlements;
  }

  /// Calculates individual member breakdown (Paid, Share, Net)
  static Map<String, MemberFinancialSummary> calculateMemberBreakdown({
    required List<Expense> expenses,
    required List<String> allMembers,
  }) {
    final Map<String, double> totalPaid = {};
    final Map<String, double> totalShare = {};

    for (final m in allMembers) {
      totalPaid[m] = 0.0;
      totalShare[m] = 0.0;
    }

    for (final exp in expenses) {
      totalPaid[exp.paidBy] = (totalPaid[exp.paidBy] ?? 0.0) + exp.amount;
      for (final s in exp.splits) {
        totalShare[s.userId] = (totalShare[s.userId] ?? 0.0) + s.amount;
      }
    }

    final Map<String, MemberFinancialSummary> result = {};
    for (final m in allMembers) {
      final paid = totalPaid[m] ?? 0.0;
      final share = totalShare[m] ?? 0.0;
      result[m] = MemberFinancialSummary(
        userId: m,
        totalPaid: paid,
        totalShare: share,
        netBalance: paid - share,
      );
    }

    return result;
  }
}

class MemberFinancialSummary {
  final String userId;
  final double totalPaid;
  final double totalShare;
  final double netBalance;

  const MemberFinancialSummary({
    required this.userId,
    required this.totalPaid,
    required this.totalShare,
    required this.netBalance,
  });
}
