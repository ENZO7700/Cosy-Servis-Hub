// ignore_for_file: avoid_print
// Integrity Tests — CRM Client CRUD lifecycle via IsarService
//
// Verifies that CrmClient data survives complete CRUD roundtrips
// through the Isar local database without data loss or corruption.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart';
import 'package:centralny_dashboard/core/database/isar_service.dart';
import 'package:centralny_dashboard/core/database/isar_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IsarService isarService;

  setUpAll(() async {
    const MethodChannel channel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '.';
        });

    await Isar.initializeIsarCore(download: true);
    isarService = IsarService();
    await isarService.init();
  });

  setUp(() async {
    // Clean up all clients before each test
    final isar = isarService.isar;
    await isar.writeTxn(() async {
      await isar.isarClients.clear();
      await isar.isarClientActivitys.clear();
      await isar.isarOfflineQueues.clear();
    });
  });

  group('CRM Client CRUD Integrity', () {
    test('CREATE → READ roundtrip preserves all fields', () async {
      final now = DateTime.now();
      final client = IsarClient()
        ..id = 'test-client-001'
        ..companyName = 'Nexify Labs s.r.o.'
        ..contactName = 'Ján Kováč'
        ..email = 'kovac@nexify.tech'
        ..phone = '+421900123456'
        ..website = 'https://nexify.tech'
        ..service = 'PWA aplikácia'
        ..status = 'lead'
        ..budget = '2500 €'
        ..notes = 'Súrne dokončiť MVP'
        ..tasks = [
          IsarClientTask()
            ..id = 'task-001'
            ..text = 'Dokončiť Isar core'
            ..done = false
            ..dueDate = '2026-07-01'
            ..createdAt = now
            ..updatedAt = now,
        ]
        ..createdAt = now
        ..updatedAt = now
        ..syncStatus = 'pending';

      await isarService.saveLocalClient(client);

      final clients = await isarService.getCachedClients();
      expect(clients.length, 1, reason: 'One client should be stored');

      final loaded = clients.first;
      expect(loaded.id, 'test-client-001');
      expect(loaded.companyName, 'Nexify Labs s.r.o.');
      expect(loaded.contactName, 'Ján Kováč');
      expect(loaded.email, 'kovac@nexify.tech');
      expect(loaded.phone, '+421900123456');
      expect(loaded.website, 'https://nexify.tech');
      expect(loaded.service, 'PWA aplikácia');
      expect(loaded.status, 'lead');
      expect(loaded.budget, '2500 €');
      expect(loaded.notes, 'Súrne dokončiť MVP');
      expect(loaded.syncStatus, 'pending');
      expect(loaded.deletedAt, isNull);

      // Verify embedded tasks
      expect(loaded.tasks, isNotNull);
      expect(loaded.tasks!.length, 1);
      expect(loaded.tasks!.first.id, 'task-001');
      expect(loaded.tasks!.first.text, 'Dokončiť Isar core');
      expect(loaded.tasks!.first.done, false);
      expect(loaded.tasks!.first.dueDate, '2026-07-01');
    });

    test('UPDATE preserves identity and modifies changed fields', () async {
      final now = DateTime.now();
      final client = IsarClient()
        ..id = 'test-client-002'
        ..companyName = 'Pôvodný Názov'
        ..contactName = 'Osoba A'
        ..email = 'a@test.sk'
        ..status = 'lead'
        ..service = 'SEO'
        ..syncStatus = 'synced'
        ..createdAt = now
        ..updatedAt = now;

      await isarService.saveLocalClient(client);

      // Update
      final updated = IsarClient()
        ..id = 'test-client-002'
        ..companyName = 'Nový Názov'
        ..contactName = 'Osoba B'
        ..email = 'b@test.sk'
        ..status = 'active'
        ..service = 'SEO + PPC'
        ..syncStatus = 'pending'
        ..createdAt = now
        ..updatedAt = DateTime.now();

      await isarService.saveLocalClient(updated);

      final clients = await isarService.getCachedClients();
      expect(clients.length, 1, reason: 'Update should replace, not duplicate');

      final loaded = clients.first;
      expect(loaded.id, 'test-client-002');
      expect(loaded.companyName, 'Nový Názov');
      expect(loaded.contactName, 'Osoba B');
      expect(loaded.email, 'b@test.sk');
      expect(loaded.status, 'active');
      expect(loaded.service, 'SEO + PPC');
      expect(loaded.syncStatus, 'pending');
    });

    test('SOFT DELETE sets deletedAt without removing record', () async {
      final client = IsarClient()
        ..id = 'test-client-003'
        ..companyName = 'Firma na vymazanie'
        ..contactName = 'Test'
        ..status = 'lead'
        ..service = 'Web'
        ..syncStatus = 'synced'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await isarService.saveLocalClient(client);
      await isarService.deleteLocalClient('test-client-003');

      final clients = await isarService.getCachedClients();
      expect(clients.length, 1, reason: 'Soft delete should preserve record');

      final loaded = clients.first;
      expect(
        loaded.deletedAt,
        isNotNull,
        reason: 'deletedAt should be set after soft delete',
      );
      expect(
        loaded.syncStatus,
        'pending',
        reason: 'syncStatus should change to pending after soft delete',
      );
    });

    test('RESTORE after soft delete clears deletedAt', () async {
      final client = IsarClient()
        ..id = 'test-client-004'
        ..companyName = 'Firma na obnovenie'
        ..contactName = 'Test'
        ..status = 'lead'
        ..service = 'Web'
        ..syncStatus = 'synced'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await isarService.saveLocalClient(client);
      await isarService.deleteLocalClient('test-client-004');
      await isarService.restoreLocalClient('test-client-004');

      final clients = await isarService.getCachedClients();
      expect(clients.length, 1);

      final loaded = clients.first;
      expect(
        loaded.deletedAt,
        isNull,
        reason: 'deletedAt should be cleared after restore',
      );
      expect(loaded.syncStatus, 'pending');
    });

    test('PERMANENT DELETE removes record entirely', () async {
      final client = IsarClient()
        ..id = 'test-client-005'
        ..companyName = 'Firma na trvalé vymazanie'
        ..contactName = 'Test'
        ..status = 'inactive'
        ..service = 'Hosting'
        ..syncStatus = 'synced'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await isarService.saveLocalClient(client);
      await isarService.permanentlyDeleteLocalClient('test-client-005');

      final clients = await isarService.getCachedClients();
      expect(
        clients.length,
        0,
        reason: 'Permanent delete should remove record from DB',
      );
    });

    test('Multiple clients coexist independently', () async {
      final now = DateTime.now();
      for (int i = 1; i <= 5; i++) {
        final client = IsarClient()
          ..id = 'multi-client-$i'
          ..companyName = 'Firma $i'
          ..contactName = 'Osoba $i'
          ..status = i <= 3 ? 'lead' : 'active'
          ..service = 'Služba $i'
          ..syncStatus = 'synced'
          ..createdAt = now
          ..updatedAt = now;
        await isarService.saveLocalClient(client);
      }

      final clients = await isarService.getCachedClients();
      expect(clients.length, 5);

      // Soft delete one
      await isarService.deleteLocalClient('multi-client-3');
      // Permanently delete another
      await isarService.permanentlyDeleteLocalClient('multi-client-5');

      final remaining = await isarService.getCachedClients();
      expect(
        remaining.length,
        4,
        reason: 'Soft delete keeps record, permanent delete removes',
      );

      final softDeleted = remaining.firstWhere((c) => c.id == 'multi-client-3');
      expect(softDeleted.deletedAt, isNotNull);

      expect(
        remaining.any((c) => c.id == 'multi-client-5'),
        false,
        reason: 'Permanently deleted client should not exist',
      );
    });
  });
}
