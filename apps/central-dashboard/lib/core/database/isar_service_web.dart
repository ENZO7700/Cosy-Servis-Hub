import './isar_models_web.dart';
import './models.dart';

class IsarService {
  static final IsarService _instance = IsarService._internal();
  factory IsarService() => _instance;
  IsarService._internal();

  static bool isMock = false;

  final List<Project> _projects = [];
  final List<Bug> _bugs = [];
  final List<IsarOfflineQueue> _queue = [];
  final List<IsarClient> _clients = [];
  final List<IsarClientActivity> _activities = [];
  int _queueId = 0;

  Future<void> init() async {}

  Future<List<Project>> getCachedProjects() async => List.of(_projects);

  Future<void> cacheProjects(List<Project> projects) async {
    _projects
      ..clear()
      ..addAll(projects);
  }

  Future<List<Bug>> getCachedBugs() async => List.of(_bugs);

  Future<void> cacheBugs(List<Bug> bugs) async {
    final unsynced = _bugs.where((bug) => bug.id.startsWith('local_')).toList();
    _bugs
      ..clear()
      ..addAll(bugs.where((bug) => !unsynced.any((item) => item.id == bug.id)))
      ..addAll(unsynced);
  }

  Future<List<IsarOfflineQueue>> getOfflineQueue() async => List.of(_queue)
    ..sort(
      (a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)),
    );

  Future<void> addToQueue(
    String operation,
    String? bugId,
    String jsonPayload,
  ) async {
    _queue.add(
      IsarOfflineQueue()
        ..isarId = ++_queueId
        ..operation = operation
        ..bugId = bugId
        ..payload = jsonPayload
        ..createdAt = DateTime.now(),
    );
  }

  Future<void> removeFromQueue(int id) async {
    _queue.removeWhere((item) => item.isarId == id);
  }

  Future<void> saveLocalBug(Bug bug, {required bool synced}) async {
    _bugs.removeWhere((item) => item.id == bug.id);
    _bugs.add(bug);
  }

  Future<void> deleteLocalBugById(String bugId) async {
    _bugs.removeWhere((bug) => bug.id == bugId);
  }

  Future<void> markLocalBugSynced(String bugId) async {}

  Future<List<IsarClient>> getCachedClients() async => List.of(_clients);

  Future<void> saveLocalClient(IsarClient client) async {
    _clients.removeWhere((item) => item.id == client.id);
    _clients.add(client);
  }

  Future<void> deleteLocalClient(String clientId) async {
    final matches = _clients.where((item) => item.id == clientId);
    if (matches.isNotEmpty) {
      matches.first
        ..deletedAt = DateTime.now()
        ..syncStatus = 'pending';
    }
  }

  Future<void> restoreLocalClient(String clientId) async {
    final matches = _clients.where((item) => item.id == clientId);
    if (matches.isNotEmpty) {
      matches.first
        ..deletedAt = null
        ..syncStatus = 'pending';
    }
  }

  Future<void> permanentlyDeleteLocalClient(String clientId) async {
    _clients.removeWhere((item) => item.id == clientId);
  }

  Future<List<IsarClientActivity>> getCachedActivitiesForClient(
    String clientId,
  ) async {
    return _activities.where((item) => item.clientId == clientId).toList()
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
  }

  Future<void> saveLocalActivity(IsarClientActivity activity) async {
    _activities.removeWhere((item) => item.id == activity.id);
    _activities.add(activity);
  }

  Future<void> deleteLocalActivity(String activityId) async {
    _activities.removeWhere((item) => item.id == activityId);
  }

  Future<int> getCrmPendingQueueCount() async {
    return _clients.where((item) => item.syncStatus == 'pending').length;
  }
}
