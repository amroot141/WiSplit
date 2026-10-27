import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/sync_queue_service.dart';
import '../../core/network/network_info.dart';
import 'personal_ledger_provider.dart';

class SyncStatus {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final DateTime? lastSyncTime;

  const SyncStatus({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.lastSyncTime,
  });

  SyncStatus copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    DateTime? lastSyncTime,
  }) {
    return SyncStatus(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfoImpl();
});

final syncStatusProvider = StateNotifierProvider<SyncStatusNotifier, SyncStatus>((ref) {
  final networkInfo = ref.watch(networkInfoProvider);
  final syncQueue = ref.watch(syncQueueServiceProvider);
  return SyncStatusNotifier(ref, networkInfo, syncQueue);
});

class SyncStatusNotifier extends StateNotifier<SyncStatus> {
  final Ref _ref;
  final NetworkInfo _networkInfo;
  final SyncQueueService _syncQueue;
  StreamSubscription<bool>? _networkSubscription;
  Timer? _periodicSyncTimer;

  SyncStatusNotifier(this._ref, this._networkInfo, this._syncQueue)
      : super(const SyncStatus()) {
    _init();
  }

  Future<void> _init() async {
    final online = await _networkInfo.isConnected;
    final count = await _syncQueue.getPendingCount();
    state = state.copyWith(isOnline: online, pendingCount: count);

    // Initial background sync pass if connected
    if (online && count > 0) {
      triggerSync();
    }

    // Auto-sync listener: Trigger queue flush whenever connectivity returns
    _networkSubscription = _networkInfo.onConnectivityChanged.listen((online) async {
      state = state.copyWith(isOnline: online);
      if (online) {
        await triggerSync();
      }
    });

    // Continuous automatic background sync every 30 seconds
    _periodicSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final isConnected = await _networkInfo.isConnected;
      if (isConnected) {
        final pending = await _syncQueue.getPendingCount();
        if (pending > 0 && !state.isSyncing) {
          await triggerSync();
        }
      }
    });
  }

  /// Triggers an automatic or manual sync pass
  Future<void> triggerSync() async {
    if (state.isSyncing) return;
    state = state.copyWith(isSyncing: true);

    try {
      await _syncQueue.processQueue();
      final count = await _syncQueue.getPendingCount();
      state = state.copyWith(
        isSyncing: false,
        pendingCount: count,
        lastSyncTime: DateTime.now(),
      );

      // Refresh personal ledger if active
      _ref.read(personalLedgerProvider.notifier).loadLedger();
    } catch (_) {
      state = state.copyWith(isSyncing: false);
    }
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
}
