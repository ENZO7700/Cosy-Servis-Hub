import '../models/crm_lead.dart';
import './lead_repository_native.dart'
    if (dart.library.html) 'lead_repository_web.dart';

/// LeadRepository - Single Source of Truth for all lead operations
/// UI must NEVER import Isar, Sembast, or Supabase directly.
/// All lead data access must go through this repository.
abstract interface class LeadRepository {
  // ===========================================================================
  // BASIC CRUD OPERATIONS
  // ===========================================================================

  /// Get all leads, sorted by updatedAt descending
  Future<List<CrmLead>> getAll();

  /// Get lead by ID
  Future<CrmLead?> getById(String leadId);

  /// Save lead (create or update)
  Future<void> save(CrmLead lead);

  /// Soft delete lead (mark as deleted, keep in database)
  Future<void> softDelete(String leadId);

  /// Restore soft-deleted lead
  Future<void> restore(String leadId);

  /// Permanent delete lead (ADMIN ONLY - remove from database)
  Future<void> permanentDelete(String leadId);

  // ===========================================================================
  // BULK OPERATIONS
  // ===========================================================================

  /// Save multiple leads
  Future<void> saveAll(List<CrmLead> leads);

  /// Soft delete multiple leads
  Future<void> softDeleteAll(List<String> leadIds);

  /// Permanent delete multiple leads (ADMIN ONLY)
  Future<void> permanentDeleteAll(List<String> leadIds);

  // ===========================================================================
  // STAGE & STATUS OPERATIONS
  // ===========================================================================

  /// Change lead stage with activity tracking
  Future<void> changeStage(String leadId, String newStage);

  /// Bulk change stage for multiple leads
  Future<void> bulkChangeStage(List<String> leadIds, String newStage);

  /// Change lead status
  Future<void> changeStatus(String leadId, String newStatus);

  /// Bulk change status for multiple leads
  Future<void> bulkChangeStatus(List<String> leadIds, String newStatus);

  // ===========================================================================
  // SCORE OPERATIONS
  // ===========================================================================

  /// Update lead score with reason
  Future<void> updateScore(String leadId, double score, String reason);

  /// Bulk update scores
  Future<void> bulkUpdateScores(Map<String, double> leadIdToScore);

  // ===========================================================================
  // TAG OPERATIONS
  // ===========================================================================

  /// Add tag to lead
  Future<void> addTag(String leadId, String tag);

  /// Remove tag from lead
  Future<void> removeTag(String leadId, String tag);

  /// Bulk add tags to multiple leads
  Future<void> bulkAddTags(List<String> leadIds, List<String> tags);

  /// Bulk remove tags from multiple leads
  Future<void> bulkRemoveTags(List<String> leadIds, List<String> tags);

  // ===========================================================================
  // NOTES OPERATIONS
  // ===========================================================================

  /// Update lead notes
  Future<void> updateNotes(String leadId, String notes);

  /// Append to lead notes
  Future<void> appendNotes(String leadId, String additionalNotes);

  // ===========================================================================
  // FOLLOW-UP OPERATIONS
  // ===========================================================================

  /// Update follow-up date
  Future<void> updateFollowUp(String leadId, DateTime followUpAt);

  /// Mark as contacted
  Future<void> markAsContacted(String leadId, {DateTime? contactedAt});

  // ===========================================================================
  // SEARCH & FILTER OPERATIONS
  // ===========================================================================

  /// Search leads by query (searches companyName, contactName, email, notes, rawText)
  Future<List<CrmLead>> search(String query);

  /// Filter leads by various criteria
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
  });

  /// Get leads by pipeline status
  Future<List<CrmLead>> getByPipelineStatus(String status);

  /// Get leads by stage
  Future<List<CrmLead>> getByStage(String stage);

  /// Get leads by tag
  Future<List<CrmLead>> getByTag(String tag);

  /// Get leads by source
  Future<List<CrmLead>> getBySource(String source);

  // ===========================================================================
  // SORTING & PAGINATION
  // ===========================================================================

  /// Get leads with sorting
  Future<List<CrmLead>> getAllSorted({
    String sortBy = 'updatedAt',
    bool descending = true,
  });

  /// Get leads with pagination
  Future<List<CrmLead>> getAllPaginated({
    int offset = 0,
    int limit = 50,
    String sortBy = 'updatedAt',
    bool descending = true,
  });

  /// Count leads matching filter criteria
  Future<int> count({
    bool? includeDeleted,
    List<String>? stages,
    List<String>? statuses,
    List<String>? tags,
  });

  // ===========================================================================
  // SYNC STATUS OPERATIONS
  // ===========================================================================

  /// Get leads by sync status
  Future<List<CrmLead>> getBySyncStatus(String status);

  /// Get leads that need sync (pending, error, conflict)
  Future<List<CrmLead>> getNeedingSync();

  /// Update sync status
  Future<void> updateSyncStatus(String leadId, String syncStatus);

  // ===========================================================================
  // TENANT OPERATIONS
  // ===========================================================================

  /// Get leads by tenant
  Future<List<CrmLead>> getByTenant(String tenantId);

  /// Transfer lead to different tenant (ADMIN ONLY)
  Future<void> transferToTenant(String leadId, String newTenantId);
}

abstract class BaseLeadRepository implements LeadRepository {
  @override
  Future<CrmLead?> getById(String leadId) async {
    final list = await getAll();
    for (final lead in list) {
      if (lead.id == leadId) return lead;
    }
    return null;
  }

  @override
  Future<void> softDelete(String leadId) async {
    final lead = await getById(leadId);
    if (lead != null) {
      await save(
        lead.copyWith(deletedAt: DateTime.now(), syncStatus: 'pending'),
      );
    }
  }

  @override
  Future<void> restore(String leadId) async {
    final lead = await getById(leadId);
    if (lead != null) {
      await save(lead.copyWith(deletedAt: null, syncStatus: 'pending'));
    }
  }

  @override
  Future<void> saveAll(List<CrmLead> leads) async {
    for (final lead in leads) {
      await save(lead);
    }
  }

  @override
  Future<void> softDeleteAll(List<String> leadIds) async {
    for (final id in leadIds) {
      await softDelete(id);
    }
  }

  @override
  Future<void> permanentDeleteAll(List<String> leadIds) async {
    for (final id in leadIds) {
      await permanentDelete(id);
    }
  }

  @override
  Future<void> changeStage(String leadId, String newStage) async {
    final lead = await getById(leadId);
    if (lead != null) {
      await save(lead.copyWith(stage: newStage, updatedAt: DateTime.now()));
    }
  }

  @override
  Future<void> bulkChangeStage(List<String> leadIds, String newStage) async {
    for (final id in leadIds) {
      await changeStage(id, newStage);
    }
  }

  @override
  Future<void> changeStatus(String leadId, String newStatus) async {
    final lead = await getById(leadId);
    if (lead != null) {
      await save(lead.copyWith(status: newStatus, updatedAt: DateTime.now()));
    }
  }

  @override
  Future<void> bulkChangeStatus(List<String> leadIds, String newStatus) async {
    for (final id in leadIds) {
      await changeStatus(id, newStatus);
    }
  }

  @override
  Future<void> updateScore(String leadId, double score, String reason) async {
    final lead = await getById(leadId);
    if (lead != null) {
      await save(
        lead.copyWith(
          score: score,
          scoreReason: reason,
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> bulkUpdateScores(Map<String, double> leadIdToScore) async {
    for (final entry in leadIdToScore.entries) {
      final lead = await getById(entry.key);
      if (lead != null) {
        await save(
          lead.copyWith(score: entry.value, updatedAt: DateTime.now()),
        );
      }
    }
  }

  @override
  Future<void> addTag(String leadId, String tag) async {
    final lead = await getById(leadId);
    if (lead != null && !lead.tags.contains(tag)) {
      await save(
        lead.copyWith(tags: [...lead.tags, tag], updatedAt: DateTime.now()),
      );
    }
  }

  @override
  Future<void> removeTag(String leadId, String tag) async {
    final lead = await getById(leadId);
    if (lead != null && lead.tags.contains(tag)) {
      await save(
        lead.copyWith(
          tags: lead.tags.where((t) => t != tag).toList(),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> bulkAddTags(List<String> leadIds, List<String> tags) async {
    for (final id in leadIds) {
      for (final tag in tags) {
        await addTag(id, tag);
      }
    }
  }

  @override
  Future<void> bulkRemoveTags(List<String> leadIds, List<String> tags) async {
    for (final id in leadIds) {
      for (final tag in tags) {
        await removeTag(id, tag);
      }
    }
  }

  @override
  Future<void> updateNotes(String leadId, String notes) async {
    final lead = await getById(leadId);
    if (lead != null) {
      await save(lead.copyWith(notes: notes, updatedAt: DateTime.now()));
    }
  }

  @override
  Future<void> appendNotes(String leadId, String additionalNotes) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final newNotes = lead.notes.isEmpty
          ? additionalNotes
          : '${lead.notes}\n$additionalNotes';
      await save(lead.copyWith(notes: newNotes, updatedAt: DateTime.now()));
    }
  }

  @override
  Future<void> updateFollowUp(String leadId, DateTime followUpAt) async {
    final lead = await getById(leadId);
    if (lead != null) {
      await save(
        lead.copyWith(followUpAt: followUpAt, updatedAt: DateTime.now()),
      );
    }
  }

  @override
  Future<void> markAsContacted(String leadId, {DateTime? contactedAt}) async {
    final lead = await getById(leadId);
    if (lead != null) {
      final at = contactedAt ?? DateTime.now();
      await save(lead.copyWith(lastContactedAt: at, updatedAt: DateTime.now()));
    }
  }

  @override
  Future<List<CrmLead>> search(String query) async {
    final leads = await getAll();
    if (query.isEmpty) return leads;
    final q = query.toLowerCase();
    return leads.where((l) {
      return l.companyName.toLowerCase().contains(q) ||
          l.contactName.toLowerCase().contains(q) ||
          l.email.toLowerCase().contains(q) ||
          l.notes.toLowerCase().contains(q) ||
          l.rawText.toLowerCase().contains(q);
    }).toList();
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
    var leads = await getAll();
    if (includeDeleted != true) {
      leads = leads.where((l) => l.deletedAt == null).toList();
    }
    return leads.where((l) {
      if (stages != null && stages.isNotEmpty && !stages.contains(l.stage)) {
        return false;
      }
      if (statuses != null &&
          statuses.isNotEmpty &&
          !statuses.contains(l.status)) {
        return false;
      }
      if (tags != null &&
          tags.isNotEmpty &&
          !tags.any((t) => l.tags.contains(t))) {
        return false;
      }
      if (sources != null &&
          sources.isNotEmpty &&
          !sources.contains(l.source)) {
        return false;
      }
      if (contactName != null &&
          !l.contactName.toLowerCase().contains(contactName.toLowerCase())) {
        return false;
      }
      if (companyName != null &&
          !l.companyName.toLowerCase().contains(companyName.toLowerCase())) {
        return false;
      }
      if (email != null &&
          !l.email.toLowerCase().contains(email.toLowerCase())) {
        return false;
      }
      if (phone != null && !l.phone.contains(phone)) return false;
      if (country != null &&
          !l.country.toLowerCase().contains(country.toLowerCase())) {
        return false;
      }
      if (sector != null &&
          !l.sector.toLowerCase().contains(sector.toLowerCase())) {
        return false;
      }
      if (minScore != null && l.score < minScore) return false;
      if (maxScore != null && l.score > maxScore) return false;
      if (createdFrom != null && l.createdAt.isBefore(createdFrom)) {
        return false;
      }
      if (createdTo != null && l.createdAt.isAfter(createdTo)) return false;
      if (updatedFrom != null && l.updatedAt.isBefore(updatedFrom)) {
        return false;
      }
      if (updatedTo != null && l.updatedAt.isAfter(updatedTo)) return false;
      if (followUpFrom != null &&
          (l.followUpAt == null || l.followUpAt!.isBefore(followUpFrom))) {
        return false;
      }
      if (followUpTo != null &&
          (l.followUpAt == null || l.followUpAt!.isAfter(followUpTo))) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<List<CrmLead>> getByPipelineStatus(String status) async {
    return (await getAll()).where((l) => l.pipelineStatus == status).toList();
  }

  @override
  Future<List<CrmLead>> getByStage(String stage) async {
    return (await getAll()).where((l) => l.stage == stage).toList();
  }

  @override
  Future<List<CrmLead>> getByTag(String tag) async {
    return (await getAll()).where((l) => l.tags.contains(tag)).toList();
  }

  @override
  Future<List<CrmLead>> getBySource(String source) async {
    return (await getAll()).where((l) => l.source == source).toList();
  }

  @override
  Future<List<CrmLead>> getAllSorted({
    String sortBy = 'updatedAt',
    bool descending = true,
  }) async {
    final leads = await getAll();
    leads.sort((a, b) {
      dynamic valA, valB;
      switch (sortBy) {
        case 'companyName':
          valA = a.companyName;
          valB = b.companyName;
          break;
        case 'score':
          valA = a.score;
          valB = b.score;
          break;
        case 'createdAt':
          valA = a.createdAt;
          valB = b.createdAt;
          break;
        case 'importedAt':
          valA = a.importedAt;
          valB = b.importedAt;
          break;
        case 'updatedAt':
        default:
          valA = a.updatedAt;
          valB = b.updatedAt;
          break;
      }
      if (valA is Comparable && valB is Comparable) {
        return descending ? valB.compareTo(valA) : valA.compareTo(valB);
      }
      return 0;
    });
    return leads;
  }

  @override
  Future<List<CrmLead>> getAllPaginated({
    int offset = 0,
    int limit = 50,
    String sortBy = 'updatedAt',
    bool descending = true,
  }) async {
    final sorted = await getAllSorted(sortBy: sortBy, descending: descending);
    if (offset >= sorted.length) return [];
    final end = offset + limit;
    return sorted.sublist(offset, end > sorted.length ? sorted.length : end);
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

  @override
  Future<List<CrmLead>> getBySyncStatus(String status) async {
    return (await getAll()).where((l) => l.syncStatus == status).toList();
  }

  @override
  Future<List<CrmLead>> getNeedingSync() async {
    return (await getAll())
        .where(
          (l) =>
              l.syncStatus == 'pending' ||
              l.syncStatus == 'error' ||
              l.syncStatus == 'conflict',
        )
        .toList();
  }

  @override
  Future<void> updateSyncStatus(String leadId, String syncStatus) async {
    final lead = await getById(leadId);
    if (lead != null) {
      await save(
        lead.copyWith(syncStatus: syncStatus, updatedAt: DateTime.now()),
      );
    }
  }

  @override
  Future<List<CrmLead>> getByTenant(String tenantId) async {
    return (await getAll()).where((l) => l.tenantId == tenantId).toList();
  }

  @override
  Future<void> transferToTenant(String leadId, String newTenantId) async {
    final lead = await getById(leadId);
    if (lead != null) {
      await save(
        lead.copyWith(tenantId: newTenantId, updatedAt: DateTime.now()),
      );
    }
  }
}

LeadRepository createLeadRepository() => createPlatformLeadRepository();
