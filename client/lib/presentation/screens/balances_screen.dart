import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/personal_ledger_model.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/personal_ledger_provider.dart';
import '../widgets/quick_ledger_dialog.dart';

class BalancesScreen extends ConsumerWidget {
  final String currentUserId;

  const BalancesScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerState = ref.watch(personalLedgerProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final session = ref.watch(userSessionProvider).asData?.value;

    bool isCurrentUser(String nameOrId) {
      final target = nameOrId.trim().toLowerCase();
      if (target.isEmpty) return false;
      if (target == currentUserId.toLowerCase()) return true;
      if (session != null) {
        if (session.userId.toLowerCase() == target) return true;
        if (session.fullName.trim().toLowerCase() == target) return true;
        if (session.email.trim().toLowerCase() == target) return true;
        final emailPrefix = session.email.split('@').first.toLowerCase();
        if (emailPrefix == target) return true;
      }
      return false;
    }

    double groupOwedToMe = 0.0;
    double groupIOwe = 0.0;

    for (final exp in allExpenses) {
      final isPayer = isCurrentUser(exp.paidBy);
      double mySplit = 0.0;
      if (exp.splits.isNotEmpty) {
        for (final split in exp.splits) {
          if (isCurrentUser(split.userId)) {
            mySplit += split.amount;
          }
        }
      }

      if (isPayer) {
        final lent = exp.amount - mySplit;
        if (lent > 0) groupOwedToMe += lent;
      } else {
        if (mySplit > 0) groupIOwe += mySplit;
      }
    }

    final totalOwedToMe = ledgerState.totalOwedToMe(currentUserId) + groupOwedToMe;
    final totalIOwe = ledgerState.totalIOwe(currentUserId) + groupIOwe;

    return Scaffold(
      appBar: AppBar(
        title: Text('Personal Ledger', style: AppTypography.titleSm),
        actions: [
          IconButton(
            onPressed: () {
              showQuickLedgerDialog(
                ref: ref,
                currentUserId: currentUserId,
              );
            },
            icon: const Icon(Icons.add, color: AppColors.primaryContainer),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Stat Cards (You are owed vs You owe)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOU ARE OWED', style: AppTypography.labelSm),
                        const SizedBox(height: 8),
                        Text(
                          '₹${totalOwedToMe.toStringAsFixed(2)}',
                          style: AppTypography.headlineMd.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOU OWE', style: AppTypography.labelSm),
                        const SizedBox(height: 8),
                        Text(
                          '₹${totalIOwe.toStringAsFixed(2)}',
                          style: AppTypography.headlineMd.copyWith(
                            color: AppColors.pureWhite,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Direct 1-on-1 Debts Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Direct Debts (Outside Groups)', style: AppTypography.titleSm),
                IconButton(
                  onPressed: () => ref.read(personalLedgerProvider.notifier).syncOfflineQueue(),
                  icon: const Icon(Icons.sync, size: 18, color: AppColors.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (ledgerState.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Text(
                  'No direct 1-on-1 debts found.\nUse the + button or double-tap phone back to record one.',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                ),
              )
            else
              ...ledgerState.entries.map((entry) {
                final isCreditor = entry.creditorId == currentUserId;
                final otherParty = isCreditor ? entry.debtorId : entry.creditorId;
                final isSettled = entry.status == LedgerStatus.SETTLED;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _showEditDebtModal(context, ref, entry),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  otherParty,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyLg.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: isSettled ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${entry.description.isNotEmpty ? entry.description : "Debt"} • ${entry.status.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.labelMd.copyWith(
                                    color: isSettled ? AppColors.outline : AppColors.primaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isCreditor
                                    ? '+₹${entry.amount.toStringAsFixed(2)}'
                                    : '-₹${entry.amount.toStringAsFixed(2)}',
                                style: AppTypography.titleSm.copyWith(
                                  color: isCreditor ? AppColors.primaryContainer : AppColors.pureWhite,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (!isSettled)
                                IconButton(
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () {
                                    ref.read(personalLedgerProvider.notifier).settleDebt(entry.id);
                                  },
                                  icon: const Icon(Icons.check_circle_outline, color: AppColors.primaryContainer, size: 22),
                                  tooltip: 'Settle Debt',
                                )
                              else
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(Icons.done_all, color: AppColors.outline, size: 18),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showEditDebtModal(BuildContext context, WidgetRef ref, PersonalLedgerEntry entry) {
    final amountController = TextEditingController(text: entry.amount.toStringAsFixed(2));
    final descController = TextEditingController(text: entry.description);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Personal Debt', style: AppTypography.titleSm),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  tooltip: 'Delete Debt',
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await ref.read(personalLedgerProvider.notifier).deleteDebt(entry.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Debt entry deleted')),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description / Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final newAmount = double.tryParse(amountController.text.trim()) ?? entry.amount;
                final newDesc = descController.text.trim();
                Navigator.of(ctx).pop();
                await ref.read(personalLedgerProvider.notifier).updateDebt(
                  entryId: entry.id,
                  amount: newAmount,
                  description: newDesc,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Debt updated successfully')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryFixed,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
