import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import 'package:centralny_dashboard/core/ui/theme.dart';
import 'package:centralny_dashboard/core/database/isar_service.dart';
import 'package:centralny_dashboard/features/crm/providers/crm_provider.dart';
import 'package:centralny_dashboard/features/crm/providers/lead_inbox_provider.dart';
import 'package:centralny_dashboard/features/crm/screens/crm_dashboard_screen.dart';
import 'package:centralny_dashboard/features/crm/models/crm_lead.dart';
import 'package:centralny_dashboard/features/crm/repositories/lead_repository.dart';

/// In-memory LeadRepository for testing (no Isar, no disk)
class FakeLeadRepository extends BaseLeadRepository {
  final List<CrmLead> _store = [];

  FakeLeadRepository([List<CrmLead>? initial]) {
    if (initial != null) _store.addAll(initial);
  }

  @override
  Future<List<CrmLead>> getAll() async => List.from(_store);

  @override
  Future<void> save(CrmLead lead) async {
    _store.removeWhere((l) => l.id == lead.id);
    _store.add(lead);
  }

  @override
  Future<void> permanentDelete(String leadId) async {
    _store.removeWhere((l) => l.id == leadId);
  }
}

List<CrmLead> _buildTestLeads() {
  final now = DateTime.now();
  return [
    CrmLead(
      id: 'test-veezu',
      companyName: 'Veezu',
      contactName: 'Nathan Bowles',
      contactRole: 'Co-Founder & CEO',
      email: 'nathan.bowles@veezu.co.uk',
      website: 'veezu.co.uk',
      sector: 'Private Hire / Taxi',
      location: 'Cardiff HQ / UK-wide',
      country: 'UK',
      score: 9.0,
      scoreReason: '8,000+ driverov',
      notes: 'UK largest private hire operator.',
      pipelineStatus: 'new',
      rawText: 'LEAD 1',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
      importedAt: now.subtract(const Duration(days: 2)),
      tags: const ['UK', 'Taxi'],
    ),
    CrmLead(
      id: 'test-tooth-club',
      companyName: 'Tooth Club',
      contactName: 'Kunal Thakker',
      contactRole: 'Founder & CEO',
      email: 'kunal@toothclub.co.uk',
      website: 'toothclub.co.uk',
      sector: 'Multi-Site Dental Group',
      location: 'UK (19 sites)',
      country: 'UK',
      score: 9.0,
      scoreReason: '19 dental kliník',
      notes: 'Technický výpadok.',
      pipelineStatus: 'draft_ready',
      rawText: 'LEAD 2',
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(days: 3)),
      importedAt: now.subtract(const Duration(days: 3)),
      tags: const ['UK', 'Dental'],
    ),
    CrmLead(
      id: 'test-wefix',
      companyName: 'WeFix London',
      contactName: 'Scott Mullins',
      contactRole: 'CEO',
      email: 'scott@wefix.london',
      website: 'wefix.london',
      sector: 'Plumbing & Emergency Services',
      location: 'London',
      country: 'UK',
      score: 9.0,
      scoreReason: 'Rekordné emergency výjazdy',
      notes: '24/7 nonstop recepcia.',
      pipelineStatus: 'follow_up_due',
      rawText: 'LEAD 3',
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now.subtract(const Duration(days: 10)),
      importedAt: now.subtract(const Duration(days: 10)),
      tags: const ['UK', 'Emergency'],
    ),
  ];
}

void main() {
  group('CRM Lead Integration Tests', () {
    setUpAll(() async {
      GoogleFonts.config.allowRuntimeFetching = false;
      IsarService.isMock = true;
      const MethodChannel channel = MethodChannel(
        'plugins.flutter.io/path_provider',
      );
      final tempDir = Directory.systemTemp.createTempSync(
        'isar_test_crm_lead_integration_',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return tempDir.path;
          });
      await Isar.initializeIsarCore(download: true);

      final isarService = IsarService();
      await isarService.init();
    });

    tearDownAll(() {
      IsarService.isMock = false;
    });

    testWidgets('CRM Dashboard shows lead tabs and seeded leads', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testLeads = _buildTestLeads();
      final fakeRepo = FakeLeadRepository(testLeads);
      final leadProvider = LeadInboxProvider(repository: fakeRepo);
      final crmProvider = CrmProvider();

      // Wait for async load to complete
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 200)),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<CrmProvider>.value(value: crmProvider),
              ChangeNotifierProvider<LeadInboxProvider>.value(
                value: leadProvider,
              ),
            ],
            child: const Scaffold(body: CrmDashboardScreen()),
          ),
        ),
      );

      // Use pump() instead of pumpAndSettle() — TabBar animation never fully settles
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Verify main header
      expect(find.textContaining('CRM'), findsAtLeastNWidgets(1));

      // 2. Verify tabs exist
      expect(find.text('AI Leady z Reportov'), findsOneWidget);
      expect(find.text('CRM Klienti'), findsOneWidget);

      // 3. Verify lead cards are displayed
      expect(find.text('Veezu'), findsOneWidget);
      expect(find.text('Tooth Club'), findsOneWidget);
      expect(find.text('WeFix London'), findsOneWidget);

      // 4. Verify contact names
      expect(find.text('Nathan Bowles'), findsOneWidget);
      expect(find.text('Kunal Thakker'), findsOneWidget);
      expect(find.text('Scott Mullins'), findsOneWidget);

      // 5. Verify filter chips are present
      expect(find.text('Všetky leady'), findsOneWidget);
      expect(find.text('Nové'), findsOneWidget);
      expect(find.text('Pripravené drafty'), findsOneWidget);

      // 6. Test filter: click "Nové" — should show only Veezu (pipelineStatus: new)
      await tester.tap(find.text('Nové'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Veezu'), findsOneWidget);
      expect(find.text('Tooth Club'), findsNothing);
      expect(find.text('WeFix London'), findsNothing);

      // 7. Reset to all
      await tester.tap(find.text('Všetky leady'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Veezu'), findsOneWidget);
      expect(find.text('Tooth Club'), findsOneWidget);
      expect(find.text('WeFix London'), findsOneWidget);

      // 8. Verify CRM action cards
      expect(find.text('CRM Lead Management & Workflow'), findsOneWidget);
    });
  });
}
