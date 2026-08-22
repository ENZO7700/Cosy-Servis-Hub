// Lead model for CRM - Single Source of Truth
// This is the unified, immutable lead model used across the entire application.
// UI must NEVER import Isar, Sembast, or Supabase directly.
// All data access must go through LeadRepository.

/// Pipeline statuses for lead workflow
class LeadPipelineStatus {
  static const new_ = 'new';
  static const draftReady = 'draft_ready';
  static const approved = 'approved';
  static const sent = 'sent';
  static const waiting = 'waiting';
  static const followUpDue = 'follow_up_due';
  static const replied = 'replied';
  static const won = 'won';
  static const lost = 'lost';

  static const all = <String>[
    new_,
    draftReady,
    approved,
    sent,
    waiting,
    followUpDue,
    replied,
    won,
    lost,
  ];
}

/// Sales pipeline stages
class LeadStage {
  static const new_ = 'new';
  static const qualified = 'qualified';
  static const contacted = 'contacted';
  static const proposal = 'proposal';
  static const negotiation = 'negotiation';
  static const won = 'won';
  static const lost = 'lost';

  static const all = <String>[
    new_,
    qualified,
    contacted,
    proposal,
    negotiation,
    won,
    lost,
  ];
}

/// Lead status (different from pipeline status)
class LeadStatus {
  static const active = 'active';
  static const contacted = 'contacted';
  static const responded = 'responded';
  static const unresponsive = 'unresponsive';
  static const converted = 'converted';
  static const rejected = 'rejected';

  static const all = <String>[
    active,
    contacted,
    responded,
    unresponsive,
    converted,
    rejected,
  ];
}

/// Sync status for offline-first operations
class LeadSyncStatus {
  static const local = 'local';
  static const pending = 'pending';
  static const syncing = 'syncing';
  static const synced = 'synced';
  static const conflict = 'conflict';
  static const error = 'error';

  static const all = <String>[local, pending, syncing, synced, conflict, error];
}

/// Outreach drafts and templates for lead communication
class LeadOutreach {
  final String subjectSk;
  final String emailSk;
  final String subjectEn;
  final String emailEn;
  final String linkedInMessage;
  final String followUpDay5;

  const LeadOutreach({
    this.subjectSk = '',
    this.emailSk = '',
    this.subjectEn = '',
    this.emailEn = '',
    this.linkedInMessage = '',
    this.followUpDay5 = '',
  });

  factory LeadOutreach.fromJson(Map<String, dynamic>? json) {
    final value = json ?? const <String, dynamic>{};
    return LeadOutreach(
      subjectSk: value['subject_sk'] as String? ?? '',
      emailSk: value['email_sk'] as String? ?? '',
      subjectEn: value['subject_en'] as String? ?? '',
      emailEn: value['email_en'] as String? ?? '',
      linkedInMessage: value['linkedin_message'] as String? ?? '',
      followUpDay5: value['follow_up_day_5'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'subject_sk': subjectSk,
    'email_sk': emailSk,
    'subject_en': subjectEn,
    'email_en': emailEn,
    'linkedin_message': linkedInMessage,
    'follow_up_day_5': followUpDay5,
  };

  LeadOutreach copyWith({
    String? subjectSk,
    String? emailSk,
    String? subjectEn,
    String? emailEn,
    String? linkedInMessage,
    String? followUpDay5,
  }) {
    return LeadOutreach(
      subjectSk: subjectSk ?? this.subjectSk,
      emailSk: emailSk ?? this.emailSk,
      subjectEn: subjectEn ?? this.subjectEn,
      emailEn: emailEn ?? this.emailEn,
      linkedInMessage: linkedInMessage ?? this.linkedInMessage,
      followUpDay5: followUpDay5 ?? this.followUpDay5,
    );
  }
}

/// Offer details for lead
class LeadOffer {
  final String recommendedSolution;
  final String problemAndBenefit;
  final List<String> coreFeatures;
  final List<String> mvpScope;
  final List<String> optionalExtensions;
  final String priceRange;
  final String duration;
  final String nextStep;

  const LeadOffer({
    this.recommendedSolution = '',
    this.problemAndBenefit = '',
    this.coreFeatures = const [],
    this.mvpScope = const [],
    this.optionalExtensions = const [],
    this.priceRange = '',
    this.duration = '',
    this.nextStep = '',
  });

  factory LeadOffer.fromJson(Map<String, dynamic>? json) {
    final value = json ?? const <String, dynamic>{};
    List<String> strings(String key) =>
        (value[key] as List<dynamic>? ?? const []).map((e) => '$e').toList();
    return LeadOffer(
      recommendedSolution: value['recommended_solution'] as String? ?? '',
      problemAndBenefit: value['problem_and_benefit'] as String? ?? '',
      coreFeatures: strings('core_features'),
      mvpScope: strings('mvp_scope'),
      optionalExtensions: strings('optional_extensions'),
      priceRange: value['price_range'] as String? ?? '',
      duration: value['duration'] as String? ?? '',
      nextStep: value['next_step'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'recommended_solution': recommendedSolution,
    'problem_and_benefit': problemAndBenefit,
    'core_features': coreFeatures,
    'mvp_scope': mvpScope,
    'optional_extensions': optionalExtensions,
    'price_range': priceRange,
    'duration': duration,
    'next_step': nextStep,
  };

  LeadOffer copyWith({
    String? recommendedSolution,
    String? problemAndBenefit,
    List<String>? coreFeatures,
    List<String>? mvpScope,
    List<String>? optionalExtensions,
    String? priceRange,
    String? duration,
    String? nextStep,
  }) {
    return LeadOffer(
      recommendedSolution: recommendedSolution ?? this.recommendedSolution,
      problemAndBenefit: problemAndBenefit ?? this.problemAndBenefit,
      coreFeatures: coreFeatures ?? this.coreFeatures,
      mvpScope: mvpScope ?? this.mvpScope,
      optionalExtensions: optionalExtensions ?? this.optionalExtensions,
      priceRange: priceRange ?? this.priceRange,
      duration: duration ?? this.duration,
      nextStep: nextStep ?? this.nextStep,
    );
  }
}

/// Main Lead model - Single Source of Truth
class CrmLead {
  static const pipelineStatuses = LeadPipelineStatus.all;
  static const stages = LeadStage.all;
  static const statuses = LeadStatus.all;

  // IDs
  final String id;
  final String tenantId;
  final String ownerId;

  // Company information
  final String companyName;
  final String website;
  final String location;
  final String country;
  final String companySize;
  final String sector;

  // Contact information
  final String contactName;
  final String contactRole;
  final String email;
  final String phone;
  final String linkedIn;

  // Metadata
  final String source;
  final String status;
  final String stage;

  // Scoring
  final double score;
  final String scoreReason;
  final Map<String, int> partialScores;

  // Value
  final double? estimatedValue;

  // Categorization
  final List<String> tags;
  final String notes;

  // AI Analysis
  final String problem;
  final String decisionMaker;
  final String trigger;
  final String revenueEstimate;

  // Outreach status
  final String outreachStatus;

  // Data sources and uncertainty tracking
  final List<String> sources;
  final List<String> uncertainFields;
  final String rawText;

  // Outreach and offer
  final LeadOutreach outreach;
  final LeadOffer? offer;

  // Pipeline status (legacy, for backward compatibility)
  final String pipelineStatus;

  // Timestamps
  final DateTime createdAt;
  final DateTime importedAt;
  final DateTime updatedAt;
  final DateTime? lastContactedAt;
  final DateTime? followUpAt;
  final DateTime? sentAt;
  final DateTime? deletedAt;

  // Sync and versioning
  final String syncStatus;
  final int version;

  const CrmLead({
    // IDs
    required this.id,
    this.tenantId = '',
    this.ownerId = '',

    // Company information
    required this.companyName,
    this.website = '',
    this.location = '',
    this.country = '',
    this.companySize = '',
    this.sector = '',

    // Contact information
    this.contactName = '',
    this.contactRole = '',
    this.email = '',
    this.phone = '',
    this.linkedIn = '',

    // Metadata
    this.source = '',
    this.status = LeadStatus.active,
    this.stage = LeadStage.new_,

    // Scoring
    this.score = 0,
    this.scoreReason = '',
    this.partialScores = const {},

    // Value
    this.estimatedValue,

    // Categorization
    this.tags = const [],
    this.notes = '',

    // AI Analysis
    this.problem = '',
    this.decisionMaker = '',
    this.trigger = '',
    this.revenueEstimate = '',

    // Outreach status
    this.outreachStatus = 'pending',

    // Data sources and uncertainty tracking
    this.sources = const [],
    this.uncertainFields = const [],
    this.rawText = '',

    // Outreach and offer
    this.outreach = const LeadOutreach(),
    this.offer,

    // Pipeline status (legacy)
    this.pipelineStatus = LeadPipelineStatus.new_,

    // Timestamps
    required this.createdAt,
    required this.importedAt,
    required this.updatedAt,
    this.lastContactedAt,
    this.followUpAt,
    this.sentAt,
    this.deletedAt,

    // Sync and versioning
    this.syncStatus = LeadSyncStatus.local,
    this.version = 1,
  });

  factory CrmLead.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    return CrmLead(
      id: _asString(json['id']),
      tenantId: _asString(json['tenant_id']),
      ownerId: _asString(json['owner_id']),
      companyName: _asString(json['company_name']),
      website: _asString(json['website']),
      location: _asString(json['location']),
      country: _asString(json['country']),
      companySize: _asString(json['company_size']),
      sector: _asString(json['sector']),
      contactName: _asString(json['contact_name']),
      contactRole: _asString(json['contact_role']),
      email: _asString(json['email']),
      phone: _asString(json['phone']),
      linkedIn: _asString(json['linkedin']),
      source: _asString(json['source']),
      status: _asString(json['status'], fallback: LeadStatus.active),
      stage: _asString(json['stage'], fallback: LeadStage.new_),
      score: _asDouble(json['score']),
      scoreReason: _asString(json['score_reason']),
      partialScores: _asIntMap(json['partial_scores']),
      estimatedValue: _asNullableDouble(json['estimated_value']),
      tags: _asStringList(json['tags']),
      notes: _asString(json['notes']),
      problem: _asString(json['problem']),
      decisionMaker: _asString(json['decision_maker']),
      trigger: _asString(json['trigger']),
      revenueEstimate: _asString(json['revenue_estimate']),
      outreachStatus: _asString(json['outreach_status'], fallback: 'pending'),
      sources: _asStringList(json['sources']),
      uncertainFields: _asStringList(json['uncertain_fields']),
      rawText: _asString(json['raw_text']),
      outreach: LeadOutreach.fromJson(_asStringKeyedMap(json['outreach'])),
      offer: json['offer'] is Map
          ? LeadOffer.fromJson(_asStringKeyedMap(json['offer']))
          : null,
      pipelineStatus: LeadPipelineStatus.all.contains(json['pipeline_status'])
          ? _asString(json['pipeline_status'])
          : LeadPipelineStatus.new_,
      createdAt: _asDateTime(json['created_at']) ?? now,
      importedAt: _asDateTime(json['imported_at']) ?? now,
      updatedAt: _asDateTime(json['updated_at']) ?? now,
      lastContactedAt: _asDateTime(json['last_contacted_at']),
      followUpAt: _asDateTime(json['follow_up_at']),
      sentAt: _asDateTime(json['sent_at']),
      deletedAt: _asDateTime(json['deleted_at']),
      syncStatus: _asString(
        json['sync_status'],
        fallback: LeadSyncStatus.local,
      ),
      version: _asInt(json['version'], fallback: 1),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'owner_id': ownerId,
    'company_name': companyName,
    'website': website,
    'location': location,
    'country': country,
    'company_size': companySize,
    'sector': sector,
    'contact_name': contactName,
    'contact_role': contactRole,
    'email': email,
    'phone': phone,
    'linkedin': linkedIn,
    'source': source,
    'status': status,
    'stage': stage,
    'score': score,
    'score_reason': scoreReason,
    'partial_scores': partialScores,
    'estimated_value': estimatedValue,
    'tags': tags,
    'notes': notes,
    'problem': problem,
    'decision_maker': decisionMaker,
    'trigger': trigger,
    'revenue_estimate': revenueEstimate,
    'outreach_status': outreachStatus,
    'sources': sources,
    'uncertain_fields': uncertainFields,
    'raw_text': rawText,
    'outreach': outreach.toJson(),
    'offer': offer?.toJson(),
    'pipeline_status': pipelineStatus,
    'created_at': createdAt.toIso8601String(),
    'imported_at': importedAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'last_contacted_at': lastContactedAt?.toIso8601String(),
    'follow_up_at': followUpAt?.toIso8601String(),
    'sent_at': sentAt?.toIso8601String(),
    'deleted_at': deletedAt?.toIso8601String(),
    'sync_status': syncStatus,
    'version': version,
  };

  /// Computed properties
  String get normalizedEmail => email.trim().toLowerCase();

  String get normalizedDomain {
    var value = website.trim().toLowerCase();
    value = value.replaceFirst(RegExp(r'^https?://'), '');
    value = value.replaceFirst(RegExp(r'^www\.'), '');
    return value.split('/').first;
  }

  String get companyContactKey =>
      '${companyName.trim().toLowerCase()}|${contactName.trim().toLowerCase()}';

  bool get hasValidEmail => RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    caseSensitive: false,
  ).hasMatch(email.trim());

  bool get isDeleted => deletedAt != null;

  bool get isSyncPending => syncStatus == 'pending';

  CrmLead withSoftDelete() => copyWith(
    deletedAt: DateTime.now(),
    syncStatus: 'pending',
    version: version + 1,
  );

  CrmLead withRestore() =>
      copyWith(deletedAt: null, syncStatus: 'pending', version: version + 1);

  CrmLead copyWith({
    String? id,
    String? tenantId,
    String? companyName,
    String? website,
    String? location,
    String? country,
    String? companySize,
    String? sector,
    String? contactName,
    String? contactRole,
    String? email,
    String? phone,
    String? linkedIn,
    String? source,
    String? status,
    String? stage,
    double? score,
    String? scoreReason,
    Map<String, int>? partialScores,
    List<String>? tags,
    String? notes,
    String? problem,
    String? decisionMaker,
    String? trigger,
    String? revenueEstimate,
    String? outreachStatus,
    List<String>? sources,
    List<String>? uncertainFields,
    String? rawText,
    LeadOutreach? outreach,
    LeadOffer? offer,
    String? pipelineStatus,
    DateTime? createdAt,
    DateTime? importedAt,
    DateTime? updatedAt,
    DateTime? lastContactedAt,
    DateTime? followUpAt,
    DateTime? sentAt,
    DateTime? deletedAt,
    String? syncStatus,
    int? version,
  }) {
    return CrmLead(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      companyName: companyName ?? this.companyName,
      website: website ?? this.website,
      location: location ?? this.location,
      country: country ?? this.country,
      companySize: companySize ?? this.companySize,
      sector: sector ?? this.sector,
      contactName: contactName ?? this.contactName,
      contactRole: contactRole ?? this.contactRole,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      linkedIn: linkedIn ?? this.linkedIn,
      source: source ?? this.source,
      status: status ?? this.status,
      stage: stage ?? this.stage,
      score: score ?? this.score,
      scoreReason: scoreReason ?? this.scoreReason,
      partialScores: partialScores ?? this.partialScores,
      tags: tags ?? this.tags,
      notes: notes ?? this.notes,
      problem: problem ?? this.problem,
      decisionMaker: decisionMaker ?? this.decisionMaker,
      trigger: trigger ?? this.trigger,
      revenueEstimate: revenueEstimate ?? this.revenueEstimate,
      outreachStatus: outreachStatus ?? this.outreachStatus,
      sources: sources ?? this.sources,
      uncertainFields: uncertainFields ?? this.uncertainFields,
      rawText: rawText ?? this.rawText,
      outreach: outreach ?? this.outreach,
      offer: offer ?? this.offer,
      pipelineStatus: pipelineStatus ?? this.pipelineStatus,
      createdAt: createdAt ?? this.createdAt,
      importedAt: importedAt ?? this.importedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastContactedAt: lastContactedAt ?? this.lastContactedAt,
      followUpAt: followUpAt ?? this.followUpAt,
      sentAt: sentAt ?? this.sentAt,
      deletedAt: deletedAt ?? this.deletedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
    );
  }

  @override
  String toString() => 'CrmLead(id: $id, company: $companyName, stage: $stage)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrmLead && other.id == id && other.version == version;

  @override
  int get hashCode => id.hashCode ^ version.hashCode;
}

// ---------------------------------------------------------------------------
// Tolerant JSON helpers — Mistral/edge payloads often mix string/number types.
// ---------------------------------------------------------------------------

String _asString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value;
  return '$value';
}

double _asDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

double? _asNullableDouble(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

List<String> _asStringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => '$item').toList();
}

Map<String, dynamic>? _asStringKeyedMap(Object? value) {
  if (value is! Map) return null;
  return value.map((key, item) => MapEntry('$key', item));
}

Map<String, int> _asIntMap(Object? value) {
  final map = _asStringKeyedMap(value);
  if (map == null) return const {};
  return map.map((key, item) => MapEntry(key, _asInt(item)));
}
