import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/supabase_service.dart';
import './models.dart';
import './isar_service.dart' if (dart.library.html) 'isar_service_web.dart';
import '../config/config.dart';

class DataProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final IsarService _isarService = IsarService();

  List<Bug> _bugs = [];
  List<Project> _projects = [];
  bool _loading = false;
  String? _error;
  String _selectedProjectId = '__all_projects__'; // Default: ALL
  Timer? _syncTimer;

  List<Bug> get bugs => _bugs;
  List<Project> get projects => _projects;
  bool get loading => _loading;
  String? get error => _error;
  String get selectedProjectId => _selectedProjectId;

  RealtimeChannel? _realtimeChannel;

  DataProvider() {
    _init();
  }

  Future<void> _init() async {
    if (AppConfig.isTest) {
      _projects = [
        Project(
          id: 'proj_1',
          name: 'Aura Dashboard',
          description: 'Main landing page and analytics client for Aura.',
          createdBy: 'test-user-uid',
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
        Project(
          id: 'proj_2',
          name: 'Vibecraft Mobile',
          description: 'iOS/Android social experience application.',
          createdBy: 'test-user-uid',
          createdAt: DateTime.now().subtract(const Duration(days: 20)),
          updatedAt: DateTime.now().subtract(const Duration(days: 20)),
        ),
      ];

      _bugs = [
        Bug(
          id: 'bug_1',
          trackingId: 'BUG-1001',
          title: 'Chyba pri prihlásení cez Google',
          description:
              'Pri pokuse o prihlásenie cez Google appka zamrzne na bielej obrazovke.',
          projectId: 'proj_1',
          reporterId: 'test-user-uid',
          severity: 'critical',
          status: 'new',
          environment: 'Production Web',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        Bug(
          id: 'bug_2',
          trackingId: 'BUG-1002',
          title: 'Layout preteká na iPhone SE',
          description:
              'V spodnej časti obrazovky nastavení sa zobrazuje žlté pretečenie.',
          projectId: 'proj_2',
          reporterId: 'test-user-uid',
          severity: 'medium',
          status: 'in_progress',
          environment: 'iOS 17, iPhone SE',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
      notifyListeners();
      return;
    }

    await _isarService.init();
    await _supabaseService.init();

    // 1. Load cached data instantly (0ms UI loading)
    await _loadCachedData();

    // 2. Fetch fresh data from network in background
    await fetchAllData();

    // 3. Setup realtime sync
    _setupRealtime();

    // 4. Start background timer to process offline sync queue every 10 seconds
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      processOfflineQueue();
    });
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedProjs = await _isarService.getCachedProjects();
      final cachedBugs = await _isarService.getCachedBugs();
      if (cachedProjs.isNotEmpty || cachedBugs.isNotEmpty) {
        _projects = cachedProjs;
        _bugs = cachedBugs;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  Future<void> fetchAllData() async {
    // Only show loader if we have no cached data, to ensure instant startup feel
    if (_bugs.isEmpty && _projects.isEmpty) {
      _loading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final futures = await Future.wait([
        _supabaseService.getBugs(),
        _supabaseService.getProjects(),
      ]);

      final freshBugs = futures[0] as List<Bug>;
      final freshProjects = futures[1] as List<Project>;

      _bugs = freshBugs;
      _projects = freshProjects;

      // Update local Isar database cache
      await _isarService.cacheProjects(freshProjects);
      await _isarService.cacheBugs(freshBugs);
    } catch (e) {
      _error =
          'Nepodarilo sa načítať údaje zo siete. Používajú sa lokálne dáta.';
      debugPrint('Error fetching data: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _setupRealtime() {
    try {
      _realtimeChannel = _supabaseService.client
          .channel('dashboard-realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'bugs',
            callback: (payload) {
              debugPrint('Realtime bug change received: ${payload.eventType}');
              fetchAllData();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'projects',
            callback: (payload) {
              debugPrint(
                'Realtime project change received: ${payload.eventType}',
              );
              fetchAllData();
            },
          );
      _realtimeChannel!.subscribe();
    } catch (e) {
      debugPrint('Failed to setup realtime: $e');
    }
  }

  void selectProject(String projectId) {
    _selectedProjectId = projectId;
    notifyListeners();
  }

  List<Bug> get filteredBugs {
    if (_selectedProjectId == '__all_projects__') {
      return _bugs;
    }
    if (_selectedProjectId == '__unassigned_project__') {
      return _bugs
          .where((bug) => bug.projectId == null || bug.projectId!.isEmpty)
          .toList();
    }
    return _bugs.where((bug) => bug.projectId == _selectedProjectId).toList();
  }

  Future<bool> createBug({
    required String title,
    required String description,
    required String severity,
    String? projectId,
    required String reporterId,
    String? stepsToReproduce,
    String? expectedBehavior,
    String? actualBehavior,
    String? environment,
  }) async {
    final now = DateTime.now();
    // Temporary ID for offline/immediate tracking
    final tempId = 'local_${now.millisecondsSinceEpoch}';
    final trackingId =
        'BUG-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

    final bug = Bug(
      id: tempId,
      trackingId: trackingId,
      title: title,
      description: description,
      projectId: projectId,
      reporterId: reporterId,
      severity: severity,
      status: 'new',
      stepsToReproduce: stepsToReproduce,
      expectedBehavior: expectedBehavior,
      actualBehavior: actualBehavior,
      environment: environment,
      createdAt: now,
      updatedAt: now,
    );

    if (AppConfig.isTest) {
      _bugs.insert(0, bug);
      notifyListeners();
      return true;
    }

    try {
      // 1. Save locally to Isar cache immediately
      await _isarService.saveLocalBug(bug, synced: false);
    } catch (e) {
      debugPrint('Error saving to Isar cache: $e');
    }

    // 2. Add to in-memory state for instant UI update
    _bugs.insert(0, bug);
    notifyListeners();

    try {
      // 3. Queue the create task in Isar queue
      final payload = jsonEncode({
        'tracking_id': trackingId,
        'title': title,
        'description': description,
        'project_id': projectId,
        'reporter_id': reporterId,
        'severity': severity,
        'status': 'new',
        'steps_to_reproduce': stepsToReproduce,
        'expected_behavior': expectedBehavior,
        'actual_behavior': actualBehavior,
        'environment': environment,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await _isarService.addToQueue('create', tempId, payload);
    } catch (e) {
      debugPrint('Error adding to queue: $e');
    }

    try {
      // 4. Run sync queue immediately
      processOfflineQueue();
    } catch (e) {
      debugPrint('Error processing queue: $e');
    }

    return true;
  }

  Future<bool> updateBugStatus(String bugId, String status) async {
    // 1. Instantly update in-memory state
    final index = _bugs.indexWhere((b) => b.id == bugId);
    if (index != -1) {
      final updated = Bug(
        id: _bugs[index].id,
        trackingId: _bugs[index].trackingId,
        title: _bugs[index].title,
        description: _bugs[index].description,
        projectId: _bugs[index].projectId,
        assigneeId: _bugs[index].assigneeId,
        reporterId: _bugs[index].reporterId,
        severity: _bugs[index].severity,
        status: status,
        stepsToReproduce: _bugs[index].stepsToReproduce,
        expectedBehavior: _bugs[index].expectedBehavior,
        actualBehavior: _bugs[index].actualBehavior,
        environment: _bugs[index].environment,
        createdAt: _bugs[index].createdAt,
        updatedAt: DateTime.now(),
      );
      _bugs[index] = updated;
      notifyListeners();

      if (AppConfig.isTest) {
        return true;
      }

      // 2. Update local Isar bug
      final isarSynced = !bugId.startsWith('local_');
      await _isarService.saveLocalBug(updated, synced: isarSynced);
    }

    // 3. Add to sync queue
    final payload = jsonEncode({'bugId': bugId, 'status': status});
    await _isarService.addToQueue('update_status', bugId, payload);

    // 4. Run sync queue
    processOfflineQueue();

    return true;
  }

  Future<bool> updateBugSeverity(String bugId, String severity) async {
    // 1. Instantly update in-memory state
    final index = _bugs.indexWhere((b) => b.id == bugId);
    if (index != -1) {
      final updated = Bug(
        id: _bugs[index].id,
        trackingId: _bugs[index].trackingId,
        title: _bugs[index].title,
        description: _bugs[index].description,
        projectId: _bugs[index].projectId,
        assigneeId: _bugs[index].assigneeId,
        reporterId: _bugs[index].reporterId,
        severity: severity,
        status: _bugs[index].status,
        stepsToReproduce: _bugs[index].stepsToReproduce,
        expectedBehavior: _bugs[index].expectedBehavior,
        actualBehavior: _bugs[index].actualBehavior,
        environment: _bugs[index].environment,
        createdAt: _bugs[index].createdAt,
        updatedAt: DateTime.now(),
      );
      _bugs[index] = updated;
      notifyListeners();

      if (AppConfig.isTest) {
        return true;
      }

      // 2. Update local Isar bug
      final isarSynced = !bugId.startsWith('local_');
      await _isarService.saveLocalBug(updated, synced: isarSynced);
    }

    // 3. Add to sync queue
    final payload = jsonEncode({'bugId': bugId, 'severity': severity});
    await _isarService.addToQueue('update_severity', bugId, payload);

    // 4. Run sync queue
    processOfflineQueue();

    return true;
  }

  Future<void> processOfflineQueue() async {
    try {
      final queue = await _isarService.getOfflineQueue();
      if (queue.isEmpty) return;

      debugPrint('Processing offline queue. Items to sync: ${queue.length}');

      if (AppConfig.isTest) {
        for (var item in queue) {
          final op = item.operation;
          final payload = jsonDecode(item.payload ?? '{}');

          if (op == 'create') {
            final tempId = item.bugId ?? '';
            final mockRemoteId =
                'synced_${DateTime.now().millisecondsSinceEpoch}';

            final newBug = Bug(
              id: mockRemoteId,
              trackingId: payload['tracking_id'] ?? '',
              title: payload['title'] ?? '',
              description: payload['description'] ?? '',
              projectId: payload['project_id'],
              reporterId: payload['reporter_id'] ?? '',
              severity: payload['severity'] ?? 'low',
              status: payload['status'] ?? 'new',
              stepsToReproduce: payload['steps_to_reproduce'],
              expectedBehavior: payload['expected_behavior'],
              actualBehavior: payload['actual_behavior'],
              environment: payload['environment'],
              createdAt: DateTime.parse(payload['created_at']),
              updatedAt: DateTime.parse(payload['updated_at']),
            );

            await _isarService.deleteLocalBugById(tempId);

            await _isarService.saveLocalBug(newBug, synced: true);
            await _isarService.removeFromQueue(item.isarId!);

            final memIdx = _bugs.indexWhere((b) => b.id == tempId);
            if (memIdx != -1) {
              _bugs[memIdx] = newBug;
            }
          } else if (op == 'update_status' || op == 'update_severity') {
            final bugId = item.bugId ?? '';
            await _isarService.removeFromQueue(item.isarId!);
            await _isarService.markLocalBugSynced(bugId);
          }
        }
        notifyListeners();
        return;
      }

      final localIdToRemoteId = <String, String>{};

      for (var item in queue) {
        final op = item.operation;
        final payload = jsonDecode(item.payload ?? '{}');

        if (op == 'create') {
          final tempId = item.bugId ?? '';

          final bugToCreate = Bug(
            id: '', // Supabase will auto-generate UUID
            trackingId: payload['tracking_id'] ?? '',
            title: payload['title'] ?? '',
            description: payload['description'] ?? '',
            projectId: payload['project_id'],
            reporterId: payload['reporter_id'] ?? '',
            severity: payload['severity'] ?? 'low',
            status: payload['status'] ?? 'new',
            stepsToReproduce: payload['steps_to_reproduce'],
            expectedBehavior: payload['expected_behavior'],
            actualBehavior: payload['actual_behavior'],
            environment: payload['environment'],
            createdAt: DateTime.parse(payload['created_at']),
            updatedAt: DateTime.parse(payload['updated_at']),
          );

          final remoteBug = await _supabaseService.createBug(bugToCreate);
          if (remoteBug != null) {
            localIdToRemoteId[tempId] = remoteBug.id;

            // Delete temporary local record from Isar
            await _isarService.deleteLocalBugById(tempId);

            // Save new synced bug to Isar
            await _isarService.saveLocalBug(remoteBug, synced: true);
            await _isarService.removeFromQueue(item.isarId!);

            // Replace in-memory bug
            final memIdx = _bugs.indexWhere((b) => b.id == tempId);
            if (memIdx != -1) {
              _bugs[memIdx] = remoteBug;
            }
          } else {
            // Remote sync failed (still offline), break queue execution
            break;
          }
        } else if (op == 'update_status') {
          var bugId = payload['bugId'] ?? '';
          final status = payload['status'] ?? '';

          if (localIdToRemoteId.containsKey(bugId)) {
            bugId = localIdToRemoteId[bugId]!;
          }

          if (bugId.startsWith('local_')) {
            continue; // Wait for creation task to complete first
          }

          final success = await _supabaseService.updateBug(bugId, {
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          });

          if (success) {
            await _isarService.removeFromQueue(item.isarId!);
            await _isarService.markLocalBugSynced(bugId);
          } else {
            break;
          }
        } else if (op == 'update_severity') {
          var bugId = payload['bugId'] ?? '';
          final severity = payload['severity'] ?? '';

          if (localIdToRemoteId.containsKey(bugId)) {
            bugId = localIdToRemoteId[bugId]!;
          }

          if (bugId.startsWith('local_')) {
            continue;
          }

          final success = await _supabaseService.updateBug(bugId, {
            'severity': severity,
            'updated_at': DateTime.now().toIso8601String(),
          });

          if (success) {
            await _isarService.removeFromQueue(item.isarId!);
            await _isarService.markLocalBugSynced(bugId);
          } else {
            break;
          }
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error processing offline queue: $e');
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    try {
      if (_realtimeChannel != null &&
          !const bool.fromEnvironment(
            'INTEGRATION_TEST',
            defaultValue: false,
          )) {
        _supabaseService.client.removeChannel(_realtimeChannel!);
      }
    } catch (_) {}
    super.dispose();
  }
}
