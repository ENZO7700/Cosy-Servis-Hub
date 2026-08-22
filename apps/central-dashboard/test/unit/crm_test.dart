import 'package:flutter_test/flutter_test.dart';
import 'package:centralny_dashboard/features/crm/models/crm_models.dart';

void main() {
  group('CRM Models JSON serialization and deserialization tests', () {
    test('CrmClientTask toMap and fromMap/fromJson mapping', () {
      final now = DateTime.now();
      final task = CrmClientTask(
        id: 'task_1',
        text: 'Naceniť eshop',
        done: false,
        dueDate: '2026-06-10',
        createdAt: now,
        updatedAt: now,
      );

      final json = task.toJson();
      expect(json['id'], 'task_1');
      expect(json['text'], 'Naceniť eshop');
      expect(json['done'], false);
      expect(json['dueDate'], '2026-06-10');

      final taskCopy = CrmClientTask.fromJson(json);
      expect(taskCopy.id, task.id);
      expect(taskCopy.text, task.text);
      expect(taskCopy.done, task.done);
      expect(taskCopy.dueDate, task.dueDate);
      expect(taskCopy.createdAt.year, task.createdAt.year);
    });

    test('CrmClient toMap and fromMap/fromJson mapping', () {
      final now = DateTime.now();
      final client = CrmClient(
        id: 'client_uuid',
        companyName: 'Nexify Labs s.r.o.',
        contactName: 'Ján Kováč',
        email: 'kovac@nexify.tech',
        phone: '+421900123456',
        website: 'https://nexify.tech',
        service: 'PWA aplikácia',
        status: 'Vo vývoji',
        budget: '2500 €',
        notes: 'Súrne dokončiť MVP',
        tasks: [
          CrmClientTask(
            id: 'task_1',
            text: 'Dokončiť Isar lokálny core',
            done: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      );

      final json = client.toJson();
      expect(json['id'], 'client_uuid');
      expect(json['companyName'], 'Nexify Labs s.r.o.');
      expect(json['contactName'], 'Ján Kováč');
      expect(json['email'], 'kovac@nexify.tech');
      expect(json['service'], 'PWA aplikácia');
      expect(json['status'], 'Vo vývoji');
      expect(json['budget'], '2500 €');
      expect(json['syncStatus'], 'pending');

      final clientCopy = CrmClient.fromJson(json);
      expect(clientCopy.id, client.id);
      expect(clientCopy.companyName, client.companyName);
      expect(clientCopy.contactName, client.contactName);
      expect(clientCopy.email, client.email);
      expect(clientCopy.service, client.service);
      expect(clientCopy.status, client.status);
      expect(clientCopy.budget, client.budget);
      expect(clientCopy.syncStatus, client.syncStatus);
      expect(clientCopy.tasks.length, 1);
      expect(clientCopy.tasks.first.text, 'Dokončiť Isar lokálny core');
      expect(clientCopy.tasks.first.done, true);
    });

    test('CrmClientActivity toMap and fromMap/fromJson mapping', () {
      final now = DateTime.now();
      final activity = CrmClientActivity(
        id: 'activity_uuid',
        clientId: 'client_uuid',
        type: 'meeting',
        title: 'Úvodný kick-off míting',
        content: 'Prešli sme si wireframy a budget.',
        createdAt: now,
      );

      final json = activity.toJson();
      expect(json['id'], 'activity_uuid');
      expect(json['clientId'], 'client_uuid');
      expect(json['type'], 'meeting');
      expect(json['title'], 'Úvodný kick-off míting');
      expect(json['content'], 'Prešli sme si wireframy a budget.');

      final activityCopy = CrmClientActivity.fromJson(json);
      expect(activityCopy.id, activity.id);
      expect(activityCopy.clientId, activity.clientId);
      expect(activityCopy.type, activity.type);
      expect(activityCopy.title, activity.title);
      expect(activityCopy.content, activity.content);
    });
  });
}
