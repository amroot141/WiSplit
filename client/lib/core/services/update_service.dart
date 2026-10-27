import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class ReleaseInfo {
  final String tagName;
  final String name;
  final String body;
  final String downloadUrl;
  final String htmlUrl;
  final DateTime publishedAt;

  const ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.downloadUrl,
    required this.htmlUrl,
    required this.publishedAt,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    String download = '';
    final assets = json['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      // Find .apk asset first, otherwise use first asset
      final apkAsset = assets.firstWhere(
        (a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.apk'),
        orElse: () => assets.first,
      );
      download = apkAsset['browser_download_url'] as String? ?? '';
    }

    final html = json['html_url'] as String? ?? 'https://github.com/amroot141/WiSplit/releases/latest';

    return ReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? 'New Release',
      body: json['body'] as String? ?? '',
      downloadUrl: download.isNotEmpty ? download : html,
      htmlUrl: html,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class UpdateService {
  // Current app release version
  static const String currentAppVersion = '1.0.9';
  static const String githubRepo = 'amroot141/WiSplit';
  static const String _apiUrl = 'https://api.github.com/repos/$githubRepo/releases/latest';

  static bool _hasCheckedThisSession = false;

  /// Compares semantic versions (e.g., "v1.0.8" vs "1.0.9").
  /// Returns 1 if v1 > v2, -1 if v1 < v2, and 0 if equal.
  static int compareVersions(String v1, String v2) {
    String clean(String v) => v.trim().replaceAll(RegExp(r'^[vV]'), '');
    final parts1 = clean(v1).split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = clean(v2).split('.').map((p) => int.tryParse(p) ?? 0).toList();

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  /// Fetches the latest release info from GitHub API.
  static Future<ReleaseInfo?> fetchLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'WiSplit-Mobile-App',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ReleaseInfo.fromJson(data);
      }
    } catch (_) {
      // Network or timeout errors
    }
    return null;
  }

  /// Silent automatic check on app startup. Shows modal only if update exists.
  static Future<void> checkForUpdatesSilently(BuildContext context) async {
    if (_hasCheckedThisSession) return;
    _hasCheckedThisSession = true;

    final release = await fetchLatestRelease();
    if (release == null || !context.mounted) return;

    if (compareVersions(release.tagName, currentAppVersion) > 0) {
      showUpdateDialog(context, release);
    }
  }

  /// Manual check from Profile / Settings screen.
  static Future<void> checkAndPrompt(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking for updates...'),
        duration: Duration(seconds: 2),
      ),
    );

    final release = await fetchLatestRelease();
    if (!context.mounted) return;

    if (release == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check for updates. Please check your internet connection.'),
        ),
      );
      return;
    }

    if (compareVersions(release.tagName, currentAppVersion) > 0) {
      showUpdateDialog(context, release);
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.primaryContainer, size: 24),
              const SizedBox(width: 10),
              Text('WiSplit is Up to Date', style: AppTypography.titleSm),
            ],
          ),
          content: Text(
            'You are running version v$currentAppVersion. You have the latest features and security updates.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryFixed,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Shows the update dialog with changelog and direct download action.
  static void showUpdateDialog(BuildContext context, ReleaseInfo release) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded, color: AppColors.primaryContainer, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update Available', style: AppTypography.titleSm),
                  Text(
                    '${release.tagName} is now ready',
                    style: AppTypography.labelSm.copyWith(color: AppColors.primaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'What\'s New:',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    release.body.isNotEmpty
                        ? release.body
                        : 'New improvements, bug fixes, and offline performance enhancements.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Current Version: v$currentAppVersion  ➔  Latest: ${release.tagName}',
                  style: AppTypography.labelSm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later', style: TextStyle(color: AppColors.outline)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final uri = Uri.parse(release.downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download APK'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimaryFixed,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
