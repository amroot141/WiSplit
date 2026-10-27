import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/algorithms/debt_simplifier.dart';
import '../../core/services/export_service.dart';
import '../../core/services/import_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/expense_models.dart';
import '../../data/models/group_model.dart';
import '../../data/models/settlement_model.dart';
import '../providers/expense_provider.dart';
import '../providers/group_list_provider.dart';
import '../widgets/add_expense_bottom_sheet.dart';
import '../widgets/record_payment_bottom_sheet.dart';
import 'expense_details_screen.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final GroupModel group;
  final String currentUserId;

  const GroupDetailScreen({
    super.key,
    required this.group,
    required this.currentUserId,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupExpenseNotifierProvider(widget.group.id));

    // Calculate total expenses for this group in INR
    final totalSpent = groupState.expenses.fold<double>(
      0.0,
      (sum, e) => sum + e.amount,
    );

    final members = widget.group.members.isNotEmpty
        ? widget.group.members
        : [widget.currentUserId];

    // Calculate offline debt simplification (who owes whom)
    final settlements = DebtSimplifier.calculateSimplifiedDebts(
      expenses: groupState.expenses,
      allMembers: members,
    );

    // Calculate current user's financial standing in this group
    final memberBreakdown = DebtSimplifier.calculateMemberBreakdown(
      expenses: groupState.expenses,
      allMembers: members,
    );
    final mySummary = memberBreakdown[widget.currentUserId];
    final myPaid = mySummary?.totalPaid ?? 0.0;
    final myShare = mySummary?.totalShare ?? 0.0;
    final myNet = mySummary?.netBalance ?? 0.0;

    final inviteCode = 'WS-${widget.group.id.length >= 6 ? widget.group.id.substring(0, 6).toUpperCase() : widget.group.id.toUpperCase()}';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.group.name, style: AppTypography.titleSm),
        actions: [
          // Import from CSV / XLS
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: AppColors.primaryContainer),
            tooltip: 'Import from CSV / XLS',
            onPressed: () => _importFromFile(members),
          ),
          // Export to CSV / Report
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: AppColors.primaryContainer),
            tooltip: 'Export CSV / Report',
            onPressed: () => _showExportOptions(context, groupState.expenses, settlements),
          ),
          // Delete Group
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Delete Group',
            onPressed: () => _confirmDeleteGroup(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Group Spending & Net Balance Hero ───────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL GROUP SPEND',
                        style: AppTypography.labelSm.copyWith(
                          letterSpacing: 2.0,
                          color: AppColors.outline,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          '${members.length} members',
                          style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${totalSpent.toStringAsFixed(2)}',
                    style: AppTypography.displayHeroMobile.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User's Personal Breakdown Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('You Paid', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                            const SizedBox(height: 2),
                            Text('₹${myPaid.toStringAsFixed(2)}', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Share', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                            const SizedBox(height: 2),
                            Text('₹${myShare.toStringAsFixed(2)}', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Your Net', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                            const SizedBox(height: 2),
                            Text(
                              myNet >= 0
                                  ? '+₹${myNet.toStringAsFixed(2)}'
                                  : '-₹${(-myNet).toStringAsFixed(2)}',
                              style: AppTypography.bodyLg.copyWith(
                                color: myNet >= 0 ? AppColors.primaryContainer : AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // View Member Breakdown Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _showMemberBreakdownModal(context, memberBreakdown),
                      icon: const Icon(Icons.pie_chart_outline, size: 16, color: AppColors.primaryContainer),
                      label: Text(
                        'View All Member Balances',
                        style: AppTypography.labelMd.copyWith(color: AppColors.primaryContainer),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Group Invite Code & Share Link Card ─────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_2, color: AppColors.primaryContainer, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Group Invite Code', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                        const SizedBox(height: 2),
                        Text(
                          inviteCode,
                          style: AppTypography.bodyLg.copyWith(
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: AppColors.outline),
                    tooltip: 'Copy Invite Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invite code $inviteCode copied to clipboard!')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, size: 18, color: AppColors.primaryContainer),
                    tooltip: 'Share Invite Link',
                    onPressed: () {
                      final shareText = 'Join my group "${widget.group.name}" on WiSplit! Use Invite Code: $inviteCode. Download the app at https://github.com/amroot141/WiSplit/releases/latest';
                      Clipboard.setData(ClipboardData(text: shareText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Group invite link copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Suggested Payments ("Who Owes Whom") ────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SUGGESTED PAYMENTS (WHO OWES WHOM)',
                  style: AppTypography.labelSm.copyWith(
                    letterSpacing: 1.5,
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${settlements.length} payments',
                  style: AppTypography.labelSm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (settlements.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.primaryContainer, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All balances are settled! Nobody owes anyone in this group.',
                        style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...settlements.map((s) {
                final isMeDebtor = s.fromUserId == widget.currentUserId;
                final isMeCreditor = s.toUserId == widget.currentUserId;
                final displayNameDebtor = isMeDebtor ? 'You' : s.fromUserId;
                final displayNameCreditor = isMeCreditor ? 'You' : s.toUserId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(18),
                    border: isMeDebtor
                        ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
                        : (isMeCreditor ? Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.3)) : null),
                  ),
                  child: Row(
                    children: [
                      // Status Avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isMeDebtor
                            ? AppColors.errorContainer.withValues(alpha: 0.4)
                            : AppColors.primaryContainer.withValues(alpha: 0.2),
                        child: Icon(
                          isMeDebtor ? Icons.arrow_outward : Icons.arrow_downward,
                          size: 18,
                          color: isMeDebtor ? AppColors.error : AppColors.primaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Debt detail
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$displayNameDebtor owes $displayNameCreditor',
                              style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${s.amount.toStringAsFixed(2)}',
                              style: AppTypography.titleSm.copyWith(
                                color: isMeDebtor ? AppColors.error : AppColors.primaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action Button (Pay / Settle / Remind)
                      if (isMeDebtor)
                        ElevatedButton(
                          onPressed: () => _openPaymentDialog(context, s),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimaryFixed,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text('Pay (UPI)'),
                        )
                      else if (isMeCreditor)
                        OutlinedButton(
                          onPressed: () => _openRequestPaymentDialog(context, s),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryContainer,
                            side: const BorderSide(color: AppColors.primaryContainer),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text('Request'),
                        )
                      else
                        TextButton(
                          onPressed: () => _recordSettlementExpense(context, s),
                          child: const Text('Settle', style: TextStyle(color: AppColors.outline)),
                        ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 28),

            // ── Action Buttons: Add Expense + Record Payment ────────────────
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showAddExpenseBottomSheet(
                        context,
                        groupId: widget.group.id,
                        currentUserId: widget.currentUserId,
                        groupMemberIds: members,
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Expense'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimaryFixed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showRecordPaymentBottomSheet(
                        context,
                        groupId: widget.group.id,
                        currentUserId: widget.currentUserId,
                        groupMemberIds: members,
                      );
                    },
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Record Payment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryContainer,
                      side: const BorderSide(color: AppColors.primaryContainer),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Real Group Expenses Feed ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EXPENSES (${groupState.expenses.length})',
                  style: AppTypography.labelSm.copyWith(letterSpacing: 1.5),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (groupState.expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text(
                    'No expenses recorded in this group yet.\nTap "+ Add Expense" to record your first shared expense.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                  ),
                ),
              )
            else
              ...groupState.expenses.map((exp) {
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExpenseDetailsScreen(
                          expense: exp,
                          currentUserId: widget.currentUserId,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exp.description,
                                style: AppTypography.bodyLg,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Paid by ${exp.paidBy} • ${exp.splitType.name.toLowerCase()} • ${exp.createdAt.day}/${exp.createdAt.month}/${exp.createdAt.year} ${exp.createdAt.hour.toString().padLeft(2, '0')}:${exp.createdAt.minute.toString().padLeft(2, '0')}',
                                style: AppTypography.labelMd.copyWith(color: AppColors.outline),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '₹${exp.amount.toStringAsFixed(2)}',
                              style: AppTypography.titleSm.copyWith(
                                color: AppColors.pureWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.outline),
                              tooltip: 'Delete Expense',
                              onPressed: () => _confirmDeleteExpense(context, exp),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── Payment Dialog (UPI Intent or Settle) ──────────────────────────────────
  void _openPaymentDialog(BuildContext context, DebtSettlement settlement) {
    final upiIdController = TextEditingController(text: '${settlement.toUserId}@upi');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
            Text('Pay Suggested Settlement', style: AppTypography.titleSm),
            const SizedBox(height: 6),
            Text(
              'Pay ₹${settlement.amount.toStringAsFixed(2)} to ${settlement.toUserId}',
              style: AppTypography.bodyMd.copyWith(color: AppColors.primaryContainer, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),

            // UPI ID field
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: upiIdController,
                style: AppTypography.bodyLg,
                decoration: const InputDecoration(
                  labelText: 'Recipient UPI ID',
                  labelStyle: TextStyle(color: AppColors.outline),
                  prefixIcon: Icon(Icons.account_balance_wallet, color: AppColors.primaryContainer),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Button 1: Copy UPI Payment Link / Open UPI
            ElevatedButton.icon(
              onPressed: () {
                final upiString = 'upi://pay?pa=${upiIdController.text.trim()}&pn=${settlement.toUserId}&am=${settlement.amount.toStringAsFixed(2)}&cu=INR';
                Clipboard.setData(ClipboardData(text: upiString));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('UPI payment intent copied for ${settlement.toUserId}! You can paste in GPay, PhonePe, or Paytm.'),
                    action: SnackBarAction(
                      label: 'Record Settled',
                      onPressed: () => _recordSettlementExpense(context, settlement),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.bolt),
              label: const Text('Pay via UPI / Copy UPI Link'),
            ),
            const SizedBox(height: 12),

            // Button 2: Mark as Settled directly
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _recordSettlementExpense(context, settlement);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Mark as Settled (Paid in Cash/UPI)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryContainer,
                side: const BorderSide(color: AppColors.primaryContainer),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Request Payment Dialog ────────────────────────────────────────────────
  void _openRequestPaymentDialog(BuildContext context, DebtSettlement settlement) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
            Text('Request Payment', style: AppTypography.titleSm),
            const SizedBox(height: 6),
            Text(
              '${settlement.fromUserId} owes you ₹${settlement.amount.toStringAsFixed(2)}',
              style: AppTypography.bodyMd.copyWith(color: AppColors.primaryContainer),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () {
                final message = 'Hey ${settlement.fromUserId}, please settle ₹${settlement.amount.toStringAsFixed(2)} for our group "${widget.group.name}" on WiSplit.';
                Clipboard.setData(ClipboardData(text: message));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment reminder copied! Ready to paste into WhatsApp/Messages.')),
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Copy Reminder Message'),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _recordSettlementExpense(context, settlement);
              },
              icon: const Icon(Icons.check),
              label: const Text('Mark as Received / Settled'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryContainer,
                side: const BorderSide(color: AppColors.primaryContainer),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Record Balancing Settlement in Group ──────────────────────────────────
  Future<void> _recordSettlementExpense(BuildContext context, DebtSettlement settlement) async {
    final request = CreateExpenseRequest(
      paidBy: settlement.fromUserId,
      amount: settlement.amount,
      currency: 'INR',
      description: 'Settlement: ${settlement.fromUserId} → ${settlement.toUserId}',
      splitType: SplitType.EXACT,
      splits: [
        SplitItemInput(userId: settlement.toUserId, amount: settlement.amount),
      ],
    );

    await ref.read(groupExpenseNotifierProvider(widget.group.id).notifier).addExpense(request);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settlement of ₹${settlement.amount.toStringAsFixed(2)} recorded successfully!'),
        ),
      );
    }
  }

  // ── Export Options Modal (CSV / Text / PDF Summary) ────────────────────────
  void _showExportOptions(
    BuildContext context,
    List<Expense> expenses,
    List<DebtSettlement> settlements,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
            Text('Export Group Data', style: AppTypography.titleSm),
            const SizedBox(height: 6),
            Text('Export expenses, splits, and suggested settlements in INR', style: AppTypography.labelMd.copyWith(color: AppColors.outline)),
            const SizedBox(height: 24),

            // Option 1: CSV Export
            ListTile(
              tileColor: AppColors.surfaceContainerHigh,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.table_chart, color: AppColors.primaryContainer),
              title: const Text('Export to CSV (Spreadsheet / Excel)'),
              subtitle: const Text('RFC-4180 CSV for Google Sheets, Excel, or Numbers'),
              trailing: const Icon(Icons.copy, size: 18, color: AppColors.outline),
              onTap: () {
                final csv = ExportService.generateCsv(
                  group: widget.group,
                  expenses: expenses,
                  settlements: settlements,
                );
                Clipboard.setData(ClipboardData(text: csv));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('CSV data copied to clipboard! Ready to paste into Excel or Google Sheets.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Option 2: Summary Report (Text / PDF ready)
            ListTile(
              tileColor: AppColors.surfaceContainerHigh,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.description, color: AppColors.primaryContainer),
              title: const Text('Export Summary Report (PDF / Text)'),
              subtitle: const Text('Formatted readable breakdown with settlement plan'),
              trailing: const Icon(Icons.copy, size: 18, color: AppColors.outline),
              onTap: () {
                final summary = ExportService.generateSummaryReport(
                  group: widget.group,
                  expenses: expenses,
                  settlements: settlements,
                );
                Clipboard.setData(ClipboardData(text: summary));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Summary report copied to clipboard! Ready to paste, print, or share.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Member Breakdown Modal ────────────────────────────────────────────────
  void _showMemberBreakdownModal(
    BuildContext context,
    Map<String, MemberFinancialSummary> breakdown,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
            Text('Group Member Balances', style: AppTypography.titleSm),
            const SizedBox(height: 16),

            ...breakdown.values.map((m) {
              final isMe = m.userId == widget.currentUserId;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? '${m.userId} (You)' : m.userId,
                          style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Paid: ₹${m.totalPaid.toStringAsFixed(2)} • Share: ₹${m.totalShare.toStringAsFixed(2)}',
                          style: AppTypography.labelSm.copyWith(color: AppColors.outline),
                        ),
                      ],
                    ),
                    Text(
                      m.netBalance >= 0
                          ? '+₹${m.netBalance.toStringAsFixed(2)}'
                          : '-₹${(-m.netBalance).toStringAsFixed(2)}',
                      style: AppTypography.titleSm.copyWith(
                        color: m.netBalance >= 0 ? AppColors.primaryContainer : AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteExpense(BuildContext context, Expense exp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Text('Delete Expense', style: AppTypography.titleSm),
        content: Text(
          'Are you sure you want to delete "${exp.description}"?',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(groupExpenseNotifierProvider(widget.group.id).notifier)
                  .deleteExpense(exp.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Expense "${exp.description}" deleted')),
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

  void _confirmDeleteGroup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Text('Delete Group', style: AppTypography.titleSm),
        content: Text(
          'Are you sure you want to delete "${widget.group.name}"? This action cannot be undone.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
              await ref.read(groupListProvider.notifier).deleteGroup(widget.group.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromFile(List<String> members) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ImportService.supportedExtensions,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file data')),
          );
        }
        return;
      }

      final rows = await ImportService.parseFileBytes(bytes, file.name);

      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No valid expenses found. Supported format: Date, Description, Paid By, Amount',
              ),
            ),
          );
        }
        return;
      }

      final totalSum = rows.fold<double>(0.0, (sum, r) => sum + r.amount);
      final paymentCount = rows.where((r) => r.isPayment).length;
      final expenseCount = rows.length - paymentCount;

      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.file_upload_outlined, color: AppColors.primaryContainer),
              const SizedBox(width: 10),
              Text('Import Records', style: AppTypography.titleSm),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${rows.length} record(s) in "${file.name}":',
                style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (expenseCount > 0)
                Text(
                  '• $expenseCount Expense(s)',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                ),
              if (paymentCount > 0)
                Text(
                  '• $paymentCount Payment(s)',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.primaryContainer, fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 8),
              Text(
                'Total Volume: ₹${totalSum.toStringAsFixed(2)}',
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Expenses and payments will be allocated to group members and balances recalculated automatically.',
                style: AppTypography.labelMd.copyWith(color: AppColors.outline),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryFixed,
              ),
              child: Text('Import (${rows.length})'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final requests = ImportService.toExpenseRequests(rows, members);
        final notifier = ref.read(groupExpenseNotifierProvider(widget.group.id).notifier);

        await notifier.addExpensesBatch(requests);
        ref.read(allExpensesProvider.notifier).loadAllExpenses();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported $expenseCount expense(s) and $paymentCount payment(s) into ${widget.group.name}!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }
}

