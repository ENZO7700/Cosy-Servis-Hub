/// Dart port of `src/api/analytics.ts`.
library;

import '../../../core/utils/autoops_local_store.dart';
import '../../../domain/autoops/domain.dart';
import 'autoops_mock_data.dart' as mock;

class AutoOpsAnalyticsRepository {
  const AutoOpsAnalyticsRepository();

  Future<List<AnalyticsPoint>> points() => cachedMock<List<AnalyticsPoint>>(
        'autoops:analytics:points',
        () async => mock.analyticsPoints,
        encode: (value) => value.map((e) => e.toJson()).toList(),
        decode: (json) =>
            (json as List).map((e) => AnalyticsPoint.fromJson(e as Map<String, dynamic>)).toList(),
        fallback: const [],
      );
}
