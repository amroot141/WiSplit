import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/personal_ledger_model.dart';
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
    final totalOwedToMe = ledgerState.totalOwedToMe(currentUserId);
    final totalIOwe = ledgerState.totalIOwe(currentUserId);

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

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            otherParty,
                            style: AppTypography.bodyLg.copyWith(
                              fontWeight: FontWeight.w500,
                              decoration: isSettled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${entry.description} • ${entry.status.name}',
                            style: AppTypography.labelMd.copyWith(
                              color: isSettled ? AppColors.outline : AppColors.primaryContainer,
                            ),
                          ),
                        ],
                      ),
                      Row(
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
                          if (!isSettled) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                ref.read(personalLedgerProvider.notifier).settleDebt(entry.id);
                              },
                              icon: const Icon(Icons.check_circle_outline, color: AppColors.primaryContainer, size: 22),
                              tooltip: 'Settle Debt',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
