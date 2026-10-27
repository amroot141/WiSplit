import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../providers/group_list_provider.dart';

Future<void> showCreateGroupBottomSheet(
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
    builder: (ctx) => CreateGroupBottomSheetContent(currentUserId: currentUserId),
  );
}

class CreateGroupBottomSheetContent extends ConsumerStatefulWidget {
  final String currentUserId;

  const CreateGroupBottomSheetContent({super.key, required this.currentUserId});

  @override
  ConsumerState<CreateGroupBottomSheetContent> createState() =>
      _CreateGroupBottomSheetContentState();
}

class _CreateGroupBottomSheetContentState
    extends ConsumerState<CreateGroupBottomSheetContent> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _memberController = TextEditingController();
  final List<String> _members = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _addMember() {
    final text = _memberController.text.trim();
    if (text.isNotEmpty && !_members.contains(text)) {
      setState(() {
        _members.add(text);
        _memberController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                Text('Create New Group', style: AppTypography.titleSm),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameController,
              style: AppTypography.headlineMd,
              cursorColor: AppColors.primaryContainer,
              decoration: InputDecoration(
                hintText: 'Group Name',
                hintStyle: AppTypography.headlineMd.copyWith(color: AppColors.subtleGray),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descController,
              style: AppTypography.bodyLg,
              cursorColor: AppColors.primaryContainer,
              decoration: InputDecoration(
                hintText: 'Description (optional)',
                hintStyle: AppTypography.bodyLg.copyWith(color: AppColors.subtleGray),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.subject, color: AppColors.outline),
              ),
            ),
            const SizedBox(height: 24),

            Text('GROUP MEMBERS', style: AppTypography.labelSm.copyWith(letterSpacing: 1.5)),
            const SizedBox(height: 10),

            if (_members.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._members.map((m) {
                    return Chip(
                      label: Text(m, style: AppTypography.bodyMd),
                      onDeleted: () => setState(() => _members.remove(m)),
                      deleteIconColor: AppColors.outline,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _memberController,
                    style: AppTypography.bodyMd,
                    cursorColor: AppColors.primaryContainer,
                    decoration: InputDecoration(
                      hintText: 'Enter member name',
                      hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.subtleGray),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _addMember(),
                  ),
                ),
                IconButton(
                  onPressed: _addMember,
                  icon: const Icon(Icons.add_circle, color: AppColors.primaryContainer),
                  tooltip: 'Add Member',
                ),
              ],
            ),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _isSaving ? null : _saveGroup,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create Group'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _saveGroup() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(groupListProvider.notifier).createGroup(
            name: name,
            description: desc,
            createdBy: widget.currentUserId,
            members: _members,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$name" created!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
