import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/hardware/back_tap_channel.dart';
import '../../core/services/import_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/group_model.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/group_list_provider.dart';
import '../providers/personal_ledger_provider.dart';
import '../providers/sync_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Gesture trigger preferences (Back Double Tap, Back Triple Tap, Shake, Power Triple Tap)
  String _selectedGesture = 'BACK_DOUBLE_TAP';
  String _selectedSensitivity = 'MEDIUM';

  static const List<Map<String, String>> _avatarPresets = [
    {'name': 'Taro Lavender', 'color': '0xFFBFA2FA', 'emoji': '⚡'},
    {'name': 'Emerald Obsidian', 'color': '0xFF10B981', 'emoji': '💎'},
    {'name': 'Cyber Gold', 'color': '0xFFF59E0B', 'emoji': '🪙'},
    {'name': 'Neon Coral', 'color': '0xFFF43F5E', 'emoji': '🔥'},
    {'name': 'Electric Azure', 'color': '0xFF3B82F6', 'emoji': '🌐'},
    {'name': 'Minimalist Monolith', 'color': '0xFFE2E8F0', 'emoji': '🪐'},
  ];

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(userSessionProvider);
    final user = sessionAsync.value;
    final groups = ref.watch(groupListProvider);
    final ledgerState = ref.watch(personalLedgerProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    final currentUserId = user?.userId ?? 'local-user';
    final userName = user?.fullName ?? 'WiSplit User';
    final userEmail = user?.email ?? 'user@wisplit.app';
    final netBalance = ledgerState.netBalance(currentUserId);
    final avatar = user?.avatarUrl;

    final initials = userName.isNotEmpty
        ? userName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'WS';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text('Profile & Settings', style: AppTypography.titleSm),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── User Identity Hero Card ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // Profile Picture with Tap to Change Avatar
                  GestureDetector(
                    onTap: () => _showAvatarPicker(context),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primaryContainer,
                          child: avatar != null && avatar.startsWith('0x')
                              ? Text(
                                  _avatarPresets.firstWhere(
                                    (p) => p['color'] == avatar,
                                    orElse: () => {'emoji': '⚡'},
                                  )['emoji']!,
                                  style: const TextStyle(fontSize: 32),
                                )
                              : Text(
                                  initials,
                                  style: AppTypography.headlineMd.copyWith(
                                    color: AppColors.onPrimaryFixed,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 14, color: AppColors.primaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    userName,
                    style: AppTypography.headlineMd.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                  ),
                  const SizedBox(height: 12),

                  // User ID Pill with Copy
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: currentUserId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Account ID copied to clipboard')),
                      );
                    },
                    borderRadius: BorderRadius.circular(9999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.fingerprint, size: 14, color: AppColors.primaryContainer),
                          const SizedBox(width: 6),
                          Text(
                            currentUserId.length > 18
                                ? '${currentUserId.substring(0, 8)}...${currentUserId.substring(currentUserId.length - 6)}'
                                : currentUserId,
                            style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy, size: 12, color: AppColors.outline),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Financial Overview Stats (INR ₹) ────────────────────────────
            Row(
              children: [
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
                        Text('NET BALANCE', style: AppTypography.labelSm),
                        const SizedBox(height: 6),
                        Text(
                          '₹${netBalance.toStringAsFixed(2)}',
                          style: AppTypography.titleSm.copyWith(
                            color: netBalance >= 0 ? AppColors.primaryContainer : AppColors.pureWhite,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
                        Text('ACTIVE GROUPS', style: AppTypography.labelSm),
                        const SizedBox(height: 6),
                        Text(
                          '${groups.length} groups',
                          style: AppTypography.titleSm.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Hardware Trigger Customization ──────────────────────────────
            Text(
              'HARDWARE SHORTCUT TRIGGER',
              style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.touch_app, color: AppColors.primaryContainer, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Quick Entry Trigger', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                            Text('Opens quick split modal instantly', style: AppTypography.labelMd.copyWith(color: AppColors.outline)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Gesture Type Picker
                  Text('Trigger Gesture', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildGestureChip('Back 2 Taps', 'BACK_DOUBLE_TAP'),
                      _buildGestureChip('Back 3 Taps', 'BACK_TRIPLE_TAP'),
                      _buildGestureChip('Phone Shake', 'SHAKE'),
                      _buildGestureChip('Power 3 Taps', 'POWER_TRIPLE_TAP'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Sensitivity Adjustment Picker
                  Text('Sensor Sensitivity', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildSensitivityChip('Low', 'LOW'),
                      const SizedBox(width: 8),
                      _buildSensitivityChip('Medium', 'MEDIUM'),
                      const SizedBox(width: 8),
                      _buildSensitivityChip('High', 'HIGH'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Share WiSplit / Invite Friends ──────────────────────────────
            Text(
              'INVITE & SHARE',
              style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.share, color: AppColors.primaryContainer, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Share WiSplit App', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                            Text('Invite friends to split expenses in INR', style: AppTypography.labelMd.copyWith(color: AppColors.outline)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          const ClipboardData(
                            text: 'Split expenses effortlessly with WiSplit: Minimalist offline-first fintech app in INR. Download at https://github.com/amroot141/WiSplit/releases/latest',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('WiSplit invite link copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy App Sharing Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryContainer,
                        side: const BorderSide(color: AppColors.primaryContainer),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Data Management & Import (CSV / XLS) ────────────────────────
            Text(
              'DATA MANAGEMENT & IMPORT',
              style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.file_upload_outlined, color: AppColors.primaryContainer, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Import Expense Sheets', style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                            Text('Supports Excel (.xlsx, .xls) and CSV / TSV', style: AppTypography.labelMd.copyWith(color: AppColors.outline)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _importSheetFromSettings(groups),
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Import File'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimaryFixed,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: ImportService.generateTemplate()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('CSV template copied to clipboard!')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Template'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.outline,
                          side: const BorderSide(color: AppColors.outlineVariant),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Cloud Sync Status ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        syncStatus.isOnline ? Icons.cloud_done : Icons.cloud_off,
                        color: syncStatus.isOnline ? AppColors.primaryContainer : AppColors.outline,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            syncStatus.isOnline ? 'Cloud Synced (Auto-Active)' : 'Offline Local Storage',
                            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            syncStatus.pendingCount > 0
                                ? '${syncStatus.pendingCount} queued for sync'
                                : 'Background auto-sync enabled',
                            style: AppTypography.labelSm.copyWith(color: AppColors.outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: syncStatus.isSyncing
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.sync, color: AppColors.primaryContainer),
                    onPressed: () => ref.read(syncStatusProvider.notifier).triggerSync(),
                    tooltip: 'Sync now',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── About & Links ───────────────────────────────────────────────
            Text(
              'ABOUT & LINKS',
              style: AppTypography.labelSm.copyWith(letterSpacing: 1.5, color: AppColors.outline),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  _buildLinkTile(
                    icon: Icons.code,
                    label: 'GitHub Repository',
                    subtitle: 'github.com/amroot141/WiSplit',
                    url: 'https://github.com/amroot141/WiSplit',
                    isFirst: true,
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                  _buildLinkTile(
                    icon: Icons.download_rounded,
                    label: 'Download Latest APK',
                    subtitle: 'github.com/amroot141/WiSplit/releases',
                    url: 'https://github.com/amroot141/WiSplit/releases/latest',
                    isFirst: false,
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                  _buildLinkTile(
                    icon: Icons.bug_report_outlined,
                    label: 'Report an Issue',
                    subtitle: 'Open a bug report on GitHub',
                    url: 'https://github.com/amroot141/WiSplit/issues/new',
                    isFirst: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'WiSplit v1.0.0 · Open Source · MIT License',
                style: AppTypography.labelSm.copyWith(color: AppColors.outline),
              ),
            ),
            const SizedBox(height: 24),

            // ── Sign Out Button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _confirmSignOut(context, ref),
                icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
                label: Text(
                  'Sign Out',
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureChip(String label, String value) {
    final isSelected = _selectedGesture == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryContainer,
      backgroundColor: AppColors.surfaceContainerHigh,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.onPrimaryFixed : AppColors.onSurface,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
      onSelected: (_) {
        setState(() => _selectedGesture = value);
        _applyTriggerConfig();
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
      side: BorderSide.none,
    );
  }

  Widget _buildSensitivityChip(String label, String value) {
    final isSelected = _selectedSensitivity == value;
    return Expanded(
      child: ChoiceChip(
        label: Center(child: Text(label)),
        selected: isSelected,
        selectedColor: AppColors.primaryContainer,
        backgroundColor: AppColors.surfaceContainerHigh,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.onPrimaryFixed : AppColors.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        onSelected: (_) {
          setState(() => _selectedSensitivity = value);
          _applyTriggerConfig();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
        side: BorderSide.none,
      ),
    );
  }

  void _applyTriggerConfig() {
    BackTapChannel.updateConfig(
      gesture: _selectedGesture,
      sensitivity: _selectedSensitivity,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trigger updated: $_selectedGesture ($_selectedSensitivity sensitivity)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAvatarPicker(BuildContext context) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text('Choose Profile Avatar', style: AppTypography.titleSm),
            const SizedBox(height: 6),
            Text('Select your OLED fintech avatar badge', style: AppTypography.labelMd.copyWith(color: AppColors.outline)),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.0,
              ),
              itemCount: _avatarPresets.length,
              itemBuilder: (context, idx) {
                final preset = _avatarPresets[idx];
                final colorVal = int.parse(preset['color']!);
                return InkWell(
                  onTap: () {
                    ref.read(userSessionProvider.notifier).updateAvatar(preset['color']!);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Avatar updated to ${preset['name']}!')),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Color(colorVal).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color(colorVal), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(preset['emoji']!, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(
                          preset['name']!.split(' ').first,
                          style: AppTypography.labelSm.copyWith(color: Color(colorVal)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        title: Text('Sign Out', style: AppTypography.titleSm),
        content: Text(
          'Are you sure you want to sign out? Your offline records remain securely saved on this device.',
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
              await ref.read(userSessionProvider.notifier).signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _importSheetFromSettings(List<GroupModel> groups) {
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create or join a group first to import expenses into it.')),
      );
      return;
    }

    if (groups.length == 1) {
      _pickAndImportForGroup(groups.first);
      return;
    }

    // Multiple groups: let user select target group
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text('Select Destination Group', style: AppTypography.titleSm),
            const SizedBox(height: 6),
            Text('Choose which group to import expenses into', style: AppTypography.labelMd.copyWith(color: AppColors.outline)),
            const SizedBox(height: 16),
            ...groups.map((g) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: AppColors.surfaceContainerHigh,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.surfaceContainerHighest,
                      child: Icon(Icons.group, color: AppColors.primaryContainer, size: 20),
                    ),
                    title: Text(g.name, style: AppTypography.bodyLg.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text('${g.memberIds.length} members', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _pickAndImportForGroup(g);
                    },
                  ),
                )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndImportForGroup(GroupModel group) async {
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
                'No valid expenses found in file. Supported format: Date, Description, Paid By, Amount',
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
              Text('Import to ${group.name}', style: AppTypography.titleSm),
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
                'Importing will record expenses and direct payments into "${group.name}" with automatic dates/times.',
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
        final requests = ImportService.toExpenseRequests(rows, group.memberIds);
        final notifier = ref.read(groupExpenseNotifierProvider(group.id).notifier);

        await notifier.addExpensesBatch(requests);
        ref.read(allExpensesProvider.notifier).loadAllExpenses();
        ref.read(groupListProvider.notifier).loadGroups();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Imported $expenseCount expense(s) and $paymentCount payment(s) into ${group.name}!'),
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

  Widget _buildLinkTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required String url,
    required bool isFirst,
  }) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open: $url')),
          );
        }
      },
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(20) : Radius.zero,
        bottom: const Radius.circular(0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryContainer, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    subtitle,
                    style: AppTypography.labelSm.copyWith(color: AppColors.outline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 16, color: AppColors.outline),
          ],
        ),
      ),
    );
  }
}
