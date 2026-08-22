/// Dart port of `src/types/domain.ts` from the AutoOps AI web app.
///
/// Enums carry the exact wire string used by the TS union types (via
/// `.value` / `fromValue`) so that JSON payloads stay compatible with the
/// existing mock data / eventual backend contract.
library;

typedef ID = String;

enum AgentMode {
  fullyAutonomous('fully_autonomous'),
  supervised('supervised'),
  paused('paused');

  const AgentMode(this.value);
  final String value;

  static AgentMode fromValue(String value) =>
      AgentMode.values.firstWhere((e) => e.value == value);
}

enum ActivityType {
  email('email'),
  invoice('invoice'),
  shipping('shipping'),
  order('order'),
  workflow('workflow'),
  risk('risk');

  const ActivityType(this.value);
  final String value;

  static ActivityType fromValue(String value) =>
      ActivityType.values.firstWhere((e) => e.value == value);
}

enum ActivityStatus {
  done('done'),
  pending('pending'),
  needsReview('needs_review'),
  failed('failed');

  const ActivityStatus(this.value);
  final String value;

  static ActivityStatus fromValue(String value) =>
      ActivityStatus.values.firstWhere((e) => e.value == value);
}

enum AuthProvider {
  supabase('supabase'),
  mock('mock');

  const AuthProvider(this.value);
  final String value;

  static AuthProvider fromValue(String value) =>
      AuthProvider.values.firstWhere((e) => e.value == value);
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.workspaceName,
    this.avatarUrl,
  });

  final ID id;
  final String email;
  final String name;
  final String workspaceName;
  final String? avatarUrl;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        workspaceName: json['workspaceName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'workspaceName': workspaceName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      };
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.provider,
    required this.expiresAt,
  });

  final UserProfile user;
  final String accessToken;
  final AuthProvider provider;
  final String expiresAt;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
        user: UserProfile.fromJson(json['user'] as Map<String, dynamic>),
        accessToken: json['accessToken'] as String,
        provider: AuthProvider.fromValue(json['provider'] as String),
        expiresAt: json['expiresAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'accessToken': accessToken,
        'provider': provider.value,
        'expiresAt': expiresAt,
      };
}

class DashboardStats {
  const DashboardStats({
    required this.savedHoursToday,
    required this.savedHoursWeek,
    required this.ordersProcessed,
    required this.emailsAnswered,
    required this.invoicesSent,
    required this.avgConfidence,
    required this.riskEvents,
    required this.costSavedToday,
  });

  final double savedHoursToday;
  final double savedHoursWeek;
  final int ordersProcessed;
  final int emailsAnswered;
  final int invoicesSent;
  final double avgConfidence;
  final int riskEvents;
  final double costSavedToday;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        savedHoursToday: (json['savedHoursToday'] as num).toDouble(),
        savedHoursWeek: (json['savedHoursWeek'] as num).toDouble(),
        ordersProcessed: json['ordersProcessed'] as int,
        emailsAnswered: json['emailsAnswered'] as int,
        invoicesSent: json['invoicesSent'] as int,
        avgConfidence: (json['avgConfidence'] as num).toDouble(),
        riskEvents: json['riskEvents'] as int,
        costSavedToday: (json['costSavedToday'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'savedHoursToday': savedHoursToday,
        'savedHoursWeek': savedHoursWeek,
        'ordersProcessed': ordersProcessed,
        'emailsAnswered': emailsAnswered,
        'invoicesSent': invoicesSent,
        'avgConfidence': avgConfidence,
        'riskEvents': riskEvents,
        'costSavedToday': costSavedToday,
      };
}

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.source,
    required this.createdAt,
    required this.status,
    required this.confidence,
    this.moneyImpactEur,
  });

  final ID id;
  final ActivityType type;
  final String title;
  final String description;
  final String source;
  final String createdAt;
  final ActivityStatus status;
  final double confidence;
  final double? moneyImpactEur;

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        id: json['id'] as String,
        type: ActivityType.fromValue(json['type'] as String),
        title: json['title'] as String,
        description: json['description'] as String,
        source: json['source'] as String,
        createdAt: json['createdAt'] as String,
        status: ActivityStatus.fromValue(json['status'] as String),
        confidence: (json['confidence'] as num).toDouble(),
        moneyImpactEur: (json['moneyImpactEur'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.value,
        'title': title,
        'description': description,
        'source': source,
        'createdAt': createdAt,
        'status': status.value,
        'confidence': confidence,
        if (moneyImpactEur != null) 'moneyImpactEur': moneyImpactEur,
      };
}

class AgentStatus {
  const AgentStatus({
    required this.mode,
    required this.uptimePercent,
    required this.currentTask,
    required this.queueDepth,
    required this.autonomyScore,
    required this.guardrails,
  });

  final AgentMode mode;
  final double uptimePercent;
  final String currentTask;
  final int queueDepth;
  final int autonomyScore;
  final List<String> guardrails;

  factory AgentStatus.fromJson(Map<String, dynamic> json) => AgentStatus(
        mode: AgentMode.fromValue(json['mode'] as String),
        uptimePercent: (json['uptimePercent'] as num).toDouble(),
        currentTask: json['currentTask'] as String,
        queueDepth: json['queueDepth'] as int,
        autonomyScore: json['autonomyScore'] as int,
        guardrails: (json['guardrails'] as List).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.value,
        'uptimePercent': uptimePercent,
        'currentTask': currentTask,
        'queueDepth': queueDepth,
        'autonomyScore': autonomyScore,
        'guardrails': guardrails,
      };
}

enum AgentActionKind {
  sendEmail('send_email'),
  createInvoice('create_invoice'),
  replyCustomer('reply_customer'),
  bookShipping('book_shipping'),
  escalateHuman('escalate_human'),
  summarizeInbox('summarize_inbox');

  const AgentActionKind(this.value);
  final String value;

  static AgentActionKind fromValue(String value) =>
      AgentActionKind.values.firstWhere((e) => e.value == value);
}

enum AgentActionStatus {
  executed('executed'),
  requiresApproval('requires_approval'),
  blocked('blocked');

  const AgentActionStatus(this.value);
  final String value;

  static AgentActionStatus fromValue(String value) =>
      AgentActionStatus.values.firstWhere((e) => e.value == value);
}

class AgentCommand {
  const AgentCommand({required this.prompt, required this.workspaceId});

  final String prompt;
  final String workspaceId;

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'workspaceId': workspaceId,
      };
}

class AgentActionResult {
  const AgentActionResult({
    required this.id,
    required this.kind,
    required this.title,
    required this.summary,
    required this.status,
    required this.confidence,
    required this.createdAt,
    required this.payloadPreview,
  });

  final ID id;
  final AgentActionKind kind;
  final String title;
  final String summary;
  final AgentActionStatus status;
  final double confidence;
  final String createdAt;

  /// Mirrors `Record<string, string | number | boolean>` from the TS type.
  final Map<String, Object> payloadPreview;

  factory AgentActionResult.fromJson(Map<String, dynamic> json) =>
      AgentActionResult(
        id: json['id'] as String,
        kind: AgentActionKind.fromValue(json['kind'] as String),
        title: json['title'] as String,
        summary: json['summary'] as String,
        status: AgentActionStatus.fromValue(json['status'] as String),
        confidence: (json['confidence'] as num).toDouble(),
        createdAt: json['createdAt'] as String,
        payloadPreview:
            (json['payloadPreview'] as Map<String, dynamic>).cast<String, Object>(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.value,
        'title': title,
        'summary': summary,
        'status': status.value,
        'confidence': confidence,
        'createdAt': createdAt,
        'payloadPreview': payloadPreview,
      };
}

enum IntegrationKey {
  shopify('shopify'),
  woocommerce('woocommerce'),
  gmail('gmail'),
  superfaktura('superfaktura'),
  idoklad('idoklad'),
  packeta('packeta'),
  gls('gls'),
  instagram('instagram'),
  facebook('facebook'),
  upgates('upgates');

  const IntegrationKey(this.value);
  final String value;

  static IntegrationKey fromValue(String value) =>
      IntegrationKey.values.firstWhere((e) => e.value == value);
}

enum IntegrationCategory {
  commerce('commerce'),
  email('email'),
  accounting('accounting'),
  shipping('shipping'),
  social('social'),
  support('support');

  const IntegrationCategory(this.value);
  final String value;

  static IntegrationCategory fromValue(String value) =>
      IntegrationCategory.values.firstWhere((e) => e.value == value);
}

enum IntegrationHealth {
  healthy('healthy'),
  degraded('degraded'),
  offline('offline');

  const IntegrationHealth(this.value);
  final String value;

  static IntegrationHealth fromValue(String value) =>
      IntegrationHealth.values.firstWhere((e) => e.value == value);
}

class Integration {
  const Integration({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.connected,
    required this.health,
    required this.lastSyncAt,
    required this.scopes,
    required this.monthlyActions,
    required this.latencyMs,
  });

  final IntegrationKey id;
  final String name;
  final String description;
  final IntegrationCategory category;
  final bool connected;
  final IntegrationHealth health;
  final String lastSyncAt;
  final List<String> scopes;
  final int monthlyActions;
  final int latencyMs;

  factory Integration.fromJson(Map<String, dynamic> json) => Integration(
        id: IntegrationKey.fromValue(json['id'] as String),
        name: json['name'] as String,
        description: json['description'] as String,
        category: IntegrationCategory.fromValue(json['category'] as String),
        connected: json['connected'] as bool,
        health: IntegrationHealth.fromValue(json['health'] as String),
        lastSyncAt: json['lastSyncAt'] as String,
        scopes: (json['scopes'] as List).cast<String>(),
        monthlyActions: json['monthlyActions'] as int,
        latencyMs: json['latencyMs'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id.value,
        'name': name,
        'description': description,
        'category': category.value,
        'connected': connected,
        'health': health.value,
        'lastSyncAt': lastSyncAt,
        'scopes': scopes,
        'monthlyActions': monthlyActions,
        'latencyMs': latencyMs,
      };

  Integration copyWith({
    bool? connected,
    IntegrationHealth? health,
    String? lastSyncAt,
    int? monthlyActions,
    int? latencyMs,
  }) =>
      Integration(
        id: id,
        name: name,
        description: description,
        category: category,
        connected: connected ?? this.connected,
        health: health ?? this.health,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        scopes: scopes,
        monthlyActions: monthlyActions ?? this.monthlyActions,
        latencyMs: latencyMs ?? this.latencyMs,
      );
}

enum InboxSource {
  gmail('gmail'),
  shopify('shopify'),
  woocommerce('woocommerce'),
  instagram('instagram'),
  support('support');

  const InboxSource(this.value);
  final String value;

  static InboxSource fromValue(String value) =>
      InboxSource.values.firstWhere((e) => e.value == value);
}

enum InboxCategory {
  complaint('complaint'),
  invoice('invoice'),
  shipping('shipping'),
  returns('returns'),
  lead('lead'),
  vip('vip'),
  spam('spam');

  const InboxCategory(this.value);
  final String value;

  static InboxCategory fromValue(String value) =>
      InboxCategory.values.firstWhere((e) => e.value == value);
}

enum InboxPriority {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  const InboxPriority(this.value);
  final String value;

  static InboxPriority fromValue(String value) =>
      InboxPriority.values.firstWhere((e) => e.value == value);
}

enum InboxSentiment {
  positive('positive'),
  neutral('neutral'),
  negative('negative');

  const InboxSentiment(this.value);
  final String value;

  static InboxSentiment fromValue(String value) =>
      InboxSentiment.values.firstWhere((e) => e.value == value);
}

enum InboxStatus {
  autoReplied('auto_replied'),
  queued('queued'),
  needsHuman('needs_human'),
  closed('closed');

  const InboxStatus(this.value);
  final String value;

  static InboxStatus fromValue(String value) =>
      InboxStatus.values.firstWhere((e) => e.value == value);
}

class UnifiedInboxItem {
  const UnifiedInboxItem({
    required this.id,
    required this.source,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.category,
    required this.priority,
    required this.sentiment,
    required this.status,
    this.aiDraft,
    required this.receivedAt,
    this.orderRef,
    this.valueEur,
  });

  final ID id;
  final InboxSource source;
  final String sender;
  final String subject;
  final String preview;
  final InboxCategory category;
  final InboxPriority priority;
  final InboxSentiment sentiment;
  final InboxStatus status;
  final String? aiDraft;
  final String receivedAt;
  final String? orderRef;
  final double? valueEur;

  factory UnifiedInboxItem.fromJson(Map<String, dynamic> json) =>
      UnifiedInboxItem(
        id: json['id'] as String,
        source: InboxSource.fromValue(json['source'] as String),
        sender: json['sender'] as String,
        subject: json['subject'] as String,
        preview: json['preview'] as String,
        category: InboxCategory.fromValue(json['category'] as String),
        priority: InboxPriority.fromValue(json['priority'] as String),
        sentiment: InboxSentiment.fromValue(json['sentiment'] as String),
        status: InboxStatus.fromValue(json['status'] as String),
        aiDraft: json['aiDraft'] as String?,
        receivedAt: json['receivedAt'] as String,
        orderRef: json['orderRef'] as String?,
        valueEur: (json['valueEur'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source.value,
        'sender': sender,
        'subject': subject,
        'preview': preview,
        'category': category.value,
        'priority': priority.value,
        'sentiment': sentiment.value,
        'status': status.value,
        if (aiDraft != null) 'aiDraft': aiDraft,
        'receivedAt': receivedAt,
        if (orderRef != null) 'orderRef': orderRef,
        if (valueEur != null) 'valueEur': valueEur,
      };

  UnifiedInboxItem copyWith({InboxStatus? status}) => UnifiedInboxItem(
        id: id,
        source: source,
        sender: sender,
        subject: subject,
        preview: preview,
        category: category,
        priority: priority,
        sentiment: sentiment,
        status: status ?? this.status,
        aiDraft: aiDraft,
        receivedAt: receivedAt,
        orderRef: orderRef,
        valueEur: valueEur,
      );
}

enum WorkflowNodeType {
  trigger('trigger'),
  action('action'),
  condition('condition'),
  approval('approval');

  const WorkflowNodeType(this.value);
  final String value;

  static WorkflowNodeType fromValue(String value) =>
      WorkflowNodeType.values.firstWhere((e) => e.value == value);
}

enum WorkflowConnector {
  gmail('gmail'),
  shopify('shopify'),
  woocommerce('woocommerce'),
  superfaktura('superfaktura'),
  idoklad('idoklad'),
  packeta('packeta'),
  gls('gls'),
  instagram('instagram'),
  agent('agent');

  const WorkflowConnector(this.value);
  final String value;

  static WorkflowConnector fromValue(String value) =>
      WorkflowConnector.values.firstWhere((e) => e.value == value);
}

enum WorkflowNodeStatus {
  idle('idle'),
  running('running'),
  success('success'),
  warning('warning');

  const WorkflowNodeStatus(this.value);
  final String value;

  static WorkflowNodeStatus fromValue(String value) =>
      WorkflowNodeStatus.values.firstWhere((e) => e.value == value);
}

class WorkflowNode {
  const WorkflowNode({
    required this.id,
    required this.type,
    required this.connector,
    required this.label,
    required this.description,
    required this.x,
    required this.y,
    required this.status,
  });

  final ID id;
  final WorkflowNodeType type;
  final WorkflowConnector connector;
  final String label;
  final String description;
  final double x;
  final double y;
  final WorkflowNodeStatus status;

  factory WorkflowNode.fromJson(Map<String, dynamic> json) => WorkflowNode(
        id: json['id'] as String,
        type: WorkflowNodeType.fromValue(json['type'] as String),
        connector: WorkflowConnector.fromValue(json['connector'] as String),
        label: json['label'] as String,
        description: json['description'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        status: WorkflowNodeStatus.fromValue(json['status'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.value,
        'connector': connector.value,
        'label': label,
        'description': description,
        'x': x,
        'y': y,
        'status': status.value,
      };
}

class WorkflowEdge {
  const WorkflowEdge({required this.id, required this.from, required this.to});

  final ID id;
  final ID from;
  final ID to;

  factory WorkflowEdge.fromJson(Map<String, dynamic> json) => WorkflowEdge(
        id: json['id'] as String,
        from: json['from'] as String,
        to: json['to'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'from': from, 'to': to};
}

class WorkflowGraph {
  const WorkflowGraph({
    required this.id,
    required this.name,
    required this.description,
    required this.nodes,
    required this.edges,
    required this.updatedAt,
  });

  final ID id;
  final String name;
  final String description;
  final List<WorkflowNode> nodes;
  final List<WorkflowEdge> edges;
  final String updatedAt;

  factory WorkflowGraph.fromJson(Map<String, dynamic> json) => WorkflowGraph(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        nodes: (json['nodes'] as List)
            .map((e) => WorkflowNode.fromJson(e as Map<String, dynamic>))
            .toList(),
        edges: (json['edges'] as List)
            .map((e) => WorkflowEdge.fromJson(e as Map<String, dynamic>))
            .toList(),
        updatedAt: json['updatedAt'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'nodes': nodes.map((e) => e.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt,
      };

  WorkflowGraph copyWith({
    String? name,
    String? description,
    List<WorkflowNode>? nodes,
    List<WorkflowEdge>? edges,
    String? updatedAt,
  }) =>
      WorkflowGraph(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        nodes: nodes ?? this.nodes,
        edges: edges ?? this.edges,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class AnalyticsPoint {
  const AnalyticsPoint({
    required this.date,
    required this.savedHours,
    required this.costSaved,
    required this.handledTasks,
    required this.accuracy,
  });

  final String date;
  final double savedHours;
  final double costSaved;
  final double handledTasks;
  final double accuracy;

  factory AnalyticsPoint.fromJson(Map<String, dynamic> json) => AnalyticsPoint(
        date: json['date'] as String,
        savedHours: (json['savedHours'] as num).toDouble(),
        costSaved: (json['costSaved'] as num).toDouble(),
        handledTasks: (json['handledTasks'] as num).toDouble(),
        accuracy: (json['accuracy'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'savedHours': savedHours,
        'costSaved': costSaved,
        'handledTasks': handledTasks,
        'accuracy': accuracy,
      };
}
