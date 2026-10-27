import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/group_model.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/personal_ledger_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/group_list_provider.dart';
import 'friend_profile_screen.dart';
import 'group_detail_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final String currentUserId;
  final String defaultGroupId;

  const HomeScreen({
    super.key,
    required this.currentUserId,
    this.defaultGroupId = 'apartment-4b-group',
  });

  /// Triggered via Android hardware back double-tap MethodChannel
  static Future<void> showQuickAddModal(
    BuildContext context, {
    required String currentUserId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (modalContext) => Consumer(
        builder: (context, ref, _) => _QuickAddModalContent(
          currentUserId: currentUserId,
          ref: ref,
        ),
      ),
    );
  }

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _RecentItem {
  final String id;
  final String title;
  final String subtitle;
  final double netImpact;
  final double totalAmount;
  final DateTime date;
  final bool isGroup;
  final String? groupId;
  final String? friendId;

  _RecentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.netImpact,
    required this.totalAmount,
    required this.date,
    required this.isGroup,
    this.groupId,
    this.friendId,
  });
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showToast = false;
  String _toastMessage = 'All balance requests dispatched';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(allExpensesProvider.notifier).loadAllExpenses();
      ref.read(personalLedgerProvider.notifier).loadLedger();
      ref.read(groupListProvider.notifier).loadGroups();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdatesSilently(context);
    });
  }

  void _triggerToast(String message) {
    setState(() {
      _showToast = true;
      _toastMessage = message;
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _showToast = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ledgerState = ref.watch(personalLedgerProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final groups = ref.watch(groupListProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final session = ref.watch(userSessionProvider).asData?.value;

    bool isCurrentUser(String nameOrId) {
      final target = nameOrId.trim().toLowerCase();
      if (target.isEmpty) return false;
      if (target == widget.currentUserId.toLowerCase()) return true;
      if (session != null) {
        if (session.userId.toLowerCase() == target) return true;
        if (session.fullName.trim().toLowerCase() == target) return true;
        if (session.email.trim().toLowerCase() == target) return true;
        final emailPrefix = session.email.split('@').first.toLowerCase();
        if (emailPrefix == target) return true;
      }
      return false;
    }

    // 1. Personal 1-on-1 direct debts
    final personalNet = ledgerState.netBalance(widget.currentUserId);

    // 2. Group expenses net balance across all groups
    double groupNet = 0.0;
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
        groupNet += (exp.amount - mySplit);
      } else {
        groupNet -= mySplit;
      }
    }

    final totalNetBalance = personalNet + groupNet;
    final isPositive = totalNetBalance >= -0.001;

    // 3. Unified recent transactions feed
    final List<_RecentItem> recentItems = [];

    for (final entry in ledgerState.entries) {
      final isCreditor = entry.creditorId == widget.currentUserId;
      final otherParty = isCreditor ? entry.debtorId : entry.creditorId;
      final impact = isCreditor ? entry.amount : -entry.amount;
      recentItems.add(
        _RecentItem(
          id: entry.id,
          title: otherParty,
          subtitle: '${entry.description.isNotEmpty ? entry.description : "Direct debt"} • ${entry.status.name.toLowerCase()}',
          netImpact: impact,
          totalAmount: entry.amount,
          date: entry.createdAt,
          isGroup: false,
          friendId: otherParty,
        ),
      );
    }

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

      final impact = isPayer ? (exp.amount - mySplit) : -mySplit;
      final subtitle = isPayer
          ? 'You paid ₹${exp.amount.toStringAsFixed(2)}'
          : '${exp.paidBy} paid ₹${exp.amount.toStringAsFixed(2)}';

      recentItems.add(
        _RecentItem(
          id: exp.id,
          title: exp.description.isNotEmpty ? exp.description : 'Group Expense',
          subtitle: subtitle,
          netImpact: impact,
          totalAmount: exp.amount,
          date: exp.createdAt,
          isGroup: true,
          groupId: exp.groupId,
        ),
      );
    }

    recentItems.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/wisplit_logo.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            Text('WiSplit', style: AppTypography.titleSm),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),

                // ── Reactive Net Balance Hero ───────────────────────────────
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
                      '₹',
                      style: AppTypography.displayHeroMobile.copyWith(
                        color: AppColors.primaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      totalNetBalance.abs().toStringAsFixed(2),
                      style: AppTypography.displayHeroMobile.copyWith(
                        color: AppColors.pureWhite,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Trend indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 15,
                      color: isPositive ? AppColors.primaryContainer : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPositive
                          ? (totalNetBalance > 0.009
                              ? '+₹${totalNetBalance.toStringAsFixed(2)} you are owed'
                              : 'All settled up! ₹0.00')
                          : '-₹${totalNetBalance.abs().toStringAsFixed(2)} you owe',
                      style: AppTypography.labelMd.copyWith(
                        color: isPositive ? AppColors.primaryContainer : AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // ── Settle Up Primary Action Button ─────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _handleSettleUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimaryFixed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                    child: Text(
                      'Settle Up',
                      style: AppTypography.titleSm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onPrimaryFixed,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // ── Recent Section Header ───────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent', style: AppTypography.titleSm),
                    Text(
                      syncStatus.pendingCount > 0
                          ? '${syncStatus.pendingCount} PENDING'
                          : 'ALL SETTLED',
                      style: AppTypography.labelSm.copyWith(
                        color: syncStatus.pendingCount > 0
                            ? AppColors.tertiary
                            : AppColors.outline,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Dynamic Recent Transactions Feed ────────────────────────
                if (recentItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48.0),
                    child: Text(
                      'No recent transactions in local queue.\nDouble-tap the back of your phone to add one, or import CSV.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentItems.length > 25 ? 25 : recentItems.length,
                    itemBuilder: (context, index) {
                      final item = recentItems[index];
                      final initials = item.title.isNotEmpty
                          ? item.title.substring(0, item.title.length >= 2 ? 2 : 1).toUpperCase()
                          : 'TX';

                      return InkWell(
                        onTap: () {
                          if (item.isGroup && item.groupId != null) {
                            final matchedGroup = groups.firstWhere(
                              (g) => g.id == item.groupId,
                              orElse: () => GroupModel(
                                id: item.groupId!,
                                name: 'Group',
                                description: '',
                                createdBy: '',
                                members: [],
                                createdAt: DateTime.now(),
                              ),
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GroupDetailScreen(
                                  group: matchedGroup,
                                  currentUserId: widget.currentUserId,
                                ),
                              ),
                            );
                          } else if (item.friendId != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FriendProfileScreen(
                                  friendName: item.friendId!,
                                  currentUserId: widget.currentUserId,
                                  friendUserId: item.friendId!,
                                ),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: item.isGroup
                                            ? AppColors.primaryContainer.withValues(alpha: 0.15)
                                            : AppColors.surfaceContainerHigh,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: item.isGroup
                                          ? const Icon(Icons.receipt_long, color: AppColors.primaryContainer, size: 20)
                                          : Text(
                                              initials,
                                              style: AppTypography.labelMd.copyWith(
                                                color: AppColors.onSurface,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.bodyLg.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.labelMd.copyWith(
                                              color: AppColors.outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.netImpact >= 0
                                        ? '+₹${item.netImpact.toStringAsFixed(2)}'
                                        : '-₹${item.netImpact.abs().toStringAsFixed(2)}',
                                    style: AppTypography.titleSm.copyWith(
                                      color: item.netImpact >= 0
                                          ? AppColors.primaryContainer
                                          : AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (item.isGroup)
                                    Text(
                                      'Total ₹${item.totalAmount.toStringAsFixed(2)}',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.outline,
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // ── Stitch Toast Notification (Floating Pill) ────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            bottom: _showToast ? 24 : -60,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.primaryContainer, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _toastMessage,
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Triggers debt simplification on active groups or direct ledger
  Future<void> _handleSettleUp() async {
    final groups = ref.read(groupListProvider);
    final ledgerState = ref.read(personalLedgerProvider);
    final unsettledLedger = ledgerState.entries.where((e) => e.status.name == 'UNSETTLED').toList();

    if (groups.isEmpty && unsettledLedger.isEmpty) {
      _triggerToast('All caught up! No pending debts to settle.');
      return;
    }

    if (groups.isNotEmpty) {
      final activeGroupId = groups.first.id;
      final notifier = ref.read(groupExpenseNotifierProvider(activeGroupId).notifier);
      await notifier.loadSimplifiedDebts();

      final groupState = ref.read(groupExpenseNotifierProvider(activeGroupId));
      _triggerToast('Settlements calculated');

      if (!mounted) return;

      if (groupState.settlements.isNotEmpty) {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surfaceContainerLow,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          builder: (ctx) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Simplified Debt Settlements', style: AppTypography.titleSm),
                  const SizedBox(height: 6),
                  Text(
                    'Optimal settlement plan for "${groups.first.name}"',
                    style: AppTypography.labelMd.copyWith(color: AppColors.outline),
                  ),
                  const SizedBox(height: 20),
                  ...groupState.settlements.map((s) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${s.fromUserId} → ${s.toUserId}',
                            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '₹${s.amount.toStringAsFixed(2)}',
                            style: AppTypography.titleSm.copyWith(
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Done'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
        return;
      }
    }

    // Direct personal ledger settlement
    if (unsettledLedger.isNotEmpty) {
      for (final e in unsettledLedger) {
        await ref.read(personalLedgerProvider.notifier).settleDebt(e.id);
      }
      _triggerToast('All personal debts settled!');
    }
  }
}

/// Headless bottom sheet popped on native Android back double-tap
class _QuickAddModalContent extends StatefulWidget {
  final String currentUserId;
  final WidgetRef ref;

  const _QuickAddModalContent({
    required this.currentUserId,
    required this.ref,
  });

  @override
  State<_QuickAddModalContent> createState() => _QuickAddModalContentState();
}

class _QuickAddModalContentState extends State<_QuickAddModalContent> {
  final _amountController = TextEditingController();
  final _friendController = TextEditingController();
  final _descController = TextEditingController(text: 'Quick Back-Tap Entry');
  bool _theyOweMe = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _friendController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
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
                Row(
                  children: [
                    Text('Quick Personal Ledger', style: AppTypography.titleSm),
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Hero Floating Amount
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹ ',
                    style: AppTypography.displayHeroMobile.copyWith(
                      color: AppColors.primaryContainer,
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTypography.displayHeroMobile,
                      cursorColor: AppColors.primaryContainer,
                      decoration: InputDecoration(
                        hintText: '0.00',
                        hintStyle: AppTypography.displayHeroMobile.copyWith(
                          color: AppColors.subtleGray,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Friend Name Input
            TextField(
              controller: _friendController,
              style: AppTypography.bodyLg,
              cursorColor: AppColors.primaryContainer,
              decoration: InputDecoration(
                hintText: "Friend's Name / Handle",
                hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.subtleGray),
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.outline),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),

            // Description Input
            TextField(
              controller: _descController,
              style: AppTypography.bodyLg,
              cursorColor: AppColors.primaryContainer,
              decoration: InputDecoration(
                hintText: 'Description',
                hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.subtleGray),
                prefixIcon: const Icon(Icons.edit_note, color: AppColors.outline),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 20),

            // Toggle Pill: "They owe me" vs "I owe them"
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _theyOweMe = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _theyOweMe ? AppColors.primaryContainer : AppColors.chipBackground,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'They owe me',
                        style: TextStyle(
                          color: _theyOweMe ? AppColors.onPrimaryFixed : AppColors.onSurface,
                          fontWeight: _theyOweMe ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _theyOweMe = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_theyOweMe ? AppColors.primaryContainer : AppColors.chipBackground,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'I owe them',
                        style: TextStyle(
                          color: !_theyOweMe ? AppColors.onPrimaryFixed : AppColors.onSurface,
                          fontWeight: !_theyOweMe ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Submit Button
            ElevatedButton(
              onPressed: _isSaving ? null : _savePersonalEntry,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save to Ledger'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _savePersonalEntry() async {
    final amount = double.tryParse(_amountController.text.trim());
    final friend = _friendController.text.trim();
    final desc = _descController.text.trim();

    if (amount == null || amount <= 0 || friend.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount and friend name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final creditor = _theyOweMe ? widget.currentUserId : friend;
    final debtor = _theyOweMe ? friend : widget.currentUserId;

    // Writes optimistically to local SQLite database & queues for Supabase sync!
    await widget.ref.read(personalLedgerProvider.notifier).recordDebt(
          creditorId: creditor,
          debtorId: debtor,
          amount: amount,
          description: desc.isEmpty ? 'Quick Tap Entry' : desc,
        );

    setState(() => _isSaving = false);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to personal ledger (queued locally)')),
      );
    }
  }
}
