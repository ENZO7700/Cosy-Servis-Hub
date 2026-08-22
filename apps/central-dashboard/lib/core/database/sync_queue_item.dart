/// Sync operation types
enum SyncOperationType {
  create,
  update,
  softDelete,
  restore,
  permanentDelete,
  bulkUpdate,
}

/// Sync entity types
enum SyncEntityType {
  lead,
  client,
  project,
  bug,
  activity,
  outreach,
  note,
  tag,
}

/// Sync status states
enum SyncStatus { pending, processing, synced, retry, failed, conflict }

/// Model for sync queue items - used for both local storage and API communication
class SyncQueueItem {
  /// Unique identifier for the sync operation
  final String id;

  /// Type of entity being synced
  final SyncEntityType entityType;

  /// ID of the entity being synced
  final String entityId;

  /// Operation to perform
  final SyncOperationType operation;

  /// JSON payload containing the data to sync
  final Map<String, dynamic> payload;

  /// Idempotency key to prevent duplicate processing
  final String idempotencyKey;

  /// Tenant ID for multi-tenant isolation
  final String tenantId;

  /// User ID who initiated the operation
  final String userId;

  /// Timestamp when the operation was created
  final DateTime createdAt;

  /// Timestamp when the operation was last updated
  final DateTime updatedAt;

  /// Number of retry attempts
  final int attemptCount;

  /// Next attempt timestamp for retry
  final DateTime? nextAttemptAt;

  /// Last error message if operation failed
  final String? lastError;

  /// Current status of the operation
  final SyncStatus status;

  /// Whether this operation has permanently failed
  final bool permanentFailure;

  /// Priority level (lower = higher priority)
  final int priority;

  /// Version of the entity at the time of operation
  final int entityVersion;

  /// Source of the operation (e.g., 'mobile', 'web', 'import')
  final String source;

  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.idempotencyKey,
    required this.tenantId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.attemptCount,
    this.nextAttemptAt,
    this.lastError,
    required this.status,
    this.permanentFailure = false,
    this.priority = 0,
    this.entityVersion = 0,
    this.source = 'unknown',
  });

  /// Create a pending sync operation
  factory SyncQueueItem.create({
    required String id,
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperationType operation,
    required Map<String, dynamic> payload,
    required String tenantId,
    required String userId,
    String? idempotencyKey,
    int entityVersion = 0,
    String source = 'unknown',
    int priority = 0,
  }) {
    return SyncQueueItem(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      idempotencyKey:
          idempotencyKey ??
          _generateIdempotencyKey(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            timestamp: DateTime.now(),
          ),
      tenantId: tenantId,
      userId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      attemptCount: 0,
      nextAttemptAt: null,
      lastError: null,
      status: SyncStatus.pending,
      permanentFailure: false,
      entityVersion: entityVersion,
      source: source,
      priority: priority,
    );
  }

  /// Create from JSON
  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as String? ?? '',
      entityType: SyncEntityType.values.byName(
        json['entityType'] as String? ?? 'lead',
      ),
      entityId: json['entityId'] as String? ?? '',
      operation: SyncOperationType.values.byName(
        json['operation'] as String? ?? 'create',
      ),
      payload: Map<String, dynamic>.from(
        json['payload'] as Map<String, dynamic>? ?? {},
      ),
      idempotencyKey: json['idempotencyKey'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? ''),
      attemptCount: json['attemptCount'] as int? ?? 0,
      nextAttemptAt: json['nextAttemptAt'] != null
          ? DateTime.parse(json['nextAttemptAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
      status: SyncStatus.values.byName(json['status'] as String? ?? 'pending'),
      permanentFailure: json['permanentFailure'] as bool? ?? false,
      priority: json['priority'] as int? ?? 0,
      entityVersion: json['entityVersion'] as int? ?? 0,
      source: json['source'] as String? ?? 'unknown',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType.name,
      'entityId': entityId,
      'operation': operation.name,
      'payload': payload,
      'idempotencyKey': idempotencyKey,
      'tenantId': tenantId,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'attemptCount': attemptCount,
      'nextAttemptAt': nextAttemptAt?.toIso8601String(),
      'lastError': lastError,
      'status': status.name,
      'permanentFailure': permanentFailure,
      'priority': priority,
      'entityVersion': entityVersion,
      'source': source,
    };
  }

  /// Generate a unique idempotency key
  static String _generateIdempotencyKey({
    required SyncEntityType entityType,
    required String entityId,
    required SyncOperationType operation,
    required DateTime timestamp,
  }) {
    return '${entityType.name}_${entityId}_${operation.name}_${timestamp.millisecondsSinceEpoch}';
  }

  /// Create a copy with updated fields
  SyncQueueItem copyWith({
    String? id,
    SyncEntityType? entityType,
    String? entityId,
    SyncOperationType? operation,
    Map<String, dynamic>? payload,
    String? idempotencyKey,
    String? tenantId,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? attemptCount,
    DateTime? nextAttemptAt,
    String? lastError,
    SyncStatus? status,
    bool? permanentFailure,
    int? priority,
    int? entityVersion,
    String? source,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
      permanentFailure: permanentFailure ?? this.permanentFailure,
      priority: priority ?? this.priority,
      entityVersion: entityVersion ?? this.entityVersion,
      source: source ?? this.source,
    );
  }

  /// Check if this item needs sync
  bool get needsSync =>
      status == SyncStatus.pending ||
      status == SyncStatus.retry ||
      status == SyncStatus.failed && !permanentFailure;

  /// Check if this item is in a terminal state
  bool get isTerminal =>
      status == SyncStatus.synced && !needsSync ||
      status == SyncStatus.failed && permanentFailure ||
      status == SyncStatus.conflict;

  /// Get retry delay based on attempt count (exponential backoff)
  Duration get retryDelay {
    // Base delay of 1 second, doubling with each attempt, capped at 1 hour
    final seconds = 1 * (1 << attemptCount);
    return Duration(seconds: seconds.clamp(1, 3600));
  }

  @override
  String toString() {
    return 'SyncQueueItem{'
        'id: $id, '
        'entityType: ${entityType.name}, '
        'entityId: $entityId, '
        'operation: ${operation.name}, '
        'status: ${status.name}, '
        'attemptCount: $attemptCount'
        '}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncQueueItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Dead letter queue item for permanently failed operations
class DeadLetterQueueItem {
  final String id;
  final SyncQueueItem originalItem;
  final String errorType;
  final String errorMessage;
  final Map<String, dynamic>? errorContext;
  final DateTime createdAt;
  final bool reviewed;
  final String? reviewNotes;

  const DeadLetterQueueItem({
    required this.id,
    required this.originalItem,
    required this.errorType,
    required this.errorMessage,
    this.errorContext,
    required this.createdAt,
    this.reviewed = false,
    this.reviewNotes,
  });

  factory DeadLetterQueueItem.fromSyncItem({
    required SyncQueueItem item,
    required String errorType,
    required String errorMessage,
    Map<String, dynamic>? errorContext,
    String? id,
  }) {
    return DeadLetterQueueItem(
      id: id ?? '${item.id}_dlq_${DateTime.now().millisecondsSinceEpoch}',
      originalItem: item,
      errorType: errorType,
      errorMessage: errorMessage,
      errorContext: errorContext,
      createdAt: DateTime.now(),
      reviewed: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalItem': originalItem.toJson(),
      'errorType': errorType,
      'errorMessage': errorMessage,
      'errorContext': errorContext,
      'createdAt': createdAt.toIso8601String(),
      'reviewed': reviewed,
      'reviewNotes': reviewNotes,
    };
  }

  factory DeadLetterQueueItem.fromJson(Map<String, dynamic> json) {
    return DeadLetterQueueItem(
      id: json['id'] as String? ?? '',
      originalItem: SyncQueueItem.fromJson(
        Map<String, dynamic>.from(
          json['originalItem'] as Map<String, dynamic>? ?? {},
        ),
      ),
      errorType: json['errorType'] as String? ?? '',
      errorMessage: json['errorMessage'] as String? ?? '',
      errorContext: json['errorContext'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? ''),
      reviewed: json['reviewed'] as bool? ?? false,
      reviewNotes: json['reviewNotes'] as String?,
    );
  }
}
