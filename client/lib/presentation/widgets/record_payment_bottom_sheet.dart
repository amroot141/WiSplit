import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/expense_models.dart';
import '../providers/expense_provider.dart';

/// Shows a bottom sheet to record a direct payment between two group members.
/// Shows a bottom sheet to record or edit a direct payment between two group members.
/// e.g., "A paid B ₹300"
Future<void> showRecordPaymentBottomSheet(
  BuildContext context, {
  required String groupId,
  required String currentUserId,
  required List<String> groupMemberIds,
  Expense? existingPayment,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => RecordPaymentContent(
      groupId: groupId,
      currentUserId: currentUserId,
      groupMemberIds: groupMemberIds,
      existingPayment: existingPayment,
    ),
  );
}

class RecordPaymentContent extends ConsumerStatefulWidget {
  final String groupId;
  final String currentUserId;
  final List<String> groupMemberIds;
  final Expense? existingPayment;

  const RecordPaymentContent({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.groupMemberIds,
    this.existingPayment,
  });

  @override
  ConsumerState<RecordPaymentContent> createState() => _RecordPaymentContentState();
}

class _RecordPaymentContentState extends ConsumerState<RecordPaymentContent> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  late String _fromUser;
  late String _toUser;
  late DateTime _paymentDate;
  late TimeOfDay _paymentTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPayment;
    if (p != null) {
      _amountController.text = p.amount.toStringAsFixed(2);
      _fromUser = p.paidBy;
      _toUser = p.splits.isNotEmpty
          ? p.splits.first.userId
          : widget.groupMemberIds.firstWhere((m) => m != p.paidBy, orElse: () => p.paidBy);
      _paymentDate = p.createdAt;
      _paymentTime = TimeOfDay.fromDateTime(p.createdAt);

      // Extract note from description e.g. "Payment: A → B (Dinner note)"
      final noteMatch = RegExp(r'\((.*?)\)').firstMatch(p.description);
      if (noteMatch != null) {
        _noteController.text = noteMatch.group(1) ?? '';
      }
    } else {
      _fromUser = widget.currentUserId;
      _toUser = widget.groupMemberIds.firstWhere(
        (m) => m != widget.currentUserId,
        orElse: () => widget.currentUserId,
      );
      _paymentDate = DateTime.now();
      _paymentTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
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

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.existingPayment != null ? 'Edit Payment' : 'Record Payment',
                        style: AppTypography.titleSm,
                      ),
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
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Hero Amount Input
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹ ',
                        style: AppTypography.displayHeroMobile.copyWith(
                          fontSize: 34,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: AppTypography.displayHeroMobile.copyWith(fontSize: 34),
                          cursorColor: AppColors.primaryContainer,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: AppTypography.displayHeroMobile.copyWith(
                              fontSize: 34,
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
              ),
              const SizedBox(height: 20),

              // Optional note
              TextField(
                controller: _noteController,
                style: AppTypography.bodyLg,
                cursorColor: AppColors.primaryContainer,
                decoration: InputDecoration(
                  hintText: 'Payment note (optional)',
                  hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.subtleGray),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.notes, color: AppColors.outline, size: 24),
                ),
              ),
              const SizedBox(height: 24),

              // ── FROM (Payer) ──────────────────────────────────────────────
              Text(
                'FROM (PAYER)',
                style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: widget.groupMemberIds.map((member) {
                    final isSelected = _fromUser == member;
                    final displayName = member == widget.currentUserId ? 'You' : member;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(displayName),
                        selected: isSelected,
                        selectedColor: AppColors.primaryContainer,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.onPrimaryFixed : AppColors.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        onSelected: (_) => setState(() => _fromUser = member),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                        side: BorderSide.none,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Arrow indicator
              Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_downward, color: AppColors.primaryContainer, size: 20),
                ),
              ),
              const SizedBox(height: 12),

              // ── TO (Receiver) ─────────────────────────────────────────────
              Text(
                'TO (RECEIVER)',
                style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: widget.groupMemberIds.where((m) => m != _fromUser).map((member) {
                    final isSelected = _toUser == member;
                    final displayName = member == widget.currentUserId ? 'You' : member;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(displayName),
                        selected: isSelected,
                        selectedColor: AppColors.primaryContainer,
                        backgroundColor: AppColors.surfaceContainerHigh,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.onPrimaryFixed : AppColors.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        onSelected: (_) => setState(() => _toUser = member),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                        side: BorderSide.none,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // ── Date & Time Picker ────────────────────────────────────────
              Text(
                'PAYMENT DATE & TIME',
                style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: AppColors.primaryContainer),
                            const SizedBox(width: 10),
                            Text(
                              '${_paymentDate.day}/${_paymentDate.month}/${_paymentDate.year}',
                              style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: AppColors.primaryContainer),
                            const SizedBox(width: 10),
                            Text(
                              _paymentTime.format(context),
                              style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Summary Preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments, color: AppColors.primaryContainer, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_fromUser == widget.currentUserId ? "You" : _fromUser} paid ${_toUser == widget.currentUserId ? "You" : _toUser} ₹${_amountController.text.isEmpty ? "0.00" : _amountController.text}',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.primaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Confirm Button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitPayment,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(widget.existingPayment != null ? 'Save Changes' : 'Confirm Payment'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryContainer,
            surface: AppColors.surfaceContainerLow,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _paymentTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryContainer,
            surface: AppColors.surfaceContainerLow,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _paymentTime = picked);
    }
  }

  Future<void> _submitPayment() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a payment amount')),
      );
      return;
    }

    if (_fromUser == _toUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payer and receiver cannot be the same person')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final note = _noteController.text.trim();
    final fromDisplay = _fromUser == widget.currentUserId ? 'You' : _fromUser;
    final toDisplay = _toUser == widget.currentUserId ? 'You' : _toUser;
    final description = note.isNotEmpty
        ? 'Payment: $fromDisplay → $toDisplay ($note)'
        : 'Payment: $fromDisplay → $toDisplay';

    final combinedDateTime = DateTime(
      _paymentDate.year,
      _paymentDate.month,
      _paymentDate.day,
      _paymentTime.hour,
      _paymentTime.minute,
    );

    final request = CreateExpenseRequest(
      paidBy: _fromUser,
      amount: amount,
      currency: 'INR',
      description: description,
      splitType: SplitType.EXACT,
      splits: [
        SplitItemInput(userId: _toUser, amount: amount),
      ],
      createdAt: combinedDateTime,
    );

    final notifier = ref.read(groupExpenseNotifierProvider(widget.groupId).notifier);
    if (widget.existingPayment != null) {
      await notifier.updateExpense(widget.existingPayment!.id, request);
    } else {
      await notifier.addExpense(request);
    }

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingPayment != null
                ? 'Payment updated successfully!'
                : 'Payment of ₹${amount.toStringAsFixed(2)} from $fromDisplay to $toDisplay recorded!',
          ),
        ),
      );
    }
  }
}
