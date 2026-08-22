import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import './ai_assistant_iframe_stub.dart'
    if (dart.library.html) './ai_assistant_iframe_web.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/network/supabase_service.dart';
import '../../core/database/models.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/responsive.dart';
import '../../core/config/config.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isAnythingLlmFrame = true;
  final TextEditingController _anythingLlmUrlController =
      TextEditingController(text: 'http://localhost:3001');
  Key _anythingLlmFrameKey = UniqueKey();

  List<AiConversation> _conversations = [];
  List<AiMessage> _messages = [];
  AiConversation? _activeConversation;
  bool _loadingConvs = false;
  bool _loadingMsgs = false;
  bool _sending = false;
  String? _aiError;

  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConversations();
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    _anythingLlmUrlController.dispose();
    _scrollController.dispose();
    _unsubscribeRealtime();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _loadingConvs = true);

    if (AppConfig.isTest) {
      await Future.delayed(const Duration(milliseconds: 200));
      final mockConvs = [
        AiConversation(
          id: 'conv_1',
          title: 'Optimalizácia Isar databázy',
          userId: 'test-user-uid',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
        AiConversation(
          id: 'conv_2',
          title: 'Google Login Issue',
          userId: 'test-user-uid',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
      setState(() {
        _conversations = mockConvs;
        _loadingConvs = false;
      });
      if (mockConvs.isNotEmpty) {
        _selectConversation(mockConvs.first);
      }
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.uid ?? '';

    final convs = await _supabase.getConversations(userId);
    setState(() {
      _conversations = convs;
      _loadingConvs = false;
    });

    if (convs.isNotEmpty) {
      _selectConversation(convs.first);
    }
  }

  Future<void> _selectConversation(AiConversation conv) async {
    _unsubscribeRealtime();
    setState(() {
      _activeConversation = conv;
      _loadingMsgs = true;
      _messages = [];
    });

    if (AppConfig.isTest) {
      await Future.delayed(const Duration(milliseconds: 200));
      final List<AiMessage> mockMsgs;
      if (conv.id == 'conv_1') {
        mockMsgs = [
          AiMessage(
            id: 'msg_1',
            conversationId: 'conv_1',
            content: 'Ahoj! Ako ti dnes môžem pomôcť?',
            role: 'assistant',
            userId: 'ai',
            createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
          ),
        ];
      } else {
        mockMsgs = [
          AiMessage(
            id: 'msg_4',
            conversationId: 'conv_2',
            content:
                'Mám problém s prihlásením cez Google. V logoch vidím chybu prepojenia.',
            role: 'user',
            userId: 'test-user-uid',
            createdAt: DateTime.now().subtract(const Duration(hours: 23)),
          ),
          AiMessage(
            id: 'msg_5',
            conversationId: 'conv_2',
            content:
                'Skontroluj, či máš správne nakonfigurované SHA-1 odtlačky kľúčov vo Firebase konzole pre tvoju Android/iOS aplikáciu. Bez nich Google sign-in zlyhá.',
            role: 'assistant',
            userId: 'ai',
            createdAt: DateTime.now().subtract(const Duration(hours: 22)),
          ),
        ];
      }
      setState(() {
        _messages = mockMsgs;
        _loadingMsgs = false;
      });
      _scrollToBottom();
      return;
    }

    final msgs = await _supabase.getMessages(conv.id);
    setState(() {
      _messages = msgs;
      _loadingMsgs = false;
    });

    _subscribeRealtime(conv.id);
    _scrollToBottom();
  }

  void _subscribeRealtime(String conversationId) {
    if (AppConfig.isTest) {
      return;
    }
    try {
      _realtimeChannel = _supabase.client
          .channel('ai-messages-realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'ai_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (payload) {
              final newMsg = AiMessage.fromMap(payload.newRecord);
              setState(() {
                // Ensure we don't add duplicates
                if (!_messages.any((m) => m.id == newMsg.id)) {
                  _messages.add(newMsg);
                }
              });
              _scrollToBottom();
            },
          );
      _realtimeChannel!.subscribe();
    } catch (e) {
      debugPrint('Realtime AI subscription failed: $e');
    }
  }

  void _unsubscribeRealtime() {
    if (AppConfig.isTest) {
      return;
    }
    if (_realtimeChannel != null) {
      _supabase.client.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
  }

  Future<void> _createNewChat() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.uid ?? '';
    if (userId.isEmpty) return;

    setState(() => _loadingMsgs = true);

    if (AppConfig.isTest) {
      await Future.delayed(const Duration(milliseconds: 200));
      final newConv = AiConversation(
        id: 'conv_new_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Nová konverzácia',
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      setState(() {
        _conversations.insert(0, newConv);
        _loadingMsgs = false;
      });
      _selectConversation(newConv);
      return;
    }

    final newConv = await _supabase.createConversation(
      'Nová konverzácia',
      userId,
    );
    if (newConv != null) {
      setState(() {
        _conversations.insert(0, newConv);
      });
      _selectConversation(newConv);
    } else {
      setState(() => _loadingMsgs = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _activeConversation == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.user?.uid ?? '';

    setState(() => _sending = true);
    _msgController.clear();

    final userMsg = AiMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: _activeConversation!.id,
      content: text,
      role: 'user',
      userId: userId,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
    });
    _scrollToBottom();

    if (AppConfig.isTest) {
      await Future.delayed(const Duration(milliseconds: 500));
      final aiMsg = AiMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        conversationId: _activeConversation!.id,
        content:
            'Toto je simulovaná odpoveď na: "$text". Ako expert ti odporúčam preveriť chybové hlásenia a postupovať podľa blueprintu.',
        role: 'assistant',
        userId: 'ai',
        createdAt: DateTime.now(),
      );
      setState(() {
        _messages.add(aiMsg);
        _sending = false;
      });
      _scrollToBottom();
      return;
    }

    // Save user message to database
    final savedMsg = await _supabase.createMessage(userMsg);
    if (savedMsg != null) {
      setState(() {
        if (!_messages.any((m) => m.id == savedMsg.id)) {
          _messages.add(savedMsg);
        }
      });
      _scrollToBottom();
    }

    setState(() => _aiError = null);
    await _callAiRouter();

    setState(() => _sending = false);
  }

  // Zavolá existujúcu ai-router edge function (Mistral function calling nad bugs/comments) presne tým istým
  // vzorom ako LeadAiService pre lead-assistant (Firebase ID token ako Authorization header, keďže Supabase
  // klient tu beží len s anon kľúčom bez vlastnej Supabase Auth session). Edge function vloží AI odpoveď
  // priamo do ai_messages server-side - existujúca realtime subscription (_subscribeRealtime) ju automaticky
  // pridá do zoznamu správ, takže tu netreba nič manuálne vkladať do UI.
  Future<void> _callAiRouter() async {
    if (_activeConversation == null) return;

    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final token = await firebaseUser?.getIdToken();
    if (token == null || token.isEmpty) {
      setState(() => _aiError = 'Pre AI odpoveď sa musíš znovu prihlásiť.');
      return;
    }

    final history = _messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();

    try {
      final response = await _supabase.client.functions.invoke(
        'ai-router',
        body: {
          'providers': ['mistral'],
          'conversation_id': _activeConversation!.id,
          'messages': history,
        },
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = response.data;
      final results = data is Map ? data['results'] as List<dynamic>? : null;
      final firstResult = results != null && results.isNotEmpty
          ? results.first as Map
          : null;

      if (firstResult == null) {
        setState(() => _aiError = 'AI asistent nevrátil žiadnu odpoveď.');
      } else if (firstResult['error'] != null) {
        setState(
          () => _aiError = 'AI asistent zlyhal: ${firstResult['error']}',
        );
      }
    } on FunctionException catch (error) {
      setState(
        () => _aiError =
            'AI asistent zlyhal: ${error.details ?? error.reasonPhrase ?? error.status}',
      );
    } catch (e) {
      setState(() => _aiError = 'AI asistent zlyhal: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isAnythingLlmFrame
                ? _buildAnythingLlmFrame()
                : Row(
                    children: [
                      if (isDesktop) _buildSidebar(),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Color(0x10FFFFFF)),
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: _activeConversation == null
                                    ? _buildNoConversationPlaceholder()
                                    : _buildChatArea(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Colors.black.withValues(alpha: 0.1),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppTheme.primary, width: 0.5),
                ),
              ),
              icon: const Icon(LucideIcons.plus, size: 14),
              label: const Text(
                'Nový chat',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: _createNewChat,
            ),
          ),
          const Divider(color: Color(0x10FFFFFF)),
          Expanded(
            child: _loadingConvs
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final c = _conversations[index];
                      final isActive = _activeConversation?.id == c.id;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 4.0,
                        ),
                        child: InkWell(
                          onTap: () => _selectConversation(c),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: isActive
                                ? AppTheme.activeGlassDecoration(
                                    borderRadius: 8,
                                  )
                                : null,
                            child: Row(
                              children: [
                                const Icon(
                                  LucideIcons.messageSquare,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    c.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isActive
                                          ? AppTheme.textPrimary
                                          : AppTheme.textSecondary,
                                      fontWeight: isActive
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDesktop = Responsive.isDesktop(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0x0AFFFFFF),
        border: Border(bottom: BorderSide(color: Color(0x15FFFFFF))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title & Icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.bot,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Asistent / AnythingLLM',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        _isAnythingLlmFrame
                            ? 'AnythingLLM 1:1 Embedded Frame Mode'
                            : 'Native Supabase Chat Mode',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Mode Toggle & Action Buttons
              Row(
                children: [
                  Container(
                    height: 36,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0x0EFFFFFF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x15FFFFFF)),
                    ),
                    child: Row(
                      children: [
                        _buildModeTabButton(
                          title: '🤖 AnythingLLM (1:1 Frame)',
                          isActive: _isAnythingLlmFrame,
                          onTap: () => setState(() => _isAnythingLlmFrame = true),
                        ),
                        const SizedBox(width: 4),
                        _buildModeTabButton(
                          title: '💬 Native Chat',
                          isActive: !_isAnythingLlmFrame,
                          onTap: () => setState(() => _isAnythingLlmFrame = false),
                        ),
                      ],
                    ),
                  ),
                  if (!isDesktop && !_isAnythingLlmFrame) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(LucideIcons.messageSquare, size: 18),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: const Color(0xFF0F0F12),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          builder: (context) {
                            return SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'Moje konverzácie',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Divider(),
                                  ListTile(
                                    leading: const Icon(
                                      LucideIcons.plus,
                                      size: 16,
                                      color: AppTheme.primary,
                                    ),
                                    title: const Text(
                                      'Nový chat',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _createNewChat();
                                    },
                                  ),
                                  const Divider(),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: _conversations.length,
                                      itemBuilder: (context, index) {
                                        final c = _conversations[index];
                                        return ListTile(
                                          leading: const Icon(
                                            LucideIcons.messageSquare,
                                            size: 16,
                                          ),
                                          title: Text(
                                            c.title,
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                          onTap: () {
                                            Navigator.pop(context);
                                            _selectConversation(c);
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),

          // AnythingLLM URL Toolbar (Only visible in Frame mode)
          if (_isAnythingLlmFrame) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0x08FFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x10FFFFFF)),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.globe,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'URL:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _anythingLlmUrlController,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          hintText: 'napr. http://localhost:3001',
                          hintStyle: const TextStyle(
                            color: Color(0x35FFFFFF),
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0x0CFFFFFF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: Color(0x15FFFFFF)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppTheme.primary),
                          ),
                        ),
                        onSubmitted: (_) {
                          setState(() {
                            _anythingLlmFrameKey = UniqueKey();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Presets Popup
                  PopupMenuButton<String>(
                    tooltip: 'Rýchle URL predvoľby',
                    icon: const Icon(
                      LucideIcons.list,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    onSelected: (url) {
                      setState(() {
                        _anythingLlmUrlController.text = url;
                        _anythingLlmFrameKey = UniqueKey();
                      });
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'http://localhost:3001',
                        child: Text('http://localhost:3001 (AnythingLLM Default)'),
                      ),
                      PopupMenuItem(
                        value: 'http://localhost:3000',
                        child: Text('http://localhost:3000'),
                      ),
                      PopupMenuItem(
                        value: 'http://127.0.0.1:3001',
                        child: Text('http://127.0.0.1:3001'),
                      ),
                    ],
                  ),

                  // Refresh Button
                  IconButton(
                    tooltip: 'Obnoviť 1:1 frame',
                    icon: const Icon(
                      LucideIcons.refreshCw,
                      size: 15,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() {
                        _anythingLlmFrameKey = UniqueKey();
                      });
                    },
                  ),

                  // Open Externally Button
                  IconButton(
                    tooltip: 'Otvoriť v novej karte ↗️',
                    icon: const Icon(
                      LucideIcons.externalLink,
                      size: 15,
                      color: AppTheme.primary,
                    ),
                    onPressed: _openAnythingLlmExternally,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeTabButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  void _openAnythingLlmExternally() {
    final url = _anythingLlmUrlController.text.trim();
    if (url.isNotEmpty) {
      openExternalUrl(url);
    }
  }

  Widget _buildAnythingLlmFrame() {
    final url = _anythingLlmUrlController.text.trim();

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: createAnythingLLMIFrameWidget(url, key: _anythingLlmFrameKey),
      ),
    );
  }

  Widget _buildNoConversationPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: const Icon(
              LucideIcons.bot,
              color: AppTheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Vitajte v AI Asistentovi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Môžete klásť otázky o svojich projektoch a nahlásených chybách.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _createNewChat,
            child: const Text(
              'Začať novú konverzáciu',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    if (_loadingMsgs) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Messages list
        Expanded(
          child: _messages.isEmpty
              ? _buildWelcomeMessage()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final m = _messages[index];
                    final isUser = m.role == 'user';
                    return _buildMessageBubble(m.content, isUser);
                  },
                ),
        ),

        if (_aiError != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.35)),
            ),
            child: Text(
              _aiError!,
              style: const TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ),

        // Text input field
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0x05FFFFFF),
            border: Border(top: BorderSide(color: Color(0x10FFFFFF))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0x0EFFFFFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x12FFFFFF)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Položte otázku...',
                      hintStyle: TextStyle(
                        color: Color(0x35FFFFFF),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary,
                child: IconButton(
                  icon: const Icon(
                    LucideIcons.send,
                    color: Colors.white,
                    size: 14,
                  ),
                  onPressed: _sending ? null : _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.bot,
              color: AppTheme.textSecondary,
              size: 30,
            ),
            const SizedBox(height: 12),
            const Text(
              'Konverzácia je prázdna',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Položte prvú otázku! Napr.: „Koľko kritických chýb máme?“',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String content, bool isUser) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
              child: const Icon(
                LucideIcons.bot,
                color: AppTheme.primary,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primary : const Color(0x0EFFFFFF),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                ),
                border: isUser
                    ? null
                    : Border.all(color: const Color(0x12FFFFFF)),
              ),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 12,
                  color: isUser ? Colors.white : AppTheme.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0x0EFFFFFF),
              child: const Icon(
                LucideIcons.user,
                color: AppTheme.textSecondary,
                size: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
