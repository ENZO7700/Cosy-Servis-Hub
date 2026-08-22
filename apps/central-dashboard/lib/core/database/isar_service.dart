import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';
import './isar_models.dart';
import './models.dart';

class IsarService {
  static final IsarService _instance = IsarService._internal();
  factory IsarService() => _instance;
  IsarService._internal();

  Isar? _isar;
  static bool isMock = false;

  Future<void> init() async {
    if (isMock) return;
    if (kIsWeb) {
      return; // Web uses the conditional in-memory compatibility service.
    }
    if (_isar != null) return;
    try {
      final String path;
      if (kIsWeb) {
        path = '';
      } else {
        final dir = await getApplicationDocumentsDirectory();
        path = dir.path;
      }
      _isar = await Isar.open([
        IsarProjectSchema,
        IsarBugSchema,
        IsarOfflineQueueSchema,
        IsarClientSchema,
        IsarClientActivitySchema,
        IsarLeadSchema,
      ], directory: path);
    } catch (e) {
      debugPrint('Error initializing Isar: $e');
    }
  }

  Isar get isar {
    if (_isar == null) {
      throw Exception('Isar has not been initialized. Call init() first.');
    }
    return _isar!;
  }

  // --- Caching Projects ---
  Future<List<Project>> getCachedProjects() async {
    await init();
    if (_isar == null) return [];
    final isarProjs = await isar.isarProjects.where().findAll();
    return isarProjs
        .map(
          (ip) => Project(
            id: ip.id ?? '',
            name: ip.name ?? '',
            description: ip.description,
            createdBy: ip.createdBy,
            createdAt: ip.createdAt ?? DateTime.now(),
            updatedAt: ip.updatedAt ?? DateTime.now(),
          ),
        )
        .toList();
  }

  Future<void> cacheProjects(List<Project> projects) async {
    await init();
    if (_isar == null) return;
    await isar.writeTxn(() async {
      // Clear existing first
      await isar.isarProjects.clear();

      final isarProjs = projects
          .map(
            (p) => IsarProject()
              ..id = p.id
              ..name = p.name
              ..description = p.description
              ..createdBy = p.createdBy
              ..createdAt = p.createdAt
              ..updatedAt = p.updatedAt,
          )
          .toList();

      await isar.isarProjects.putAll(isarProjs);
    });
  }

  // --- Caching Bugs ---
  Future<List<Bug>> getCachedBugs() async {
    await init();
    if (_isar == null) return [];
    final isarBugs = await isar.isarBugs.where().findAll();
    return isarBugs
        .map(
          (ib) => Bug(
            id: ib.id ?? '',
            trackingId: ib.trackingId ?? '',
            title: ib.title ?? '',
            description: ib.description ?? '',
            projectId: ib.projectId,
            assigneeId: ib.assigneeId,
            reporterId: ib.reporterId ?? '',
            severity: ib.severity ?? 'low',
            status: ib.status ?? 'new',
            stepsToReproduce: ib.stepsToReproduce,
            expectedBehavior: ib.expectedBehavior,
            actualBehavior: ib.actualBehavior,
            environment: ib.environment,
            createdAt: ib.createdAt ?? DateTime.now(),
            updatedAt: ib.updatedAt ?? DateTime.now(),
          ),
        )
        .toList();
  }

  Future<void> cacheBugs(List<Bug> bugs) async {
    await init();
    if (_isar == null) return;
    await isar.writeTxn(() async {
      // We only clear/replace bugs that are ALREADY synced.
      // Unsynced bugs should NOT be overwritten by remote, since they represent offline changes.
      final localUnsynced = await isar.isarBugs
          .filter()
          .syncedEqualTo(false)
          .findAll();
      final localUnsyncedMap = {for (var b in localUnsynced) b.trackingId: b};

      await isar.isarBugs.clear();

      final listToPut = <IsarBug>[];

      // Add remote bugs
      for (var b in bugs) {
        if (localUnsyncedMap.containsKey(b.trackingId)) {
          continue; // Skip remote version; use local unsynced version instead
        }
        final isarBug = IsarBug()
          ..id = b.id
          ..trackingId = b.trackingId
          ..title = b.title
          ..description = b.description
          ..projectId = b.projectId
          ..assigneeId = b.assigneeId
          ..reporterId = b.reporterId
          ..severity = b.severity
          ..status = b.status
          ..stepsToReproduce = b.stepsToReproduce
          ..expectedBehavior = b.expectedBehavior
          ..actualBehavior = b.actualBehavior
          ..environment = b.environment
          ..createdAt = b.createdAt
          ..updatedAt = b.updatedAt
          ..synced = true;
        listToPut.add(isarBug);
      }

      // Re-add unsynced bugs so they are not lost
      for (var ub in localUnsynced) {
        listToPut.add(ub);
      }

      await isar.isarBugs.putAll(listToPut);
    });
  }

  // --- Offline Sync Queue ---
  Future<List<IsarOfflineQueue>> getOfflineQueue() async {
    await init();
    if (_isar == null) return [];
    return await isar.isarOfflineQueues.where().sortByCreatedAt().findAll();
  }

  Future<void> addToQueue(
    String operation,
    String? bugId,
    String jsonPayload,
  ) async {
    await init();
    if (_isar == null) return;
    await isar.writeTxn(() async {
      final queueItem = IsarOfflineQueue()
        ..operation = operation
        ..bugId = bugId
        ..payload = jsonPayload
        ..createdAt = DateTime.now();
      await isar.isarOfflineQueues.put(queueItem);
    });
  }

  Future<void> removeFromQueue(int id) async {
    await init();
    if (_isar == null) return;
    await isar.writeTxn(() async {
      await isar.isarOfflineQueues.delete(id);
    });
  }

  Future<void> saveLocalBug(Bug bug, {required bool synced}) async {
    await init();
    if (_isar == null) {
      return;
    }
    try {
      await isar.writeTxn(() async {
        // Find if already exists in local DB
        final existing = await isar.isarBugs
            .filter()
            .trackingIdEqualTo(bug.trackingId)
            .findFirst();

        final ib = existing ?? IsarBug();
        ib.id = bug.id;
        ib.trackingId = bug.trackingId;
        ib.title = bug.title;
        ib.description = bug.description;
        ib.projectId = bug.projectId;
        ib.assigneeId = bug.assigneeId;
        ib.reporterId = bug.reporterId;
        ib.severity = bug.severity;
        ib.status = bug.status;
        ib.stepsToReproduce = bug.stepsToReproduce;
        ib.expectedBehavior = bug.expectedBehavior;
        ib.actualBehavior = bug.actualBehavior;
        ib.environment = bug.environment;
        ib.createdAt = bug.createdAt;
        ib.updatedAt = bug.updatedAt;
        ib.synced = synced;

        await isar.isarBugs.put(ib);
      });
    } catch (e) {
      debugPrint('Error saving local bug: $e');
    }
  }

  Future<void> deleteLocalBugById(String bugId) async {
    await init();
    if (_isar == null) return;
    await isar.writeTxn(() async {
      final existing = await isar.isarBugs
          .filter()
          .idEqualTo(bugId)
          .findFirst();
      if (existing?.isarId != null) {
        await isar.isarBugs.delete(existing!.isarId!);
      }
    });
  }

  Future<void> markLocalBugSynced(String bugId) async {
    await init();
    if (_isar == null) return;
    final existing = await isar.isarBugs.filter().idEqualTo(bugId).findFirst();
    if (existing == null) return;
    existing.synced = true;
    await isar.writeTxn(() => isar.isarBugs.put(existing));
  }

  // --- CRM Clients ---
  Future<List<IsarClient>> getCachedClients() async {
    await init();
    if (_isar == null) return [];
    return await isar.isarClients.where().findAll();
  }

  Future<void> saveLocalClient(IsarClient client) async {
    await init();
    if (_isar == null) return;
    try {
      await isar.writeTxn(() async {
        final existing = await isar.isarClients
            .filter()
            .idEqualTo(client.id)
            .findFirst();
        if (existing != null) {
          client.isarId = existing.isarId;
        }
        await isar.isarClients.put(client);
      });
    } catch (e) {
      debugPrint('Error saving local client: $e');
    }
  }

  Future<void> deleteLocalClient(String clientId) async {
    await init();
    if (_isar == null) return;
    try {
      await isar.writeTxn(() async {
        final existing = await isar.isarClients
            .filter()
            .idEqualTo(clientId)
            .findFirst();
        if (existing != null) {
          existing.deletedAt = DateTime.now();
          existing.syncStatus = 'pending';
          await isar.isarClients.put(existing);
        }
      });
    } catch (e) {
      debugPrint('Error soft deleting local client: $e');
    }
  }

  Future<void> restoreLocalClient(String clientId) async {
    await init();
    if (_isar == null) return;
    try {
      await isar.writeTxn(() async {
        final existing = await isar.isarClients
            .filter()
            .idEqualTo(clientId)
            .findFirst();
        if (existing != null) {
          existing.deletedAt = null;
          existing.syncStatus = 'pending';
          await isar.isarClients.put(existing);
        }
      });
    } catch (e) {
      debugPrint('Error restoring local client: $e');
    }
  }

  Future<void> permanentlyDeleteLocalClient(String clientId) async {
    await init();
    if (_isar == null) return;
    try {
      await isar.writeTxn(() async {
        final existing = await isar.isarClients
            .filter()
            .idEqualTo(clientId)
            .findFirst();
        if (existing != null) {
          await isar.isarClients.delete(existing.isarId!);
        }
      });
    } catch (e) {
      debugPrint('Error permanently deleting local client: $e');
    }
  }

  // --- CRM Activities ---
  Future<List<IsarClientActivity>> getCachedActivitiesForClient(
    String clientId,
  ) async {
    await init();
    if (_isar == null) return [];
    return await isar.isarClientActivitys
        .filter()
        .clientIdEqualTo(clientId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<void> saveLocalActivity(IsarClientActivity activity) async {
    await init();
    if (_isar == null) return;
    try {
      await isar.writeTxn(() async {
        final existing = await isar.isarClientActivitys
            .filter()
            .idEqualTo(activity.id)
            .findFirst();
        if (existing != null) {
          activity.isarId = existing.isarId;
        }
        await isar.isarClientActivitys.put(activity);
      });
    } catch (e) {
      debugPrint('Error saving local activity: $e');
    }
  }

  Future<void> deleteLocalActivity(String activityId) async {
    await init();
    if (_isar == null) return;
    try {
      await isar.writeTxn(() async {
        final existing = await isar.isarClientActivitys
            .filter()
            .idEqualTo(activityId)
            .findFirst();
        if (existing != null) {
          await isar.isarClientActivitys.delete(existing.isarId!);
        }
      });
    } catch (e) {
      debugPrint('Error deleting local activity: $e');
    }
  }

  // Helper na počítanie CRM pending queue položiek (TODO: synchronizácia queue s remote backendom)
  Future<int> getCrmPendingQueueCount() async {
    await init();
    if (_isar == null) return 0;
    // Počet neodoslaných zmien pre klientov v lokálnej DB
    final pendingClients = await isar.isarClients
        .filter()
        .syncStatusEqualTo('pending')
        .count();
    return pendingClients;
  }
}
