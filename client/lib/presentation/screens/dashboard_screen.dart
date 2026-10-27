import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../providers/personal_ledger_provider.dart';
import '../widgets/add_expense_bottom_sheet.dart';
import 'auth_screen.dart';
import 'friend_profile_screen.dart';

class DashboardScreen extends ConsumerWidget {
  final String currentUserId;

  const DashboardScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerState = ref.watch(personalLedgerProvider);
    final netBalance = ledgerState.netBalance(currentUserId);
    final isPositive = netBalance >= 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('WiSplit', style: AppTypography.titleSm),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AuthScreen(
                      onAuthenticated: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Authenticated successfully!')),
                        );
                      },
                    ),
                  ),
                );
              },
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryContainer,
                child: Icon(Icons.person, size: 18, color: AppColors.onPrimaryFixed),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),

            // Hero Net Balance
            Text(
              'NET BALANCE',
              style: AppTypography.labelSm.copyWith(
                letterSpacing: 2.0,
                color: AppColors.outline,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '\$',
                  style: AppTypography.displayHeroMobile.copyWith(
                    color: AppColors.primaryContainer,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  netBalance.abs().toStringAsFixed(2),
                  style: AppTypography.displayHeroMobile.copyWith(
                    color: AppColors.pureWhite,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Trend Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 15,
                  color: AppColors.primaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  isPositive
                      ? '+\$${netBalance.toStringAsFixed(2)} net owed to you'
                      : '-\$${netBalance.abs().toStringAsFixed(2)} net you owe',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),

            // Settle Up Primary Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  showAddExpenseBottomSheet(
                    context,
                    groupId: 'default-group-id',
                    currentUserId: currentUserId,
                    groupMemberIds: [currentUserId, 'friend-user-id'],
                  );
                },
                child: const Text('Record Split / Settle'),
              ),
            ),
            const SizedBox(height: 48),

            // Recent Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent', style: AppTypography.titleSm),
                Text(
                  ledgerState.pendingSyncCount > 0
                      ? '${ledgerState.pendingSyncCount} pending sync'
                      : 'ALL SYNCED',
                  style: AppTypography.labelSm.copyWith(
                    color: ledgerState.pendingSyncCount > 0
                        ? AppColors.tertiary
                        : AppColors.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Transaction Rows
            if (ledgerState.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Text(
                  'No transactions recorded yet.\nTap Record Split or double-tap phone back.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ledgerState.entries.length,
                itemBuilder: (context, index) {
                  final entry = ledgerState.entries[index];
                  final isCreditor = entry.creditorId == currentUserId;
                  final otherParty = isCreditor ? entry.debtorId : entry.creditorId;
                  final initials = otherParty.isNotEmpty
                      ? otherParty.substring(0, otherParty.length >= 2 ? 2 : 1).toUpperCase()
                      : 'FR';

                  return InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FriendProfileScreen(
                            friendName: otherParty,
                            currentUserId: currentUserId,
                            friendUserId: otherParty,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: Avatar + Details
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initials,
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    otherParty,
                                    style: AppTypography.bodyLg.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${entry.description} • ${entry.status.name.toLowerCase()}',
                                    style: AppTypography.labelMd.copyWith(
                                      color: AppColors.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Right: Amount in Taro Lavender or White
                          Text(
                            isCreditor
                                ? '+\$${entry.amount.toStringAsFixed(2)}'
                                : '-\$${entry.amount.toStringAsFixed(2)}',
                            style: AppTypography.titleSm.copyWith(
                              color: isCreditor
                                  ? AppColors.primaryContainer
                                  : AppColors.pureWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
