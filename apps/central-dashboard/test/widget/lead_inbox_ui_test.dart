import 'package:centralny_dashboard/features/crm/models/crm_lead.dart';
import 'package:centralny_dashboard/features/crm/providers/lead_inbox_provider.dart';
import 'package:centralny_dashboard/features/crm/repositories/lead_repository.dart';
import 'package:centralny_dashboard/features/leads/lead_inbox_screen.dart';
import 'package:centralny_dashboard/features/crm/services/lead_ai_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('opens report preview and imports a selected lead', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final existing = _lead('existing', 'Pulse Laser Clinic');
    final imported = _lead('new-lead', 'Skin Perfection London');
    final repository = _MemoryRepository([existing]);
    final provider = LeadInboxProvider(
      repository: repository,
      ai: _FakeAutomation([imported]),
    );
    await provider.load();

    await tester.pumpWidget(
      ChangeNotifierProvider<LeadInboxProvider>.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const LeadInboxScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Lead Inbox'), findsOneWidget);
    expect(find.text('Pulse Laser Clinic'), findsOneWidget);

    await tester.tap(find.byKey(const Key('open_lead_import')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('lead_import_text')),
      'DAILY LEAD REPORT with Skin Perfection London details',
    );
    await tester.tap(find.byKey(const Key('parse_leads_button')));
    await tester.pumpAndSettle();

    expect(find.text('Skin Perfection London'), findsOneWidget);
    expect(find.textContaining('Nič sa neuloží'), findsNothing);

    await tester.tap(find.byKey(const Key('confirm_lead_import')));
    await tester.pumpAndSettle();

    expect(find.text('Skin Perfection London'), findsOneWidget);
    expect(provider.leads, hasLength(2));
  });
}

CrmLead _lead(String id, String company) {
  final now = DateTime(2026, 7, 18);
  return CrmLead(
    id: id,
    companyName: company,
    website: '$id.example.com',
    contactName: 'Test Contact',
    email: 'contact@$id.example.com',
    score: 8,
    importedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

class _MemoryRepository extends BaseLeadRepository {
  final Map<String, CrmLead> records;

  _MemoryRepository(List<CrmLead> leads)
    : records = {for (final lead in leads) lead.id: lead};

  @override
  Future<void> permanentDelete(String leadId) async => records.remove(leadId);

  @override
  Future<List<CrmLead>> getAll() async => records.values.toList();

  @override
  Future<void> save(CrmLead lead) async => records[lead.id] = lead;
}

class _FakeAutomation implements LeadAutomationService {
  final List<CrmLead> parsed;
  _FakeAutomation(this.parsed);

  @override
  Future<void> disconnectGmail() async {}

  @override
  Future<LeadOffer> generateOffer(CrmLead lead) async =>
      const LeadOffer(recommendedSolution: 'PWA');

  @override
  Future<LeadOutreach> generateOutreach(CrmLead lead) async =>
      const LeadOutreach(emailEn: 'Draft');

  @override
  Future<Uri> getGmailConnectUrl() async =>
      Uri.parse('https://accounts.google.com');

  @override
  Future<GmailConnectionStatus> getGmailStatus() async =>
      const GmailConnectionStatus(connected: false);

  @override
  Future<List<CrmLead>> parseLeads(String rawText) async => parsed;

  @override
  Future<List<CrmLead>> parseLeadChunk(
    String rawText, {
    required String jobId,
    required int chunkIndex,
    required int chunkTotal,
  }) async {
    if (chunkIndex == 0) return parsed;
    return const [];
  }

  @override
  Future<void> sendEmail({
    required CrmLead lead,
    required String subject,
    required String body,
    required String idempotencyKey,
  }) async {}
}
