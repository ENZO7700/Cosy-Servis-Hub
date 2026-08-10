import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/supabase_service.dart';
import '../models/crm_lead.dart';
import '../utils/lead_report_splitter.dart';

class LeadAiException implements Exception {
  final String message;
  const LeadAiException(this.message);

  @override
  String toString() => message;
}

class GmailConnectionStatus {
  final bool connected;
  final String email;

  const GmailConnectionStatus({required this.connected, this.email = ''});

  factory GmailConnectionStatus.fromJson(Map<String, dynamic> json) {
    return GmailConnectionStatus(
      connected: json['connected'] == true,
      email: json['email'] as String? ?? '',
    );
  }
}

abstract interface class LeadAutomationService {
  Future<List<CrmLead>> parseLeads(String rawText);

  Future<List<CrmLead>> parseLeadChunk(
    String rawText, {
    required String jobId,
    required int chunkIndex,
    required int chunkTotal,
  });

  Future<LeadOutreach> generateOutreach(CrmLead lead);
  Future<LeadOffer> generateOffer(CrmLead lead);
  Future<GmailConnectionStatus> getGmailStatus();
  Future<Uri> getGmailConnectUrl();
  Future<void> disconnectGmail();
  Future<void> sendEmail({
    required CrmLead lead,
    required String subject,
    required String body,
    required String idempotencyKey,
  });
}

class LeadAiService implements LeadAutomationService {
  final SupabaseClient? _supabase;
  final LeadReportSplitter _splitter;
  final Uuid _uuid;

  LeadAiService([
    this._supabase,
    LeadReportSplitter? splitter,
    Uuid? uuid,
  ]) : _splitter = splitter ?? const LeadReportSplitter(),
       _uuid = uuid ?? const Uuid();

  SupabaseClient get _client => _supabase ?? SupabaseService().client;

  @override
  Future<List<CrmLead>> parseLeads(String rawText) async {
    final trimmed = rawText.trim();
    if (trimmed.length < 40) {
      throw const LeadAiException(
        'Text je príliš krátky. Vlož celý lead report (min. ~40 znakov).',
      );
    }
    if (trimmed.length > 120000) {
      throw const LeadAiException(
        'Text je príliš dlhý. Rozdeľ report na menšie časti.',
      );
    }

    final chunks = _splitter.split(trimmed);
    final jobId = _uuid.v4();
    final all = <CrmLead>[];
    for (var i = 0; i < chunks.length; i++) {
      final part = await parseLeadChunk(
        chunks[i],
        jobId: jobId,
        chunkIndex: i,
        chunkTotal: chunks.length,
      );
      all.addAll(part);
    }
    if (all.isEmpty) {
      throw const LeadAiException(
        'Mistral nenašiel žiadne leady v texte. Skontroluj formát reportu.',
      );
    }
    return all;
  }

  @override
  Future<List<CrmLead>> parseLeadChunk(
    String rawText, {
    required String jobId,
    required int chunkIndex,
    required int chunkTotal,
  }) async {
    final trimmed = rawText.trim();
    if (trimmed.length < 20) {
      throw const LeadAiException(
        'Blok textu je príliš krátky na parsovanie.',
      );
    }
    if (trimmed.length > 8000) {
      throw const LeadAiException(
        'Blok textu je príliš dlhý. Report treba rozdeliť na menšie časti.',
      );
    }

    final data = await _invoke('parse_leads_chunk', {
      'raw_text': trimmed,
      'job_id': jobId,
      'chunk_index': chunkIndex,
      'chunk_total': chunkTotal,
    });
    return _mapLeads(data['leads']);
  }

  List<CrmLead> _mapLeads(Object? leads) {
    if (leads is! List) {
      throw const LeadAiException(
        'Mistral vrátil neplatný formát leadu. Skús generovanie zopakovať.',
      );
    }
    if (leads.isEmpty) return const [];

    final now = DateTime.now();
    try {
      return leads.map((item) {
        if (item is! Map) {
          throw const LeadAiException(
            'Mistral vrátil neplatný formát leadu. Skús generovanie zopakovať.',
          );
        }
        final json = <String, dynamic>{
          for (final entry in item.entries) '${entry.key}': entry.value,
        };
        json['imported_at'] = now.toIso8601String();
        json['updated_at'] = now.toIso8601String();
        json['pipeline_status'] = 'new';
        return CrmLead.fromJson(json);
      }).toList();
    } on LeadAiException {
      rethrow;
    } catch (error) {
      throw LeadAiException('Nepodarilo sa spracovať AI odpoveď: $error');
    }
  }

  @override
  Future<LeadOutreach> generateOutreach(CrmLead lead) async {
    final data = await _invoke('generate_outreach', {'lead': lead.toJson()});
    return LeadOutreach.fromJson(
      Map<String, dynamic>.from(data['outreach'] as Map),
    );
  }

  @override
  Future<LeadOffer> generateOffer(CrmLead lead) async {
    final data = await _invoke('generate_offer', {'lead': lead.toJson()});
    return LeadOffer.fromJson(Map<String, dynamic>.from(data['offer'] as Map));
  }

  @override
  Future<GmailConnectionStatus> getGmailStatus() async {
    final data = await _invoke('gmail_status', const {});
    return GmailConnectionStatus.fromJson(data);
  }

  @override
  Future<Uri> getGmailConnectUrl() async {
    final data = await _invoke('gmail_connect_url', const {});
    final url = Uri.tryParse(data['url'] as String? ?? '');
    if (url == null || url.scheme != 'https') {
      throw const LeadAiException('Server nevrátil platnú Gmail OAuth URL.');
    }
    return url;
  }

  @override
  Future<void> disconnectGmail() => _invoke('gmail_disconnect', const {});

  @override
  Future<void> sendEmail({
    required CrmLead lead,
    required String subject,
    required String body,
    required String idempotencyKey,
  }) async {
    await _invoke('send_email', {
      'lead_id': lead.id,
      'to': lead.email.trim(),
      'subject': subject,
      'body': body,
      'idempotency_key': idempotencyKey,
    });
  }

  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const LeadAiException(
        'Pre túto operáciu sa musíš znovu prihlásiť.',
      );
    }

    try {
      final response = await _client.functions.invoke(
        'lead-assistant',
        body: {'action': action, ...payload},
        headers: {'Authorization': 'Bearer $token'},
      );
      final raw = response.data;
      if (raw is! Map) {
        throw const LeadAiException('Server vrátil neplatnú odpoveď.');
      }
      final data = Map<String, dynamic>.from(raw);
      if (data['error'] != null) {
        throw LeadAiException(_localizedError('${data['error']}'));
      }
      return data;
    } on FunctionException catch (error) {
      final code = _extractErrorCode(error.details);
      throw LeadAiException(
        code == null
            ? 'AI služba je momentálne nedostupná (HTTP ${error.status}).'
            : _localizedError(code),
      );
    } on LeadAiException {
      rethrow;
    } catch (error) {
      throw LeadAiException('AI služba nie je dostupná: $error');
    }
  }

  String? _extractErrorCode(Object? details) {
    if (details is Map) {
      final error = details['error'] ?? details['message'] ?? details['msg'];
      if (error != null) return error.toString();
    }
    if (details is String && details.isNotEmpty) {
      final trimmed = details.trim();
      if (trimmed.startsWith('{') && trimmed.contains('error')) {
        try {
          final map = Map<String, dynamic>.from(
            (const JsonDecoder().convert(trimmed) as Map).map(
              (key, value) => MapEntry('$key', value),
            ),
          );
          final error = map['error']?.toString();
          if (error != null && error.isNotEmpty) return error;
        } catch (_) {
          // fall through
        }
      }
      return trimmed;
    }
    return null;
  }

  String _localizedError(String code) {
    return switch (code) {
      'unauthorized' => 'Prihlásenie vypršalo. Prihlás sa znova.',
      'rate_limited' => 'Príliš veľa požiadaviek. Skús to o chvíľu.',
      'invalid_input' =>
        'Vstup nie je možné spracovať. Vlož celý lead report (min. ~40 znakov).',
      'invalid_ai_response' =>
        'Mistral vrátil neúplné dáta. Skús generovanie zopakovať.',
      'mistral_unavailable' => 'Mistral je momentálne nedostupný.',
      'mistral_timeout' =>
        'Mistral nestihlo odpovedať v čase. Skús zopakovať zlyhané bloky.',
      'forbidden_origin' =>
        'Origin nie je povolený (CORS). Skontroluj CRM_ALLOWED_ORIGIN.',
      'server_not_configured' =>
        'Edge Function nemá nastavené secrets (FIREBASE/MISTRAL).',
      'gmail_not_connected' => 'Najprv prepoj Gmail účet.',
      'invalid_recipient' => 'Lead nemá platnú e-mailovú adresu.',
      'duplicate_send' => 'Tento e-mail už bol odoslaný.',
      _ => 'Operácia zlyhala: $code',
    };
  }
}
