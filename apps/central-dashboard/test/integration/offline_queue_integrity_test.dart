// ignore_for_file: avoid_print
// Integrity Tests — Offline Queue
//
// Verifies that CRM operations are properly enqueued in the Isar
// offline queue and can be read back with correct operation types
// and JSON payloads.

import 'dart:convert';
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
    final isar = isarService.isar;
    await isar.writeTxn(() async {
      await isar.isarOfflineQueues.clear();
      await isar.isarClients.clear();
    });
  });

  group('Offline Queue Integrity', () {
    test('addToQueue stores operation with correct type and payload', () async {
      final payload = jsonEncode({
        'id': 'client-001',
        'companyName': 'Test Firma',
        'status': 'lead',
      });

      await isarService.addToQueue('crm_create_client', 'client-001', payload);

      final queue = await isarService.getOfflineQueue();
      expect(queue.length, 1);
      expect(queue.first.operation, 'crm_create_client');
      expect(queue.first.bugId, 'client-001');
      expect(queue.first.createdAt, isNotNull);

      // Verify payload is valid JSON and can be decoded
      final decoded = jsonDecode(queue.first.payload!);
      expect(decoded['id'], 'client-001');
      expect(decoded['companyName'], 'Test Firma');
      expect(decoded['status'], 'lead');
    });

    test('Multiple operations maintain chronological order', () async {
      final operations = [
        'crm_create_client',
        'crm_update_client',
        'crm_add_task',
        'crm_delete_client',
      ];

      for (int i = 0; i < operations.length; i++) {
        await isarService.addToQueue(
          operations[i],
          'client-$i',
          jsonEncode({'index': i}),
        );
        // Small delay to ensure distinct timestamps
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final queue = await isarService.getOfflineQueue();
      expect(queue.length, 4);

      // Queue is sorted by createdAt (ascending)
      for (int i = 0; i < operations.length; i++) {
        expect(queue[i].operation, operations[i]);
      }
    });

    test('removeFromQueue only removes target item', () async {
      await isarService.addToQueue(
        'crm_create_client',
        'a',
        jsonEncode({'op': 'a'}),
      );
      await Future.delayed(const Duration(milliseconds: 10));
      await isarService.addToQueue(
        'crm_update_client',
        'b',
        jsonEncode({'op': 'b'}),
      );
      await Future.delayed(const Duration(milliseconds: 10));
      await isarService.addToQueue(
        'crm_delete_client',
        'c',
        jsonEncode({'op': 'c'}),
      );

      final queue = await isarService.getOfflineQueue();
      expect(queue.length, 3);

      // Remove the middle item
      await isarService.removeFromQueue(queue[1].isarId!);

      final after = await isarService.getOfflineQueue();
      expect(after.length, 2);
      expect(after[0].operation, 'crm_create_client');
      expect(after[1].operation, 'crm_delete_client');
    });

    test('Queue payload survives special characters and unicode', () async {
      final payload = jsonEncode({
        'companyName': 'Špeciálna Firma s.r.o. — ťažký prípad',
        'notes': 'Poznámka s diakritikou: ľščťžýáíéúäôň 🚀',
        'budget': '€ 1 500,00',
      });

      await isarService.addToQueue('crm_create_client', 'unicode-1', payload);

      final queue = await isarService.getOfflineQueue();
      final decoded = jsonDecode(queue.first.payload!);
      expect(decoded['companyName'], 'Špeciálna Firma s.r.o. — ťažký prípad');
      expect(decoded['notes'], contains('ľščťžýáíéúäôň'));
      expect(decoded['notes'], contains('🚀'));
      expect(decoded['budget'], '€ 1 500,00');
    });

    test('getCrmPendingQueueCount returns correct count', () async {
      // Create 3 clients: 2 pending, 1 synced
      final list = ['pending', 'synced', 'pending'];
      for (int i = 0; i < list.length; i++) {
        final status = list[i];
        final client = IsarClient()
          ..id = 'count-$status-$i'
          ..companyName = 'Count Test'
          ..status = 'lead'
          ..service = 'Test'
          ..syncStatus = status
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();
        await isarService.saveLocalClient(client);
      }

      final count = await isarService.getCrmPendingQueueCount();
      expect(
        count,
        2,
        reason: 'Should count only clients with syncStatus=pending',
      );
    });
  });
}
