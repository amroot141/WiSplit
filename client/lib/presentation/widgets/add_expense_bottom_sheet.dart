import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/expense_models.dart';
import '../providers/expense_provider.dart';

Future<void> showAddExpenseBottomSheet(
  BuildContext context, {
  required String groupId,
  required String currentUserId,
  required List<String> groupMemberIds,
  Expense? existingExpense,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => AddExpenseBottomSheetContent(
      groupId: groupId,
      currentUserId: currentUserId,
      groupMemberIds: groupMemberIds,
      existingExpense: existingExpense,
    ),
  );
}

class AddExpenseBottomSheetContent extends ConsumerStatefulWidget {
  final String groupId;
  final String currentUserId;
  final List<String> groupMemberIds;
  final Expense? existingExpense;

  const AddExpenseBottomSheetContent({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.groupMemberIds,
    this.existingExpense,
  });

  @override
  ConsumerState<AddExpenseBottomSheetContent> createState() =>
      _AddExpenseBottomSheetContentState();
}

class _AddExpenseBottomSheetContentState
    extends ConsumerState<AddExpenseBottomSheetContent> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  SplitType _splitType = SplitType.EQUAL;
  late String _paidBy;
  late List<String> _allMembers;
  late Set<String> _selectedParticipants;
  bool _isSubmitting = false;

  // Auto-populated date & time (editable)
  late DateTime _expenseDate;
  late TimeOfDay _expenseTime;

  // Custom Split Values per participant
  final Map<String, TextEditingController> _exactControllers = {};
  final Map<String, TextEditingController> _percentageControllers = {};
  final Map<String, int> _shares = {};

  @override
  void initState() {
    super.initState();
    _allMembers = widget.groupMemberIds.isNotEmpty
        ? widget.groupMemberIds
        : [widget.currentUserId];

    final exp = widget.existingExpense;
    if (exp != null) {
      _amountController.text = exp.amount.toStringAsFixed(2);
      _descController.text = exp.description;
      _paidBy = exp.paidBy;
      _splitType = exp.splitType;
      _expenseDate = exp.createdAt;
      _expenseTime = TimeOfDay.fromDateTime(exp.createdAt);
      _selectedParticipants = exp.splits.map((s) => s.userId).toSet();
    } else {
      _paidBy = widget.currentUserId;
      _selectedParticipants = _allMembers.toSet();
      _expenseDate = DateTime.now();
      _expenseTime = TimeOfDay.now();
    }

    // Initialize custom split values
    for (final member in _allMembers) {
      final split = exp?.splits.where((s) => s.userId == member).firstOrNull;
      _exactControllers[member] = TextEditingController(
        text: split != null && split.amount > 0 ? split.amount.toStringAsFixed(2) : '',
      );
      _percentageControllers[member] = TextEditingController(
        text: split?.percentage != null ? split!.percentage!.toStringAsFixed(1) : '',
      );
      _shares[member] = split?.shares?.toInt() ?? 1;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    for (final c in _exactControllers.values) {
      c.dispose();
    }
    for (final c in _percentageControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _totalAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

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
              // Top drag handle
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

              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.existingExpense != null ? 'Edit Expense' : 'Record Split',
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
                          onChanged: (_) => setState(() {}),
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

            // Description Input Field
            TextField(
              controller: _descController,
              style: AppTypography.bodyLg,
              cursorColor: AppColors.primaryContainer,
              decoration: InputDecoration(
                hintText: 'What was this expense for?',
                hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.subtleGray),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.edit_note, color: AppColors.outline, size: 24),
              ),
            ),
            const SizedBox(height: 20),

            // ── Expense Date & Time (auto-populated, editable) ──────────────
            Text(
              'DATE & TIME',
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
                            '${_expenseDate.day}/${_expenseDate.month}/${_expenseDate.year}',
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
                            _expenseTime.format(context),
                            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Who Paid Section ────────────────────────────────────────────
            Text(
              'PAID BY',
              style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _allMembers.map((member) {
                  final isPayer = _paidBy == member;
                  final displayName = member == widget.currentUserId ? 'You' : member;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(displayName),
                      selected: isPayer,
                      selectedColor: AppColors.primaryContainer,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      labelStyle: TextStyle(
                        color: isPayer ? AppColors.onPrimaryFixed : AppColors.onSurface,
                        fontWeight: isPayer ? FontWeight.w600 : FontWeight.w400,
                      ),
                      onSelected: (_) => setState(() => _paidBy = member),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                      side: BorderSide.none,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // ── Split Method Bar ────────────────────────────────────────────
            Text(
              'SPLIT METHOD',
              style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: SplitType.values.map((type) {
                  final isSelected = _splitType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _splitType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryContainer : AppColors.chipBackground,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          type.name,
                          style: AppTypography.labelMd.copyWith(
                            color: isSelected ? AppColors.onPrimaryFixed : AppColors.onSurface,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 28),

            // ── Split Customizer Table (Equal, Exact, Percentage, Shares) ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PARTICIPANTS (${_selectedParticipants.length}/${_allMembers.length})',
                  style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedParticipants.length == _allMembers.length) {
                        _selectedParticipants = {widget.currentUserId};
                      } else {
                        _selectedParticipants = _allMembers.toSet();
                      }
                    });
                  },
                  child: Text(
                    _selectedParticipants.length == _allMembers.length ? 'Select Only Me' : 'Select All',
                    style: AppTypography.labelSm.copyWith(color: AppColors.primaryContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ..._allMembers.map((member) {
              final isIncluded = _selectedParticipants.contains(member);
              final isMe = member == widget.currentUserId;
              final displayName = isMe ? 'You ($member)' : member;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isIncluded ? AppColors.surfaceContainerHigh : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: isIncluded
                      ? Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.3), width: 1)
                      : null,
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isIncluded,
                      activeColor: AppColors.primaryContainer,
                      checkColor: AppColors.onPrimaryFixed,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedParticipants.add(member);
                          } else {
                            if (_selectedParticipants.length > 1) {
                              _selectedParticipants.remove(member);
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyLg.copyWith(
                              fontWeight: isIncluded ? FontWeight.w600 : FontWeight.w400,
                              color: isIncluded ? AppColors.onSurface : AppColors.outline,
                            ),
                          ),
                          if (_splitType == SplitType.EQUAL && isIncluded && _selectedParticipants.isNotEmpty)
                            Text(
                              '₹${(_totalAmount / _selectedParticipants.length).toStringAsFixed(2)}',
                              style: AppTypography.labelSm.copyWith(color: AppColors.primaryContainer),
                            ),
                        ],
                      ),
                    ),

                    // Custom input based on split method
                    if (isIncluded) ...[
                      if (_splitType == SplitType.EXACT)
                        SizedBox(
                          width: 76,
                          child: TextField(
                            controller: _exactControllers[member],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            style: AppTypography.bodyLg.copyWith(color: AppColors.primaryContainer),
                            decoration: const InputDecoration(
                              prefixText: '₹ ',
                              prefixStyle: TextStyle(color: AppColors.outline),
                              hintText: '0.00',
                              hintStyle: TextStyle(color: AppColors.subtleGray),
                              isDense: true,
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.primaryContainer),
                              ),
                            ),
                          ),
                        ),

                      if (_splitType == SplitType.PERCENTAGE)
                        SizedBox(
                          width: 66,
                          child: TextField(
                            controller: _percentageControllers[member],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            style: AppTypography.bodyLg.copyWith(color: AppColors.primaryContainer),
                            decoration: const InputDecoration(
                              suffixText: ' %',
                              suffixStyle: TextStyle(color: AppColors.outline),
                              hintText: '0',
                              hintStyle: TextStyle(color: AppColors.subtleGray),
                              isDense: true,
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: AppColors.primaryContainer),
                              ),
                            ),
                          ),
                        ),

                      if (_splitType == SplitType.SHARES)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                final cur = _shares[member] ?? 1;
                                if (cur > 1) {
                                  setState(() => _shares[member] = cur - 1);
                                }
                              },
                              icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.outline),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              splashRadius: 16,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                '${_shares[member] ?? 1}',
                                style: AppTypography.titleSm.copyWith(color: AppColors.primaryContainer),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                final cur = _shares[member] ?? 1;
                                setState(() => _shares[member] = cur + 1);
                              },
                              icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primaryContainer),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              splashRadius: 16,
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 32),

            // Confirm Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitExpense,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(widget.existingExpense != null ? 'Save Changes' : 'Confirm & Save Split'),
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
      initialDate: _expenseDate,
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
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _expenseTime,
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
      setState(() => _expenseTime = picked);
    }
  }

  Future<void> _submitExpense() async {
    final amount = _totalAmount;
    final description = _descController.text.trim();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an expense amount')),
      );
      return;
    }

    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one participant')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Build splits based on split method
    List<SplitItemInput> splits = [];

    if (_splitType == SplitType.EQUAL) {
      final share = amount / _selectedParticipants.length;
      splits = _selectedParticipants.map((u) => SplitItemInput(userId: u, amount: share)).toList();
    } else if (_splitType == SplitType.EXACT) {
      splits = _selectedParticipants.map((u) {
        final val = double.tryParse(_exactControllers[u]?.text.trim() ?? '') ?? 0.0;
        return SplitItemInput(userId: u, amount: val);
      }).toList();
    } else if (_splitType == SplitType.PERCENTAGE) {
      splits = _selectedParticipants.map((u) {
        final pct = double.tryParse(_percentageControllers[u]?.text.trim() ?? '') ?? 0.0;
        return SplitItemInput(userId: u, percentage: pct, amount: (pct / 100.0) * amount);
      }).toList();
    } else if (_splitType == SplitType.SHARES) {
      final totalShares = _selectedParticipants.fold<int>(0, (sum, u) => sum + (_shares[u] ?? 1));
      splits = _selectedParticipants.map((u) {
        final s = _shares[u] ?? 1;
        return SplitItemInput(
          userId: u,
          shares: s.toDouble(),
          amount: totalShares > 0 ? (s / totalShares) * amount : 0.0,
        );
      }).toList();
    }

    final combinedDateTime = DateTime(
      _expenseDate.year,
      _expenseDate.month,
      _expenseDate.day,
      _expenseTime.hour,
      _expenseTime.minute,
    );

    final request = CreateExpenseRequest(
      paidBy: _paidBy,
      amount: amount,
      currency: 'INR',
      description: description.isEmpty ? 'Group Expense' : description,
      splitType: _splitType,
      splits: splits,
      createdAt: combinedDateTime,
    );

    final notifier = ref.read(groupExpenseNotifierProvider(widget.groupId).notifier);
    Expense? result;
    if (widget.existingExpense != null) {
      result = await notifier.updateExpense(widget.existingExpense!.id, request);
    } else {
      result = await notifier.addExpense(request);
    }

    setState(() => _isSubmitting = false);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingExpense != null
                ? 'Expense updated successfully!'
                : (result != null ? 'Expense recorded!' : 'Expense saved locally (offline queued)'),
          ),
        ),
      );
    }
  }
}
