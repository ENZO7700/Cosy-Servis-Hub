/// Dart port of `src/api/agent.ts`.
library;

import '../../../core/security/autoops_security.dart';
import '../../../core/utils/autoops_local_store.dart';
import '../../../core/utils/autoops_utils.dart';
import '../../../domain/autoops/domain.dart';

class _ActionPattern {
  const _ActionPattern(this.test, this.kind, this.title);

  final RegExp test;
  final AgentActionKind kind;
  final String title;
}

final List<_ActionPattern> _actionPatterns = [
  _ActionPattern(
    RegExp(r'invoice|fakt[uú]r|superfaktura|idoklad', caseSensitive: false),
    AgentActionKind.createInvoice,
    'Create invoice draft',
  ),
  _ActionPattern(
    RegExp(r'email|mail|reply|odpoved', caseSensitive: false),
    AgentActionKind.sendEmail,
    'Send customer email',
  ),
  _ActionPattern(
    RegExp(r'packeta|gls|shipment|label|zásiel|bal[ií]k', caseSensitive: false),
    AgentActionKind.bookShipping,
    'Book shipment',
  ),
  _ActionPattern(
    RegExp(r'inbox|summar', caseSensitive: false),
    AgentActionKind.summarizeInbox,
    'Summarize inbox',
  ),
  _ActionPattern(
    RegExp(r'customer|zákaz', caseSensitive: false),
    AgentActionKind.replyCustomer,
    'Reply to customer',
  ),
];

({AgentActionKind kind, String title}) _inferAction(String prompt) {
  for (final pattern in _actionPatterns) {
    if (pattern.test.hasMatch(prompt)) {
      return (kind: pattern.kind, title: pattern.title);
    }
  }
  return (kind: AgentActionKind.escalateHuman, title: 'Escalate to human operator');
}

class AutoOpsAgentRepository {
  const AutoOpsAgentRepository();

  Future<AgentActionResult> execute(AgentCommand command) async {
    await sleep(const Duration(milliseconds: 760));
    final cleanPrompt = sanitizePrompt(command.prompt);
    final inferred = _inferAction(cleanPrompt);
    final approval = requiresHumanApproval(cleanPrompt);
    final confidence = approval
        ? 76.0
        : inferred.kind == AgentActionKind.escalateHuman
            ? 63.0
            : 92.0;

    final truncatedPrompt =
        cleanPrompt.length > 140 ? cleanPrompt.substring(0, 140) : cleanPrompt;

    return AgentActionResult(
      id: uid('agent_action'),
      kind: inferred.kind,
      title: inferred.title,
      summary: approval
          ? 'Action prepared but held for approval because it affects money, accounting or customer risk. Boring? Yes. Lawsuit-preventing? Also yes.'
          : 'Executed mock action for: "$truncatedPrompt". Replace this with the real LLM tool-router when you wire the Action Graph engine.',
      status: approval
          ? AgentActionStatus.requiresApproval
          : inferred.kind == AgentActionKind.escalateHuman
              ? AgentActionStatus.blocked
              : AgentActionStatus.executed,
      confidence: confidence,
      createdAt: DateTime.now().toIso8601String(),
      payloadPreview: {
        'workspaceId': command.workspaceId,
        'sanitizedPrompt': cleanPrompt.length > 180 ? cleanPrompt.substring(0, 180) : cleanPrompt,
        'dryRun': true,
        'auditRequired': approval,
      },
    );
  }

  Future<List<AgentActionResult>> history() => cachedMock<List<AgentActionResult>>(
        'autoops:agent:history',
        () async => <AgentActionResult>[],
        encode: (value) => value.map((e) => e.toJson()).toList(),
        decode: (json) => (json as List)
            .map((e) => AgentActionResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        fallback: const [],
      );
}
