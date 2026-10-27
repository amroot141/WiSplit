import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/expense_models.dart';
import '../providers/expense_provider.dart';

class ExpenseDetailsScreen extends ConsumerWidget {
  final Expense expense;
  final String currentUserId;

  const ExpenseDetailsScreen({
    super.key,
    required this.expense,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPayer = expense.paidBy == currentUserId;
    final mySplit = expense.splits.firstWhere(
      (s) => s.userId == currentUserId,
      orElse: () => ExpenseSplit(
        id: '',
        expenseId: expense.id,
        userId: currentUserId,
        amount: expense.amount / (expense.splits.isNotEmpty ? expense.splits.length : 1),
        createdAt: DateTime.now(),
      ),
    );
    final otherSplitAmount = expense.amount - mySplit.amount;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Expense Details', style: AppTypography.titleSm),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Delete Expense',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metadata Tag
            Row(
              children: [
                Text(
                  expense.splitType.name,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primaryContainer,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${expense.createdAt.day.toString().padLeft(2, '0')}/${expense.createdAt.month.toString().padLeft(2, '0')}/${expense.createdAt.year} at ${expense.createdAt.hour.toString().padLeft(2, '0')}:${expense.createdAt.minute.toString().padLeft(2, '0')}',
                  style: AppTypography.labelSm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Expense Title
            Text(expense.description, style: AppTypography.headlineLg),
            const SizedBox(height: 4),
            Text(
              isPayer ? 'Paid by You' : 'Paid by ${expense.paidBy}',
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Hero Amount
            Text(
              '₹${expense.amount.toStringAsFixed(2)}',
              style: AppTypography.displayHeroMobile.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),

            // Status Badges
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 15, color: AppColors.primaryContainer),
                      const SizedBox(width: 6),
                      Text(
                        isPayer ? 'Paid in full by You' : 'Paid by ${expense.paidBy}',
                        style: AppTypography.labelMd.copyWith(color: AppColors.onSurface),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Metric Comparison Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Share', style: AppTypography.labelMd),
                        const SizedBox(height: 4),
                        Text(
                          '₹${mySplit.amount.toStringAsFixed(2)}',
                          style: AppTypography.titleSm.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text('Split: ${expense.splitType.name.toLowerCase()}', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
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
                        Text('Others Owe You', style: AppTypography.labelMd.copyWith(color: AppColors.secondary)),
                        const SizedBox(height: 4),
                        Text(
                          '₹${otherSplitAmount.toStringAsFixed(2)}',
                          style: AppTypography.titleSm.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Shared portion', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Participants Breakdown Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PARTICIPANTS (${expense.splits.length})',
                  style: AppTypography.labelSm.copyWith(letterSpacing: 1.5),
                ),
                Text(
                  expense.splitType.name,
                  style: AppTypography.labelSm.copyWith(color: AppColors.primaryContainer),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...expense.splits.map((s) {
              final isMe = s.userId == currentUserId;
              final initials = isMe
                  ? 'YOU'
                  : (s.userId.isNotEmpty
                      ? s.userId.substring(0, s.userId.length >= 2 ? 2 : 1).toUpperCase()
                      : 'U');

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: isMe ? AppColors.primaryContainer : AppColors.surfaceContainerHighest,
                          child: Text(
                            initials,
                            style: AppTypography.labelSm.copyWith(
                              color: isMe ? AppColors.onPrimaryFixed : AppColors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isMe ? 'You (Payer)' : s.userId, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500)),
                            Text('Share: ₹${s.amount.toStringAsFixed(2)}', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      isMe ? '+₹${(expense.amount - s.amount).toStringAsFixed(2)}' : '-₹${s.amount.toStringAsFixed(2)}',
                      style: AppTypography.titleSm.copyWith(
                        color: isMe ? AppColors.primaryContainer : AppColors.pureWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 36),

            // Delete Expense Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _confirmDelete(context, ref),
                icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                label: Text(
                  'Delete Expense',
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerHigh,
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Text('Delete Expense', style: AppTypography.titleSm),
        content: Text(
          'Are you sure you want to delete "${expense.description}"? This will remove the expense and recalculate group balances.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop(); // dismiss dialog
              Navigator.of(context).pop(); // return to group screen
              await ref.read(groupExpenseNotifierProvider(expense.groupId).notifier).deleteExpense(expense.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Expense "${expense.description}" deleted')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
