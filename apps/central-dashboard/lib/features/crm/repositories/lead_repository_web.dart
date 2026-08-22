import 'package:sembast_web/sembast_web.dart';

import '../models/crm_lead.dart';
import './lead_repository.dart';

LeadRepository createPlatformLeadRepository() => WebLeadRepository();

class WebLeadRepository implements LeadRepository {
  final StoreRef<String, Map<String, Object?>> _store = stringMapStoreFactory
      .store('crm_leads');
  Database? _database;

  Future<Database> get _db async {
    return _database ??= await databaseFactoryWeb.openDatabase(
      'cmr_plus_lead_inbox.db',
    );
  }

  // ===========================================================================
  // BASIC CRUD OPERATIONS
  // ===========================================================================

  @override
  Future<List<CrmLead>> getAll() async {
    final snapshots = await _store.find(
      await _db,
      finder: Finder(sortOrders: [SortOrder('updated_at', false)]),
    );
    return snapshots
        .map((snapshot) => CrmLead.fromJson(snapshot.value))
        .toList();
  }

  @override
  Future<CrmLead?> getById(String leadId) async {
    final snapshot = await _store.record(leadId).get(await _db);
    if (snapshot == null) return null;
    return CrmLead.fromJson(snapshot);
  }

  @override
  Future<void> save(CrmLead lead) async {
    await _store.record(lead.id).put(await _db, lead.toJson());
  }

  @override
  Future<void> softDelete(String leadId) async {
    final lead = await getById(leadId);
    if (lead != null && !lead.isDeleted) {
      await save(lead.withSoftDelete());
    }
  }

  @override
  Future<void> restore(String leadId) async {
    final lead = await getById(leadId);
    if (lead != null && lead.isDeleted) {
      await save(lead.withRestore());
    }
  }

  @override
  Future<void> permanentDelete(String leadId) async {
    await _store.record(leadId).delete(await _db);
  }

  // ===========================================================================
  // BULK OPERATIONS
  // ===========================================================================

  @override
  Future<void> saveAll(List<CrmLead> leads) async {
    final db = await _db;
    for (final lead in leads) {
      await _store.record(lead.id).put(db, lead.toJson());
    }
  }

  @override
  Future<void> softDeleteAll(List<String> leadIds) async {
    for (final leadId in leadIds) {
      await softDelete(leadId);
    }
  }

  @override
  Future<void> permanentDeleteAll(List<String> leadIds) async {
    final db = await _db;
    for (final leadId in leadIds) {
      await _store.record(leadId).delete(db);
    }
  }

  // ===========================================================================
  // STAGE & STATUS OPERATIONS
  // ===========================================================================

  @override
  Future<void> changeStage(String leadId, String newStage) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final updatedLead = lead.copyWith(
        stage: newStage,
        updatedAt: DateTime.now(),
        version: lead.version + 1,
        syncStatus: 'pending',
      );
      await save(updatedLead);
    }
  }

  @override
  Future<void> bulkChangeStage(List<String> leadIds, String newStage) async {
    for (final leadId in leadIds) {
      await changeStage(leadId, newStage);
    }
  }

  @override
  Future<void> changeStatus(String leadId, String newStatus) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final updatedLead = lead.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
        version: lead.version + 1,
        syncStatus: 'pending',
      );
      await save(updatedLead);
    }
  }

  @override
  Future<void> bulkChangeStatus(List<String> leadIds, String newStatus) async {
    for (final leadId in leadIds) {
      await changeStatus(leadId, newStatus);
    }
  }

  // ===========================================================================
  // SCORE OPERATIONS
  // ===========================================================================

  @override
  Future<void> updateScore(String leadId, double score, String reason) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final updatedLead = lead.copyWith(
        score: score,
        scoreReason: reason,
        updatedAt: DateTime.now(),
        version: lead.version + 1,
        syncStatus: 'pending',
      );
      await save(updatedLead);
    }
  }

  @override
  Future<void> bulkUpdateScores(Map<String, double> leadIdToScore) async {
    for (final entry in leadIdToScore.entries) {
      await updateScore(entry.key, entry.value, 'Bulk update');
    }
  }

  // ===========================================================================
  // TAG OPERATIONS
  // ===========================================================================

  @override
  Future<void> addTag(String leadId, String tag) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final newTags = List<String>.from(lead.tags);
      if (!newTags.contains(tag)) {
        newTags.add(tag);
      }
      final updatedLead = lead.copyWith(
        tags: newTags,
        updatedAt: DateTime.now(),
        version: lead.version + 1,
        syncStatus: 'pending',
      );
      await save(updatedLead);
    }
  }

  @override
  Future<void> removeTag(String leadId, String tag) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final newTags = List<String>.from(lead.tags)..remove(tag);
      final updatedLead = lead.copyWith(
        tags: newTags,
        updatedAt: DateTime.now(),
        version: lead.version + 1,
        syncStatus: 'pending',
      );
      await save(updatedLead);
    }
  }

  @override
  Future<void> bulkAddTags(List<String> leadIds, List<String> tags) async {
    for (final leadId in leadIds) {
      for (final tag in tags) {
        await addTag(leadId, tag);
      }
    }
  }

  @override
  Future<void> bulkRemoveTags(List<String> leadIds, List<String> tags) async {
    for (final leadId in leadIds) {
      for (final tag in tags) {
        await removeTag(leadId, tag);
      }
    }
  }

  // ===========================================================================
  // NOTES OPERATIONS
  // ===========================================================================

  @override
  Future<void> updateNotes(String leadId, String notes) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final updatedLead = lead.copyWith(
        notes: notes,
        updatedAt: DateTime.now(),
        version: lead.version + 1,
        syncStatus: 'pending',
      );
      await save(updatedLead);
    }
  }

  @override
  Future<void> appendNotes(String leadId, String additionalNotes) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final updatedLead = lead.copyWith(
        notes: lead.notes.isEmpty
            ? additionalNotes
            : '${lead.notes}\n\n$additionalNotes',
        updatedAt: DateTime.now(),
        version: lead.version + 1,
        syncStatus: 'pending',
      );
      await save(updatedLead);
    }
  }

  // ===========================================================================
  // FOLLOW-UP OPERATIONS
  // ===========================================================================

  @override
  Future<void> updateFollowUp(String leadId, DateTime followUpAt) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final updatedLead = lead.copyWith(
        followUpAt: followUpAt,
        updatedAt: DateTime.now(),
        version: lead.version + 1,
        syncStatus: 'pending',
      );
      await save(updatedLead);
    }
  }

  @override
  Future<void> markAsContacted(String leadId, {DateTime? contactedAt}) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final updatedLead = lead.copyWith(
        lastContactedAt: contactedAt ?? DateTime.now(),
        status: 'contacted',
        updatedAt: DateTime.now(),
        version: lead.version + 1,
        syncStatus: 'pending',
      );
      await save(updatedLead);
    }
  }

  // ===========================================================================
  // SEARCH & FILTER OPERATIONS
  // ===========================================================================

  @override
  Future<List<CrmLead>> search(String query) async {
    final allLeads = await getAll();
    if (query.isEmpty) return allLeads;

    final lowerQuery = query.toLowerCase();
    return allLeads
        .where(
          (lead) =>
              lead.companyName.toLowerCase().contains(lowerQuery) ||
              lead.contactName.toLowerCase().contains(lowerQuery) ||
              lead.email.toLowerCase().contains(lowerQuery) ||
              lead.phone.toLowerCase().contains(lowerQuery) ||
              lead.notes.toLowerCase().contains(lowerQuery) ||
              lead.rawText.toLowerCase().contains(lowerQuery) ||
              lead.website.toLowerCase().contains(lowerQuery) ||
              lead.sector.toLowerCase().contains(lowerQuery) ||
              lead.location.toLowerCase().contains(lowerQuery) ||
              lead.country.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  @override
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
    final allLeads = await getAll();
    return allLeads.where((lead) {
      // Deleted filter
      if (includeDeleted == false && lead.isDeleted) {
        return false;
      }

      // Stage filter
      if (stages != null && stages.isNotEmpty && !stages.contains(lead.stage)) {
        return false;
      }

      // Status filter
      if (statuses != null &&
          statuses.isNotEmpty &&
          !statuses.contains(lead.status)) {
        return false;
      }

      // Tags filter
      if (tags != null && tags.isNotEmpty) {
        final leadTags = lead.tags.toSet();
        final filterTags = tags.toSet();
        if (leadTags.intersection(filterTags).isEmpty) {
          return false;
        }
      }

      // Sources filter
      if (sources != null && sources.isNotEmpty) {
        final leadSources = lead.sources.toSet();
        final filterSources = sources.toSet();
        if (leadSources.intersection(filterSources).isEmpty) {
          return false;
        }
      }

      // Contact name filter
      if (contactName != null &&
          contactName.isNotEmpty &&
          !lead.contactName.toLowerCase().contains(contactName.toLowerCase())) {
        return false;
      }

      // Company name filter
      if (companyName != null &&
          companyName.isNotEmpty &&
          !lead.companyName.toLowerCase().contains(companyName.toLowerCase())) {
        return false;
      }

      // Email filter
      if (email != null &&
          email.isNotEmpty &&
          !lead.email.toLowerCase().contains(email.toLowerCase())) {
        return false;
      }

      // Phone filter
      if (phone != null &&
          phone.isNotEmpty &&
          !lead.phone.toLowerCase().contains(phone.toLowerCase())) {
        return false;
      }

      // Country filter
      if (country != null &&
          country.isNotEmpty &&
          !lead.country.toLowerCase().contains(country.toLowerCase())) {
        return false;
      }

      // Sector filter
      if (sector != null &&
          sector.isNotEmpty &&
          !lead.sector.toLowerCase().contains(sector.toLowerCase())) {
        return false;
      }

      // Score range filter
      if (minScore != null && lead.score < minScore) {
        return false;
      }
      if (maxScore != null && lead.score > maxScore) {
        return false;
      }

      // Date filters
      if (createdFrom != null && lead.createdAt.isBefore(createdFrom)) {
        return false;
      }
      if (createdTo != null && lead.createdAt.isAfter(createdTo)) {
        return false;
      }
      if (updatedFrom != null && lead.updatedAt.isBefore(updatedFrom)) {
        return false;
      }
      if (updatedTo != null && lead.updatedAt.isAfter(updatedTo)) {
        return false;
      }
      if (followUpFrom != null &&
          lead.followUpAt != null &&
          lead.followUpAt!.isBefore(followUpFrom)) {
        return false;
      }
      if (followUpTo != null &&
          lead.followUpAt != null &&
          lead.followUpAt!.isAfter(followUpTo)) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Future<List<CrmLead>> getByPipelineStatus(String status) async {
    final allLeads = await getAll();
    return allLeads.where((lead) => lead.pipelineStatus == status).toList();
  }

  @override
  Future<List<CrmLead>> getByStage(String stage) async {
    final allLeads = await getAll();
    return allLeads.where((lead) => lead.stage == stage).toList();
  }

  @override
  Future<List<CrmLead>> getByTag(String tag) async {
    final allLeads = await getAll();
    return allLeads.where((lead) => lead.tags.contains(tag)).toList();
  }

  @override
  Future<List<CrmLead>> getBySource(String source) async {
    final allLeads = await getAll();
    return allLeads.where((lead) => lead.sources.contains(source)).toList();
  }

  // ===========================================================================
  // SORTING & PAGINATION
  // ===========================================================================

  @override
  Future<List<CrmLead>> getAllSorted({
    String sortBy = 'updatedAt',
    bool descending = true,
  }) async {
    final allLeads = await getAll();

    allLeads.sort((a, b) => _compareLeads(a, b, sortBy, descending));
    return allLeads;
  }

  @override
  Future<List<CrmLead>> getAllPaginated({
    int offset = 0,
    int limit = 50,
    String sortBy = 'updatedAt',
    bool descending = true,
  }) async {
    final allLeads = await getAllSorted(sortBy: sortBy, descending: descending);
    return allLeads.skip(offset).take(limit).toList();
  }

  @override
  Future<int> count({
    bool? includeDeleted,
    List<String>? stages,
    List<String>? statuses,
    List<String>? tags,
  }) async {
    final filtered = await filter(
      stages: stages,
      statuses: statuses,
      tags: tags,
      includeDeleted: includeDeleted,
    );
    return filtered.length;
  }

  // ===========================================================================
  // SYNC STATUS OPERATIONS
  // ===========================================================================

  @override
  Future<List<CrmLead>> getBySyncStatus(String status) async {
    final allLeads = await getAll();
    return allLeads.where((lead) => lead.syncStatus == status).toList();
  }

  @override
  Future<List<CrmLead>> getNeedingSync() async {
    final allLeads = await getAll();
    return allLeads.where((lead) => lead.isSyncPending).toList();
  }

  @override
  Future<void> updateSyncStatus(String leadId, String syncStatus) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final updatedLead = lead.copyWith(
        syncStatus: syncStatus,
        updatedAt: DateTime.now(),
        version: lead.version + 1,
      );
      await save(updatedLead);
    }
  }

  // ===========================================================================
  // TENANT OPERATIONS
  // ===========================================================================

  @override
  Future<List<CrmLead>> getByTenant(String tenantId) async {
    final allLeads = await getAll();
    return allLeads.where((lead) => lead.tenantId == tenantId).toList();
  }

  @override
  Future<void> transferToTenant(String leadId, String newTenantId) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final updatedLead = lead.copyWith(
        tenantId: newTenantId,
        updatedAt: DateTime.now(),
        version: lead.version + 1,
        syncStatus: 'pending',
      );
      await save(updatedLead);
    }
  }

  // ===========================================================================
  // HELPER METHODS
  // ===========================================================================

  /// Helper to compare two leads for sorting
  int _compareLeads(CrmLead a, CrmLead b, String sortBy, bool descending) {
    final aValue = _getSortValue(a, sortBy);
    final bValue = _getSortValue(b, sortBy);
    final comparison = aValue.compareTo(bValue);
    return descending ? -comparison : comparison;
  }

  /// Helper to get sort value from lead
  dynamic _getSortValue(CrmLead lead, String sortBy) {
    switch (sortBy) {
      case 'id':
        return lead.id;
      case 'companyName':
        return lead.companyName.toLowerCase();
      case 'contactName':
        return lead.contactName.toLowerCase();
      case 'email':
        return lead.email.toLowerCase();
      case 'score':
        return lead.score;
      case 'stage':
        return lead.stage;
      case 'status':
        return lead.status;
      case 'createdAt':
        return lead.createdAt;
      case 'importedAt':
        return lead.importedAt;
      case 'updatedAt':
        return lead.updatedAt;
      case 'followUpAt':
        return lead.followUpAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      case 'lastContactedAt':
        return lead.lastContactedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      default:
        return lead.updatedAt;
    }
  }
}
