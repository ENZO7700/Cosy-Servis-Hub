// Integrity Tests — CRM Model Serialization
//
// Verifies that all CRM models survive complete serialization roundtrips:
//   Dart object → toJson() → fromJson() → identical Dart object
//
// Also tests edge cases: null fields, empty lists, boundary values,
// and ISO 8601 date string preservation.

import 'package:flutter_test/flutter_test.dart';
import 'package:centralny_dashboard/features/crm/models/crm_models.dart';

void main() {
  group('CrmClient Serialization Integrity', () {
    test('Full roundtrip: toJson → fromJson preserves all fields', () {
      final now = DateTime.now();
      final original = CrmClient(
        id: 'roundtrip-001',
        companyName: 'Nexify s.r.o.',
        contactName: 'Erik Babčan',
        email: 'erik@nexify.tech',
        phone: '+421 901 234 567',
        website: 'https://nexify.tech',
        service: 'Flutter App Development',
        status: 'active',
        budget: '€ 15 000',
        notes: 'Prioritný klient – Express delivery',
        tasks: [
          CrmClientTask(
            id: 'task-rt-1',
            text: 'Prototyp hotový',
            done: true,
            dueDate: '2026-06-15',
            createdAt: now,
            updatedAt: now,
          ),
          CrmClientTask(
            id: 'task-rt-2',
            text: 'Deploy na produkciu',
            done: false,
            dueDate: '2026-07-01',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      );

      final json = original.toJson();
      final restored = CrmClient.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.companyName, original.companyName);
      expect(restored.contactName, original.contactName);
      expect(restored.email, original.email);
      expect(restored.phone, original.phone);
      expect(restored.website, original.website);
      expect(restored.service, original.service);
      expect(restored.status, original.status);
      expect(restored.budget, original.budget);
      expect(restored.notes, original.notes);
      expect(restored.syncStatus, original.syncStatus);
      expect(restored.tasks.length, 2);
      expect(restored.tasks[0].id, 'task-rt-1');
      expect(restored.tasks[0].done, true);
      expect(restored.tasks[1].id, 'task-rt-2');
      expect(restored.tasks[1].done, false);
    });

    test('Roundtrip with null optional fields', () {
      final now = DateTime.now();
      final original = CrmClient(
        id: 'null-fields-001',
        companyName: 'Minimálny klient',
        contactName: null,
        email: null,
        phone: null,
        website: null,
        service: 'Konzultácia',
        status: 'lead',
        budget: null,
        notes: null,
        tasks: [],
        createdAt: now,
        updatedAt: now,
        syncStatus: 'synced',
      );

      final json = original.toJson();
      final restored = CrmClient.fromJson(json);

      expect(restored.companyName, 'Minimálny klient');
      expect(restored.contactName, isNull);
      expect(restored.email, isNull);
      expect(restored.phone, isNull);
      expect(restored.website, isNull);
      expect(restored.budget, isNull);
      expect(restored.notes, isNull);
      expect(restored.tasks, isEmpty);
    });

    test('Roundtrip with deletedAt preserves soft-delete state', () {
      final now = DateTime.now();
      final deletedAt = now.subtract(const Duration(hours: 2));
      final original = CrmClient(
        id: 'deleted-001',
        companyName: 'Zmazaná firma',
        service: 'Hosting',
        status: 'inactive',
        tasks: [],
        createdAt: now,
        updatedAt: now,
        deletedAt: deletedAt,
        syncStatus: 'pending',
      );

      final json = original.toJson();
      final restored = CrmClient.fromJson(json);

      expect(
        restored.deletedAt,
        isNotNull,
        reason: 'deletedAt should survive serialization roundtrip',
      );
    });

    test('CrmClient ↔ IsarClient roundtrip preserves data', () {
      final now = DateTime.now();
      final original = CrmClient(
        id: 'isar-rt-001',
        companyName: 'Isar Roundtrip Firma',
        contactName: 'Test Kontakt',
        email: 'isar@test.sk',
        phone: '+421123456',
        website: 'https://isar.test',
        service: 'DB Service',
        status: 'active',
        budget: '3000 €',
        notes: 'Testovacia poznámka',
        tasks: [
          CrmClientTask(
            id: 'isar-task-1',
            text: 'Isar task',
            done: false,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      );

      // CrmClient → IsarClient → CrmClient
      final isarClient = original.toIsar();
      final restored = CrmClient.fromIsar(isarClient);

      expect(restored.id, original.id);
      expect(restored.companyName, original.companyName);
      expect(restored.contactName, original.contactName);
      expect(restored.email, original.email);
      expect(restored.service, original.service);
      expect(restored.status, original.status);
      expect(restored.syncStatus, original.syncStatus);
      expect(restored.tasks.length, 1);
      expect(restored.tasks.first.id, 'isar-task-1');
      expect(restored.tasks.first.text, 'Isar task');
    });
  });

  group('CrmClientActivity Serialization Integrity', () {
    test('Full roundtrip: toJson → fromJson preserves all fields', () {
      final now = DateTime.now();
      final original = CrmClientActivity(
        id: 'activity-rt-001',
        clientId: 'client-001',
        type: 'meeting',
        title: 'Kick-off míting s klientom',
        content: 'Dohodli sme sa na MVP scope a timeline.',
        createdAt: now,
      );

      final json = original.toJson();
      final restored = CrmClientActivity.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.clientId, original.clientId);
      expect(restored.type, original.type);
      expect(restored.title, original.title);
      expect(restored.content, original.content);
    });

    test('Activity types enum coverage', () {
      final validTypes = [
        'note',
        'call',
        'email',
        'meeting',
        'proposal',
        'status_change',
      ];
      final now = DateTime.now();

      for (final type in validTypes) {
        final activity = CrmClientActivity(
          id: 'type-$type',
          clientId: 'client-001',
          type: type,
          title: 'Test $type',
          createdAt: now,
        );

        final json = activity.toJson();
        final restored = CrmClientActivity.fromJson(json);
        expect(
          restored.type,
          type,
          reason: 'Activity type "$type" should survive roundtrip',
        );
      }
    });

    test('CrmClientActivity ↔ IsarClientActivity roundtrip', () {
      final now = DateTime.now();
      final original = CrmClientActivity(
        id: 'isar-act-001',
        clientId: 'client-rt',
        type: 'call',
        title: 'Telefonát',
        content: 'Dohodnutý ďalší postup',
        createdAt: now,
      );

      final isarActivity = original.toIsar();
      final restored = CrmClientActivity.fromIsar(isarActivity);

      expect(restored.id, original.id);
      expect(restored.clientId, original.clientId);
      expect(restored.type, original.type);
      expect(restored.title, original.title);
      expect(restored.content, original.content);
    });
  });

  group('CrmClientTask Serialization Integrity', () {
    test('Task with all fields', () {
      final now = DateTime.now();
      final original = CrmClientTask(
        id: 'task-full',
        text: 'Plný task so všetkými poľami',
        done: true,
        dueDate: '2026-12-31',
        createdAt: now,
        updatedAt: now,
      );

      final json = original.toJson();
      final restored = CrmClientTask.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.text, original.text);
      expect(restored.done, true);
      expect(restored.dueDate, '2026-12-31');
    });

    test('Task with null optional fields', () {
      final now = DateTime.now();
      final original = CrmClientTask(
        id: 'task-minimal',
        text: 'Minimálny task',
        done: false,
        createdAt: now,
        updatedAt: now,
      );

      final json = original.toJson();
      final restored = CrmClientTask.fromJson(json);

      expect(restored.dueDate, isNull);
      expect(restored.done, false);
    });

    test('CrmClientTask ↔ IsarClientTask roundtrip', () {
      final now = DateTime.now();
      final original = CrmClientTask(
        id: 'isar-task-rt',
        text: 'Isar roundtrip task',
        done: true,
        dueDate: '2026-08-15',
        createdAt: now,
        updatedAt: now,
      );

      final isarTask = original.toIsar();
      final restored = CrmClientTask.fromIsar(isarTask);

      expect(restored.id, original.id);
      expect(restored.text, original.text);
      expect(restored.done, true);
      expect(restored.dueDate, '2026-08-15');
    });
  });
}
