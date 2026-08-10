import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/config.dart';
import '../database/models.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    if (!AppConfig.isConfigured) return;
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
    }
  }

  SupabaseClient get client {
    if (!_initialized) {
      throw Exception(
        'Supabase has not been initialized. Please configure VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY.',
      );
    }
    return Supabase.instance.client;
  }

  bool isUuid(String value) {
    final RegExp uuidRegExp = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidRegExp.hasMatch(value);
  }

  /// True when PostgREST says the relation is missing (PGRST205 / 404).
  bool _isMissingRelation(Object error) {
    final text = error.toString();
    return text.contains('PGRST205') ||
        text.contains('Could not find the table') ||
        (text.contains('relation') && text.contains('does not exist'));
  }

  void _logSoft(String action, Object error) {
    if (_isMissingRelation(error)) {
      debugPrint('Supabase $action skipped (table missing): $error');
      return;
    }
    debugPrint('Supabase $action failed: $error');
  }

  // Fetch profiles (user_id is Firebase UID text, not Supabase auth UUID)
  Future<Profile?> getProfile(String userId) async {
    if (userId.trim().isEmpty) return null;
    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return Profile.fromMap(response);
    } catch (e) {
      _logSoft('getProfile', e);
      return null;
    }
  }

  // Fetch bugs
  Future<List<Bug>> getBugs() async {
    try {
      final response = await client
          .from('bugs')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((map) => Bug.fromMap(map)).toList();
    } catch (e) {
      _logSoft('getBugs', e);
      return [];
    }
  }

  // Fetch projects
  Future<List<Project>> getProjects() async {
    try {
      final response = await client
          .from('projects')
          .select()
          .order('created_at', ascending: false);
      return (response as List).map((map) => Project.fromMap(map)).toList();
    } catch (e) {
      _logSoft('getProjects', e);
      return [];
    }
  }

  // Create bug
  Future<Bug?> createBug(Bug bug) async {
    try {
      final response = await client
          .from('bugs')
          .insert(bug.toMap())
          .select()
          .single();
      return Bug.fromMap(response);
    } catch (e) {
      _logSoft('createBug', e);
      return null;
    }
  }

  // Update bug status/severity/assignee
  Future<bool> updateBug(String id, Map<String, dynamic> updates) async {
    try {
      await client.from('bugs').update(updates).eq('id', id);
      return true;
    } catch (e) {
      _logSoft('updateBug', e);
      return false;
    }
  }

  // Fetch AI conversations
  Future<List<AiConversation>> getConversations(String userId) async {
    if (userId.trim().isEmpty) return [];
    try {
      final response = await client
          .from('ai_conversations')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);
      return (response as List)
          .map((map) => AiConversation.fromMap(map))
          .toList();
    } catch (e) {
      _logSoft('getConversations', e);
      return [];
    }
  }

  // Fetch AI messages
  Future<List<AiMessage>> getMessages(String conversationId) async {
    try {
      final response = await client
          .from('ai_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      return (response as List).map((map) => AiMessage.fromMap(map)).toList();
    } catch (e) {
      _logSoft('getMessages', e);
      return [];
    }
  }

  // Create AI conversation
  Future<AiConversation?> createConversation(
    String title,
    String userId,
  ) async {
    if (userId.trim().isEmpty) return null;
    try {
      final response = await client
          .from('ai_conversations')
          .insert({'title': title, 'user_id': userId})
          .select()
          .single();
      return AiConversation.fromMap(response);
    } catch (e) {
      _logSoft('createConversation', e);
      return null;
    }
  }

  // Insert AI message
  Future<AiMessage?> createMessage(AiMessage message) async {
    try {
      final response = await client
          .from('ai_messages')
          .insert(message.toMap())
          .select()
          .single();
      return AiMessage.fromMap(response);
    } catch (e) {
      _logSoft('createMessage', e);
      return null;
    }
  }
}
