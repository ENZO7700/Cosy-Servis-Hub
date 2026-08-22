/// Dart port of `src/lib/action-graph/engine.ts`.
library;

import '../../domain/autoops/domain.dart';

enum IssueLevel {
  warning('warning'),
  error('error');

  const IssueLevel(this.value);
  final String value;
}

class GraphValidationIssue {
  const GraphValidationIssue({required this.level, required this.message, this.nodeId});

  final IssueLevel level;
  final String message;
  final String? nodeId;
}

List<GraphValidationIssue> validateGraph(WorkflowGraph graph) {
  final issues = <GraphValidationIssue>[];
  final triggerNodes = graph.nodes.where((node) => node.type == WorkflowNodeType.trigger);
  final approvalNodes = graph.nodes.where((node) => node.type == WorkflowNodeType.approval);

  if (triggerNodes.isEmpty) {
    issues.add(const GraphValidationIssue(
      level: IssueLevel.error,
      message: 'Workflow needs at least one trigger node.',
    ));
  }

  if (approvalNodes.isEmpty) {
    issues.add(const GraphValidationIssue(
      level: IssueLevel.warning,
      message: 'No approval guardrail found. Brave. Also how incidents are born.',
    ));
  }

  for (final node in graph.nodes) {
    final outgoing = graph.edges.any((edge) => edge.from == node.id);
    final incoming = graph.edges.any((edge) => edge.to == node.id);

    if (node.type != WorkflowNodeType.trigger && !incoming) {
      issues.add(GraphValidationIssue(
        level: IssueLevel.warning,
        message: '${node.label} has no incoming edge.',
        nodeId: node.id,
      ));
    }

    if (node.type != WorkflowNodeType.approval && !outgoing) {
      issues.add(GraphValidationIssue(
        level: IssueLevel.warning,
        message: '${node.label} has no outgoing edge.',
        nodeId: node.id,
      ));
    }
  }

  return issues;
}

List<WorkflowEdge> createLinearEdges(List<WorkflowNode> nodes) {
  final edges = <WorkflowEdge>[];
  for (var index = 0; index < nodes.length - 1; index++) {
    edges.add(WorkflowEdge(
      id: 'edge_${nodes[index].id}_${nodes[index + 1].id}',
      from: nodes[index].id,
      to: nodes[index + 1].id,
    ));
  }
  return edges;
}
