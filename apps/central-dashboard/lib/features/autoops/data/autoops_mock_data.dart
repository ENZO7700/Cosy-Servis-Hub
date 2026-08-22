/// Dart port of `src/api/mock-data.ts` — same seed data, same shape.
library;

import 'dart:math';

import '../../../core/action_graph/engine.dart';
import '../../../domain/autoops/domain.dart';

String _formatDayMonth(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';

final DateTime _now = DateTime.now();

String _minutesAgo(int minutes) =>
    _now.subtract(Duration(minutes: minutes)).toIso8601String();

String _daysAgo(int days) => _now.subtract(Duration(days: days)).toIso8601String();

final DashboardStats dashboardStats = const DashboardStats(
  savedHoursToday: 6.8,
  savedHoursWeek: 34.5,
  ordersProcessed: 184,
  emailsAnswered: 72,
  invoicesSent: 49,
  avgConfidence: 94.2,
  riskEvents: 3,
  costSavedToday: 612,
);

final AgentStatus agentStatus = const AgentStatus(
  mode: AgentMode.fullyAutonomous,
  uptimePercent: 99.87,
  currentTask: 'Pairing Packeta labels with Shopify paid orders',
  queueDepth: 17,
  autonomyScore: 91,
  guardrails: [
    'Refunds require human approval',
    'Accounting mutations are audit-logged',
    'Low confidence replies are queued',
    'VIP customer complaints escalate',
  ],
);

final List<ActivityItem> activityFeed = [
  ActivityItem(
    id: 'act_001',
    type: ActivityType.shipping,
    title: 'Packeta labels created',
    description: 'Generated 16 pickup-point shipments for orders SK-10492 to SK-10508.',
    source: 'Packeta + Shopify',
    createdAt: _minutesAgo(6),
    status: ActivityStatus.done,
    confidence: 98,
    moneyImpactEur: 44,
  ),
  ActivityItem(
    id: 'act_002',
    type: ActivityType.invoice,
    title: 'SuperFaktura invoices issued',
    description: 'Issued VAT invoices for paid B2B orders from Brno, Žilina and Košice.',
    source: 'SuperFaktura',
    createdAt: _minutesAgo(18),
    status: ActivityStatus.done,
    confidence: 96,
    moneyImpactEur: 320,
  ),
  ActivityItem(
    id: 'act_003',
    type: ActivityType.email,
    title: 'Warranty complaint drafted',
    description:
        'Prepared polite-but-firm reply for customer asking whether a chewed cable is "factory condition". Humanity limps on.',
    source: 'Gmail',
    createdAt: _minutesAgo(31),
    status: ActivityStatus.needsReview,
    confidence: 78,
  ),
  ActivityItem(
    id: 'act_004',
    type: ActivityType.order,
    title: 'WooCommerce payment reconciled',
    description: 'Matched bank reference VS20260428-781 with order CZ-77821.',
    source: 'WooCommerce + iDoklad',
    createdAt: _minutesAgo(46),
    status: ActivityStatus.done,
    confidence: 94,
    moneyImpactEur: 129,
  ),
  ActivityItem(
    id: 'act_005',
    type: ActivityType.risk,
    title: 'Refund blocked by guardrail',
    description:
        'Refund request exceeded autonomous threshold. Sent to human queue before accounting becomes modern art.',
    source: 'Agent Guardrails',
    createdAt: _minutesAgo(61),
    status: ActivityStatus.pending,
    confidence: 82,
  ),
];

final List<Integration> integrations = [
  Integration(
    id: IntegrationKey.shopify,
    name: 'Shopify',
    description: 'Orders, customers, refunds, fulfillment events and webhook ingestion for paid orders.',
    category: IntegrationCategory.commerce,
    connected: true,
    health: IntegrationHealth.healthy,
    lastSyncAt: _minutesAgo(3),
    scopes: const ['read_orders', 'write_fulfillments', 'read_customers'],
    monthlyActions: 18420,
    latencyMs: 140,
  ),
  Integration(
    id: IntegrationKey.woocommerce,
    name: 'WooCommerce',
    description: 'Order sync, stock updates and payment matching for WordPress stores.',
    category: IntegrationCategory.commerce,
    connected: false,
    health: IntegrationHealth.offline,
    lastSyncAt: _daysAgo(9),
    scopes: const ['read_orders', 'write_orders', 'read_products'],
    monthlyActions: 0,
    latencyMs: 0,
  ),
  Integration(
    id: IntegrationKey.gmail,
    name: 'Gmail',
    description: 'Unified customer email inbox with intent classification and supervised auto-replies.',
    category: IntegrationCategory.email,
    connected: true,
    health: IntegrationHealth.healthy,
    lastSyncAt: _minutesAgo(1),
    scopes: const ['gmail.readonly', 'gmail.send', 'gmail.modify'],
    monthlyActions: 9321,
    latencyMs: 88,
  ),
  Integration(
    id: IntegrationKey.superfaktura,
    name: 'SuperFaktúra',
    description: 'Slovak invoice creation, VAT profiles, proforma invoices and accounting exports.',
    category: IntegrationCategory.accounting,
    connected: true,
    health: IntegrationHealth.healthy,
    lastSyncAt: _minutesAgo(12),
    scopes: const ['invoices.create', 'customers.read', 'payments.match'],
    monthlyActions: 3120,
    latencyMs: 220,
  ),
  Integration(
    id: IntegrationKey.idoklad,
    name: 'iDoklad',
    description: 'Czech invoice workflows, payment pairing and customer/company register lookup.',
    category: IntegrationCategory.accounting,
    connected: false,
    health: IntegrationHealth.offline,
    lastSyncAt: _daysAgo(4),
    scopes: const ['issued_invoices', 'contacts', 'payments'],
    monthlyActions: 0,
    latencyMs: 0,
  ),
  Integration(
    id: IntegrationKey.packeta,
    name: 'Packeta',
    description: 'Pickup-point delivery, barcode labels, tracking events and parcel status sync.',
    category: IntegrationCategory.shipping,
    connected: true,
    health: IntegrationHealth.degraded,
    lastSyncAt: _minutesAgo(28),
    scopes: const ['parcel.create', 'label.download', 'tracking.read'],
    monthlyActions: 5411,
    latencyMs: 430,
  ),
  Integration(
    id: IntegrationKey.gls,
    name: 'GLS',
    description: 'Courier labels, parcel tracking, pickup manifests and cross-border delivery.',
    category: IntegrationCategory.shipping,
    connected: false,
    health: IntegrationHealth.offline,
    lastSyncAt: _daysAgo(12),
    scopes: const ['shipments.create', 'labels.read', 'tracking.read'],
    monthlyActions: 0,
    latencyMs: 0,
  ),
  Integration(
    id: IntegrationKey.instagram,
    name: 'Instagram DMs',
    description: 'Message triage for social selling, lead capture and angry emoji containment.',
    category: IntegrationCategory.social,
    connected: true,
    health: IntegrationHealth.healthy,
    lastSyncAt: _minutesAgo(4),
    scopes: const ['messages.read', 'messages.reply', 'profile.read'],
    monthlyActions: 1450,
    latencyMs: 172,
  ),
  Integration(
    id: IntegrationKey.upgates,
    name: 'Upgates',
    description: 'CZ/SK e-shop connector for orders, product feeds and customer synchronization.',
    category: IntegrationCategory.commerce,
    connected: false,
    health: IntegrationHealth.offline,
    lastSyncAt: _daysAgo(20),
    scopes: const ['orders', 'products', 'customers'],
    monthlyActions: 0,
    latencyMs: 0,
  ),
];

final List<UnifiedInboxItem> inboxItems = [
  UnifiedInboxItem(
    id: 'msg_001',
    source: InboxSource.gmail,
    sender: 'Martina Kováčová <martina.kovacova@example.sk>',
    subject: 'Kde je moja zásielka SK-10498?',
    preview:
        'Dobrý deň, zásielka mala byť v Packete včera, ale stále nevidím žiadny pohyb. Prosím o preverenie.',
    category: InboxCategory.shipping,
    priority: InboxPriority.high,
    sentiment: InboxSentiment.negative,
    status: InboxStatus.queued,
    aiDraft:
        'Dobrý deň, Martina, preverili sme zásielku SK-10498. Podľa Packety bola oneskorená pri triedení v depe Bratislava. Očakávané doručenie je zajtra. Pošleme tracking link a ospravedlnenie.',
    receivedAt: _minutesAgo(8),
    orderRef: 'SK-10498',
    valueEur: 86,
  ),
  UnifiedInboxItem(
    id: 'msg_002',
    source: InboxSource.shopify,
    sender: 'Shopify Flow',
    subject: 'High-value order paid: SK-10512',
    preview:
        'Order SK-10512 has been paid. Customer requested invoice to company: Tatra Elektro s.r.o., VAT ID SK2120...',
    category: InboxCategory.invoice,
    priority: InboxPriority.medium,
    sentiment: InboxSentiment.neutral,
    status: InboxStatus.autoReplied,
    receivedAt: _minutesAgo(22),
    orderRef: 'SK-10512',
    valueEur: 1240,
  ),
  UnifiedInboxItem(
    id: 'msg_003',
    source: InboxSource.instagram,
    sender: '@lucia.fit.sk',
    subject: 'DM: Spolupráca / veľkoobchod',
    preview:
        'Ahojte, beriete veľkoobchodné objednávky pre fitness štúdio v Nitre? Potrebujeme pravidelne 30-50 ks mesačne.',
    category: InboxCategory.lead,
    priority: InboxPriority.medium,
    sentiment: InboxSentiment.positive,
    status: InboxStatus.queued,
    aiDraft:
        'Ahoj Lucia, áno, veľkoobchod riešime. Pošleme cenník a krátky formulár pre pravidelné objednávky.',
    receivedAt: _minutesAgo(37),
    valueEur: 950,
  ),
  UnifiedInboxItem(
    id: 'msg_004',
    source: InboxSource.support,
    sender: 'Petr Novák <petr.novak@example.cz>',
    subject: 'Reklamace: poškozený balík GLS CZ-77821',
    preview:
        'Balík dorazil otevřený a produkt je poškozený. Prosím okamžité řešení, jinak dávám negativní hodnocení.',
    category: InboxCategory.complaint,
    priority: InboxPriority.critical,
    sentiment: InboxSentiment.negative,
    status: InboxStatus.needsHuman,
    aiDraft:
        'Dobrý den, Petře, omlouváme se za komplikaci. Prosíme o fotografii obalu a produktu. Případ předáváme reklamačnímu týmu a připravíme výměnu.',
    receivedAt: _minutesAgo(44),
    orderRef: 'CZ-77821',
    valueEur: 179,
  ),
  UnifiedInboxItem(
    id: 'msg_005',
    source: InboxSource.woocommerce,
    sender: 'WooCommerce',
    subject: 'Unpaid order reminder CZ-77830',
    preview: 'Customer selected bank transfer but payment has not been matched after 48 hours.',
    category: InboxCategory.invoice,
    priority: InboxPriority.low,
    sentiment: InboxSentiment.neutral,
    status: InboxStatus.queued,
    receivedAt: _minutesAgo(52),
    orderRef: 'CZ-77830',
    valueEur: 64,
  ),
  UnifiedInboxItem(
    id: 'msg_006',
    source: InboxSource.gmail,
    sender: 'VIP: Ján Hrčka <jan.hrcka@example.sk>',
    subject: 'Prosím o urgentný dobropis',
    preview:
        'Potrebujem dobropis k faktúre SF-2026-0418 ešte dnes, účtovníctvo nám horí. Ako vždy, v piatok o 16:58.',
    category: InboxCategory.vip,
    priority: InboxPriority.high,
    sentiment: InboxSentiment.neutral,
    status: InboxStatus.needsHuman,
    aiDraft:
        'Dobrý deň, Ján, podklady máme pripravené. Keďže ide o dobropis, posielame to na rýchle schválenie účtovníctvu.',
    receivedAt: _minutesAgo(67),
    orderRef: 'SF-2026-0418',
    valueEur: 410,
  ),
];

final List<WorkflowNode> _workflowNodes = [
  const WorkflowNode(
    id: 'node_gmail',
    type: WorkflowNodeType.trigger,
    connector: WorkflowConnector.gmail,
    label: 'Gmail: New support email',
    description: 'Classify incoming Gmail conversations by intent and sentiment.',
    x: 60,
    y: 120,
    status: WorkflowNodeStatus.success,
  ),
  const WorkflowNode(
    id: 'node_shopify',
    type: WorkflowNodeType.action,
    connector: WorkflowConnector.shopify,
    label: 'Shopify: Lookup order',
    description: 'Find the matching order, customer and fulfillment state.',
    x: 350,
    y: 120,
    status: WorkflowNodeStatus.success,
  ),
  const WorkflowNode(
    id: 'node_superfaktura',
    type: WorkflowNodeType.action,
    connector: WorkflowConnector.superfaktura,
    label: 'SuperFaktúra: Create invoice',
    description: 'Generate invoice or proforma based on payment state.',
    x: 640,
    y: 120,
    status: WorkflowNodeStatus.running,
  ),
  const WorkflowNode(
    id: 'node_packeta',
    type: WorkflowNodeType.action,
    connector: WorkflowConnector.packeta,
    label: 'Packeta: Create label',
    description: 'Create shipment and attach tracking URL to customer email.',
    x: 930,
    y: 120,
    status: WorkflowNodeStatus.idle,
  ),
  const WorkflowNode(
    id: 'node_approval',
    type: WorkflowNodeType.approval,
    connector: WorkflowConnector.agent,
    label: 'Guardrail: Approval for refunds',
    description: 'Pause on refunds, discounts and accounting mutations.',
    x: 640,
    y: 340,
    status: WorkflowNodeStatus.warning,
  ),
];

final WorkflowGraph workflowGraph = WorkflowGraph(
  id: 'wf_core_ops',
  name: 'Order-to-cash autonomous flow',
  description: 'Gmail → Shopify → SuperFaktúra → Packeta with approval guardrails for risky actions.',
  nodes: _workflowNodes,
  edges: [
    ...createLinearEdges(_workflowNodes.take(4).toList()),
    const WorkflowEdge(id: 'edge_shopify_approval', from: 'node_shopify', to: 'node_approval'),
    const WorkflowEdge(id: 'edge_approval_superfaktura', from: 'node_approval', to: 'node_superfaktura'),
  ],
  updatedAt: _minutesAgo(13),
);

final List<AnalyticsPoint> analyticsPoints = List.generate(14, (index) {
  final day = 13 - index;
  final date = _now.subtract(Duration(days: day));
  return AnalyticsPoint(
    date: _formatDayMonth(date),
    savedHours: 3.8 + sin(index / 2) * 1.2 + index * 0.27,
    costSaved: (280 + index * 34 + cos(index.toDouble()) * 42).roundToDouble(),
    handledTasks: (80 + index * 9 + sin(index.toDouble()) * 11).roundToDouble(),
    accuracy: min(98.5, 88 + index * 0.55 + sin(index / 3) * 1.8),
  );
});
