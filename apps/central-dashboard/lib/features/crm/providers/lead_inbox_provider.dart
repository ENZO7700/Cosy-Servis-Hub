import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/crm_lead.dart';
import '../repositories/lead_repository.dart';
import '../services/lead_ai_service.dart';
import '../utils/lead_report_splitter.dart';

class LeadImportCandidate {
  final CrmLead lead;
  bool selected;
  final bool duplicate;

  LeadImportCandidate({
    required this.lead,
    this.selected = true,
    this.duplicate = false,
  });
}

enum ParsePhase {
  idle,
  preparing,
  chunking,
  parsing,
  merging,
  done,
  partial,
  failed,
  cancelled,
}

class ParseProgress {
  final ParsePhase phase;
  final int chunkIndex;
  final int chunkTotal;
  final int leadsFound;
  final int chunksFailed;
  final String statusLine;
  final double value;

  const ParseProgress({
    this.phase = ParsePhase.idle,
    this.chunkIndex = 0,
    this.chunkTotal = 0,
    this.leadsFound = 0,
    this.chunksFailed = 0,
    this.statusLine = '',
    this.value = 0,
  });

  bool get isActive =>
      phase == ParsePhase.preparing ||
      phase == ParsePhase.chunking ||
      phase == ParsePhase.parsing ||
      phase == ParsePhase.merging;
}

class _FailedParseChunk {
  final int index;
  final String text;
  final String reason;

  const _FailedParseChunk({
    required this.index,
    required this.text,
    required this.reason,
  });
}

class LeadInboxProvider extends ChangeNotifier {
  final LeadRepository _repository;
  final LeadAutomationService _ai;
  final Uuid _uuid;
  final LeadReportSplitter _splitter;

  LeadInboxProvider({
    LeadRepository? repository,
    LeadAutomationService? ai,
    Uuid? uuid,
    LeadReportSplitter? splitter,
  }) : _repository = repository ?? createLeadRepository(),
       _ai = ai ?? LeadAiService(),
       _uuid = uuid ?? const Uuid(),
       _splitter = splitter ?? const LeadReportSplitter() {
    load();
  }

  List<CrmLead> _leads = [];
  List<LeadImportCandidate> _preview = [];
  bool _loading = false;
  String? _error;
  String? _parseWarning;
  GmailConnectionStatus _gmail = const GmailConnectionStatus(connected: false);
  ParseProgress _parseProgress = const ParseProgress();
  bool _cancelRequested = false;
  String _parseJobId = '';
  final List<_FailedParseChunk> _failedChunks = [];
  List<CrmLead> _parsedAccumulator = [];

  static const int _parseConcurrency = 2;

  List<CrmLead> get leads => List.unmodifiable(_leads);
  List<LeadImportCandidate> get preview => List.unmodifiable(_preview);
  bool get loading => _loading;
  bool get parsing => _parseProgress.isActive;
  ParseProgress get parseProgress => _parseProgress;
  String? get error => _error;
  String? get parseWarning => _parseWarning;
  bool get hasFailedChunks => _failedChunks.isNotEmpty;
  GmailConnectionStatus get gmail => _gmail;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _leads = await _repository.getAll();
      if (_leads.isEmpty) {
        await _seedInitialLeads();
        _leads = await _repository.getAll();
      }
      await refreshFollowUpStatuses();
    } catch (_) {
      _error = 'Lokálne leady sa nepodarilo načítať.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _seedInitialLeads() async {
    final now = DateTime.now();
    final sampleLeads = [
      CrmLead(
        id: 'seed-veezu',
        companyName: 'Veezu',
        contactName: 'Nathan Bowles',
        contactRole: 'Co-Founder & CEO',
        email: 'nathan.bowles@veezu.co.uk',
        website: 'veezu.co.uk',
        sector: 'Private Hire / Taxi',
        location: 'Cardiff HQ / UK-wide',
        country: 'UK',
        score: 9.0,
        scoreReason:
            '8,000+ driverov, 25M+ rides/rok, akvizície regionálnych taxi firiem',
        notes:
            'UK largest private hire operator. Akviruje City Taxis, Dragon Taxis, Cwmbran Cars, Aqua Cars. Potrebuje zjednotiť booking technológiu.',
        pipelineStatus: 'new',
        rawText: 'LEAD 1 — Veezu / Nathan Bowles (9/10)',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 2)),
        importedAt: now.subtract(const Duration(days: 2)),
        tags: const ['UK', 'Taxi', 'High-Score', '8000+ Drivers'],
      ),
      CrmLead(
        id: 'seed-tooth-club',
        companyName: 'Tooth Club',
        contactName: 'Kunal Thakker',
        contactRole: 'Founder & CEO',
        email: 'kunal@toothclub.co.uk',
        website: 'toothclub.co.uk',
        sector: 'Multi-Site Dental Group',
        location: 'UK (19 sites)',
        country: 'UK',
        score: 9.0,
        scoreReason:
            '19 kliník (cieľ 50 do 2030), výpadok online bookingu na Dentally Portal',
        notes:
            'Ex-Goldman Sachs banker. Technický výpadok bookingu na Instagram story. Masívny scaling challenge pre booking infraštruktúru.',
        pipelineStatus: 'draft_ready',
        rawText: 'LEAD 2 — Tooth Club / Kunal Thakker (9/10)',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 3)),
        importedAt: now.subtract(const Duration(days: 3)),
        tags: const ['UK', 'Dental', 'High-Score', '19 Sites'],
      ),
      CrmLead(
        id: 'seed-treetops-dental',
        companyName: 'Treetops Dental Group',
        contactName: 'Polly Bhambra',
        contactRole: 'Co-Owner & Director',
        email: 'reception@treetopsdentalsurgery.co.uk',
        website: 'treetopsdentalsurgery.co.uk',
        sector: 'Multi-Clinic Dental',
        location: 'Wolverhampton / Midlands',
        country: 'UK',
        score: 9.0,
        scoreReason:
            'Skupina 10 dentálnych praktík, £180K Lloyds funding na rozvoj',
        notes:
            '10 kliník bez centralizovaného booking systému. Telefonické a mailové rezervácie.',
        pipelineStatus: 'new',
        rawText: 'LEAD 3 — Treetops Dental Group / Polly Bhambra (9/10)',
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 4)),
        importedAt: now.subtract(const Duration(days: 4)),
        tags: const ['UK', 'Dental', '10 Sites'],
      ),
      CrmLead(
        id: 'seed-pro-dental',
        companyName: 'Pro Dental Clinic',
        contactName: 'Nikki Burgess',
        contactRole: 'Owner & Founder',
        email: 'nikki@prodentalclinic.co.uk',
        website: 'prodentalclinic.co.uk',
        sector: 'Multi-Clinic Dental + Aesthetics',
        location: 'London (Harley Street + Marylebone), Epping',
        country: 'UK',
        score: 9.0,
        scoreReason:
            '2 kliniky v Londýne + 3. akvizícia v Epping + aesthetics firma v Essex',
        notes:
            'Multi-clinic + multi-service booking cez telefón a email. Potrebuje centralizovaný systém pri akvizícii.',
        pipelineStatus: 'waiting',
        rawText: 'LEAD 4 — Pro Dental Clinic / Nikki Burgess (9/10)',
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(days: 5)),
        importedAt: now.subtract(const Duration(days: 5)),
        tags: const ['UK', 'Dental', 'London'],
      ),
      CrmLead(
        id: 'seed-luxe-fitness',
        companyName: 'Luxe Fitness Club',
        contactName: 'Allyn Condon',
        contactRole: 'Co-Founder & Managing Director',
        email: 'allyn@luxe-fitness.com',
        website: 'luxe-fitness.com',
        sector: 'Fitness & Wellness',
        location: 'Bristol, Manchester, Birmingham',
        country: 'UK',
        score: 9.0,
        scoreReason:
            '4 fitness lokácie (otvorená Birmingham Paradise 17 500 sq ft)',
        notes:
            '24/7 prevádzka, 100+ tried týždenne na lokáciu. Potreba multi-location booking a členskej PWA aplikácie.',
        pipelineStatus: 'new',
        rawText: 'LEAD 5 — Luxe Fitness Club / Allyn Condon (9/10)',
        createdAt: now.subtract(const Duration(days: 6)),
        updatedAt: now.subtract(const Duration(days: 6)),
        importedAt: now.subtract(const Duration(days: 6)),
        tags: const ['UK', 'Fitness', '4 Sites'],
      ),
      CrmLead(
        id: 'seed-artistry-dental',
        companyName: 'Artistry Dental',
        contactName: 'Dr Arti Shah',
        contactRole: 'Founder & Principal Dentist',
        email: 'info@artistrydental.co.uk',
        website: 'artistrydental.co.uk',
        sector: 'Dental Studio',
        location: 'London',
        country: 'UK',
        score: 9.0,
        scoreReason: 'Otvorenie novej kliniky v Londýne tento týždeň',
        notes:
            'Opening signal: Nová klinika hneď potrebuje moderný online booking a klientsky portál.',
        pipelineStatus: 'new',
        rawText: 'LEAD 6 — Artistry Dental / Dr Arti Shah (9/10)',
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 7)),
        importedAt: now.subtract(const Duration(days: 7)),
        tags: const ['UK', 'Dental', 'New Opening'],
      ),
      CrmLead(
        id: 'seed-sherbet-taxi',
        companyName: 'Sherbet Electric Taxi',
        contactName: 'Asher Moses',
        contactRole: 'CEO',
        email: 'asher@sherbettaxi.com',
        website: 'sherbettaxi.com',
        sector: 'Electric Taxi Fleet',
        location: 'London',
        country: 'UK',
        score: 9.0,
        scoreReason:
            '£40M expanzia fleetu zo 550 na 3,000 elektrických vozidiel',
        notes:
            'Masívna expanzia vozového parku v Londýne. Potrebuje automatizáciu dispečingu a správy vodičov.',
        pipelineStatus: 'follow_up_due',
        rawText: 'LEAD 7 — Sherbet Electric Taxi / Asher Moses (9/10)',
        createdAt: now.subtract(const Duration(days: 8)),
        updatedAt: now.subtract(const Duration(days: 8)),
        importedAt: now.subtract(const Duration(days: 8)),
        tags: const ['UK', 'Fleet', 'EV'],
      ),
      CrmLead(
        id: 'seed-vieux-barber',
        companyName: 'Vieux Barbershop',
        contactName: 'George',
        contactRole: 'Founder & Master Barber',
        email: 'booking@vieuxbarbershop.com',
        website: 'vieuxbarbershop.com',
        sector: 'Barbershop / Grooming',
        location: 'Maidstone',
        country: 'UK',
        score: 9.0,
        scoreReason:
            'Expanzia na druhu lokaciu Vieux 2.0, rezervácie iba cez Instagram DM',
        notes:
            'Ručné vybavovanie správ na IG/FB. Žiadny automatický online kalendár.',
        pipelineStatus: 'new',
        rawText: 'LEAD 8 — Vieux Barbershop / George (9/10)',
        createdAt: now.subtract(const Duration(days: 9)),
        updatedAt: now.subtract(const Duration(days: 9)),
        importedAt: now.subtract(const Duration(days: 9)),
        tags: const ['UK', 'Barber', 'Social Booking'],
      ),
      CrmLead(
        id: 'seed-wefix-london',
        companyName: 'WeFix London',
        contactName: 'Scott Mullins',
        contactRole: 'CEO',
        email: 'scott@wefix.london',
        website: 'wefix.london',
        sector: 'Plumbing & Emergency Services',
        location: 'London',
        country: 'UK',
        score: 9.0,
        scoreReason:
            'Rekordné čísla havarijných výjazdov 24/7, čisto telefonická recepcia',
        notes:
            'Každý hovor 5+ minút. Urgentné vyťaženie. PWA s emergency slotmi a automatickým dispatchom.',
        pipelineStatus: 'draft_ready',
        rawText: 'LEAD 9 — WeFix London / Scott Mullins (9/10)',
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: now.subtract(const Duration(days: 10)),
        importedAt: now.subtract(const Duration(days: 10)),
        tags: const ['UK', 'Emergency', '24/7 Services'],
      ),
      CrmLead(
        id: 'seed-managed247',
        companyName: 'Managed247 MSP',
        contactName: 'John Pepper',
        contactRole: 'CEO',
        email: 'john.pepper@managed247.com',
        website: 'managed247.com',
        sector: 'IT & Managed Services',
        location: 'UK',
        country: 'UK',
        score: 8.0,
        scoreReason: 'Spustenie novej IT služby od júna, rastúci tím',
        notes: 'IT MSP firma spúšťa nový klientsky portál pre onboarding.',
        pipelineStatus: 'new',
        rawText: 'LEAD 10 — Managed247 MSP / John Pepper (8/10)',
        createdAt: now.subtract(const Duration(days: 11)),
        updatedAt: now.subtract(const Duration(days: 11)),
        importedAt: now.subtract(const Duration(days: 11)),
        tags: const ['UK', 'IT Services', 'MSP'],
      ),
    ];
    await _repository.saveAll([...sampleLeads, ..._buildBatchSeedLeads(now)]);
  }

  /// Additional leads extracted from the accumulated daily reports
  /// (docs/alleads.md). Companies already present in [sampleLeads] above
  /// are intentionally skipped to avoid duplicates.
  List<CrmLead> _buildBatchSeedLeads(DateTime now) {
    CrmLead lead({
      required String id,
      required String companyName,
      String contactName = '',
      String contactRole = '',
      String email = '',
      String website = '',
      required String sector,
      String location = 'UK',
      required double score,
      required String scoreReason,
      String notes = '',
      String pipelineStatus = 'new',
      required int daysAgo,
      List<String> tags = const [],
    }) {
      final ts = now.subtract(Duration(days: daysAgo));
      return CrmLead(
        id: id,
        companyName: companyName,
        contactName: contactName,
        contactRole: contactRole,
        email: email,
        website: website,
        sector: sector,
        location: location,
        country: 'UK',
        score: score,
        scoreReason: scoreReason,
        notes: notes,
        pipelineStatus: pipelineStatus,
        rawText: '$companyName — $scoreReason',
        createdAt: ts,
        updatedAt: ts,
        importedAt: ts,
        tags: tags,
      );
    }

    return [
      // Batch 2 — 20. júla 2026
      lead(
        id: 'seed-x-club',
        companyName: 'X-Club',
        contactName: 'Amanda Baracho & Steph Davidge',
        website: 'xclubs.co.uk',
        sector: 'Multi-Location Pilates & Wellness',
        score: 9,
        scoreReason: 'Multi-location pilates a wellness sieť',
        daysAgo: 1,
        tags: const ['UK', 'Fitness'],
      ),
      lead(
        id: 'seed-gould-barbers',
        companyName: 'Gould Barbers',
        contactName: 'Darran & Leigh Gould',
        website: 'gouldbarbers.co.uk',
        sector: 'Barbershop Chain + Franchise',
        score: 9,
        scoreReason: '50+ predajní, spúšťajú franchise koncept',
        daysAgo: 1,
        tags: const ['UK', 'Barber', 'Franchise'],
      ),
      lead(
        id: 'seed-skingevity',
        companyName: 'Skingevity',
        contactName: 'Andrea Agnolio & Enrico Ghio',
        email: 'andrea@skingevity.co.uk',
        sector: 'Medical Aesthetics Group (PE-backed)',
        score: 9,
        scoreReason: 'Priamy email na oboch spoluzakladateľov, PE-backed rast',
        daysAgo: 1,
        tags: const ['UK', 'Aesthetics'],
      ),
      lead(
        id: 'seed-virtue-vets',
        companyName: 'Virtue Vets',
        contactName: 'Ben Sacagiu',
        contactRole: 'Founder',
        sector: 'Veterinary Group',
        score: 8,
        scoreReason: 'Rast zo 4 na 50 kliník',
        daysAgo: 1,
        tags: const ['UK', 'Veterinary'],
      ),
      lead(
        id: 'seed-mad-london',
        companyName: 'MAD London',
        contactName: 'Vishal Amin',
        contactRole: 'Co-Founder & CEO',
        sector: 'Boutique Fitness + Franchise',
        score: 8,
        scoreReason: 'Boutique fitness franchise expanzia',
        daysAgo: 1,
        tags: const ['UK', 'Fitness'],
      ),
      lead(
        id: 'seed-platinum-travel',
        companyName: 'Platinum Travel',
        contactName: 'Alex & Ryan Elbourne',
        website: 'platinumtravelbarnsley.co.uk',
        sector: 'Private Hire Fleet',
        score: 8,
        scoreReason: '140 vodičov vo flotile',
        daysAgo: 1,
        tags: const ['UK', 'Fleet'],
      ),
      lead(
        id: 'seed-riverdale-healthcare',
        companyName: 'Riverdale Healthcare',
        contactName: 'Mark Seekings',
        contactRole: 'Co-Founder & Chair',
        website: 'riverdalehealthcare.com',
        sector: 'Multi-Site Dental Group',
        score: 8,
        scoreReason: '18 dentálnych kliník',
        daysAgo: 1,
        tags: const ['UK', 'Dental'],
      ),
      lead(
        id: 'seed-sisu-aesthetic',
        companyName: 'Sisu Aesthetic Clinic',
        contactName: 'Pat Phelan & Dr Brian Cotter',
        website: 'sisuclinic.com',
        sector: 'Multi-Location Aesthetics',
        location: 'Írsko + UK',
        score: 8,
        scoreReason: 'Multi-location aesthetics naprieč Írskom a UK',
        daysAgo: 1,
        tags: const ['UK', 'Ireland', 'Aesthetics'],
      ),
      lead(
        id: 'seed-seren-dental',
        companyName: 'Seren Dental',
        contactName: 'Devin & Rozie Mandalia',
        email: 'devinm95@hotmail.co.uk',
        sector: 'Dental + Aesthetics',
        score: 7,
        scoreReason: 'Nová klinika, priamy email k dispozícii',
        daysAgo: 1,
        tags: const ['UK', 'Dental'],
      ),
      lead(
        id: 'seed-pet-spa-london',
        companyName: 'The Pet Spa London',
        contactName: '@ThePetSpaLondon',
        contactRole: 'Instagram / Facebook',
        sector: 'Pet Grooming',
        score: 7,
        scoreReason: 'Otvára druhú lokáciu',
        daysAgo: 1,
        tags: const ['UK', 'Pet Grooming'],
      ),

      // Batch 3 — 19. júla 2026 (Veezu vynechané, už je medzi top leadmi)
      lead(
        id: 'seed-ten-health-fitness',
        companyName: 'Ten Health & Fitness',
        contactName: 'Joanne Mathews',
        contactRole: 'CEO & Founder',
        website: 'tenhealthfitness.com',
        sector: 'Boutique Fitness + Franchise',
        score: 9,
        scoreReason:
            'Spúšťajú franchise koncept Tenreformer (10+ nových štúdií)',
        daysAgo: 2,
        tags: const ['UK', 'Fitness', 'Franchise'],
      ),
      lead(
        id: 'seed-glide-physio',
        companyName: 'Glide Physio',
        contactName: 'Ryan Taylor',
        contactRole: 'Business Owner',
        sector: 'Physiotherapy',
        score: 8,
        scoreReason: 'Grand opening 2. kliniky',
        daysAgo: 2,
        tags: const ['UK', 'Physio'],
      ),
      lead(
        id: 'seed-samantha-cusick',
        companyName: 'Samantha Cusick London',
        contactName: 'Samantha Cusick',
        contactRole: 'Founder',
        website: 'samanthacusicklondon.com',
        sector: 'Multi-Location Luxury Salon',
        score: 9,
        scoreReason: '3 luxusné salóny v Londýne',
        daysAgo: 2,
        tags: const ['UK', 'Salon', 'London'],
      ),
      lead(
        id: 'seed-denovo-dental',
        companyName: 'DeNovo Dental Partners',
        contactName: 'Mark Aichroth',
        contactRole: 'Co-Founder & CEO',
        website: 'denovo.partners',
        sector: 'Multi-Site Dental Group',
        score: 9,
        scoreReason: '6+ akvirikovaných kliník',
        daysAgo: 2,
        tags: const ['UK', 'Dental'],
      ),
      lead(
        id: 'seed-club-pilates-uk',
        companyName: 'Club Pilates UK',
        contactName: 'Richard Uku',
        contactRole: 'Master Franchise Owner',
        website: 'clubpilates.uk',
        sector: 'Fitness Franchise',
        score: 8,
        scoreReason: 'Plán 50 štúdií v UK',
        daysAgo: 2,
        tags: const ['UK', 'Fitness', 'Franchise'],
      ),
      lead(
        id: 'seed-neville-hair-beauty',
        companyName: 'Neville Hair & Beauty',
        contactName: 'Elena Lavagni',
        contactRole: 'Founder & Director',
        website: 'nevillehairandbeauty.com',
        sector: 'Multi-Location Luxury Salon',
        location: 'Belgravia, London',
        score: 8,
        scoreReason: 'Luxusný salón v Belgravii',
        daysAgo: 2,
        tags: const ['UK', 'Salon', 'London'],
      ),
      lead(
        id: 'seed-beauty-rooms-medispa',
        companyName: 'The Beauty Rooms Medi Spa',
        contactName: 'Amanda Simpson',
        contactRole: 'Director',
        website: 'thebeautyroomsmedispa.co.uk',
        sector: 'Medi-Spa + Franchise',
        score: 8,
        scoreReason: 'Medi-spa franchise rozvoj',
        daysAgo: 2,
        tags: const ['UK', 'Aesthetics'],
      ),
      lead(
        id: 'seed-fs-chauffeurs',
        companyName: 'FS Chauffeurs Heathrow',
        contactName: 'Russell S.',
        contactRole: 'Founder & CEO',
        sector: 'Premium Chauffeur',
        score: 7,
        scoreReason: '22+ rokov na trhu',
        daysAgo: 2,
        tags: const ['UK', 'Chauffeur'],
      ),
      lead(
        id: 'seed-kroovel',
        companyName: 'Kroovel Ltd',
        contactRole: 'Founder & MD',
        sector: 'Luxury Transport + Lifestyle',
        score: 7,
        scoreReason: 'Jachty a lietadlá — luxury lifestyle transport',
        daysAgo: 2,
        tags: const ['UK', 'Luxury'],
      ),

      // Batch 4 — 18. júla 2026 (Tooth Club vynechaný, už je medzi top leadmi)
      lead(
        id: 'seed-razorblue',
        companyName: 'Razorblue Group',
        contactName: 'Dan Kitchen',
        contactRole: 'Founder & CEO',
        website: 'razorblue.com',
        sector: 'MSP / IT Support',
        score: 8,
        scoreReason: '£19M revenue, aktívne akvizície',
        daysAgo: 3,
        tags: const ['UK', 'IT Services'],
      ),
      lead(
        id: 'seed-tiger-cleaning',
        companyName: 'Tiger Cleaning',
        contactName: 'Alex Williams',
        contactRole: 'MD / CEO',
        website: 'tigercleaning.co.uk',
        sector: 'Commercial Cleaning',
        score: 8,
        scoreReason: 'Dvojité ocenenie 2026',
        daysAgo: 3,
        tags: const ['UK', 'Field Service'],
      ),
      lead(
        id: 'seed-dinez-taxis',
        companyName: 'Dinez Taxis & Airport Transfers',
        contactName: 'Dinez Carnay',
        contactRole: 'Founder',
        website: 'dinez.co.uk',
        sector: 'Premium Chauffeur',
        score: 8,
        scoreReason: '9x TripAdvisor Award',
        daysAgo: 3,
        tags: const ['UK', 'Chauffeur'],
      ),
      lead(
        id: 'seed-revitalize-clinic',
        companyName: 'Revitalize Clinic',
        contactName: 'Elliott Reid',
        contactRole: 'Owner & VP Inst. of Osteopathy',
        website: 'revitalizeclinic.co.uk',
        sector: 'Osteopathy & Multi-Disciplinary Clinic',
        score: 8,
        scoreReason: '15k+ pacientov',
        daysAgo: 3,
        tags: const ['UK', 'Physio'],
      ),
      lead(
        id: 'seed-shampooch',
        companyName: 'Shampooch Dog Spa',
        contactName: 'Daniel Price & James Ralph',
        contactRole: 'Co-Owners',
        sector: 'Pet Grooming Chain',
        score: 8,
        scoreReason: '4. salón otvorený',
        daysAgo: 3,
        tags: const ['UK', 'Pet Grooming'],
      ),
      lead(
        id: 'seed-junction21-chauffeurs',
        companyName: 'Junction 21 Chauffeurs',
        contactName: 'John Byrne',
        contactRole: 'Co-Founder',
        website: 'junction21chauffeurs.co.uk',
        sector: 'Chauffeur / Executive Transport',
        location: 'Greater Manchester',
        score: 7,
        scoreReason: 'Executive transport v Greater Manchester',
        daysAgo: 3,
        tags: const ['UK', 'Chauffeur'],
      ),
      lead(
        id: 'seed-eugene-chauffeurs',
        companyName: 'Eugene Chauffeurs',
        contactName: 'Eugene Owusu Afram Jnr',
        contactRole: 'Founder & CEO',
        website: 'eugenechauffeurs.com',
        sector: 'Luxury Chauffeur + Concierge',
        location: 'London',
        score: 7,
        scoreReason: 'Luxury concierge chauffeur služby v Londýne',
        daysAgo: 3,
        tags: const ['UK', 'Chauffeur', 'London'],
      ),
      lead(
        id: 'seed-pulse-laser-clinic',
        companyName: 'Pulse Laser Clinic',
        contactName: 'Maria Dinopoulos',
        contactRole: 'Co-Founder',
        email: 'info@pulse-clinic.co.uk',
        sector: 'Aesthetics / Laser Clinic',
        location: 'Fitzrovia, London',
        score: 7,
        scoreReason: '10+ rokov na trhu, priamy email k dispozícii',
        daysAgo: 3,
        tags: const ['UK', 'Aesthetics'],
      ),
      lead(
        id: 'seed-skin-perfection-london',
        companyName: 'Skin Perfection London',
        contactName: 'Ayse Suleyman',
        contactRole: 'Founder & Director',
        website: 'skinperfectionlondon.co.uk',
        sector: 'Laser & Skin Clinic',
        location: 'Marylebone, London',
        score: 7,
        scoreReason: '12+ rokov na trhu',
        daysAgo: 3,
        tags: const ['UK', 'Aesthetics'],
      ),

      // Batch 5 — 17. júla 2026 (Treetops Dental vynechaný, už je medzi top leadmi)
      lead(
        id: 'seed-beyond-hair',
        companyName: 'Beyond Hair',
        contactName: 'Wayne Daws',
        contactRole: 'Co-Owner & Founder',
        sector: 'Barbershop Chain',
        score: 8,
        scoreReason: '4+ lokácie v Londýne',
        daysAgo: 4,
        tags: const ['UK', 'Barber', 'London'],
      ),
      lead(
        id: 'seed-define-clinic',
        companyName: 'Define Clinic',
        contactName: 'Dr Benji Dhillon',
        contactRole: 'Founder',
        website: 'defineclinic.co.uk',
        sector: 'Aesthetics',
        location: 'Harley Street, London',
        score: 9,
        scoreReason:
            'Harley Street + 2 nové lokácie + edukačná platforma Aesthetix360',
        daysAgo: 4,
        tags: const ['UK', 'Aesthetics', 'London'],
      ),
      lead(
        id: 'seed-foundry-fitness',
        companyName: 'The Foundry Fitness',
        contactName: 'Ben Stroud',
        contactRole: 'Founder & Owner',
        sector: 'Fitness Hub',
        score: 8,
        scoreReason: '2. gym, break-even v 1. mesiaci',
        daysAgo: 4,
        tags: const ['UK', 'Fitness'],
      ),
      lead(
        id: 'seed-bodyfunction-clinic',
        companyName: 'Bodyfunction Clinic',
        contactName: 'Danny Morgan',
        contactRole: 'Founder & Osteopath',
        website: 'bodyfunction.co.uk',
        sector: 'Osteopathy / Physio',
        location: 'Islington, London',
        score: 8,
        scoreReason: 'Rastúca klinika, nábor personálu',
        daysAgo: 4,
        tags: const ['UK', 'Physio', 'London'],
      ),
      lead(
        id: 'seed-cosmetic-skin-clinic',
        companyName: 'Cosmetic Skin Clinic',
        contactName: 'Dr Tracy Mountford',
        contactRole: 'Founder',
        website: 'cosmeticskinclinic.com',
        sector: 'Premium Aesthetics',
        location: 'Harley Street + Bucks',
        score: 7,
        scoreReason: 'Premium aesthetics naprieč dvoma lokáciami',
        daysAgo: 4,
        tags: const ['UK', 'Aesthetics'],
      ),
      lead(
        id: 'seed-edward-james-salons',
        companyName: 'Edward James Salons',
        contactName: 'Edward James',
        contactRole: 'Creative & MD',
        website: 'edwardjameslondon.com',
        sector: 'Salon Chain',
        location: 'London',
        score: 8,
        scoreReason: '4 Aveda salóny v Londýne',
        daysAgo: 4,
        tags: const ['UK', 'Salon', 'London'],
      ),
      lead(
        id: 'seed-take-me-group',
        companyName: 'Take Me Group',
        contactName: 'David Hunter',
        contactRole: 'CEO',
        website: 'takeme.taxi',
        sector: 'Taxi / Private Hire',
        score: 8,
        scoreReason: 'Akvizičná spree v celom UK',
        daysAgo: 4,
        tags: const ['UK', 'Taxi'],
      ),
      lead(
        id: 'seed-awe-london',
        companyName: 'Awe London',
        contactName: 'Kamden Monplaisir',
        contactRole: 'Founder',
        sector: 'Nail Salon Chain',
        location: 'Shoreditch & Canary Wharf, London',
        score: 8,
        scoreReason: '2 lokácie v Londýne',
        daysAgo: 4,
        tags: const ['UK', 'Salon', 'London'],
      ),
      lead(
        id: 'seed-energie-fitness',
        companyName: 'Energie Fitness',
        contactName: 'Narinder Kaushal',
        contactRole: 'Business Owner',
        sector: 'Fitness Franchise',
        location: 'Írsko',
        score: 8,
        scoreReason: '5 klubov v Írsku',
        daysAgo: 4,
        tags: const ['Ireland', 'Fitness', 'Franchise'],
      ),

      // Batch 6 — 16. júla 2026 (Pro Dental Clinic vynechaný, už je medzi top leadmi)
      lead(
        id: 'seed-au-dental',
        companyName: 'Au Dental (Tejani Dental)',
        contactName: 'Aly Khan Tejani',
        contactRole: 'Acquisitions & Ops Director',
        website: 'audental.co.uk',
        sector: 'Dental Group',
        score: 8,
        scoreReason: '7 dentálnych kliník',
        daysAgo: 5,
        tags: const ['UK', 'Dental'],
      ),
      lead(
        id: 'seed-mk-health-hub',
        companyName: 'MK Health Hub / MK Reformed',
        contactName: 'Matt Kendrick',
        contactRole: 'Founder & CEO',
        website: 'mkhealthhub.co.uk',
        sector: 'Boutique Fitness + Franchise',
        score: 9,
        scoreReason: 'Spúšťajú Pilates franchise sieť MK Reformed',
        daysAgo: 5,
        tags: const ['UK', 'Fitness', 'Franchise'],
      ),
      lead(
        id: 'seed-ukcg',
        companyName: 'UKCG (UK Commercial Group)',
        contactName: 'Tony Earnshaw',
        contactRole: 'CEO & Founder',
        sector: 'HVAC / Facilities Engineering',
        location: 'UK / Európa',
        score: 9,
        scoreReason:
            'Veľký medzinárodný kontrakt na HVAC údržbu naprieč Európou',
        daysAgo: 5,
        tags: const ['UK', 'Field Service'],
      ),
      lead(
        id: 'seed-barbersno1',
        companyName: 'BARBERSNO1',
        contactRole: 'Store No17 opening (Knowsley Village)',
        sector: 'Barbershop Chain',
        score: 8,
        scoreReason: '15+ prevádzok + Barbering Academy',
        daysAgo: 5,
        tags: const ['UK', 'Barber'],
      ),
      lead(
        id: 'seed-xcel-health-group',
        companyName: 'Xcel Health Group',
        contactName: 'Xavier Rajarathnam',
        contactRole: 'Founder & CEO',
        website: 'xcelhealth.co.uk',
        sector: 'Physiotherapy Group',
        location: 'London / Surrey',
        score: 9,
        scoreReason: 'Agresívna akvizičná stratégia fyzioterapeutických kliník',
        daysAgo: 5,
        tags: const ['UK', 'Physio'],
      ),
      lead(
        id: 'seed-pneuma-group',
        companyName: 'Pneuma Group (Parkers Chauffeurs)',
        contactName: 'Laurence Beck',
        contactRole: 'Divisional Director',
        website: 'pneumagroup.co.uk',
        sector: 'Chauffeur / Transport',
        location: 'UK / USA',
        score: 9,
        scoreReason: 'Akvizícia Parkers Chauffeurs a expanzia v UK aj v USA',
        daysAgo: 5,
        tags: const ['UK', 'Chauffeur'],
      ),
      lead(
        id: 'seed-md-electrical',
        companyName: 'MD Electrical Contractors',
        contactName: 'Chris Deeney',
        contactRole: 'Managing Director',
        sector: 'Electrical Contractor',
        score: 8,
        scoreReason: 'Nové sídlo + tréningové centrum',
        daysAgo: 5,
        tags: const ['UK', 'Field Service'],
      ),
      lead(
        id: 'seed-wellness-hub',
        companyName: 'The Wellness Hub',
        contactName: 'Emma James',
        contactRole: 'Founder & Clinical Director',
        website: 'the-wellness-hub.co.uk',
        sector: 'Physio + Wellness Hub',
        score: 8,
        scoreReason: '30 rokov praxe',
        daysAgo: 5,
        tags: const ['UK', 'Physio'],
      ),
      lead(
        id: 'seed-3-way-physio',
        companyName: '3 Way Physio',
        contactName: 'Yves De Vos',
        contactRole: 'Multi-Clinic Owner',
        website: '3wayphysio.co.uk',
        sector: 'Multi-Clinic Physio',
        score: 9,
        scoreReason: '3. klinika + nový Operations Director na centralizáciu',
        daysAgo: 5,
        tags: const ['UK', 'Physio'],
      ),

      // Batch 7 — 15. júla 2026 (Luxe Fitness Club vynechaný, už je medzi top leadmi)
      lead(
        id: 'seed-barber-barber',
        companyName: 'Barber Barber',
        contactName: 'Johnny Baba',
        contactRole: 'Co-Founder & Owner',
        sector: 'Barbershop Chain',
        score: 8,
        scoreReason: '5+ lokácií v UK',
        daysAgo: 6,
        tags: const ['UK', 'Barber'],
      ),
      lead(
        id: 'seed-barbican-physio',
        companyName: 'Barbican Physio',
        contactName: 'Susan Julians',
        contactRole: 'Founder & Clinical Lead',
        sector: 'Physiotherapy Clinic',
        score: 8,
        scoreReason: '7-figure klinika, 20+ rokov na trhu',
        daysAgo: 6,
        tags: const ['UK', 'Physio'],
      ),
      lead(
        id: 'seed-drmr-clinic',
        companyName: 'DRMR Clinic',
        contactName: 'Dr Manrina Rhode',
        contactRole: 'Founder & CEO',
        email: 'bookings@drmr.co.uk',
        sector: 'Luxury Dental + Aesthetics',
        location: 'Brompton Road, SW3, London',
        score: 9,
        scoreReason:
            'Luxusná multi-service klinika (Veneers, Aesthetics, Genetics, Skincare)',
        daysAgo: 6,
        tags: const ['UK', 'Aesthetics', 'London'],
      ),
      lead(
        id: 'seed-long-lane',
        companyName: 'Long Lane',
        contactName: 'Harrison Hide',
        contactRole: 'Founder',
        website: 'longlane.co.uk',
        sector: 'Hotel + Members Club',
        score: 8,
        scoreReason: 'Prvý sober wellness hotel v UK, £4M investícia',
        daysAgo: 6,
        tags: const ['UK', 'Wellness'],
      ),
      lead(
        id: 'seed-limotak-global',
        companyName: 'Limotak Global',
        contactName: 'Yaroslav Pestov',
        contactRole: 'CEO',
        website: 'limotak.com',
        sector: 'Chauffeur / Transport',
        location: '100+ krajín',
        score: 8,
        scoreReason: 'Globálna chauffeur sieť v 100+ krajinách',
        daysAgo: 6,
        tags: const ['Global', 'Chauffeur'],
      ),
      lead(
        id: 'seed-beaute-group',
        companyName: 'The Beauté Group',
        contactName: 'Emily-Louise Varnfield',
        contactRole: 'Founder & CEO',
        sector: 'Aesthetics / Skin Longevity',
        score: 8,
        scoreReason: '£1.2M investment raise',
        daysAgo: 6,
        tags: const ['UK', 'Aesthetics'],
      ),
      lead(
        id: 'seed-dg-group',
        companyName: 'DG Group (DG Cars)',
        contactName: 'Omair Javaid',
        contactRole: 'Director',
        website: 'thedg.group',
        sector: 'Taxi / Private Hire Fleet',
        location: 'East Midlands',
        score: 7,
        scoreReason: '550+ vozidiel v East Midlands',
        daysAgo: 6,
        tags: const ['UK', 'Fleet'],
      ),
      lead(
        id: 'seed-dog-world-grooming',
        companyName: 'Dog World Grooming',
        contactName: 'Kasia Zawadzka',
        contactRole: 'Co-Founder',
        sector: 'Pet Grooming + Academy',
        score: 7,
        scoreReason: 'Salón + školiace centrum',
        daysAgo: 6,
        tags: const ['UK', 'Pet Grooming'],
      ),
      lead(
        id: 'seed-hybrid-fitness-uk',
        companyName: 'Hybrid Fitness UK',
        contactName: 'Antony Townsley',
        contactRole: 'Franchise Director',
        sector: 'Fitness Franchise',
        score: 7,
        scoreReason: '170+ gym openings v pláne',
        daysAgo: 6,
        tags: const ['UK', 'Fitness', 'Franchise'],
      ),

      // Report 29.6.2026 (Artistry Dental, Sherbet Electric Taxi, Managed247 MSP vynechané, už sú medzi top leadmi)
      lead(
        id: 'seed-fitness-studio-spencers-wood',
        companyName: 'Fitness Studio (Spencers Wood)',
        sector: 'Fitness',
        location: 'Spencers Wood',
        score: 8,
        scoreReason: 'Otváranie v júni, potrebný rezervačný systém',
        daysAgo: 22,
        tags: const ['UK', 'Fitness'],
      ),
      lead(
        id: 'seed-creature-comforts-vet',
        companyName: 'Creature Comforts Vet',
        contactName: 'Russell Welsh & Daniel Attia',
        contactRole: 'Co-Founders',
        sector: 'Veterinary',
        score: 8,
        scoreReason: 'Tech vet klinika',
        daysAgo: 22,
        tags: const ['UK', 'Veterinary'],
      ),
      lead(
        id: 'seed-times-one-hundred',
        companyName: 'Times One Hundred Digital Agency',
        sector: 'Digital Agency',
        score: 8,
        scoreReason: '15-30 členov tímu, rastová fáza',
        daysAgo: 22,
        tags: const ['UK', 'Agency'],
      ),
      lead(
        id: 'seed-galetech-group',
        companyName: 'Galetech Group Renewables',
        sector: 'Renewables',
        score: 8,
        scoreReason: 'Field worker dispatch pre obnoviteľné zdroje',
        daysAgo: 22,
        tags: const ['UK', 'Field Service'],
      ),
      lead(
        id: 'seed-window-cleaning-field-service',
        companyName: 'Window Cleaning Field Service',
        sector: 'Commercial Window Cleaning',
        score: 7,
        scoreReason: '£1M tržby',
        daysAgo: 22,
        tags: const ['UK', 'Field Service'],
      ),
      lead(
        id: 'seed-beauty-studio-wellness',
        companyName: 'Beauty Studio Wellness',
        sector: 'Beauty Salon',
        score: 7,
        scoreReason: 'Rezervácie len cez Instagram',
        daysAgo: 22,
        tags: const ['UK', 'Beauty'],
      ),
      lead(
        id: 'seed-growth-division-agency',
        companyName: 'Growth Division Agency',
        sector: 'Marketing Agency',
        score: 7,
        scoreReason: 'V procese škálovania',
        daysAgo: 22,
        tags: const ['UK', 'Agency'],
      ),

      // Report 28.6.2026
      lead(
        id: 'seed-brethrens-barbers',
        companyName: 'Brethrens Barbers',
        contactName: 'Fiona Shaw',
        contactRole: 'Founder',
        sector: 'Barbershop',
        score: 9,
        scoreReason: 'Otvorená nová prevádzka',
        daysAgo: 23,
        tags: const ['UK', 'Barber'],
      ),
      lead(
        id: 'seed-workout-central',
        companyName: 'Workout Central',
        sector: 'Fitness',
        score: 8,
        scoreReason: 'Otváranie fitnescentra',
        daysAgo: 23,
        tags: const ['UK', 'Fitness'],
      ),
      lead(
        id: 'seed-golden-design',
        companyName: 'GOLDEN Design',
        sector: 'Design Agency',
        location: 'Leeds & Belfast',
        score: 9,
        scoreReason: 'Nábor tímov v Leeds a Belfast',
        daysAgo: 23,
        tags: const ['UK', 'Agency'],
      ),
      lead(
        id: 'seed-character-creates',
        companyName: 'Character Creates',
        sector: 'Creative Studio',
        score: 7,
        scoreReason: 'Štúdio v raste',
        daysAgo: 23,
        tags: const ['UK', 'Agency'],
      ),
      lead(
        id: 'seed-atypikal-creative',
        companyName: 'Atypikal Creative',
        sector: 'Creative Agency',
        score: 8,
        scoreReason: 'Nábor seniorov',
        daysAgo: 23,
        tags: const ['UK', 'Agency'],
      ),
      lead(
        id: 'seed-fitness-lab',
        companyName: 'Fitness Lab',
        sector: 'Personal Training',
        location: 'London',
        score: 8,
        scoreReason: '3 lokácie osobných tréningov v Londýne',
        daysAgo: 23,
        tags: const ['UK', 'Fitness', 'London'],
      ),
      lead(
        id: 'seed-clubright',
        companyName: 'ClubRight',
        sector: 'Gym Software',
        score: 7,
        scoreReason: 'Softvér pre gymy, možnosť partnerstva',
        daysAgo: 23,
        tags: const ['UK', 'Software'],
      ),
      lead(
        id: 'seed-everyday-fitness',
        companyName: 'Everyday Fitness',
        sector: 'Fitness',
        location: 'Swindon',
        score: 7,
        scoreReason: 'Expanzívny gym v Swindone',
        daysAgo: 23,
        tags: const ['UK', 'Fitness'],
      ),
      lead(
        id: 'seed-studio-cotton',
        companyName: 'Studio Cotton',
        sector: 'Design Studio',
        score: 7,
        scoreReason: 'Dizajnové štúdio v raste',
        daysAgo: 23,
        tags: const ['UK', 'Agency'],
      ),

      // Report 27.6.2026 (Vieux Barbershop, WeFix London vynechané, už sú medzi top leadmi)
      lead(
        id: 'seed-chaps-barber-shop',
        companyName: 'Chaps Barber Shop',
        contactName: 'Bill Chapman',
        contactRole: 'Owner',
        website: 'chapsbarbersnorthowram.co',
        sector: 'Barbershop Chain',
        score: 8,
        scoreReason: 'Award-winning barber, nová lokácia',
        daysAgo: 24,
        tags: const ['UK', 'Barber'],
      ),
      lead(
        id: 'seed-candour-seo',
        companyName: 'Candour SEO Agency',
        contactName: 'Mark Williams-Cook',
        contactRole: 'Director',
        email: 'contact@withcandour.co.uk',
        sector: 'SEO Agency',
        location: 'Norwich',
        score: 9,
        scoreReason: '25-členný tím v raste',
        daysAgo: 24,
        tags: const ['UK', 'Agency'],
      ),
      lead(
        id: 'seed-rise-at-seven',
        companyName: 'Rise at Seven',
        contactName: 'Carrie Rose',
        contactRole: 'CEO & Founder',
        website: 'riseatseven.com',
        sector: 'SEO + Content Agency',
        score: 8,
        scoreReason: 'Medzinárodný growth',
        daysAgo: 24,
        tags: const ['UK', 'Agency'],
      ),
      lead(
        id: 'seed-3b-website-design',
        companyName: '3B Website Design',
        contactName: 'David Christopher',
        contactRole: 'Founder',
        email: 'info@3bwebsitedesign.com',
        sector: 'Web Agency',
        score: 7,
        scoreReason: 'Founder-led web agentúra',
        daysAgo: 24,
        tags: const ['UK', 'Agency'],
      ),
      lead(
        id: 'seed-boost-fractional-marketing',
        companyName: 'Boost Fractional Marketing',
        contactName: 'Adrian Whitcombe',
        contactRole: 'Founder',
        email: 'info@boostfma.com',
        sector: 'Marketing Agency',
        score: 8,
        scoreReason: 'Sieť fractional marketing partnerov',
        daysAgo: 24,
        tags: const ['UK', 'Agency'],
      ),
      lead(
        id: 'seed-snowden-barbers',
        companyName: 'Snowden Barbers',
        contactName: 'Bailey Snowden',
        contactRole: 'Owner',
        sector: 'Barbershop',
        location: 'Belfast',
        score: 7,
        scoreReason: 'WAHL UK Scholar of the Year',
        daysAgo: 24,
        tags: const ['UK', 'Barber'],
      ),
      lead(
        id: 'seed-31-cutz-academy',
        companyName: '31 Cutz Academy',
        contactName: 'Luqman',
        contactRole: 'Founder',
        sector: 'Barber Network & Academy',
        score: 7,
        scoreReason: 'Nové školiace stredisko',
        daysAgo: 24,
        tags: const ['UK', 'Barber'],
      ),
      lead(
        id: 'seed-chopsons-barbering',
        companyName: 'Chopsons Barbering',
        contactRole: 'Owner',
        sector: 'Barbershop',
        location: 'Burscough',
        score: 7,
        scoreReason: 'Nová prevádzka v Burscough',
        daysAgo: 24,
        tags: const ['UK', 'Barber'],
      ),

      // Report 25.6.2026 Run #2 (WeFix London vynechaný, už je medzi top leadmi)
      lead(
        id: 'seed-funeral-partners',
        companyName: 'Funeral Partners Limited',
        contactName: 'Sam Kershaw',
        contactRole: 'CEO',
        email: 'corporate@funeralpartners.co.uk',
        sector: 'Pohrebné služby',
        score: 8,
        scoreReason: '200+ pobočiek v UK',
        daysAgo: 26,
        tags: const ['UK', 'Funeral Services'],
      ),
      lead(
        id: 'seed-fitness-worx-gyms',
        companyName: 'Fitness Worx Gyms',
        website: 'fitnessworxgyms.co.uk',
        sector: 'Gym Network',
        score: 7,
        scoreReason: 'Rollout nového konceptu Glute Zones',
        daysAgo: 26,
        tags: const ['UK', 'Fitness'],
      ),
      lead(
        id: 'seed-emj-uk-wellness',
        companyName: 'EMJ UK Wellness Centre',
        contactName: 'Mel Cherrett',
        contactRole: 'Founder',
        website: 'emjuk.co.uk',
        sector: 'Wellness / Fitness',
        score: 8,
        scoreReason: 'Otvorené 1. júna 2026',
        daysAgo: 26,
        tags: const ['UK', 'Wellness'],
      ),
      lead(
        id: 'seed-grant-goodstein-dental',
        companyName: 'Grant Goodstein Dental Care',
        contactName: 'Grant Goodstein',
        contactRole: 'Practice Owner',
        sector: 'Dental Practice',
        score: 7,
        scoreReason: 'Ex-tech exec zakladateľ',
        daysAgo: 26,
        tags: const ['UK', 'Dental'],
      ),
      lead(
        id: 'seed-icabbi-newcastle',
        companyName: 'iCabbi Newcastle',
        website: 'icabbi.com',
        sector: 'Taxi / Private Hire Network',
        score: 8,
        scoreReason: 'Expanzia do 7 miest',
        daysAgo: 26,
        tags: const ['UK', 'Taxi'],
      ),
      lead(
        id: 'seed-dr-bobby-bhandal',
        companyName: 'Dr Bobby Bhandal Dentistry',
        contactName: 'Dr Bobby Bhandal',
        contactRole: 'Founder',
        sector: 'Dental Practice',
        score: 7,
        scoreReason: 'Thought-leader zakladateľ',
        daysAgo: 26,
        tags: const ['UK', 'Dental'],
      ),
      lead(
        id: 'seed-optivet-referrals',
        companyName: 'Optivet Referrals',
        contactName: 'Dr Gemma Turner',
        contactRole: 'Lead',
        website: 'optivet.com',
        sector: 'Špecializovaná Vet Klinika',
        location: 'Waltham Forest, London',
        score: 7,
        scoreReason: 'Nová klinika vo Waltham Forest',
        daysAgo: 26,
        tags: const ['UK', 'Veterinary', 'London'],
      ),
      lead(
        id: 'seed-heartland-dental',
        companyName: 'Heartland Dental',
        website: 'heartland.com',
        sector: 'Dental Support Organization',
        location: 'Európa',
        score: 7,
        scoreReason: 'DSO expanzia do Európy',
        daysAgo: 26,
        tags: const ['UK', 'Dental'],
      ),
      lead(
        id: 'seed-dental-concepts',
        companyName: 'Dental Concepts',
        contactName: 'Dr Manish Chitnis',
        contactRole: 'Principal Dentist & Owner',
        sector: 'Multi-Location Dental Group',
        score: 7,
        scoreReason: '5-10 kliník',
        daysAgo: 26,
        tags: const ['UK', 'Dental'],
      ),

      // Zvýraznený TOP 5 výber (dnešný report, 21. júla 2026)
      lead(
        id: 'seed-neom-wellbeing',
        companyName: 'NEOM Wellbeing',
        contactName: 'Nick Marvin',
        contactRole: 'Global Digital Director',
        website: 'neomwellbeing.com',
        sector: 'Wellbeing Retail',
        score: 9,
        scoreReason:
            'Masívny rollout do 800+ prevádzok Superdrug + vlastné treatment rooms',
        daysAgo: 0,
        tags: const ['UK', 'Wellness', 'Retail'],
      ),
    ];
  }

  Future<void> parseForPreview(String rawText) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      _error = 'Vlož text leadového reportu.';
      notifyListeners();
      return;
    }
    if (trimmed.length < 40) {
      _error =
          'Text je príliš krátky. Vlož celý lead report (min. ~40 znakov).';
      notifyListeners();
      return;
    }
    if (trimmed.length > 120000) {
      _error = 'Text je príliš dlhý. Rozdeľ report na menšie časti.';
      notifyListeners();
      return;
    }

    _cancelRequested = false;
    _error = null;
    _parseWarning = null;
    _preview = [];
    _failedChunks.clear();
    _parsedAccumulator = [];
    _parseJobId = _uuid.v4();
    _setProgress(
      const ParseProgress(
        phase: ParsePhase.preparing,
        statusLine: 'Pripravujem report…',
        value: 0.02,
      ),
    );

    try {
      _setProgress(
        ParseProgress(
          phase: ParsePhase.chunking,
          statusLine: 'Rozdeľujem report na bloky…',
          value: 0.05,
        ),
      );
      final chunks = _splitter.split(trimmed);
      if (chunks.isEmpty) {
        _error = 'V texte sa nenašli žiadne leady na import.';
        _setProgress(const ParseProgress(phase: ParsePhase.failed));
        return;
      }

      await _parseChunks(chunks, jobId: _parseJobId);

      if (_cancelRequested) {
        _buildPreviewFromAccumulator();
        _parseWarning = _preview.isEmpty
            ? null
            : 'Parsovanie zrušené. Zobrazené sú len stihnuté leady.';
        _setProgress(
          ParseProgress(
            phase: _preview.isEmpty ? ParsePhase.cancelled : ParsePhase.partial,
            chunkIndex: _parseProgress.chunkIndex,
            chunkTotal: chunks.length,
            leadsFound: _parsedAccumulator.length,
            chunksFailed: _failedChunks.length,
            statusLine: _preview.isEmpty
                ? 'Zrušené'
                : 'Zrušené · ${_preview.length} leadov',
            value: _parseProgress.value,
          ),
        );
        if (_preview.isEmpty) {
          _error = 'Parsovanie bolo zrušené.';
        }
        return;
      }

      _setProgress(
        ParseProgress(
          phase: ParsePhase.merging,
          chunkIndex: chunks.length,
          chunkTotal: chunks.length,
          leadsFound: _parsedAccumulator.length,
          chunksFailed: _failedChunks.length,
          statusLine: 'Spájam duplicity…',
          value: 0.95,
        ),
      );
      _buildPreviewFromAccumulator();

      if (_preview.isEmpty) {
        _error = _failedChunks.isEmpty
            ? 'V texte sa nenašli žiadne leady na import.'
            : _uniformFailureMessage(_failedChunks) ??
                'Mistral nestihlo spracovať report. Skús zopakovať zlyhané bloky.';
        _setProgress(
          ParseProgress(
            phase: ParsePhase.failed,
            chunkTotal: chunks.length,
            chunksFailed: _failedChunks.length,
            statusLine: 'Zlyhalo',
            value: 1,
          ),
        );
        return;
      }

      final failed = _failedChunks.length;
      if (failed > 0) {
        _parseWarning =
            '$failed blok${failed == 1 ? '' : 'y'} zlyhal${failed == 1 ? '' : 'i'} — môžeš ich zopakovať.';
        _setProgress(
          ParseProgress(
            phase: ParsePhase.partial,
            chunkIndex: chunks.length,
            chunkTotal: chunks.length,
            leadsFound: _preview.length,
            chunksFailed: failed,
            statusLine:
                'Hotovo: ${_preview.length} leadov ($failed treba zopakovať)',
            value: 1,
          ),
        );
      } else {
        _setProgress(
          ParseProgress(
            phase: ParsePhase.done,
            chunkIndex: chunks.length,
            chunkTotal: chunks.length,
            leadsFound: _preview.length,
            statusLine: 'Hotovo: ${_preview.length} leadov',
            value: 1,
          ),
        );
      }
    } on LeadAiException catch (error) {
      _error = error.message;
      _setProgress(
        ParseProgress(
          phase: ParsePhase.failed,
          statusLine: 'Zlyhalo',
          value: _parseProgress.value,
          leadsFound: _parsedAccumulator.length,
          chunksFailed: _failedChunks.length,
        ),
      );
    } catch (error) {
      _error = 'Import zlyhal: $error';
      _setProgress(
        ParseProgress(
          phase: ParsePhase.failed,
          statusLine: 'Zlyhalo',
          value: _parseProgress.value,
          leadsFound: _parsedAccumulator.length,
          chunksFailed: _failedChunks.length,
        ),
      );
    }
  }

  void cancelParse() {
    if (!_parseProgress.isActive) return;
    _cancelRequested = true;
    _setProgress(
      ParseProgress(
        phase: ParsePhase.parsing,
        chunkIndex: _parseProgress.chunkIndex,
        chunkTotal: _parseProgress.chunkTotal,
        leadsFound: _parseProgress.leadsFound,
        chunksFailed: _parseProgress.chunksFailed,
        statusLine: 'Ruším…',
        value: _parseProgress.value,
      ),
    );
  }

  Future<void> retryFailedChunks() async {
    if (_failedChunks.isEmpty || _parseProgress.isActive) return;
    final pending = List<_FailedParseChunk>.from(_failedChunks);
    _failedChunks.clear();
    _cancelRequested = false;
    _error = null;
    _parseWarning = null;

    final texts = pending.map((c) => c.text).toList();
    // Preserve original indices in progress labels via synthetic total.
    await _parseChunks(
      texts,
      jobId: _parseJobId.isEmpty ? _uuid.v4() : _parseJobId,
      indexOffset: 0,
      labelTotal: pending.length,
    );

    if (_cancelRequested) {
      _buildPreviewFromAccumulator();
      _setProgress(
        ParseProgress(
          phase: _preview.isEmpty ? ParsePhase.cancelled : ParsePhase.partial,
          leadsFound: _parsedAccumulator.length,
          chunksFailed: _failedChunks.length,
          chunkTotal: pending.length,
          statusLine: 'Zrušené',
          value: _parseProgress.value,
        ),
      );
      return;
    }

    _setProgress(
      ParseProgress(
        phase: ParsePhase.merging,
        chunkTotal: pending.length,
        chunkIndex: pending.length,
        leadsFound: _parsedAccumulator.length,
        chunksFailed: _failedChunks.length,
        statusLine: 'Spájam duplicity…',
        value: 0.95,
      ),
    );
    _buildPreviewFromAccumulator();

    if (_preview.isEmpty) {
      _error = 'Opätovné spracovanie nenašlo žiadne leady.';
      _setProgress(
        ParseProgress(
          phase: ParsePhase.failed,
          chunksFailed: _failedChunks.length,
          statusLine: 'Zlyhalo',
          value: 1,
        ),
      );
      return;
    }

    final failed = _failedChunks.length;
    _parseWarning = failed > 0
        ? '$failed blok${failed == 1 ? '' : 'y'} stále zlyhal${failed == 1 ? '' : 'i'}.'
        : null;
    _setProgress(
      ParseProgress(
        phase: failed > 0 ? ParsePhase.partial : ParsePhase.done,
        chunkIndex: pending.length,
        chunkTotal: pending.length,
        leadsFound: _preview.length,
        chunksFailed: failed,
        statusLine: failed > 0
            ? 'Hotovo s výhradami: ${_preview.length} leadov'
            : 'Hotovo: ${_preview.length} leadov',
        value: 1,
      ),
    );
  }

  Future<void> _parseChunks(
    List<String> chunks, {
    required String jobId,
    int indexOffset = 0,
    int? labelTotal,
  }) async {
    final total = labelTotal ?? chunks.length;
    var next = 0;
    var completed = 0;

    Future<void> worker() async {
      while (true) {
        if (_cancelRequested) return;
        final i = next;
        next++;
        if (i >= chunks.length) return;

        final displayIndex = i + 1;
        _setProgress(
          ParseProgress(
            phase: ParsePhase.parsing,
            chunkIndex: displayIndex,
            chunkTotal: total,
            leadsFound: _parsedAccumulator.length,
            chunksFailed: _failedChunks.length,
            statusLine: 'Blok $displayIndex/$total — hľadám kontakty',
            value: 0.08 + (completed / total) * 0.85,
          ),
        );

        try {
          final leads = await _ai.parseLeadChunk(
            chunks[i],
            jobId: jobId,
            chunkIndex: indexOffset + i,
            chunkTotal: total,
          );
          if (_cancelRequested) return;
          _parsedAccumulator.addAll(leads);
        } catch (error) {
          if (_cancelRequested) return;
          _failedChunks.add(
            _FailedParseChunk(
              index: indexOffset + i,
              text: chunks[i],
              reason: error.toString(),
            ),
          );
        } finally {
          completed++;
          _setProgress(
            ParseProgress(
              phase: ParsePhase.parsing,
              chunkIndex: displayIndex,
              chunkTotal: total,
              leadsFound: _parsedAccumulator.length,
              chunksFailed: _failedChunks.length,
              statusLine: 'Blok $displayIndex/$total — hotovo',
              value: 0.08 + (completed / total) * 0.85,
            ),
          );
        }
      }
    }

    final workers = List.generate(
      _parseConcurrency.clamp(1, chunks.length),
      (_) => worker(),
    );
    await Future.wait(workers);
  }

  void _buildPreviewFromAccumulator() {
    final seenKeys = <String>{};
    final candidates = <LeadImportCandidate>[];
    for (final lead in _parsedAccumulator) {
      final normalized = lead.copyWith(updatedAt: DateTime.now());
      final withId = CrmLead.fromJson({
        ...normalized.toJson(),
        'id': normalized.id.isEmpty ? _uuid.v4() : normalized.id,
      });
      final dedupeKey = [
        withId.normalizedEmail,
        withId.normalizedDomain,
        withId.companyContactKey,
      ].join('|');
      if (seenKeys.contains(dedupeKey) && dedupeKey != '||') {
        continue;
      }
      seenKeys.add(dedupeKey);
      final duplicate = findDuplicate(withId) != null;
      candidates.add(
        LeadImportCandidate(
          lead: withId,
          duplicate: duplicate,
          selected: !duplicate,
        ),
      );
    }
    candidates.sort((a, b) => b.lead.score.compareTo(a.lead.score));
    _preview = candidates;
  }

  void _setProgress(ParseProgress progress) {
    _parseProgress = progress;
    notifyListeners();
  }

  String? _uniformFailureMessage(List<_FailedParseChunk> failed) {
    if (failed.isEmpty) return null;
    final first = failed.first.reason;
    if (failed.every((item) => item.reason == first) && first.isNotEmpty) {
      return first;
    }
    return null;
  }

  CrmLead? findDuplicate(CrmLead candidate) {
    for (final existing in _leads) {
      if (candidate.normalizedEmail.isNotEmpty &&
          candidate.normalizedEmail == existing.normalizedEmail) {
        return existing;
      }
      if (candidate.normalizedDomain.isNotEmpty &&
          candidate.normalizedDomain == existing.normalizedDomain) {
        return existing;
      }
      if (candidate.companyContactKey != '|' &&
          candidate.companyContactKey == existing.companyContactKey) {
        return existing;
      }
    }
    return null;
  }

  void setCandidateSelected(int index, bool selected) {
    if (index < 0 || index >= _preview.length) return;
    _preview[index].selected = selected;
    notifyListeners();
  }

  Future<int> confirmImport() async {
    var imported = 0;
    for (final candidate in _preview.where((item) => item.selected)) {
      if (findDuplicate(candidate.lead) != null) continue;
      await _repository.save(candidate.lead);
      _leads.insert(0, candidate.lead);
      imported++;
    }
    _preview = [];
    notifyListeners();
    return imported;
  }

  void clearPreview() {
    _preview = [];
    _error = null;
    _parseWarning = null;
    _failedChunks.clear();
    _parsedAccumulator = [];
    _cancelRequested = false;
    _parseProgress = const ParseProgress();
    notifyListeners();
  }

  Future<void> updateLead(CrmLead lead) async {
    final updated = lead.copyWith(updatedAt: DateTime.now());
    await _repository.save(updated);
    final index = _leads.indexWhere((item) => item.id == updated.id);
    if (index >= 0) _leads[index] = updated;
    notifyListeners();
  }

  Future<void> generateOutreach(CrmLead lead) async {
    _error = null;
    notifyListeners();
    try {
      final outreach = await _ai.generateOutreach(lead);
      await updateLead(
        lead.copyWith(outreach: outreach, pipelineStatus: 'draft_ready'),
      );
    } on LeadAiException catch (error) {
      _error = error.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> generateOffer(CrmLead lead) async {
    _error = null;
    notifyListeners();
    try {
      final offer = await _ai.generateOffer(lead);
      await updateLead(lead.copyWith(offer: offer));
    } on LeadAiException catch (error) {
      _error = error.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshGmailStatus() async {
    try {
      _gmail = await _ai.getGmailStatus();
    } on LeadAiException catch (error) {
      _error = error.message;
    }
    notifyListeners();
  }

  Future<Uri> getGmailConnectUrl() => _ai.getGmailConnectUrl();

  Future<void> disconnectGmail() async {
    await _ai.disconnectGmail();
    _gmail = const GmailConnectionStatus(connected: false);
    notifyListeners();
  }

  Future<void> sendEmail({
    required CrmLead lead,
    required String subject,
    required String body,
    required String idempotencyKey,
  }) async {
    final approved = lead.copyWith(pipelineStatus: 'approved');
    await updateLead(approved);
    try {
      await _ai.sendEmail(
        lead: approved,
        subject: subject,
        body: body,
        idempotencyKey: idempotencyKey,
      );
      final sentAt = DateTime.now();
      await updateLead(
        approved.copyWith(
          pipelineStatus: 'waiting',
          sentAt: sentAt,
          followUpAt: sentAt.add(const Duration(days: 5)),
        ),
      );
    } on LeadAiException catch (error) {
      _error = error.message;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshFollowUpStatuses() async {
    final now = DateTime.now();
    for (var index = 0; index < _leads.length; index++) {
      final lead = _leads[index];
      if (lead.pipelineStatus == 'waiting' &&
          lead.followUpAt != null &&
          !lead.followUpAt!.isAfter(now)) {
        final updated = lead.copyWith(pipelineStatus: 'follow_up_due');
        await _repository.save(updated);
        _leads[index] = updated;
      }
    }
  }

  // ===========================================================================
  // DELETE OPERATIONS
  // ===========================================================================

  Future<void> softDelete(String leadId) async {
    await _repository.softDelete(leadId);
    _leads.removeWhere((lead) => lead.id == leadId);
    notifyListeners();
  }

  Future<void> restore(String leadId) async {
    final lead = await _repository.getById(leadId);
    if (lead != null) {
      await _repository.restore(leadId);
      final index = _leads.indexWhere((item) => item.id == leadId);
      if (index >= 0) {
        _leads[index] = lead.copyWith(deletedAt: null);
      } else {
        _leads.insert(0, lead.copyWith(deletedAt: null));
      }
      notifyListeners();
    }
  }

  Future<void> permanentDelete(String leadId) async {
    await _repository.permanentDelete(leadId);
    _leads.removeWhere((lead) => lead.id == leadId);
    notifyListeners();
  }

  // ===========================================================================
  // BULK OPERATIONS
  // ===========================================================================

  Future<void> saveAll(List<CrmLead> leads) async {
    await _repository.saveAll(leads);
    for (final lead in leads) {
      final index = _leads.indexWhere((item) => item.id == lead.id);
      if (index >= 0) {
        _leads[index] = lead;
      } else {
        _leads.insert(0, lead);
      }
    }
    notifyListeners();
  }

  Future<void> softDeleteAll(List<String> leadIds) async {
    await _repository.softDeleteAll(leadIds);
    _leads.removeWhere((lead) => leadIds.contains(lead.id));
    notifyListeners();
  }

  Future<void> permanentDeleteAll(List<String> leadIds) async {
    await _repository.permanentDeleteAll(leadIds);
    _leads.removeWhere((lead) => leadIds.contains(lead.id));
    notifyListeners();
  }

  // ===========================================================================
  // STAGE & STATUS OPERATIONS
  // ===========================================================================

  Future<void> changeStage(String leadId, String newStage) async {
    await _repository.changeStage(leadId, newStage);
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index >= 0) {
      _leads[index] = _leads[index].copyWith(
        stage: newStage,
        updatedAt: DateTime.now(),
        version: _leads[index].version + 1,
        syncStatus: 'pending',
      );
      notifyListeners();
    }
  }

  Future<void> bulkChangeStage(List<String> leadIds, String newStage) async {
    await _repository.bulkChangeStage(leadIds, newStage);
    for (final leadId in leadIds) {
      final index = _leads.indexWhere((lead) => lead.id == leadId);
      if (index >= 0) {
        _leads[index] = _leads[index].copyWith(
          stage: newStage,
          updatedAt: DateTime.now(),
          version: _leads[index].version + 1,
          syncStatus: 'pending',
        );
      }
    }
    notifyListeners();
  }

  Future<void> changeStatus(String leadId, String newStatus) async {
    await _repository.changeStatus(leadId, newStatus);
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index >= 0) {
      _leads[index] = _leads[index].copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
        version: _leads[index].version + 1,
        syncStatus: 'pending',
      );
      notifyListeners();
    }
  }

  Future<void> bulkChangeStatus(List<String> leadIds, String newStatus) async {
    await _repository.bulkChangeStatus(leadIds, newStatus);
    for (final leadId in leadIds) {
      final index = _leads.indexWhere((lead) => lead.id == leadId);
      if (index >= 0) {
        _leads[index] = _leads[index].copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
          version: _leads[index].version + 1,
          syncStatus: 'pending',
        );
      }
    }
    notifyListeners();
  }

  // ===========================================================================
  // SCORE OPERATIONS
  // ===========================================================================

  Future<void> updateScore(String leadId, double score, String reason) async {
    await _repository.updateScore(leadId, score, reason);
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index >= 0) {
      _leads[index] = _leads[index].copyWith(
        score: score,
        scoreReason: reason,
        updatedAt: DateTime.now(),
        version: _leads[index].version + 1,
        syncStatus: 'pending',
      );
      notifyListeners();
    }
  }

  Future<void> bulkUpdateScores(Map<String, double> leadIdToScore) async {
    await _repository.bulkUpdateScores(leadIdToScore);
    for (final entry in leadIdToScore.entries) {
      final index = _leads.indexWhere((lead) => lead.id == entry.key);
      if (index >= 0) {
        _leads[index] = _leads[index].copyWith(
          score: entry.value,
          scoreReason: 'Bulk update',
          updatedAt: DateTime.now(),
          version: _leads[index].version + 1,
          syncStatus: 'pending',
        );
      }
    }
    notifyListeners();
  }

  // ===========================================================================
  // TAG OPERATIONS
  // ===========================================================================

  Future<void> addTag(String leadId, String tag) async {
    await _repository.addTag(leadId, tag);
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index >= 0) {
      final newTags = List<String>.from(_leads[index].tags);
      if (!newTags.contains(tag)) {
        newTags.add(tag);
      }
      _leads[index] = _leads[index].copyWith(
        tags: newTags,
        updatedAt: DateTime.now(),
        version: _leads[index].version + 1,
        syncStatus: 'pending',
      );
      notifyListeners();
    }
  }

  Future<void> removeTag(String leadId, String tag) async {
    await _repository.removeTag(leadId, tag);
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index >= 0) {
      final newTags = List<String>.from(_leads[index].tags)..remove(tag);
      _leads[index] = _leads[index].copyWith(
        tags: newTags,
        updatedAt: DateTime.now(),
        version: _leads[index].version + 1,
        syncStatus: 'pending',
      );
      notifyListeners();
    }
  }

  Future<void> bulkAddTags(List<String> leadIds, List<String> tags) async {
    await _repository.bulkAddTags(leadIds, tags);
    for (final leadId in leadIds) {
      final index = _leads.indexWhere((lead) => lead.id == leadId);
      if (index >= 0) {
        final newTags = List<String>.from(_leads[index].tags);
        for (final tag in tags) {
          if (!newTags.contains(tag)) {
            newTags.add(tag);
          }
        }
        _leads[index] = _leads[index].copyWith(
          tags: newTags,
          updatedAt: DateTime.now(),
          version: _leads[index].version + 1,
          syncStatus: 'pending',
        );
      }
    }
    notifyListeners();
  }

  Future<void> bulkRemoveTags(List<String> leadIds, List<String> tags) async {
    await _repository.bulkRemoveTags(leadIds, tags);
    for (final leadId in leadIds) {
      final index = _leads.indexWhere((lead) => lead.id == leadId);
      if (index >= 0) {
        final newTags = List<String>.from(_leads[index].tags);
        for (final tag in tags) {
          newTags.remove(tag);
        }
        _leads[index] = _leads[index].copyWith(
          tags: newTags,
          updatedAt: DateTime.now(),
          version: _leads[index].version + 1,
          syncStatus: 'pending',
        );
      }
    }
    notifyListeners();
  }

  // ===========================================================================
  // NOTES OPERATIONS
  // ===========================================================================

  Future<void> updateNotes(String leadId, String notes) async {
    await _repository.updateNotes(leadId, notes);
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index >= 0) {
      _leads[index] = _leads[index].copyWith(
        notes: notes,
        updatedAt: DateTime.now(),
        version: _leads[index].version + 1,
        syncStatus: 'pending',
      );
      notifyListeners();
    }
  }

  Future<void> appendNotes(String leadId, String additionalNotes) async {
    await _repository.appendNotes(leadId, additionalNotes);
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index >= 0) {
      final lead = _leads[index];
      final newNotes = lead.notes.isEmpty
          ? additionalNotes
          : '${lead.notes}\n\n$additionalNotes';
      _leads[index] = lead.copyWith(
        notes: newNotes,
        updatedAt: DateTime.now(),
        version: lead.version + 1,
        syncStatus: 'pending',
      );
      notifyListeners();
    }
  }

  // ===========================================================================
  // FOLLOW-UP OPERATIONS
  // ===========================================================================

  Future<void> updateFollowUp(String leadId, DateTime followUpAt) async {
    await _repository.updateFollowUp(leadId, followUpAt);
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index >= 0) {
      _leads[index] = _leads[index].copyWith(
        followUpAt: followUpAt,
        updatedAt: DateTime.now(),
        version: _leads[index].version + 1,
        syncStatus: 'pending',
      );
      notifyListeners();
    }
  }

  Future<void> markAsContacted(String leadId, {DateTime? contactedAt}) async {
    await _repository.markAsContacted(leadId, contactedAt: contactedAt);
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index >= 0) {
      _leads[index] = _leads[index].copyWith(
        lastContactedAt: contactedAt ?? DateTime.now(),
        status: 'contacted',
        updatedAt: DateTime.now(),
        version: _leads[index].version + 1,
        syncStatus: 'pending',
      );
      notifyListeners();
    }
  }

  // ===========================================================================
  // SEARCH & FILTER OPERATIONS
  // ===========================================================================

  Future<List<CrmLead>> search(String query) async {
    return await _repository.search(query);
  }

  Future<List<CrmLead>> filter({
    List<String>? stages,
    List<String>? statuses,
    List<String>? tags,
    List<String>? sources,
    String? contactName,
    String? companyName,
    String? email,
    String? phone,
    String? country,
    String? sector,
    double? minScore,
    double? maxScore,
    bool? includeDeleted,
    DateTime? createdFrom,
    DateTime? createdTo,
    DateTime? updatedFrom,
    DateTime? updatedTo,
    DateTime? followUpFrom,
    DateTime? followUpTo,
  }) async {
    return await _repository.filter(
      stages: stages,
      statuses: statuses,
      tags: tags,
      sources: sources,
      contactName: contactName,
      companyName: companyName,
      email: email,
      phone: phone,
      country: country,
      sector: sector,
      minScore: minScore,
      maxScore: maxScore,
      includeDeleted: includeDeleted,
      createdFrom: createdFrom,
      createdTo: createdTo,
      updatedFrom: updatedFrom,
      updatedTo: updatedTo,
      followUpFrom: followUpFrom,
      followUpTo: followUpTo,
    );
  }

  Future<List<CrmLead>> getByPipelineStatus(String status) async {
    return await _repository.getByPipelineStatus(status);
  }

  Future<List<CrmLead>> getByStage(String stage) async {
    return await _repository.getByStage(stage);
  }

  Future<List<CrmLead>> getByTag(String tag) async {
    return await _repository.getByTag(tag);
  }

  Future<List<CrmLead>> getBySource(String source) async {
    return await _repository.getBySource(source);
  }

  // ===========================================================================
  // SORTING & PAGINATION
  // ===========================================================================

  Future<List<CrmLead>> getAllSorted({
    String sortBy = 'updatedAt',
    bool descending = true,
  }) async {
    return await _repository.getAllSorted(
      sortBy: sortBy,
      descending: descending,
    );
  }

  Future<List<CrmLead>> getAllPaginated({
    int offset = 0,
    int limit = 50,
    String sortBy = 'updatedAt',
    bool descending = true,
  }) async {
    return await _repository.getAllPaginated(
      offset: offset,
      limit: limit,
      sortBy: sortBy,
      descending: descending,
    );
  }

  Future<int> count({
    bool? includeDeleted,
    List<String>? stages,
    List<String>? statuses,
    List<String>? tags,
  }) async {
    return await _repository.count(
      includeDeleted: includeDeleted,
      stages: stages,
      statuses: statuses,
      tags: tags,
    );
  }

  // ===========================================================================
  // SYNC STATUS OPERATIONS
  // ===========================================================================

  Future<List<CrmLead>> getBySyncStatus(String status) async {
    return await _repository.getBySyncStatus(status);
  }

  Future<List<CrmLead>> getNeedingSync() async {
    return await _repository.getNeedingSync();
  }

  Future<void> updateSyncStatus(String leadId, String syncStatus) async {
    await _repository.updateSyncStatus(leadId, syncStatus);
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index >= 0) {
      _leads[index] = _leads[index].copyWith(
        syncStatus: syncStatus,
        updatedAt: DateTime.now(),
        version: _leads[index].version + 1,
      );
      notifyListeners();
    }
  }

  // ===========================================================================
  // TENANT OPERATIONS
  // ===========================================================================

  Future<List<CrmLead>> getByTenant(String tenantId) async {
    return await _repository.getByTenant(tenantId);
  }

  Future<void> transferToTenant(String leadId, String newTenantId) async {
    await _repository.transferToTenant(leadId, newTenantId);
    final index = _leads.indexWhere((lead) => lead.id == leadId);
    if (index >= 0) {
      _leads[index] = _leads[index].copyWith(
        tenantId: newTenantId,
        updatedAt: DateTime.now(),
        version: _leads[index].version + 1,
        syncStatus: 'pending',
      );
      notifyListeners();
    }
  }
}
