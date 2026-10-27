import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../providers/expense_provider.dart';
import '../providers/personal_ledger_provider.dart';
import '../providers/sync_provider.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncStatusProvider);
    final ledgerState = ref.watch(personalLedgerProvider);
    final allExpenses = ref.watch(allExpensesProvider);

    // Combine personal ledger entries and group expenses into real activity items
    final List<Map<String, dynamic>> allActivities = [];

    for (final entry in ledgerState.entries) {
      allActivities.add({
        'title': entry.description.isNotEmpty ? entry.description : 'Personal Ledger',
        'subtitle': 'Direct debt with ${entry.debtorId} • ${entry.status.name.toLowerCase()}',
        'amount': '₹${entry.amount.toStringAsFixed(2)}',
        'isPositive': true,
        'date': entry.createdAt,
        'icon': Icons.swap_horiz,
      });
    }

    for (final exp in allExpenses) {
      allActivities.add({
        'title': exp.description.isNotEmpty ? exp.description : 'Group Expense',
        'subtitle': 'Paid by ${exp.paidBy} • Group Split',
        'amount': '₹${exp.amount.toStringAsFixed(2)}',
        'isPositive': false,
        'date': exp.createdAt,
        'icon': Icons.receipt_long,
      });
    }

    // Sort by date descending
    allActivities.sort((a, b) {
      final dateA = a['date'] as DateTime? ?? DateTime.now();
      final dateB = b['date'] as DateTime? ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Activity Feed', style: AppTypography.titleSm),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              ref.read(personalLedgerProvider.notifier).syncOfflineQueue();
              ref.read(allExpensesProvider.notifier).loadAllExpenses();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Offline Sync Status Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  syncStatus.isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: syncStatus.isOnline ? AppColors.primaryContainer : AppColors.outline,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        syncStatus.isOnline ? 'Online Sync Active' : 'Offline Mode (Local Storage)',
                        style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        syncStatus.pendingCount > 0
                            ? '${syncStatus.pendingCount} transactions pending sync'
                            : 'All records synced with Supabase',
                        style: AppTypography.labelMd,
                      ),
                    ],
                  ),
                ),
                if (syncStatus.pendingCount > 0)
                  TextButton(
                    onPressed: () async {
                      await ref.read(syncStatusProvider.notifier).triggerSync();
                      ref.read(allExpensesProvider.notifier).loadAllExpenses();
                    },
                    child: const Text('Sync Now'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (allActivities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_outlined, size: 30, color: AppColors.primaryContainer),
                    ),
                    const SizedBox(height: 20),
                    Text('No Recent Activity', style: AppTypography.titleSm),
                    const SizedBox(height: 8),
                    Text(
                      'Your expenses, group splits, and quick personal ledger transactions will appear here.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'RECENT TIMELINE',
              style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
            ),
            const SizedBox(height: 12),
            ...allActivities.map((act) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(act['icon'] as IconData, size: 20, color: AppColors.primaryContainer),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(act['title'] as String, style: AppTypography.bodyLg),
                          const SizedBox(height: 2),
                          Text(act['subtitle'] as String, style: AppTypography.labelMd.copyWith(color: AppColors.outline)),
                        ],
                      ),
                    ),
                    Text(
                      act['amount'] as String,
                      style: AppTypography.titleSm.copyWith(
                        color: (act['isPositive'] as bool)
                            ? AppColors.primaryContainer
                            : AppColors.pureWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
