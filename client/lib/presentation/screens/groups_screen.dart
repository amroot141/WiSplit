import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../providers/group_list_provider.dart';
import '../widgets/create_group_bottom_sheet.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends ConsumerWidget {
  final String currentUserId;

  const GroupsScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupListProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Groups', style: AppTypography.titleSm),
        actions: [
          IconButton(
            onPressed: () => _showJoinGroupDialog(context, ref),
            icon: const Icon(Icons.group_add_outlined, color: AppColors.onSurfaceVariant),
            tooltip: 'Join with Invite Code',
          ),
          IconButton(
            onPressed: () => showCreateGroupBottomSheet(context, currentUserId: currentUserId),
            icon: const Icon(Icons.add, color: AppColors.primaryContainer),
            tooltip: 'Create New Group',
          ),
        ],
      ),
      body: groups.isEmpty
          ? _buildEmptyState(context, ref)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = groups[index];
                final memberCount = group.members.length;

                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupDetailScreen(
                          group: group,
                          currentUserId: currentUserId,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
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
                              width: 46,
                              height: 46,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.group, color: AppColors.primaryContainer, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  group.description.isNotEmpty
                                      ? group.description
                                      : '$memberCount member${memberCount == 1 ? '' : 's'}',
                                  style: AppTypography.labelMd.copyWith(color: AppColors.outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.outline, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_outlined, size: 36, color: AppColors.primaryContainer),
            ),
            const SizedBox(height: 24),
            Text('No Groups Created', style: AppTypography.titleSm),
            const SizedBox(height: 8),
            Text(
              'Create a group for your apartment, road trip, dinner party, or project team to track and simplify shared debts in INR.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(color: AppColors.outline, height: 1.4),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => showCreateGroupBottomSheet(context, currentUserId: currentUserId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create First Group'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showJoinGroupDialog(context, ref),
              icon: const Icon(Icons.qr_code, size: 18),
              label: const Text('Join with Invite Code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryContainer,
                side: const BorderSide(color: AppColors.primaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinGroupDialog(BuildContext context, WidgetRef ref) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Text('Join Group', style: AppTypography.titleSm),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the 6-character group invite code shared by your friend.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              style: AppTypography.bodyLg.copyWith(
                letterSpacing: 2.0,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryContainer,
              ),
              decoration: const InputDecoration(
                hintText: 'e.g. WS-8A9F',
                hintStyle: TextStyle(letterSpacing: 0, color: AppColors.subtleGray),
                prefixIcon: Icon(Icons.vpn_key_outlined, color: AppColors.outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();
              if (code.isEmpty) return;

              Navigator.of(ctx).pop();

              await ref.read(groupListProvider.notifier).createGroup(
                    name: 'Group ($code)',
                    description: 'Joined via invite code $code',
                    currency: 'INR',
                    createdBy: currentUserId,
                    members: [currentUserId],
                  );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Successfully joined group with code $code!')),
                );
              }
            },
            child: const Text('Join Group'),
          ),
        ],
      ),
    );
  }
}
