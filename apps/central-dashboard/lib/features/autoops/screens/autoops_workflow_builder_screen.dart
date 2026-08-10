import 'package:flutter/material.dart';

import '../../../core/action_graph/connectors.dart';
import '../../../core/action_graph/engine.dart';
import '../../../core/ui/theme.dart';
import '../../../domain/autoops/domain.dart';
import '../data/autoops_workflows_repository.dart';

class AutoOpsWorkflowBuilderScreen extends StatefulWidget {
  const AutoOpsWorkflowBuilderScreen({super.key});

  @override
  State<AutoOpsWorkflowBuilderScreen> createState() => _AutoOpsWorkflowBuilderScreenState();
}

class _AutoOpsWorkflowBuilderScreenState extends State<AutoOpsWorkflowBuilderScreen> {
  final AutoOpsWorkflowsRepository _workflowsRepo = AutoOpsWorkflowsRepository();
  WorkflowGraph? _graph;
  WorkflowNode? _selectedNode;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadGraph();
  }

  Future<void> _loadGraph() async {
    final active = await _workflowsRepo.getActive();
    setState(() {
      _graph = active;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_graph == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final issues = validateGraph(_graph!);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Action Graph Workflow Builder',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _graph!.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _saveGraph,
                      icon: const Icon(Icons.save, size: 16),
                      label: Text(_saving ? 'Ukladám...' : 'Uložiť Workflow'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Validation Issues Banner if any
            if (issues.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warning.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: AppTheme.warning, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Validačné upozornenie: ${issues.first.message}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.warning),
                      ),
                    ),
                  ],
                ),
              ),

            // Node Canvas + Detail Sidebar Row
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Graph Visual Canvas
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.glassDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Tohut uzlov (Flow Canvas)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Icon(Icons.account_tree, color: AppTheme.primary),
                            ],
                          ),
                          const Divider(height: 24),

                          // Graph Nodes List
                          Expanded(
                            child: ListView.separated(
                              itemCount: _graph!.nodes.length,
                              separatorBuilder: (_, _) => const Center(
                                child: Icon(Icons.arrow_downward, color: AppTheme.primary, size: 24),
                              ),
                              itemBuilder: (context, index) {
                                final node = _graph!.nodes[index];
                                final isSelected = _selectedNode?.id == node.id;
                                final template = connectorTemplates.firstWhere(
                                  (t) => t.connector == node.connector,
                                  orElse: () => connectorTemplates.first,
                                );

                                return InkWell(
                                  onTap: () => setState(() => _selectedNode = node),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: isSelected
                                        ? AppTheme.activeGlassDecoration()
                                        : AppTheme.glassDecoration(
                                            borderColor: template.accent.color.withAlpha(80),
                                          ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: template.accent.color.withAlpha(40),
                                          child: Icon(template.icon, color: template.accent.color),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                node.label,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                node.description,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _buildNodeStatusBadge(node.status),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Node Details / Inspector Sidebar
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.glassDecoration(),
                      child: _selectedNode == null
                          ? const Center(
                              child: Text(
                                'Kliknite na uzol v plátne pre zobrazenie detailov a konfigurácie.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Konfigurácia uzla',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 24),
                                Text(
                                  _selectedNode!.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedNode!.description,
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                Text('ID: ${_selectedNode!.id}'),
                                const SizedBox(height: 8),
                                Text('Typ: ${_selectedNode!.type.value}'),
                                const SizedBox(height: 8),
                                Text('Konektor: ${_selectedNode!.connector.value}'),
                                const SizedBox(height: 24),
                                OutlinedButton.icon(
                                  onPressed: () => setState(() => _selectedNode = null),
                                  icon: const Icon(Icons.close, size: 14),
                                  label: const Text('Zavrieť detail'),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeStatusBadge(WorkflowNodeStatus status) {
    Color bg;
    switch (status) {
      case WorkflowNodeStatus.success:
        bg = AppTheme.success;
        break;
      case WorkflowNodeStatus.running:
        bg = AppTheme.info;
        break;
      case WorkflowNodeStatus.warning:
        bg = AppTheme.warning;
        break;
      case WorkflowNodeStatus.idle:
        bg = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: bg, width: 0.8),
      ),
      child: Text(
        status.value.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bg),
      ),
    );
  }

  Future<void> _saveGraph() async {
    setState(() => _saving = true);
    await _workflowsRepo.save(_graph!);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workflow bol úspešne uložený.')),
      );
    }
  }
}
