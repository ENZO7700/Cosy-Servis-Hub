import 'package:flutter_test/flutter_test.dart';

import 'package:centralny_dashboard/core/action_graph/engine.dart';
import 'package:centralny_dashboard/core/security/autoops_security.dart';
import 'package:centralny_dashboard/domain/autoops/domain.dart';
import 'package:centralny_dashboard/features/autoops/data/autoops_agent_repository.dart';
import 'package:centralny_dashboard/features/autoops/data/autoops_mock_data.dart' as mock;

void main() {
  group('AutoOps Domain & Engine Tests', () {
    test('Action Graph Engine validates graph correctly', () {
      final issues = validateGraph(mock.workflowGraph);
      // Mock workflow contains an approval node without outgoing edge as a warning
      expect(issues.isNotEmpty, isTrue);
      expect(issues.any((i) => i.level == IssueLevel.warning), isTrue);
    });

    test('Linear edges generator links nodes sequentially', () {
      final nodes = [
        const WorkflowNode(
          id: 'n1',
          type: WorkflowNodeType.trigger,
          connector: WorkflowConnector.gmail,
          label: 'Trigger',
          description: '',
          x: 0,
          y: 0,
          status: WorkflowNodeStatus.idle,
        ),
        const WorkflowNode(
          id: 'n2',
          type: WorkflowNodeType.action,
          connector: WorkflowConnector.shopify,
          label: 'Action',
          description: '',
          x: 100,
          y: 0,
          status: WorkflowNodeStatus.idle,
        ),
      ];

      final edges = createLinearEdges(nodes);
      expect(edges.length, equals(1));
      expect(edges.first.from, equals('n1'));
      expect(edges.first.to, equals('n2'));
    });

    test('Security prompt sanitization redacts secret words and caps length', () {
      const dirtyPrompt = 'Please send API_KEY secret password <script>alert(1)</script>';
      final clean = sanitizePrompt(dirtyPrompt);
      expect(clean.contains('secret'), isFalse);
      expect(clean.contains('password'), isFalse);
      expect(clean.contains('[redacted]'), isTrue);
      expect(clean.contains('<'), isFalse);
    });

    test('Security approval guard detects risky financial/refund operations', () {
      expect(requiresHumanApproval('Chcem vratiť peniaze pre klienta'), isTrue);
      expect(requiresHumanApproval('Storno objednávky a refund'), isTrue);
      expect(requiresHumanApproval('Odošli potvrdenie e-mailom'), isFalse);
    });

    test('AutoOps Agent Repository executes command with approval check', () async {
      const repo = AutoOpsAgentRepository();
      final result = await repo.execute(const AgentCommand(
        prompt: 'Prosím o zľavu a refund objednávky',
        workspaceId: 'ws_test',
      ));

      expect(result.status, equals(AgentActionStatus.requiresApproval));
      expect(result.confidence, equals(76.0));
    });
  });
}
