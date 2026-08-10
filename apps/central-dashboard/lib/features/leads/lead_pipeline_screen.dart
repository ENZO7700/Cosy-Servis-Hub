import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../crm/models/crm_lead.dart';
import '../crm/providers/lead_pipeline_provider.dart';
import './lead_card.dart';

/// Lead Pipeline Screen - Kanban view
class LeadPipelineScreen extends StatefulWidget {
  const LeadPipelineScreen({super.key});

  @override
  State<LeadPipelineScreen> createState() => _LeadPipelineScreenState();
}

class _LeadPipelineScreenState extends State<LeadPipelineScreen> {
  @override
  void initState() {
    super.initState();
    // Load pipeline data
    final pipelineProvider = Provider.of<LeadPipelineProvider>(
      context,
      listen: false,
    );
    pipelineProvider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LeadPipelineProvider>(
      builder: (context, pipelineProvider, child) {
        if (pipelineProvider.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          appBar: _buildAppBar(context, pipelineProvider),
          body: _buildPipelineBody(context, pipelineProvider),
          floatingActionButton: _buildFloatingActionButton(context),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    LeadPipelineProvider pipelineProvider,
  ) {
    return AppBar(
      title: const Text('Lead Pipeline'),
      actions: [
        _buildMetricsButton(context, pipelineProvider),
        _buildFilterButton(context),
      ],
    );
  }

  Widget _buildMetricsButton(
    BuildContext context,
    LeadPipelineProvider pipelineProvider,
  ) {
    return IconButton(
      icon: const Icon(Icons.analytics),
      tooltip: 'Pipeline Metrics',
      onPressed: () => _showMetricsDialog(context, pipelineProvider),
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.filter_list),
      tooltip: 'Filter',
      onPressed: () => _showFilterDialog(context),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _refreshPipeline(context),
      tooltip: 'Refresh Pipeline',
      child: const Icon(Icons.refresh),
    );
  }

  Widget _buildPipelineBody(
    BuildContext context,
    LeadPipelineProvider pipelineProvider,
  ) {
    final stages = pipelineProvider.stages;
    final leadsByStage = pipelineProvider.leadsByStage;

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: stages.map((stage) {
            final stageLeads = leadsByStage[stage.id] ?? [];
            return _buildStageColumn(
              context,
              pipelineProvider,
              stage,
              stageLeads,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStageColumn(
    BuildContext context,
    LeadPipelineProvider pipelineProvider,
    PipelineStage stage,
    List<PipelineLead> stageLeads,
  ) {
    final leadsCount = stageLeads.length;
    final valueByStage = pipelineProvider.getValueByStage();
    final stageValue = valueByStage[stage.id] ?? 0;

    return Container(
      width: 320,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageHeader(context, stage, leadsCount, stageValue),
          const Divider(height: 1),
          Expanded(
            child: _buildStageLeadsList(
              context,
              pipelineProvider,
              stage,
              stageLeads,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageHeader(
    BuildContext context,
    PipelineStage stage,
    int leadsCount,
    double stageValue,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _parseColor(stage.color),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${stage.icon} ${stage.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stage.description,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$leadsCount',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (stageValue > 0)
                Text(
                  '\$${stageValue.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _parseColor(String colorHex) {
    if (colorHex.startsWith('0x')) {
      try {
        return Color(int.parse(colorHex));
      } catch (_) {
        return Colors.grey.shade200;
      }
    }
    return Colors.grey.shade200;
  }

  Widget _buildStageLeadsList(
    BuildContext context,
    LeadPipelineProvider pipelineProvider,
    PipelineStage stage,
    List<PipelineLead> stageLeads,
  ) {
    if (stageLeads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No leads in this stage',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return DragTarget<PipelineLead>(
      builder: (context, candidateData, rejectedData) {
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: stageLeads.length,
          itemBuilder: (context, index) {
            final lead = stageLeads[index];
            return _buildDraggableLeadCard(
              context,
              pipelineProvider,
              stage,
              lead,
            );
          },
        );
      },
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        // Handle drop - move lead to this stage
        pipelineProvider.updateDragTarget(stage.id);
      },
      onLeave: (data) {
        pipelineProvider.updateDragTarget(null);
      },
    );
  }

  Widget _buildDraggableLeadCard(
    BuildContext context,
    LeadPipelineProvider pipelineProvider,
    PipelineStage stage,
    PipelineLead pipelineLead,
  ) {
    final lead = pipelineLead.lead;

    return LongPressDraggable<PipelineLead>(
      key: ValueKey('lead_${lead.id}'),
      data: pipelineLead,
      feedback: Opacity(
        opacity: 0.7,
        child: _buildLeadCardContent(context, lead, stage),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildLeadCardContent(context, lead, stage),
      ),
      onDragStarted: () {
        pipelineProvider.startDrag(lead.id);
      },
      onDragEnd: (_) {
        pipelineProvider.endDrag();
      },
      child: _buildLeadCardContent(context, lead, stage),
    );
  }

  Widget _buildLeadCardContent(
    BuildContext context,
    CrmLead lead,
    PipelineStage stage,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: LeadCard(
        lead: lead,
        showStage: false,
        showActions: true,
        onTap: () => _navigateToLeadDetail(context, lead.id),
      ),
    );
  }

  void _navigateToLeadDetail(BuildContext context, String leadId) {
    // Navigate to lead detail screen
    // In actual implementation, use your navigation:
    // Navigator.push(context, MaterialPageRoute(...));
  }

  void _refreshPipeline(BuildContext context) {
    final pipelineProvider = Provider.of<LeadPipelineProvider>(
      context,
      listen: false,
    );
    pipelineProvider.refresh();
  }

  void _showMetricsDialog(
    BuildContext context,
    LeadPipelineProvider pipelineProvider,
  ) {
    final metrics = pipelineProvider.metrics;
    final countsByStage = pipelineProvider.getLeadsCountByStage();
    final valuesByStage = pipelineProvider.getValueByStage();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pipeline Metrics'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMetricRow('Total Leads', '${metrics.totalLeads}'),
                const SizedBox(height: 8),
                _buildMetricRow(
                  'Total Value',
                  '\$${metrics.totalValue.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _buildMetricRow(
                  'Conversion Rate',
                  '${(metrics.conversionRate * 100).toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 8),
                _buildMetricRow(
                  'Average Score',
                  metrics.averageScore.toStringAsFixed(1),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Leads by Stage:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...pipelineProvider.stages.map((stage) {
                  final count = countsByStage[stage.id] ?? 0;
                  final value = valuesByStage[stage.id] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${stage.icon} ${stage.name}'),
                        Text('$count leads, \$$value'),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Pipeline'),
          content: const Text('Filter options will be implemented'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
