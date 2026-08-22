/// Dart port of `src/api/integrations.ts`.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/autoops_local_store.dart';
import '../../../domain/autoops/domain.dart';
import 'autoops_mock_data.dart' as mock;

class AutoOpsIntegrationsRepository {
  AutoOpsIntegrationsRepository() : _integrations = List.of(mock.integrations);

  List<Integration> _integrations;

  static List<Map<String, dynamic>> _encode(List<Integration> value) =>
      value.map((e) => e.toJson()).toList();

  static List<Integration> _decode(Object? json) =>
      (json as List).map((e) => Integration.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<Integration>> list() => cachedMock<List<Integration>>(
        'autoops:integrations:list',
        () async => _integrations,
        encode: _encode,
        decode: _decode,
        fallback: const [],
      );

  Future<Integration?> connect(IntegrationKey id) async {
    await sleep(const Duration(milliseconds: 840));
    final nowIso = DateTime.now().toIso8601String();
    _integrations = _integrations.map((integration) {
      if (integration.id != id) return integration;
      return integration.copyWith(
        connected: true,
        health: IntegrationHealth.healthy,
        lastSyncAt: nowIso,
        monthlyActions: integration.monthlyActions > 0 ? integration.monthlyActions : 1,
        latencyMs: integration.latencyMs != 0 ? integration.latencyMs : 180,
      );
    }).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'autoops:integrations:list',
      jsonEncode({
        'value': _encode(_integrations),
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );

    try {
      return _integrations.firstWhere((integration) => integration.id == id);
    } catch (_) {
      return null;
    }
  }
}
