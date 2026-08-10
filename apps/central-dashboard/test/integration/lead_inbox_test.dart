import 'package:centralny_dashboard/features/crm/models/crm_lead.dart';
import 'package:centralny_dashboard/features/crm/providers/lead_inbox_provider.dart';
import 'package:centralny_dashboard/features/crm/repositories/lead_repository.dart';
import 'package:centralny_dashboard/features/crm/services/lead_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrmLead', () {
    test('round-trips rich lead data and validates real email addresses', () {
      final lead = sampleLead(id: 'lead-1', email: 'Maria@Pulse-Clinic.co.uk')
          .copyWith(
            outreach: const LeadOutreach(
              subjectEn: 'Premium booking',
              emailEn: 'Hi Maria',
              subjectSk: 'Prémiový booking',
              emailSk: 'Ahoj Maria',
              linkedInMessage: 'Hi Maria',
              followUpDay5: 'Following up',
            ),
            offer: const LeadOffer(
              recommendedSolution: 'Booking PWA',
              coreFeatures: ['Self booking'],
              priceRange: 'Indicative £15k–£25k',
            ),
          );

      final copy = CrmLead.fromJson(lead.toJson());

      expect(copy.companyName, 'Pulse Laser Clinic');
      expect(copy.normalizedEmail, 'maria@pulse-clinic.co.uk');
      expect(copy.normalizedDomain, 'pulse-clinic.co.uk');
      expect(copy.hasValidEmail, isTrue);
      expect(copy.outreach.subjectEn, 'Premium booking');
      expect(copy.offer?.recommendedSolution, 'Booking PWA');
    });

    test('rejects descriptive contact channel as an email', () {
      final lead = sampleLead(id: 'lead-2', email: 'Cez web / LinkedIn');
      expect(lead.hasValidEmail, isFalse);
    });

    test('tolerates messy AI JSON types for score and partial_scores', () {
      final lead = CrmLead.fromJson({
        'company_name': 'Skin Lab',
        'score': '8.4',
        'partial_scores': {'fit': '9', 'urgency': 7.6},
        'version': 2.0,
        'sources': ['web'],
        'uncertain_fields': ['phone'],
      });

      expect(lead.companyName, 'Skin Lab');
      expect(lead.score, closeTo(8.4, 0.001));
      expect(lead.partialScores['fit'], 9);
      expect(lead.partialScores['urgency'], 7);
      expect(lead.version, 2);
      expect(lead.uncertainFields, ['phone']);
    });

    test('ignores non-map partial_scores from AI', () {
      final lead = CrmLead.fromJson({
        'company_name': 'Broken AI',
        'score': 5,
        'partial_scores': ['not', 'a', 'map'],
      });
      expect(lead.partialScores, isEmpty);
      expect(lead.score, 5);
    });
  });

  group('LeadInboxProvider', () {
    test('previews imports and skips an existing domain duplicate', () async {
      final repository = MemoryLeadRepository([
        sampleLead(id: 'existing', email: 'info@pulse-clinic.co.uk'),
      ]);
      final ai = FakeLeadAutomationService([
        sampleLead(id: 'duplicate', email: ''),
        sampleLead(
          id: 'new',
          companyName: 'Skin Perfection',
          website: 'skinperfectionlondon.co.uk',
          email: 'ayse@skinperfectionlondon.co.uk',
        ),
      ]);
      final provider = LeadInboxProvider(repository: repository, ai: ai);
      await provider.load();

      await provider.parseForPreview(
        'DAILY LEAD REPORT with two complete lead blocks for import.',
      );

      expect(provider.preview, hasLength(2));
      expect(provider.preview.first.duplicate, isTrue);
      expect(provider.preview.first.selected, isFalse);
      expect(provider.preview.last.duplicate, isFalse);

      final count = await provider.confirmImport();
      expect(count, 1);
      expect(provider.leads, hasLength(2));
      expect(
        provider.leads.any((lead) => lead.companyName == 'Skin Perfection'),
        isTrue,
      );
    });

    test('generates drafts and transitions to waiting after send', () async {
      final lead = sampleLead(id: 'send-me', email: 'info@pulse-clinic.co.uk');
      final repository = MemoryLeadRepository([lead]);
      final ai = FakeLeadAutomationService([lead]);
      final provider = LeadInboxProvider(repository: repository, ai: ai);
      await provider.load();

      await provider.generateOutreach(lead);
      final drafted = provider.leads.single;
      expect(drafted.pipelineStatus, 'draft_ready');
      expect(drafted.outreach.emailEn, isNotEmpty);

      await provider.generateOffer(drafted);
      final offered = provider.leads.single;
      expect(offered.offer?.recommendedSolution, 'Booking PWA');

      await provider.sendEmail(
        lead: offered,
        subject: offered.outreach.subjectEn,
        body: offered.outreach.emailEn,
        idempotencyKey: 'd1471b2e-1a4d-4d83-9fd4-4d91dc0c2fb1',
      );

      final sent = provider.leads.single;
      expect(sent.pipelineStatus, 'waiting');
      expect(sent.sentAt, isNotNull);
      expect(sent.followUpAt!.difference(sent.sentAt!).inDays, 5);
      expect(ai.sentCount, 1);
    });

    test('keeps approved state when Gmail send fails', () async {
      final lead = sampleLead(
        id: 'send-fails',
        email: 'info@pulse-clinic.co.uk',
      );
      final repository = MemoryLeadRepository([lead]);
      final ai = FakeLeadAutomationService([lead])..failSend = true;
      final provider = LeadInboxProvider(repository: repository, ai: ai);
      await provider.load();

      expect(
        () => provider.sendEmail(
          lead: lead,
          subject: 'Subject',
          body: 'Body',
          idempotencyKey: '176aa6ae-e7b7-4fbe-a882-95389830f246',
        ),
        throwsA(isA<LeadAiException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(provider.leads.single.pipelineStatus, 'approved');
      expect(provider.leads.single.sentAt, isNull);
    });
  });
}

CrmLead sampleLead({
  required String id,
  String companyName = 'Pulse Laser Clinic',
  String website = 'https://pulse-clinic.co.uk/about',
  String email = '',
}) {
  final now = DateTime(2026, 7, 18, 10);
  return CrmLead(
    id: id,
    companyName: companyName,
    website: website,
    location: 'London',
    companySize: '5-15',
    sector: 'Aesthetics',
    contactName: 'Maria Dinopoulos',
    contactRole: 'Director',
    email: email,
    score: 7,
    partialScores: const {'decision_maker': 2, 'trigger': 2},
    problem: 'Phone and email booking',
    decisionMaker: 'Verified founder',
    trigger: 'Technology partnership',
    revenueEstimate: '£300k-800k',
    sources: const ['pulse-clinic.co.uk'],
    rawText: 'LEAD — Pulse Laser Clinic',
    importedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

class MemoryLeadRepository extends BaseLeadRepository {
  final Map<String, CrmLead> records;

  MemoryLeadRepository(List<CrmLead> leads)
    : records = {for (final lead in leads) lead.id: lead};

  @override
  Future<void> permanentDelete(String leadId) async => records.remove(leadId);

  @override
  Future<List<CrmLead>> getAll() async => records.values.toList();

  @override
  Future<void> save(CrmLead lead) async => records[lead.id] = lead;
}

class FakeLeadAutomationService implements LeadAutomationService {
  final List<CrmLead> parsed;
  bool failSend = false;
  int sentCount = 0;

  FakeLeadAutomationService(this.parsed);

  @override
  Future<void> disconnectGmail() async {}

  @override
  Future<LeadOffer> generateOffer(CrmLead lead) async {
    return const LeadOffer(
      recommendedSolution: 'Booking PWA',
      problemAndBenefit: 'Simpler booking',
      coreFeatures: ['Self booking'],
      mvpScope: ['Booking form'],
      optionalExtensions: ['Analytics'],
      priceRange: 'Indicative £15k–£25k',
      duration: '8 weeks',
      nextStep: '15-minute call',
    );
  }

  @override
  Future<LeadOutreach> generateOutreach(CrmLead lead) async {
    return const LeadOutreach(
      subjectSk: 'Rezervácie',
      emailSk: 'Dobrý deň',
      subjectEn: 'Booking experience',
      emailEn: 'Hi Maria, worth 15 minutes?',
      linkedInMessage: 'Hi Maria',
      followUpDay5: 'Following up',
    );
  }

  @override
  Future<Uri> getGmailConnectUrl() async =>
      Uri.parse('https://accounts.google.com/o/oauth2/v2/auth');

  @override
  Future<GmailConnectionStatus> getGmailStatus() async =>
      const GmailConnectionStatus(connected: true, email: 'sender@example.com');

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
  }) async {
    if (failSend) throw const LeadAiException('Send failed');
    sentCount++;
  }
}
