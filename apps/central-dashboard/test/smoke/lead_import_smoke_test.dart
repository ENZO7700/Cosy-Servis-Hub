import 'package:centralny_dashboard/features/crm/models/crm_lead.dart';
import 'package:centralny_dashboard/features/crm/providers/lead_inbox_provider.dart';
import 'package:centralny_dashboard/features/crm/repositories/lead_repository.dart';
import 'package:centralny_dashboard/features/crm/services/lead_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Offline diagnostic smoke for CRM lead import path.
///
/// Covers:
/// - messy AI JSON parsing (root cause of silent import failures)
/// - short-text client guard
/// - provider preview / confirm import
/// - duplicate detection
void main() {
  group('SMOKE · lead import diagnostics', () {
    test('S1 · CrmLead.fromJson tolerates messy Mistral types', () {
      final lead = CrmLead.fromJson({
        'company_name': 'Acme Diagnostics s.r.o.',
        'score': '8.4',
        'partial_scores': {'fit': '9', 'urgency': 7.2, 'budget': '3'},
        'version': 1.0,
        'sources': ['LinkedIn', 42],
        'uncertain_fields': ['phone'],
        'email': 'info@acme.example',
        'website': 'https://www.acme.example/about',
      });

      expect(lead.companyName, 'Acme Diagnostics s.r.o.');
      expect(lead.score, closeTo(8.4, 0.001));
      expect(lead.partialScores['fit'], 9);
      expect(lead.partialScores['urgency'], 7);
      expect(lead.partialScores['budget'], 3);
      expect(lead.version, 1);
      expect(lead.sources, ['LinkedIn', '42']);
      expect(lead.hasValidEmail, isTrue);
      expect(lead.normalizedDomain, 'acme.example');
    });

    test('S2 · non-map partial_scores does not crash', () {
      final lead = CrmLead.fromJson({
        'company_name': 'Broken AI Shape',
        'score': 5,
        'partial_scores': ['not', 'a', 'map'],
      });
      expect(lead.partialScores, isEmpty);
      expect(lead.score, 5);
    });

    test('S3 · LeadAiService rejects short text before network', () async {
      final service = LeadAiService();
      expect(
        () => service.parseLeads('too short'),
        throwsA(
          isA<LeadAiException>().having(
            (e) => e.message,
            'message',
            contains('krátky'),
          ),
        ),
      );
    });

    test('S4 · provider shows clear error for short text', () async {
      final provider = LeadInboxProvider(
        repository: _MemoryRepo([]),
        ai: _FakeAi([]),
      );
      await provider.load();

      await provider.parseForPreview('x');
      expect(provider.parsing, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.error, contains('krátky'));
      expect(provider.preview, isEmpty);
    });

    test('S5 · provider surfaces AI errors instead of silent fail', () async {
      final provider = LeadInboxProvider(
        repository: _MemoryRepo([]),
        ai: _FakeAi([])..failParse = true,
      );
      await provider.load();

      await provider.parseForPreview(
        'LEAD 1 — Full enough daily report body for parse threshold check.',
      );
      expect(provider.parsing, isFalse);
      expect(provider.error, contains('Mistral nedostupný'));
      expect(provider.preview, isEmpty);
    });

    test('S6 · preview + confirm import + skip duplicate domain', () async {
      final existing = _sample(
        id: 'existing',
        company: 'Pulse Laser',
        website: 'pulse.example',
        email: 'a@pulse.example',
      );
      final duplicate = _sample(
        id: 'dup',
        company: 'Pulse Laser 2',
        website: 'https://www.pulse.example/x',
        email: '',
      );
      final fresh = _sample(
        id: 'fresh',
        company: 'Skin Lab',
        website: 'skin.example',
        email: 'b@skin.example',
      );

      final provider = LeadInboxProvider(
        repository: _MemoryRepo([existing]),
        ai: _FakeAi([duplicate, fresh]),
      );
      await provider.load();

      await provider.parseForPreview(
        'DAILY LEAD REPORT with two complete lead blocks for import smoke.',
      );

      expect(provider.error, isNull);
      expect(provider.preview, hasLength(2));
      expect(provider.preview.first.duplicate, isTrue);
      expect(provider.preview.first.selected, isFalse);
      expect(provider.preview.last.duplicate, isFalse);
      expect(provider.preview.last.selected, isTrue);

      final imported = await provider.confirmImport();
      expect(imported, 1);
      expect(provider.leads, hasLength(2));
      expect(provider.leads.any((l) => l.companyName == 'Skin Lab'), isTrue);
    });

    test('S7 · unexpected exception becomes visible error', () async {
      final provider = LeadInboxProvider(
        repository: _MemoryRepo([]),
        ai: _FakeAi([])..throwUnexpected = true,
      );
      await provider.load();

      await provider.parseForPreview(
        'LEAD report long enough to pass local length guard for smoke test.',
      );
      expect(provider.error, contains('boom-unexpected'));
      expect(provider.parsing, isFalse);
      expect(provider.parseProgress.phase, ParsePhase.failed);
      expect(provider.hasFailedChunks, isTrue);
    });

    test('S8 · chunked parse ends in done phase with preview', () async {
      final fresh = _sample(
        id: 'fresh',
        company: 'Chunk Clinic',
        website: 'chunk.example',
        email: 'c@chunk.example',
      );
      final provider = LeadInboxProvider(
        repository: _MemoryRepo([]),
        ai: _FakeAi([fresh]),
      );
      await provider.load();

      await provider.parseForPreview(
        'LEAD 1 — Chunk Clinic\nContact: Ana\nEmail: c@chunk.example\n'
        'Notes for daily report body to exceed parse threshold length.',
      );
      expect(provider.parsing, isFalse);
      expect(provider.parseProgress.phase, ParsePhase.done);
      expect(provider.preview, hasLength(1));
      expect(provider.hasFailedChunks, isFalse);
    });
  });
}

CrmLead _sample({
  required String id,
  required String company,
  required String website,
  required String email,
}) {
  final now = DateTime(2026, 7, 21, 8);
  return CrmLead(
    id: id,
    companyName: company,
    website: website,
    email: email,
    contactName: 'Contact $id',
    score: 8,
    importedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

class _MemoryRepo extends BaseLeadRepository {
  final Map<String, CrmLead> records;
  _MemoryRepo(List<CrmLead> leads)
    : records = {for (final lead in leads) lead.id: lead};

  @override
  Future<void> permanentDelete(String leadId) async => records.remove(leadId);

  @override
  Future<List<CrmLead>> getAll() async => records.values.toList();

  @override
  Future<void> save(CrmLead lead) async => records[lead.id] = lead;
}

class _FakeAi implements LeadAutomationService {
  final List<CrmLead> parsed;
  bool failParse = false;
  bool throwUnexpected = false;
  int chunkCalls = 0;

  _FakeAi(this.parsed);

  @override
  Future<List<CrmLead>> parseLeads(String rawText) async {
    if (throwUnexpected) {
      throw StateError('boom-unexpected');
    }
    if (failParse) {
      throw const LeadAiException('Mistral nedostupný');
    }
    // Mirror production client guard so smoke tests match real service.
    if (rawText.trim().length < 40) {
      throw const LeadAiException(
        'Text je príliš krátky. Vlož celý lead report (min. ~40 znakov).',
      );
    }
    return parsed;
  }

  @override
  Future<List<CrmLead>> parseLeadChunk(
    String rawText, {
    required String jobId,
    required int chunkIndex,
    required int chunkTotal,
  }) async {
    chunkCalls++;
    if (throwUnexpected) {
      throw StateError('boom-unexpected');
    }
    if (failParse) {
      throw const LeadAiException('Mistral nedostupný');
    }
    if (chunkIndex == 0) return parsed;
    return const [];
  }

  @override
  Future<void> disconnectGmail() async {}

  @override
  Future<LeadOffer> generateOffer(CrmLead lead) async => const LeadOffer();

  @override
  Future<LeadOutreach> generateOutreach(CrmLead lead) async =>
      const LeadOutreach();

  @override
  Future<Uri> getGmailConnectUrl() async => Uri.parse('https://example.com');

  @override
  Future<GmailConnectionStatus> getGmailStatus() async =>
      const GmailConnectionStatus(connected: false);

  @override
  Future<void> sendEmail({
    required CrmLead lead,
    required String subject,
    required String body,
    required String idempotencyKey,
  }) async {}
}
