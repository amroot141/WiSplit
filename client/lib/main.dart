import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/hardware/back_tap_channel.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/activity_screen.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/balances_screen.dart';
import 'presentation/screens/groups_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/widgets/quick_ledger_dialog.dart';

import 'dart:async';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('WiSplit FlutterError: ${details.exception}');
    };
    runApp(const ProviderScope(child: WiSplitApp()));
  }, (error, stackTrace) {
    debugPrint('WiSplit Unhandled Error: $error\n$stackTrace');
  });
}

class WiSplitApp extends ConsumerStatefulWidget {
  const WiSplitApp({super.key});

  @override
  ConsumerState<WiSplitApp> createState() => _WiSplitAppState();
}

class _WiSplitAppState extends ConsumerState<WiSplitApp> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    // Native Android hardware gesture MethodChannel listener
    try {
      BackTapChannel.initialize(
        onTrigger: () {
          final ctx = rootNavigatorKey.currentContext;
          final session = ref.read(userSessionProvider).value;
          if (ctx != null && session != null) {
            HomeScreen.showQuickAddModal(ctx, currentUserId: session.userId);
          }
        },
      );
    } catch (e) {
      debugPrint('BackTapChannel initialization skipped: $e');
    }
  }

  @override
  void dispose() {
    BackTapChannel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(userSessionProvider);

    return MaterialApp(
      title: 'WiSplit',
      theme: AppTheme.darkTheme,
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      home: sessionAsync.when(
        loading: () => Scaffold(
          backgroundColor: AppColors.surface,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/wisplit_logo.png',
                    width: 64,
                    height: 64,
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.primaryContainer,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        error: (_, __) => AuthScreen(
          onAuthenticated: () {
            ref.read(userSessionProvider.notifier).checkSavedSession();
          },
        ),
        data: (session) {
          if (session == null || !session.isLoggedIn) {
            return AuthScreen(
              onAuthenticated: () {
                ref.read(userSessionProvider.notifier).checkSavedSession();
              },
            );
          }

          final currentUserId = session.userId;
          final screens = [
            HomeScreen(currentUserId: currentUserId),
            GroupsScreen(currentUserId: currentUserId),
            const ActivityScreen(),
            BalancesScreen(currentUserId: currentUserId),
          ];

          return Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.9),
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.receipt_long, 'Expenses'),
                      _buildNavItem(1, Icons.group, 'Groups'),
                      _buildNavItem(2, Icons.analytics, 'Activity'),
                      _buildNavItem(3, Icons.account_balance_wallet, 'Balances'),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: isSelected ? AppColors.primaryContainer : AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.primaryContainer : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
