/// Dart port of `src/api/dashboard.ts`.
library;

import '../../../core/utils/autoops_local_store.dart';
import '../../../domain/autoops/domain.dart';
import 'autoops_mock_data.dart' as mock;

class AutoOpsDashboardRepository {
  const AutoOpsDashboardRepository();

  Future<DashboardStats> stats() => cachedMock<DashboardStats>(
        'autoops:dashboard:stats',
        () async => mock.dashboardStats,
        encode: (value) => value.toJson(),
        decode: (json) => DashboardStats.fromJson(json as Map<String, dynamic>),
        fallback: mock.dashboardStats,
      );

  Future<List<ActivityItem>> activity() => cachedMock<List<ActivityItem>>(
        'autoops:dashboard:activity',
        () async => mock.activityFeed,
        encode: (value) => value.map((e) => e.toJson()).toList(),
        decode: (json) =>
            (json as List).map((e) => ActivityItem.fromJson(e as Map<String, dynamic>)).toList(),
        fallback: const [],
      );

  Future<AgentStatus> agentStatus() => cachedMock<AgentStatus>(
        'autoops:dashboard:agent-status',
        () async => mock.agentStatus,
        encode: (value) => value.toJson(),
        decode: (json) => AgentStatus.fromJson(json as Map<String, dynamic>),
        fallback: mock.agentStatus,
      );

  Future<List<Integration>> integrationHealth() => cachedMock<List<Integration>>(
        'autoops:dashboard:integrations',
        () async => mock.integrations.where((integration) => integration.connected).toList(),
        encode: (value) => value.map((e) => e.toJson()).toList(),
        decode: (json) =>
            (json as List).map((e) => Integration.fromJson(e as Map<String, dynamic>)).toList(),
        fallback: const [],
      );
}
