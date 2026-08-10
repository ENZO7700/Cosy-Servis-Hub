import 'package:centralny_dashboard/features/crm/models/crm_lead.dart';
import 'package:centralny_dashboard/features/crm/repositories/lead_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists CRM leads across IndexedDB repository instances', () async {
    final firstRepository = createLeadRepository();
    final now = DateTime(2026, 7, 18, 10);
    final lead = CrmLead(
      id: 'web-persistence-test',
      companyName: 'Web Persistence Test',
      importedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await firstRepository.save(lead);

    final reopenedRepository = createLeadRepository();
    final stored = await reopenedRepository.getAll();

    expect(
      stored.any(
        (item) =>
            item.id == lead.id && item.companyName == 'Web Persistence Test',
      ),
      isTrue,
    );

    await reopenedRepository.permanentDelete(lead.id);
  }, skip: !kIsWeb);
}
