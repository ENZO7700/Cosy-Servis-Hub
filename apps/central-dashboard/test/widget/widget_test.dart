import 'package:flutter_test/flutter_test.dart';
import 'package:centralny_dashboard/core/database/models.dart';

void main() {
  group('Model Mapping Tests', () {
    test('Project fromMap and toMap mapping', () {
      final map = {
        'id': 'proj-123',
        'name': 'Test Project',
        'description': 'A description for testing',
        'created_by': 'user-1',
        'created_at': '2026-05-21T12:00:00.000Z',
        'updated_at': '2026-05-21T12:30:00.000Z',
      };

      final project = Project.fromMap(map);

      expect(project.id, 'proj-123');
      expect(project.name, 'Test Project');
      expect(project.description, 'A description for testing');
      expect(project.createdBy, 'user-1');
      expect(project.createdAt, DateTime.parse('2026-05-21T12:00:00.000Z'));

      final outMap = project.toMap();
      expect(outMap['id'], 'proj-123');
      expect(outMap['name'], 'Test Project');
      expect(outMap['description'], 'A description for testing');
      expect(outMap['created_by'], 'user-1');
    });

    test('Bug fromMap and toMap mapping', () {
      final map = {
        'id': 'bug-456',
        'tracking_id': 'BUG-0001',
        'title': 'App Crashes on Start',
        'description': 'Crash when opening auth screen',
        'project_id': 'proj-123',
        'reporter_id': 'user-1',
        'severity': 'critical',
        'status': 'new',
        'environment': 'iOS 15',
        'created_at': '2026-05-21T13:00:00.000Z',
        'updated_at': '2026-05-21T13:00:00.000Z',
      };

      final bug = Bug.fromMap(map);

      expect(bug.id, 'bug-456');
      expect(bug.trackingId, 'BUG-0001');
      expect(bug.title, 'App Crashes on Start');
      expect(bug.severity, 'critical');
      expect(bug.status, 'new');
      expect(bug.environment, 'iOS 15');

      final outMap = bug.toMap();
      expect(outMap['id'], 'bug-456');
      expect(outMap['tracking_id'], 'BUG-0001');
      expect(outMap['title'], 'App Crashes on Start');
      expect(outMap['severity'], 'critical');
      expect(outMap['status'], 'new');
    });
  });
}
