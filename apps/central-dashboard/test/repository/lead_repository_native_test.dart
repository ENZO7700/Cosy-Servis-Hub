import 'dart:io';

import 'package:centralny_dashboard/core/database/isar_service.dart';
import 'package:centralny_dashboard/features/crm/models/crm_lead.dart';
import 'package:centralny_dashboard/features/crm/repositories/lead_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:sembast/sembast_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists CRM leads across native Isar repository instances', () async {
    final directory = Directory.systemTemp.createTempSync(
      'cmr-lead-native-test-',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => directory.path);

    await Isar.initializeIsarCore(download: true);
    await IsarService().init();

    final now = DateTime(2026, 7, 19, 10);
    final lead = CrmLead(
      id: 'native-persistence-test',
      companyName: 'Native Persistence Test',
      importedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    final firstRepository = createLeadRepository();
    await firstRepository.save(lead);

    final reopenedRepository = createLeadRepository();
    final stored = await reopenedRepository.getAll();

    expect(
      stored.any(
        (item) => item.id == lead.id && item.companyName == lead.companyName,
      ),
      isTrue,
    );

    await reopenedRepository.permanentDelete(lead.id);

    final legacyLead = CrmLead(
      id: 'legacy-sembast-migration-test',
      companyName: 'Legacy Sembast Migration Test',
      importedAt: now.add(const Duration(minutes: 1)),
      createdAt: now.add(const Duration(minutes: 1)),
      updatedAt: now.add(const Duration(minutes: 1)),
    );
    final legacyDatabase = await databaseFactoryIo.openDatabase(
      '${directory.path}/cmr_plus_lead_inbox.db',
    );
    await stringMapStoreFactory
        .store('crm_leads')
        .record(legacyLead.id)
        .put(legacyDatabase, legacyLead.toJson());
    await legacyDatabase.close();

    final migrationRepository = createLeadRepository();
    final migrated = await migrationRepository.getAll();
    expect(
      migrated.any(
        (item) =>
            item.id == legacyLead.id &&
            item.companyName == legacyLead.companyName,
      ),
      isTrue,
    );

    await migrationRepository.permanentDelete(legacyLead.id);
  });
}
