import '../../data/models/expense_models.dart';
import '../../data/models/group_model.dart';
import '../../data/models/settlement_model.dart';
import '../algorithms/debt_simplifier.dart';

class ExportService {
  /// Generates a RFC-4180 compliant CSV string for spreadsheets (Excel / Google Sheets).
  static String generateCsv({
    required GroupModel group,
    required List<Expense> expenses,
    required List<DebtSettlement> settlements,
  }) {
    final buffer = StringBuffer();

    // Group Header info
    buffer.writeln('# WiSplit Expense Report');
    buffer.writeln('# Group: ${_escapeCsv(group.name)}');
    buffer.writeln('# Export Date: ${DateTime.now().toIso8601String().split('T').first}');
    buffer.writeln('');

    // Section 1: Detailed Expenses Ledger
    buffer.writeln('Date,Description,Paid By,Split Method,Total (INR),Participants,Split Details');

    for (final exp in expenses) {
      final date = '${exp.createdAt.year}-${exp.createdAt.month.toString().padLeft(2, '0')}-${exp.createdAt.day.toString().padLeft(2, '0')}';
      final desc = _escapeCsv(exp.description);
      final payer = _escapeCsv(exp.paidBy);
      final method = exp.splitType.name;
      final total = exp.amount.toStringAsFixed(2);
      final participants = _escapeCsv(exp.splits.map((s) => s.userId).join('; '));
      final details = _escapeCsv(
        exp.splits.map((s) => '${s.userId}: ₹${s.amount.toStringAsFixed(2)}').join('; '),
      );

      buffer.writeln('$date,$desc,$payer,$method,$total,$participants,$details');
    }

    buffer.writeln('');
    buffer.writeln('# SUGGESTED SETTLEMENTS (WHO OWES WHOM)');
    buffer.writeln('From (Debtor),To (Creditor),Amount (INR),Payment Status');

    if (settlements.isEmpty) {
      buffer.writeln('All settled,All settled,0.00,SETTLED');
    } else {
      for (final s in settlements) {
        buffer.writeln('${_escapeCsv(s.fromUserId)},${_escapeCsv(s.toUserId)},${s.amount.toStringAsFixed(2)},PENDING');
      }
    }

    return buffer.toString();
  }

  /// Generates a human-readable text / PDF-ready printable report.
  static String generateSummaryReport({
    required GroupModel group,
    required List<Expense> expenses,
    required List<DebtSettlement> settlements,
  }) {
    final buffer = StringBuffer();
    final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final breakdown = DebtSimplifier.calculateMemberBreakdown(
      expenses: expenses,
      allMembers: group.members,
    );

    buffer.writeln('====================================================');
    buffer.writeln('              WISPLIT FINANCIAL SUMMARY             ');
    buffer.writeln('====================================================');
    buffer.writeln('Group Name   : ${group.name}');
    buffer.writeln('Group ID     : ${group.id}');
    buffer.writeln('Invite Code  : WS-${group.id.length >= 6 ? group.id.substring(0, 6).toUpperCase() : group.id.toUpperCase()}');
    buffer.writeln('Export Date  : ${DateTime.now().toLocal().toString().split('.').first}');
    buffer.writeln('Total Spent  : ₹${totalSpent.toStringAsFixed(2)}');
    buffer.writeln('Transactions : ${expenses.length}');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('');

    buffer.writeln('--- MEMBER FINANCIAL BREAKDOWN ---');
    breakdown.forEach((member, summary) {
      final netStr = summary.netBalance >= 0
          ? '+₹${summary.netBalance.toStringAsFixed(2)} (Gets back)'
          : '-₹${(-summary.netBalance).toStringAsFixed(2)} (Owes)';
      buffer.writeln('• $member:');
      buffer.writeln('   Paid : ₹${summary.totalPaid.toStringAsFixed(2)}');
      buffer.writeln('   Share: ₹${summary.totalShare.toStringAsFixed(2)}');
      buffer.writeln('   Net  : $netStr');
    });
    buffer.writeln('');

    buffer.writeln('--- SUGGESTED PAYMENTS (WHO OWES WHOM) ---');
    if (settlements.isEmpty) {
      buffer.writeln('✓ All group debts are fully balanced! No pending payments.');
    } else {
      int count = 1;
      for (final s in settlements) {
        buffer.writeln('$count. ${s.fromUserId} owes ${s.toUserId} -> ₹${s.amount.toStringAsFixed(2)}');
        count++;
      }
    }
    buffer.writeln('');

    buffer.writeln('--- COMPLETE EXPENSE LEDGER ---');
    for (final exp in expenses) {
      final date = '${exp.createdAt.month}/${exp.createdAt.day}/${exp.createdAt.year}';
      buffer.writeln('[$date] ${exp.description}');
      buffer.writeln('  Amount: ₹${exp.amount.toStringAsFixed(2)} (Paid by ${exp.paidBy})');
      buffer.writeln('  Split : ${exp.splitType.name}');
    }
    buffer.writeln('====================================================');

    return buffer.toString();
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
