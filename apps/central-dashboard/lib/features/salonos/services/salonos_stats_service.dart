import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/config.dart';
import '../../../core/network/supabase_service.dart';
import '../models/salonos_stats.dart';

class SalonosStatsException implements Exception {
  final String message;
  const SalonosStatsException(this.message);

  @override
  String toString() => message;
}

abstract interface class SalonosStatsGateway {
  Future<SalonosStats> fetchStats();
  void dispose();
}

class SalonosStatsService implements SalonosStatsGateway {
  final http.Client _client;

  SalonosStatsService({http.Client? client})
    : _client = client ?? http.Client();

  @override
  Future<SalonosStats> fetchStats() async {
    final baseUrl = AppConfig.salonosApiBaseUrl.trim();
    final providerId = AppConfig.salonosProviderId.trim();
    if (baseUrl.isEmpty || providerId.isEmpty) {
      throw const SalonosStatsException(
        'SALONOS API nie je nakonfigurované pre tento dashboard.',
      );
    }

    final session = SupabaseService().client.auth.currentSession;
    if (session == null) {
      throw const SalonosStatsException(
        'Pre načítanie SALONOS dát sa prihlás cez Supabase účet poskytovateľa.',
      );
    }

    final uri = Uri.parse(
      '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/v1/salonos/stats/'
      '${Uri.encodeComponent(providerId)}',
    );

    late final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );
    } catch (_) {
      throw const SalonosStatsException(
        'SALONOS služba je momentálne nedostupná.',
      );
    }

    final payload = _decode(response.body);
    if (response.statusCode != 200) {
      final message = payload['error'];
      throw SalonosStatsException(
        message is String && message.isNotEmpty
            ? message
            : 'Načítanie SALONOS dát zlyhalo (HTTP ${response.statusCode}).',
      );
    }

    try {
      return SalonosStats.fromJson(payload);
    } on FormatException {
      throw const SalonosStatsException(
        'SALONOS server vrátil nekompatibilnú odpoveď.',
      );
    }
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) throw const FormatException();
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw const SalonosStatsException(
        'SALONOS server vrátil neplatnú odpoveď.',
      );
    }
  }

  @override
  void dispose() => _client.close();
}
