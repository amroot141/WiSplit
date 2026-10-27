import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisplit_client/wisplit_client.dart';

/// Headless controller for triggering Personal Ledger & Group Expense actions.
/// Can be invoked from any dialog, modal sheet, or background handler without UI coupling.
class HeadlessLedgerController {
  final WidgetRef ref;

  HeadlessLedgerController(this.ref);

  /// 1. Trigger Direct 1-on-1 Debt Creation (Headless)
  Future<bool> triggerRecordDebt({
    required String creditorId,
    required String debtorId,
    required double amount,
    required String description,
    String currency = 'USD',
  }) async {
    final entry = await ref.read(personalLedgerProvider.notifier).recordDebt(
          creditorId: creditorId,
          debtorId: debtorId,
          amount: amount,
          description: description,
          currency: currency,
        );
    return entry != null;
  }

  /// 2. Trigger Debt Settlement (Headless)
  Future<bool> triggerSettleDebt(String entryId) async {
    return await ref.read(personalLedgerProvider.notifier).settleDebt(entryId);
  }

  /// 3. Trigger Debt Cancellation (Headless)
  Future<bool> triggerCancelDebt(String entryId) async {
    return await ref.read(personalLedgerProvider.notifier).cancelDebt(entryId);
  }

  /// 4. Trigger Group Expense with Split (Headless)
  Future<Expense?> triggerCreateGroupExpense({
    required String groupId,
    required String paidBy,
    required double amount,
    required String description,
    required SplitType splitType,
    required List<SplitItemInput> splits,
  }) async {
    return await ref.read(groupExpenseNotifierProvider(groupId).notifier).addExpense(
          CreateExpenseRequest(
            paidBy: paidBy,
            amount: amount,
            description: description,
            splitType: splitType,
            splits: splits,
          ),
        );
  }

  /// 5. Fetch Minimized Debt Payments (Headless)
  Future<void> triggerCalculateSettlements(String groupId) async {
    await ref.read(groupExpenseNotifierProvider(groupId).notifier).loadSimplifiedDebts();
  }
}

/// Minimal Dialog demonstrating headless trigger usage
Future<void> showHeadlessDirectDebtDialog(
  BuildContext context,
  WidgetRef ref, {
  required String currentUserId,
  required String friendUserId,
}) async {
  final controller = HeadlessLedgerController(ref);

  // In your UI layer later, simply call the headless method:
  final success = await controller.triggerRecordDebt(
    creditorId: currentUserId,
    debtorId: friendUserId,
    amount: 25.50,
    description: 'Shared lunch',
  );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Debt recorded (queued locally if offline)'
              : 'Failed to record debt',
        ),
      ),
    );
  }
}
