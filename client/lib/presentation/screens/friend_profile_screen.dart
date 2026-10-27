import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../providers/group_list_provider.dart';
import '../providers/personal_ledger_provider.dart';

class FriendProfileScreen extends ConsumerWidget {
  final String friendName;
  final String? friendHandle;
  final String currentUserId;
  final String friendUserId;

  const FriendProfileScreen({
    super.key,
    required this.friendName,
    this.friendHandle,
    required this.currentUserId,
    required this.friendUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerState = ref.watch(personalLedgerProvider);
    final allGroups = ref.watch(groupListProvider);

    // Filter real bilateral personal ledger entries
    final bilateralEntries = ledgerState.entries.where((e) {
      return (e.creditorId == currentUserId && (e.debtorId == friendUserId || e.debtorId == friendName)) ||
          ((e.creditorId == friendUserId || e.creditorId == friendName) && e.debtorId == currentUserId);
    }).toList();

    // Filter real shared groups
    final sharedGroups = allGroups.where((g) {
      return g.members.any((m) =>
          m.toLowerCase() == friendName.toLowerCase() ||
          m.toLowerCase() == friendUserId.toLowerCase());
    }).toList();

    // Calculate bilateral balance
    double friendOwesMe = 0.0;
    double iOweFriend = 0.0;
    for (final e in bilateralEntries) {
      if (e.status.name == 'UNSETTLED') {
        if (e.creditorId == currentUserId) {
          friendOwesMe += e.amount;
        } else {
          iOweFriend += e.amount;
        }
      }
    }
    final netBilateral = friendOwesMe - iOweFriend;
    final isPositive = netBilateral >= 0;

    final initials = friendName.isNotEmpty
        ? friendName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'FR';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Friend Profile', style: AppTypography.titleSm),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Avatar & Name Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      initials,
                      style: AppTypography.headlineMd.copyWith(
                        color: AppColors.onPrimaryFixed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    friendName,
                    style: AppTypography.headlineMd.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (friendHandle != null && friendHandle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      friendHandle!,
                      style: AppTypography.labelMd.copyWith(color: AppColors.outline),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Net Outstanding Hero
            Text(
              'NET OUTSTANDING',
              style: AppTypography.labelSm.copyWith(letterSpacing: 2.0, color: AppColors.outline),
            ),
            const SizedBox(height: 6),
            Text(
              isPositive
                  ? '+₹${netBilateral.toStringAsFixed(2)}'
                  : '-₹${netBilateral.abs().toStringAsFixed(2)}',
              style: AppTypography.displayHeroMobile.copyWith(
                color: isPositive ? AppColors.primaryContainer : AppColors.pureWhite,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPositive ? '$friendName owes you' : 'You owe $friendName',
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),

            // Action Buttons (Remind & Settle)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Payment reminder dispatched to $friendName')),
                      );
                    },
                    icon: const Icon(Icons.send, size: 16),
                    label: Text('Remind $friendName'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (bilateralEntries.any((e) => e.status.name == 'UNSETTLED')) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        for (final e in bilateralEntries) {
                          if (e.status.name == 'UNSETTLED') {
                            await ref.read(personalLedgerProvider.notifier).settleDebt(e.id);
                          }
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Debts with $friendName settled!')),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Settle Up'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        foregroundColor: AppColors.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 36),

            // Shared Groups Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SHARED GROUPS (${sharedGroups.length})',
                style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
              ),
            ),
            const SizedBox(height: 12),

            if (sharedGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No shared groups with $friendName yet.',
                    style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                  ),
                ),
              )
            else
              ...sharedGroups.map((g) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.group, color: AppColors.primaryContainer, size: 19),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500)),
                              Text('${g.members.length} members', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.outline),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 32),

            // Activity Ledger Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'LEDGER HISTORY (${bilateralEntries.length})',
                style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
              ),
            ),
            const SizedBox(height: 12),

            if (bilateralEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No direct personal debts recorded with $friendName.',
                    style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                  ),
                ),
              )
            else
              ...bilateralEntries.map((e) {
                final isCreditor = e.creditorId == currentUserId;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.description, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(
                            e.status.name.toLowerCase(),
                            style: AppTypography.labelSm.copyWith(
                              color: e.status.name == 'SETTLED' ? AppColors.outline : AppColors.primaryContainer,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isCreditor
                            ? '+₹${e.amount.toStringAsFixed(2)}'
                            : '-₹${e.amount.toStringAsFixed(2)}',
                        style: AppTypography.titleSm.copyWith(
                          color: isCreditor ? AppColors.primaryContainer : AppColors.pureWhite,
                          fontWeight: FontWeight.w600,
                        ),
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
