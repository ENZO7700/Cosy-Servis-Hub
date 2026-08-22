import 'package:flutter/foundation.dart';

import '../models/crm_lead.dart';
import '../repositories/lead_repository.dart';

/// Pipeline stage configuration
class PipelineStage {
  final String id;
  final String name;
  final String description;
  final int order;
  final String color;
  final String icon;

  const PipelineStage({
    required this.id,
    required this.name,
    required this.description,
    required this.order,
    required this.color,
    required this.icon,
  });

  static const List<PipelineStage> defaultStages = [
    PipelineStage(
      id: 'new',
      name: 'New',
      description: 'Newly created leads',
      order: 0,
      color: '0xFFE3F2FD',
      icon: '📥',
    ),
    PipelineStage(
      id: 'qualified',
      name: 'Qualified',
      description: 'Leads that meet criteria',
      order: 1,
      color: '0xFFE8F5E8',
      icon: '✅',
    ),
    PipelineStage(
      id: 'contacted',
      name: 'Contacted',
      description: 'First contact made',
      order: 2,
      color: '0xFFFFF8E1',
      icon: '📞',
    ),
    PipelineStage(
      id: 'proposal',
      name: 'Proposal',
      description: 'Proposal sent',
      order: 3,
      color: '0xFFFFE0B2',
      icon: '📄',
    ),
    PipelineStage(
      id: 'negotiation',
      name: 'Negotiation',
      description: 'In negotiation phase',
      order: 4,
      color: '0xFFFFCCBC',
      icon: '🤝',
    ),
    PipelineStage(
      id: 'won',
      name: 'Won',
      description: 'Successfully closed',
      order: 5,
      color: '0xFFC8E6C9',
      icon: '🎉',
    ),
    PipelineStage(
      id: 'lost',
      name: 'Lost',
      description: 'Lost opportunity',
      order: 6,
      color: '0xFFFFCDD2',
      icon: '❌',
    ),
  ];

  static PipelineStage? fromId(String? id) {
    if (id == null) return null;
    try {
      return defaultStages.firstWhere((stage) => stage.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Stage history entry
class StageHistoryEntry {
  final String id;
  final String leadId;
  final String fromStage;
  final String toStage;
  final DateTime changedAt;
  final String? changedBy;
  final String? reason;

  const StageHistoryEntry({
    required this.id,
    required this.leadId,
    required this.fromStage,
    required this.toStage,
    required this.changedAt,
    this.changedBy,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'leadId': leadId,
      'fromStage': fromStage,
      'toStage': toStage,
      'changedAt': changedAt.toIso8601String(),
      'changedBy': changedBy,
      'reason': reason,
    };
  }

  factory StageHistoryEntry.fromJson(Map<String, dynamic> json) {
    return StageHistoryEntry(
      id: json['id'] as String? ?? '',
      leadId: json['leadId'] as String? ?? '',
      fromStage: json['fromStage'] as String? ?? '',
      toStage: json['toStage'] as String? ?? '',
      changedAt: DateTime.parse(json['changedAt'] as String? ?? ''),
      changedBy: json['changedBy'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

/// Lead in pipeline with additional metadata
class PipelineLead {
  final CrmLead lead;
  final PipelineStage stage;
  final int stageOrder;
  bool isDragging;
  final bool hasConflict;

  PipelineLead({
    required this.lead,
    required this.stage,
    required this.stageOrder,
    this.isDragging = false,
    this.hasConflict = false,
  });

  String get id => lead.id;
  String get currentStage => lead.stage;
  double get score => lead.score;
  String get companyName => lead.companyName;
  String get contactName => lead.contactName;
  DateTime get updatedAt => lead.updatedAt;
}

/// Pipeline metrics
class PipelineMetrics {
  final int totalLeads;
  final int leadsByStage;
  final double totalValue;
  final double conversionRate;
  final double averageScore;

  const PipelineMetrics({
    this.totalLeads = 0,
    this.leadsByStage = 0,
    this.totalValue = 0,
    this.conversionRate = 0,
    this.averageScore = 0,
  });
}

/// Filter options for pipeline
class PipelineFilter {
  final List<String>? stages;
  final List<String>? owners;
  final List<String>? tags;
  final double? minScore;
  final double? maxScore;
  final List<String>? sources;
  final DateTime? createdFrom;
  final DateTime? createdTo;

  const PipelineFilter({
    this.stages,
    this.owners,
    this.tags,
    this.minScore,
    this.maxScore,
    this.sources,
    this.createdFrom,
    this.createdTo,
  });

  PipelineFilter copyWith({
    List<String>? stages,
    List<String>? owners,
    List<String>? tags,
    double? minScore,
    double? maxScore,
    List<String>? sources,
    DateTime? createdFrom,
    DateTime? createdTo,
  }) {
    return PipelineFilter(
      stages: stages ?? this.stages,
      owners: owners ?? this.owners,
      tags: tags ?? this.tags,
      minScore: minScore ?? this.minScore,
      maxScore: maxScore ?? this.maxScore,
      sources: sources ?? this.sources,
      createdFrom: createdFrom ?? this.createdFrom,
      createdTo: createdTo ?? this.createdTo,
    );
  }
}

/// Provider for managing lead pipeline
class LeadPipelineProvider extends ChangeNotifier {
  final LeadRepository _repository;
  List<PipelineLead> _pipelineLeads = [];
  List<PipelineStage> _stages = PipelineStage.defaultStages;
  final List<StageHistoryEntry> _stageHistory = [];

  PipelineFilter _filter = const PipelineFilter();
  PipelineMetrics _metrics = const PipelineMetrics();

  bool _loading = false;
  String? _error;
  String? _draggingLeadId;
  String? _targetStageId;

  LeadPipelineProvider({LeadRepository? repository})
    : _repository = repository ?? createLeadRepository() {
    _loadPipeline();
  }

  /// All pipeline stages
  List<PipelineStage> get stages => List.unmodifiable(_stages);

  /// Leads grouped by stage
  Map<String, List<PipelineLead>> get leadsByStage {
    final grouped = <String, List<PipelineLead>>{};
    for (final stage in _stages) {
      grouped[stage.id] = [];
    }
    for (final lead in _pipelineLeads) {
      grouped[lead.currentStage]?.add(lead);
    }
    return grouped;
  }

  /// Get leads for a specific stage
  List<PipelineLead> getLeadsForStage(String stageId) {
    return leadsByStage[stageId] ?? [];
  }

  /// Current filter
  PipelineFilter get filter => _filter;

  /// Pipeline metrics
  PipelineMetrics get metrics => _metrics;

  /// Whether loading
  bool get loading => _loading;

  /// Error message
  String? get error => _error;

  /// Whether there's a drag operation in progress
  bool get isDragging => _draggingLeadId != null;

  /// Currently dragging lead ID
  String? get draggingLeadId => _draggingLeadId;

  /// Load pipeline data
  Future<void> _loadPipeline() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final leads = await _repository.getAll();
      _pipelineLeads = leads.map((lead) {
        final stage =
            PipelineStage.fromId(lead.stage) ??
            PipelineStage.fromId('new') ??
            PipelineStage.defaultStages[0];
        return PipelineLead(lead: lead, stage: stage, stageOrder: stage.order);
      }).toList();

      // Sort leads within each stage by updatedAt
      for (final stage in _stages) {
        final stageLeads = _pipelineLeads
            .where((lead) => lead.currentStage == stage.id)
            .toList();
        stageLeads.sort((a, b) => b.lead.updatedAt.compareTo(a.lead.updatedAt));
      }

      _calculateMetrics();
    } catch (e) {
      _error = 'Failed to load pipeline: ${e.toString()}';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Calculate pipeline metrics
  void _calculateMetrics() {
    final leads = _pipelineLeads.map((pl) => pl.lead).toList();
    final wonLeads = leads.where((lead) => lead.stage == 'won').toList();
    final totalLeads = leads.length;

    // Calculate leads by stage
    int leadsByStage = 0;
    double totalValue = 0;
    double totalScore = 0;
    int scoredLeads = 0;

    for (final lead in leads) {
      totalValue += lead.estimatedValue ?? 0;
      if (lead.score > 0) {
        totalScore += lead.score;
        scoredLeads++;
      }
    }

    _metrics = PipelineMetrics(
      totalLeads: totalLeads,
      leadsByStage: leadsByStage,
      totalValue: totalValue,
      conversionRate: totalLeads > 0 ? wonLeads.length / totalLeads : 0,
      averageScore: scoredLeads > 0 ? totalScore / scoredLeads : 0,
    );
  }

  /// Move lead to a different stage
  Future<void> moveLeadToStage(
    String leadId,
    String newStageId, {
    String? reason,
  }) async {
    try {
      // Get the lead
      final leadIndex = _pipelineLeads.indexWhere((pl) => pl.id == leadId);
      if (leadIndex < 0) return;

      final pipelineLead = _pipelineLeads[leadIndex];
      final oldStage = pipelineLead.currentStage;

      // Optimistic update
      final updatedLead = pipelineLead.lead.copyWith(
        stage: newStageId,
        updatedAt: DateTime.now(),
        version: pipelineLead.lead.version + 1,
        syncStatus: 'pending',
      );

      // Update in pipeline
      _pipelineLeads[leadIndex] = PipelineLead(
        lead: updatedLead,
        stage: PipelineStage.fromId(newStageId) ?? pipelineLead.stage,
        stageOrder:
            PipelineStage.fromId(newStageId)?.order ?? pipelineLead.stageOrder,
      );

      // Add to stage history
      _addStageHistory(
        leadId: leadId,
        fromStage: oldStage,
        toStage: newStageId,
        reason: reason,
      );

      notifyListeners();

      // Perform actual update in repository
      try {
        await _repository.changeStage(leadId, newStageId);
      } catch (e) {
        // Rollback on error
        await _rollbackStageChange(leadId, oldStage, pipelineLead.lead);
        rethrow;
      }

      _calculateMetrics();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to move lead: ${e.toString()}';
      notifyListeners();
      rethrow;
    }
  }

  /// Rollback stage change on error
  Future<void> _rollbackStageChange(
    String leadId,
    String originalStage,
    CrmLead originalLead,
  ) async {
    final leadIndex = _pipelineLeads.indexWhere((pl) => pl.id == leadId);
    if (leadIndex >= 0) {
      _pipelineLeads[leadIndex] = PipelineLead(
        lead: originalLead,
        stage:
            PipelineStage.fromId(originalStage) ??
            PipelineStage.defaultStages[0],
        stageOrder: PipelineStage.fromId(originalStage)?.order ?? 0,
      );
      notifyListeners();
    }
  }

  /// Add stage history entry
  void _addStageHistory({
    required String leadId,
    required String fromStage,
    required String toStage,
    String? reason,
  }) {
    _stageHistory.add(
      StageHistoryEntry(
        id: '${leadId}_${DateTime.now().millisecondsSinceEpoch}',
        leadId: leadId,
        fromStage: fromStage,
        toStage: toStage,
        changedAt: DateTime.now(),
        reason: reason,
      ),
    );
  }

  /// Get stage history for a lead
  List<StageHistoryEntry> getStageHistoryForLead(String leadId) {
    return _stageHistory.where((entry) => entry.leadId == leadId).toList()
      ..sort((a, b) => b.changedAt.compareTo(a.changedAt));
  }

  /// Start drag operation
  void startDrag(String leadId) {
    _draggingLeadId = leadId;
    _updateDraggingState();
    notifyListeners();
  }

  /// Update drag position
  void updateDragTarget(String? stageId) {
    _targetStageId = stageId;
    _updateDraggingState();
    notifyListeners();
  }

  /// End drag operation
  Future<void> endDrag() async {
    if (_draggingLeadId != null && _targetStageId != null) {
      await moveLeadToStage(_draggingLeadId!, _targetStageId!);
    }
    _draggingLeadId = null;
    _targetStageId = null;
    _updateDraggingState();
    notifyListeners();
  }

  /// Cancel drag operation
  void cancelDrag() {
    _draggingLeadId = null;
    _targetStageId = null;
    _updateDraggingState();
    notifyListeners();
  }

  /// Update dragging state for leads
  void _updateDraggingState() {
    for (final lead in _pipelineLeads) {
      lead.isDragging = lead.id == _draggingLeadId;
    }
  }

  /// Apply filter
  void applyFilter(PipelineFilter filter) {
    _filter = filter;
    _applyFilterToLeads();
    notifyListeners();
  }

  /// Apply filter to leads
  void _applyFilterToLeads() {
    // Note: Implement actual filtering
    // For now, just notify listeners
  }

  /// Refresh pipeline
  Future<void> refresh() async {
    await _loadPipeline();
  }

  /// Mark lead as won
  Future<void> markAsWon(String leadId, {double? value, String? reason}) async {
    await moveLeadToStage(leadId, 'won', reason: reason);
  }

  /// Mark lead as lost
  Future<void> markAsLost(String leadId, {String? reason}) async {
    await moveLeadToStage(leadId, 'lost', reason: reason);
  }

  /// Get leads by owner
  List<PipelineLead> getLeadsByOwner(String ownerId) {
    return _pipelineLeads
        .where((lead) => lead.lead.ownerId == ownerId)
        .toList();
  }

  /// Get leads by tag
  List<PipelineLead> getLeadsByTag(String tag) {
    return _pipelineLeads
        .where((lead) => lead.lead.tags.contains(tag))
        .toList();
  }

  /// Get leads by score range
  List<PipelineLead> getLeadsByScoreRange(double minScore, double maxScore) {
    return _pipelineLeads
        .where(
          (lead) => lead.lead.score >= minScore && lead.lead.score <= maxScore,
        )
        .toList();
  }

  /// Get leads by source
  List<PipelineLead> getLeadsBySource(String source) {
    return _pipelineLeads
        .where((lead) => lead.lead.sources.contains(source))
        .toList();
  }

  /// Get count of leads in each stage
  Map<String, int> getLeadsCountByStage() {
    final counts = <String, int>{};
    for (final stage in _stages) {
      counts[stage.id] = getLeadsForStage(stage.id).length;
    }
    return counts;
  }

  /// Get total value by stage
  Map<String, double> getValueByStage() {
    final values = <String, double>{};
    for (final stage in _stages) {
      values[stage.id] = getLeadsForStage(
        stage.id,
      ).fold(0, (sum, lead) => sum + (lead.lead.estimatedValue ?? 0));
    }
    return values;
  }

  /// Update stage configuration
  void updateStages(List<PipelineStage> stages) {
    _stages = stages..sort((a, b) => a.order.compareTo(b.order));
    notifyListeners();
  }

  /// Reset filter
  void resetFilter() {
    _filter = const PipelineFilter();
    notifyListeners();
  }

  @override
  void dispose() {
    _pipelineLeads.clear();
    _stageHistory.clear();
    super.dispose();
  }
}
