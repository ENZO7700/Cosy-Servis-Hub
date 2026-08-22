import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../database/sync_queue_item.dart';
import '../database/isar_models.dart';
import '../database/isar_service.dart';

/// Configuration for the sync engine
class SyncEngineConfig {
  /// Maximum number of retry attempts
  final int maxRetryAttempts;

  /// Base delay for exponential backoff in seconds
  final int baseBackoffSeconds;

  /// Maximum delay for exponential backoff in seconds
  final int maxBackoffSeconds;

  /// Batch size for processing items
  final int batchSize;

  /// Delay between batches in milliseconds
  final int batchDelayMs;

  /// Whether to auto-sync when connectivity is restored
  final bool autoSyncOnConnectivityRestore;

  /// Whether to process high priority items first
  final bool processHighPriorityFirst;

  const SyncEngineConfig({
    this.maxRetryAttempts = 5,
    this.baseBackoffSeconds = 1,
    this.maxBackoffSeconds = 3600,
    this.batchSize = 10,
    this.batchDelayMs = 500,
    this.autoSyncOnConnectivityRestore = true,
    this.processHighPriorityFirst = true,
  });

  static const defaultConfig = SyncEngineConfig();
}

/// Abstract interface for sync data source
abstract interface class SyncDataSource {
  Future<List<IsarSyncQueue>> getPendingItems();
  Future<void> saveItem(IsarSyncQueue item);
  Future<void> deleteItem(int isarId);
  Future<void> deleteAllItems();
  Future<IsarSyncQueue?> getItemById(String id);
}

/// Sync status for the engine
class SyncEngineStatus {
  final bool isSyncing;
  final bool isOnline;
  final int pendingCount;
  final int processingCount;
  final int failedCount;
  final int conflictCount;
  final String? lastError;
  final DateTime? lastSyncTime;

  const SyncEngineStatus({
    this.isSyncing = false,
    this.isOnline = false,
    this.pendingCount = 0,
    this.processingCount = 0,
    this.failedCount = 0,
    this.conflictCount = 0,
    this.lastError,
    this.lastSyncTime,
  });

  SyncEngineStatus copyWith({
    bool? isSyncing,
    bool? isOnline,
    int? pendingCount,
    int? processingCount,
    int? failedCount,
    int? conflictCount,
    String? lastError,
    DateTime? lastSyncTime,
  }) {
    return SyncEngineStatus(
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      pendingCount: pendingCount ?? this.pendingCount,
      processingCount: processingCount ?? this.processingCount,
      failedCount: failedCount ?? this.failedCount,
      conflictCount: conflictCount ?? this.conflictCount,
      lastError: lastError ?? this.lastError,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// Sync progress callback
typedef SyncProgressCallback = void Function(SyncEngineStatus status);

/// Sync result callback
typedef SyncResultCallback =
    void Function({
      bool success,
      String? error,
      int itemsProcessed,
      int itemsSynced,
      int itemsFailed,
    });

/// Sync item processor - defines how to process each sync operation
/// This should be implemented by the application to handle entity-specific sync logic
abstract interface class SyncItemProcessor {
  /// Process a create operation
  Future<SyncResult> processCreate(SyncQueueItem item);

  /// Process an update operation
  Future<SyncResult> processUpdate(SyncQueueItem item);

  /// Process a soft delete operation
  Future<SyncResult> processSoftDelete(SyncQueueItem item);

  /// Process a restore operation
  Future<SyncResult> processRestore(SyncQueueItem item);

  /// Process a permanent delete operation
  Future<SyncResult> processPermanentDelete(SyncQueueItem item);

  /// Process a bulk update operation
  Future<SyncResult> processBulkUpdate(SyncQueueItem item);

  /// Resolve a conflict between local and remote data
  Future<SyncResult> resolveConflict({
    required SyncQueueItem localItem,
    required Map<String, dynamic> remoteData,
  });
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final String? error;
  final SyncStatus newStatus;
  final String? remoteId;
  final int? remoteVersion;
  final Map<String, dynamic>? remoteData;

  const SyncResult({
    this.success = false,
    this.error,
    this.newStatus = SyncStatus.failed,
    this.remoteId,
    this.remoteVersion,
    this.remoteData,
  });

  factory SyncResult.success({
    SyncStatus newStatus = SyncStatus.synced,
    String? remoteId,
    int? remoteVersion,
    Map<String, dynamic>? remoteData,
  }) {
    return SyncResult(
      success: true,
      newStatus: newStatus,
      remoteId: remoteId,
      remoteVersion: remoteVersion,
      remoteData: remoteData,
    );
  }

  factory SyncResult.failure({
    required String error,
    SyncStatus newStatus = SyncStatus.failed,
  }) {
    return SyncResult(success: false, error: error, newStatus: newStatus);
  }

  factory SyncResult.conflict({
    required String error,
    required Map<String, dynamic> remoteData,
    String? remoteId,
    int? remoteVersion,
  }) {
    return SyncResult(
      success: false,
      error: error,
      newStatus: SyncStatus.conflict,
      remoteId: remoteId,
      remoteVersion: remoteVersion,
      remoteData: remoteData,
    );
  }
}

/// Main sync engine class
class SyncEngine {
  final SyncEngineConfig _config;
  final SyncDataSource _dataSource;
  final SyncItemProcessor? _itemProcessor;

  StreamSubscription? _connectivitySubscription;
  bool _isOnline = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _lastError;

  SyncProgressCallback? onStatusChange;

  SyncEngine({
    SyncEngineConfig? config,
    SyncDataSource? dataSource,
    this.onStatusChange,
    this._itemProcessor,
  }) : _config = config ?? SyncEngineConfig.defaultConfig,
       _dataSource = dataSource ?? IsarSyncDataSource();

  /// Initialize the sync engine
  Future<void> init() async {
    await _checkConnectivity();
    _setupConnectivityListener();
  }

  /// Dispose the sync engine
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Check current connectivity
  /// Uses a simple approach without external package
  /// In production, use connectivity_plus package
  Future<void> _checkConnectivity() async {
    _isOnline = true; // Assume online for now
    // In production: use connectivity_plus
  }

  /// Setup connectivity listener
  /// In production, use connectivity_plus package
  void _setupConnectivityListener() {
    // No-op for now - in production use connectivity_plus
    // _connectivitySubscription = Connectivity().onConnectivityChanged.listen(...);
  }

  /// Notify status change to listeners
  void _notifyStatusChange() {
    if (onStatusChange != null) {
      getStatus().then((status) => onStatusChange?.call(status));
    }
  }

  /// Get current sync status
  Future<SyncEngineStatus> getStatus() async {
    final items = await _dataSource.getPendingItems();

    int pendingCount = 0;
    int processingCount = 0;
    int failedCount = 0;
    int conflictCount = 0;

    for (final item in items) {
      final status = SyncStatus.values.byName(item.status ?? 'pending');
      switch (status) {
        case SyncStatus.pending:
        case SyncStatus.retry:
          pendingCount++;
          break;
        case SyncStatus.processing:
          processingCount++;
          break;
        case SyncStatus.failed:
          failedCount++;
          break;
        case SyncStatus.conflict:
          conflictCount++;
          break;
        default:
          break;
      }
    }

    return SyncEngineStatus(
      isSyncing: _isSyncing,
      isOnline: _isOnline,
      pendingCount: pendingCount,
      processingCount: processingCount,
      failedCount: failedCount,
      conflictCount: conflictCount,
      lastError: _lastError,
      lastSyncTime: _lastSyncTime,
    );
  }

  /// Get current status synchronously (cached values)
  SyncEngineStatus get currentStatus {
    return SyncEngineStatus(
      isSyncing: _isSyncing,
      isOnline: _isOnline,
      pendingCount: 0, // Will be updated async
      processingCount: 0,
      failedCount: 0,
      conflictCount: 0,
      lastError: _lastError,
      lastSyncTime: _lastSyncTime,
    );
  }

  /// Start sync process
  Future<void> sync() async {
    if (_isSyncing) return;
    if (!_isOnline) {
      _lastError = 'Offline - cannot sync';
      _notifyStatusChange();
      return;
    }

    _isSyncing = true;
    _lastError = null;
    _notifyStatusChange();

    try {
      await _processQueue();
      _lastSyncTime = DateTime.now();
    } catch (e, stackTrace) {
      _lastError = 'Sync failed: ${e.toString()}';
      debugPrint('Sync error: $e\n$stackTrace');
    } finally {
      _isSyncing = false;
      _notifyStatusChange();
    }
  }

  /// Process the sync queue
  Future<void> _processQueue() async {
    final items = await _dataSource.getPendingItems();

    // Sort by priority and createdAt
    final sortedItems = items.where((item) {
      final status = SyncStatus.values.byName(item.status ?? 'pending');
      return status == SyncStatus.pending ||
          status == SyncStatus.retry ||
          (status == SyncStatus.failed && !item.permanentFailure);
    }).toList();

    if (_config.processHighPriorityFirst) {
      sortedItems.sort((a, b) {
        // Lower priority number = higher priority
        final priorityCompare = a.priority.compareTo(b.priority);
        if (priorityCompare != 0) return priorityCompare;
        // Then by createdAt (older first)
        final aTime = a.createdAt ?? DateTime.now();
        final bTime = b.createdAt ?? DateTime.now();
        return aTime.compareTo(bTime);
      });
    } else {
      // Process in order of creation
      sortedItems.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.now();
        final bTime = b.createdAt ?? DateTime.now();
        return aTime.compareTo(bTime);
      });
    }

    // Process in batches
    for (var i = 0; i < sortedItems.length; i += _config.batchSize) {
      final batch = sortedItems.sublist(
        i,
        i + _config.batchSize > sortedItems.length
            ? sortedItems.length
            : i + _config.batchSize,
      );

      await _processBatch(batch);

      // Delay between batches
      if (i + _config.batchSize < sortedItems.length) {
        await Future.delayed(Duration(milliseconds: _config.batchDelayMs));
      }
    }
  }

  /// Process a batch of items
  Future<void> _processBatch(List<IsarSyncQueue> batch) async {
    for (final item in batch) {
      await _processItem(item);
    }
  }

  /// Process a single sync queue item
  Future<void> _processItem(IsarSyncQueue item) async {
    try {
      // Mark as processing
      final processingItem = item
        ..status = SyncStatus.processing.name
        ..updatedAt = DateTime.now();
      await _dataSource.saveItem(processingItem);

      // Convert to SyncQueueItem
      final syncItem = _toSyncQueueItem(item);

      // Process based on operation
      SyncResult result;
      switch (SyncOperationType.values.byName(syncItem.operation.name)) {
        case SyncOperationType.create:
          result = await _processCreate(syncItem);
          break;
        case SyncOperationType.update:
          result = await _processUpdate(syncItem);
          break;
        case SyncOperationType.softDelete:
          result = await _processSoftDelete(syncItem);
          break;
        case SyncOperationType.restore:
          result = await _processRestore(syncItem);
          break;
        case SyncOperationType.permanentDelete:
          result = await _processPermanentDelete(syncItem);
          break;
        case SyncOperationType.bulkUpdate:
          result = await _processBulkUpdate(syncItem);
          break;
      }

      // Update item with result
      if (result.success) {
        // Success - mark as synced
        final updatedItem = item
          ..status = result.newStatus.name
          ..lastError = null
          ..attemptCount = 0
          ..nextAttemptAt = null
          ..updatedAt = DateTime.now();
        await _dataSource.saveItem(updatedItem);
      } else if (result.newStatus == SyncStatus.conflict) {
        // Conflict - mark as conflict for manual resolution
        final updatedItem = item
          ..status = SyncStatus.conflict.name
          ..lastError = result.error
          ..attemptCount = item.attemptCount + 1
          ..updatedAt = DateTime.now();
        await _dataSource.saveItem(updatedItem);
      } else {
        // Failed - increment attempt count and set next attempt
        final attemptCount = item.attemptCount + 1;
        if (attemptCount >= _config.maxRetryAttempts) {
          // Max retries reached
          final updatedItem = item
            ..status = SyncStatus.failed.name
            ..lastError = result.error
            ..attemptCount = attemptCount
            ..permanentFailure = true
            ..updatedAt = DateTime.now();
          await _dataSource.saveItem(updatedItem);
        } else {
          // Schedule retry
          final retryDelay = syncItem.retryDelay;
          final updatedItem = item
            ..status = SyncStatus.retry.name
            ..lastError = result.error
            ..attemptCount = attemptCount
            ..nextAttemptAt = DateTime.now().add(retryDelay)
            ..updatedAt = DateTime.now();
          await _dataSource.saveItem(updatedItem);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error processing sync item ${item.id}: $e\n$stackTrace');
      // Mark as failed
      final updatedItem = item
        ..status = SyncStatus.failed.name
        ..lastError = 'Processing error: ${e.toString()}'
        ..attemptCount = item.attemptCount + 1
        ..updatedAt = DateTime.now();
      await _dataSource.saveItem(updatedItem);
    }
  }

  /// Process create operation
  Future<SyncResult> _processCreate(SyncQueueItem item) async {
    if (_itemProcessor != null) {
      return await _itemProcessor.processCreate(item);
    }
    return SyncResult.failure(error: 'No item processor configured');
  }

  /// Process update operation
  Future<SyncResult> _processUpdate(SyncQueueItem item) async {
    if (_itemProcessor != null) {
      return await _itemProcessor.processUpdate(item);
    }
    return SyncResult.failure(error: 'No item processor configured');
  }

  /// Process soft delete operation
  Future<SyncResult> _processSoftDelete(SyncQueueItem item) async {
    if (_itemProcessor != null) {
      return await _itemProcessor.processSoftDelete(item);
    }
    return SyncResult.failure(error: 'No item processor configured');
  }

  /// Process restore operation
  Future<SyncResult> _processRestore(SyncQueueItem item) async {
    if (_itemProcessor != null) {
      return await _itemProcessor.processRestore(item);
    }
    return SyncResult.failure(error: 'No item processor configured');
  }

  /// Process permanent delete operation
  Future<SyncResult> _processPermanentDelete(SyncQueueItem item) async {
    if (_itemProcessor != null) {
      return await _itemProcessor.processPermanentDelete(item);
    }
    return SyncResult.failure(error: 'No item processor configured');
  }

  /// Process bulk update operation
  Future<SyncResult> _processBulkUpdate(SyncQueueItem item) async {
    if (_itemProcessor != null) {
      return await _itemProcessor.processBulkUpdate(item);
    }
    return SyncResult.failure(error: 'No item processor configured');
  }

  /// Convert IsarSyncQueue to SyncQueueItem
  SyncQueueItem _toSyncQueueItem(IsarSyncQueue item) {
    return SyncQueueItem(
      id: item.id ?? '',
      entityType: SyncEntityType.values.byName(item.entityType ?? 'lead'),
      entityId: item.entityId ?? '',
      operation: SyncOperationType.values.byName(item.operation ?? 'create'),
      payload: item.payload != null
          ? jsonDecode(item.payload!) as Map<String, dynamic>
          : {},
      idempotencyKey: item.idempotencyKey ?? '',
      tenantId: item.tenantId ?? '',
      userId: item.userId ?? '',
      createdAt: item.createdAt ?? DateTime.now(),
      updatedAt: item.updatedAt ?? DateTime.now(),
      attemptCount: item.attemptCount,
      nextAttemptAt: item.nextAttemptAt,
      lastError: item.lastError,
      status: SyncStatus.values.byName(item.status ?? 'pending'),
      permanentFailure: item.permanentFailure,
      priority: item.priority,
      entityVersion: item.entityVersion,
      source: item.source ?? 'unknown',
    );
  }

  /// Convert SyncQueueItem to IsarSyncQueue
  IsarSyncQueue _fromSyncQueueItem(SyncQueueItem item) {
    return IsarSyncQueue()
      ..id = item.id
      ..entityType = item.entityType.name
      ..entityId = item.entityId
      ..operation = item.operation.name
      ..payload = jsonEncode(item.payload)
      ..idempotencyKey = item.idempotencyKey
      ..tenantId = item.tenantId
      ..userId = item.userId
      ..createdAt = item.createdAt
      ..updatedAt = item.updatedAt
      ..attemptCount = item.attemptCount
      ..nextAttemptAt = item.nextAttemptAt
      ..lastError = item.lastError
      ..status = item.status.name
      ..permanentFailure = item.permanentFailure
      ..priority = item.priority
      ..entityVersion = item.entityVersion
      ..source = item.source;
  }

  /// Queue a new sync operation
  Future<void> queueOperation({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperationType operation,
    required Map<String, dynamic> payload,
    String? tenantId,
    String? userId,
    String? idempotencyKey,
    int entityVersion = 0,
    String source = 'unknown',
    int priority = 0,
  }) async {
    final item = SyncQueueItem.create(
      id: const Uuid().v4(),
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      tenantId: tenantId ?? '',
      userId: userId ?? '',
      idempotencyKey: idempotencyKey,
      entityVersion: entityVersion,
      source: source,
      priority: priority,
    );

    await _dataSource.saveItem(_fromSyncQueueItem(item));
    _notifyStatusChange();
  }

  /// Queue a create operation
  Future<void> queueCreate({
    required SyncEntityType entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    String? tenantId,
    String? userId,
    String? idempotencyKey,
    int entityVersion = 0,
    String source = 'unknown',
    int priority = 0,
  }) async {
    await queueOperation(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperationType.create,
      payload: payload,
      tenantId: tenantId,
      userId: userId,
      idempotencyKey: idempotencyKey,
      entityVersion: entityVersion,
      source: source,
      priority: priority,
    );
  }

  /// Queue an update operation
  Future<void> queueUpdate({
    required SyncEntityType entityType,
    required String entityId,
    required Map<String, dynamic> payload,
    String? tenantId,
    String? userId,
    String? idempotencyKey,
    int entityVersion = 0,
    String source = 'unknown',
    int priority = 0,
  }) async {
    await queueOperation(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperationType.update,
      payload: payload,
      tenantId: tenantId,
      userId: userId,
      idempotencyKey: idempotencyKey,
      entityVersion: entityVersion,
      source: source,
      priority: priority,
    );
  }

  /// Queue a soft delete operation
  Future<void> queueSoftDelete({
    required SyncEntityType entityType,
    required String entityId,
    String? tenantId,
    String? userId,
    String source = 'unknown',
    int priority = 0,
  }) async {
    await queueOperation(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperationType.softDelete,
      payload: {},
      tenantId: tenantId,
      userId: userId,
      entityVersion: 0,
      source: source,
      priority: priority,
    );
  }

  /// Get count of pending sync items
  Future<int> getPendingCount() async {
    final items = await _dataSource.getPendingItems();
    return items.where((item) {
      final status = SyncStatus.values.byName(item.status ?? 'pending');
      return status == SyncStatus.pending ||
          status == SyncStatus.retry ||
          (status == SyncStatus.failed && !item.permanentFailure);
    }).length;
  }

  /// Get all pending items
  Future<List<SyncQueueItem>> getPendingItems() async {
    final items = await _dataSource.getPendingItems();
    return items.map(_toSyncQueueItem).toList();
  }

  /// Clear all items from queue
  Future<void> clearQueue() async {
    await _dataSource.deleteAllItems();
    _notifyStatusChange();
  }

  /// Force sync of all items (ignore connectivity)
  Future<void> forceSync() async {
    final wasOnline = _isOnline;
    _isOnline = true; // Force online mode
    try {
      await sync();
    } finally {
      _isOnline = wasOnline;
    }
  }
}

/// Isar-based sync data source
class IsarSyncDataSource implements SyncDataSource {
  IsarSyncDataSource();

  Future<Isar> get _isar async {
    return IsarService().isar;
  }

  @override
  Future<List<IsarSyncQueue>> getPendingItems() async {
    final isar = await _isar;
    return await isar.isarSyncQueues.where().findAll();
  }

  @override
  Future<void> saveItem(IsarSyncQueue item) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      await isar.isarSyncQueues.put(item);
    });
  }

  @override
  Future<void> deleteItem(int isarId) async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      await isar.isarSyncQueues.delete(isarId);
    });
  }

  @override
  Future<void> deleteAllItems() async {
    final isar = await _isar;
    await isar.writeTxn(() async {
      await isar.isarSyncQueues.clear();
    });
  }

  @override
  Future<IsarSyncQueue?> getItemById(String id) async {
    final isar = await _isar;
    return await isar.isarSyncQueues.filter().idEqualTo(id).findFirst();
  }
}
