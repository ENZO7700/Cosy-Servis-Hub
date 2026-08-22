import 'package:flutter/foundation.dart';

import '../../../core/database/sync_queue_item.dart';
import '../../../core/sync/sync_engine.dart';

/// Provider for managing sync status in the UI
class SyncStatusProvider extends ChangeNotifier {
  final SyncEngine _syncEngine;
  final String? _tenantId;
  final String? _userId;

  final SyncEngineStatus _status = const SyncEngineStatus();
  bool _initialized = false;

  SyncStatusProvider({
    required this._syncEngine,
    this._tenantId,
    this._userId,
  }) {
    _initialize();
  }

  /// Current sync status
  SyncEngineStatus get status => _status;

  /// Whether the sync engine is initialized
  bool get initialized => _initialized;

  /// Whether currently syncing
  bool get isSyncing => _status.isSyncing;

  /// Whether currently online
  bool get isOnline => _status.isOnline;

  /// Count of pending sync items
  int get pendingCount => _status.pendingCount;

  /// Count of processing items
  int get processingCount => _status.processingCount;

  /// Count of failed items
  int get failedCount => _status.failedCount;

  /// Count of conflict items
  int get conflictCount => _status.conflictCount;

  /// Last error message
  String? get lastError => _status.lastError;

  /// Last sync time
  DateTime? get lastSyncTime => _status.lastSyncTime;

  /// Whether there are items needing sync
  bool get hasPendingItems => pendingCount > 0;

  /// Whether sync is blocked (offline)
  bool get isBlocked => !isOnline;

  /// Whether there are errors or conflicts
  bool get hasIssues => failedCount > 0 || conflictCount > 0;

  /// Initialize the provider
  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;
    notifyListeners();
  }

  /// Refresh sync status
  Future<void> refreshStatus() async {
    notifyListeners();
  }

  /// Start sync
  Future<void> sync() async {
    await _syncEngine.sync();
    notifyListeners();
  }

  /// Force sync (ignore connectivity check)
  Future<void> forceSync() async {
    await _syncEngine.forceSync();
    notifyListeners();
  }

  /// Get count of pending items
  Future<int> getPendingCount() async {
    return await _syncEngine.getPendingCount();
  }

  /// Get all pending items
  Future<List<SyncQueueItem>> getPendingItems() async {
    return await _syncEngine.getPendingItems();
  }

  /// Get items by status
  Future<List<SyncQueueItem>> getItemsByStatus(SyncStatus status) async {
    final items = await _syncEngine.getPendingItems();
    return items.where((item) => item.status == status).toList();
  }

  /// Get failed items
  Future<List<SyncQueueItem>> getFailedItems() async {
    return await getItemsByStatus(SyncStatus.failed);
  }

  /// Get conflict items
  Future<List<SyncQueueItem>> getConflictItems() async {
    return await getItemsByStatus(SyncStatus.conflict);
  }

  /// Retry all failed items
  Future<void> retryAllFailed() async {
    final items = await getFailedItems();
    for (final item in items) {
      if (!item.permanentFailure) {
        await _queueResetItem(item);
      }
    }
    notifyListeners();
  }

  /// Retry a specific item
  Future<void> retryItem(String itemId) async {
    final items = await _syncEngine.getPendingItems();
    for (final item in items) {
      if (item.id == itemId && !item.permanentFailure) {
        await _queueResetItem(item);
        break;
      }
    }
    notifyListeners();
  }

  /// Reset item for retry
  Future<void> _queueResetItem(SyncQueueItem item) async {
    await _syncEngine.queueOperation(
      entityType: item.entityType,
      entityId: item.entityId,
      operation: item.operation,
      payload: item.payload,
      tenantId: _tenantId,
      userId: _userId,
      idempotencyKey: item.idempotencyKey,
      entityVersion: item.entityVersion,
      source: item.source,
      priority: item.priority,
    );
  }

  /// Clear all items from queue
  Future<void> clearQueue() async {
    await _syncEngine.clearQueue();
    notifyListeners();
  }

  /// Clear completed items (synced, permanently failed)
  Future<void> clearCompleted() async {
    final items = await _syncEngine.getPendingItems();
    final completedItems = items.where((item) => item.isTerminal).toList();

    if (completedItems.isNotEmpty) {
      await _syncEngine.clearQueue();
      notifyListeners();
    }
  }

  /// Resolve a conflict by accepting local version
  Future<void> resolveConflictAcceptLocal(String itemId) async {
    final items = await _syncEngine.getPendingItems();
    for (final item in items) {
      if (item.id == itemId) {
        await _queueResetItem(item);
        break;
      }
    }
    notifyListeners();
  }

  /// Resolve a conflict by accepting remote version
  Future<void> resolveConflictAcceptRemote({
    required String itemId,
    required Map<String, dynamic> remoteData,
  }) async {
    // Note: Implement conflict resolution
    notifyListeners();
  }

  /// Get sync status as a string for UI display
  String getStatusDisplay() {
    if (!initialized) return 'Initializing...';
    if (!isOnline) return 'Offline';
    if (isSyncing) return 'Syncing...';
    if (hasPendingItems) return '$pendingCount pending';
    if (lastSyncTime != null) {
      return 'Synced at ${_formatTime(lastSyncTime!)}';
    }
    return 'Ready';
  }

  /// Get detailed status message
  String getDetailedStatus() {
    final parts = <String>[];

    if (!isOnline) {
      parts.add('Offline');
    }
    if (isSyncing) {
      parts.add('Syncing...');
    }
    if (pendingCount > 0) {
      parts.add('$pendingCount pending');
    }
    if (processingCount > 0) {
      parts.add('$processingCount processing');
    }
    if (failedCount > 0) {
      parts.add('$failedCount failed');
    }
    if (conflictCount > 0) {
      parts.add('$conflictCount conflicts');
    }
    if (lastSyncTime != null) {
      parts.add('Last sync: ${_formatTime(lastSyncTime!)}');
    }

    return parts.isNotEmpty ? parts.join(', ') : 'Ready';
  }

  /// Format time for display
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${time.month}/${time.day}/${time.year}';
    }
  }

  @override
  void dispose() {
    _syncEngine.dispose();
    super.dispose();
  }
}
