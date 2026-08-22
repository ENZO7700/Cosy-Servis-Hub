/// Dart port of `src/api/workflows.ts`.
library;

import '../../../core/utils/autoops_local_store.dart';
import '../../../domain/autoops/domain.dart';
import 'autoops_mock_data.dart' as mock;

class AutoOpsWorkflowsRepository {
  AutoOpsWorkflowsRepository() : _graph = mock.workflowGraph;

  WorkflowGraph _graph;

  Future<WorkflowGraph> getActive() => cachedMock<WorkflowGraph>(
        'autoops:workflows:active',
        () async => _graph,
        encode: (value) => value.toJson(),
        decode: (json) => WorkflowGraph.fromJson(json as Map<String, dynamic>),
        fallback: _graph,
      );

  Future<WorkflowGraph> save(WorkflowGraph graph) async {
    await sleep(const Duration(milliseconds: 520));
    _graph = graph.copyWith(updatedAt: DateTime.now().toIso8601String());
    await saveSnapshot<WorkflowGraph>(
      'autoops:workflows:active',
      _graph,
      encode: (value) => value.toJson(),
    );
    return _graph;
  }
}
