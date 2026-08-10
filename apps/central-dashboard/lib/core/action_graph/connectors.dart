/// Dart port of `src/lib/action-graph/connectors.ts`.
///
/// `lucide-react` icons -> `material` `IconData`; the closest visual
/// equivalent was picked per connector (Instagram/Gmail/etc. have no first
/// party Material glyph, so a generic outline icon stands in — swap for a
/// brand icon font/package if exact logos matter).
library;

import 'package:flutter/material.dart';

import '../../domain/autoops/domain.dart';

enum ConnectorAccent {
  cyan(Color(0xFF22D3EE)),
  purple(Color(0xFFA855F7)),
  green(Color(0xFF22C55E)),
  amber(Color(0xFFF59E0B));

  const ConnectorAccent(this.color);
  final Color color;
}

class ConnectorTemplate {
  const ConnectorTemplate({
    required this.connector,
    required this.type,
    required this.label,
    required this.description,
    required this.accent,
    required this.icon,
  });

  final WorkflowConnector connector;
  final WorkflowNodeType type;
  final String label;
  final String description;
  final ConnectorAccent accent;
  final IconData icon;
}

const List<ConnectorTemplate> connectorTemplates = [
  ConnectorTemplate(
    connector: WorkflowConnector.gmail,
    type: WorkflowNodeType.trigger,
    label: 'Gmail: New customer email',
    description: 'Trigger when a customer email matches intent rules.',
    accent: ConnectorAccent.cyan,
    icon: Icons.mail_outline,
  ),
  ConnectorTemplate(
    connector: WorkflowConnector.shopify,
    type: WorkflowNodeType.trigger,
    label: 'Shopify: Paid order',
    description: 'Start automation when a new paid order arrives.',
    accent: ConnectorAccent.green,
    icon: Icons.shopping_bag_outlined,
  ),
  ConnectorTemplate(
    connector: WorkflowConnector.superfaktura,
    type: WorkflowNodeType.action,
    label: 'SuperFaktura: Create invoice',
    description: 'Issue an invoice with VAT profile and order metadata.',
    accent: ConnectorAccent.purple,
    icon: Icons.description_outlined,
  ),
  ConnectorTemplate(
    connector: WorkflowConnector.packeta,
    type: WorkflowNodeType.action,
    label: 'Packeta: Create shipment',
    description: 'Book pickup point delivery and generate shipping label.',
    accent: ConnectorAccent.amber,
    icon: Icons.inventory_2_outlined,
  ),
  ConnectorTemplate(
    connector: WorkflowConnector.gls,
    type: WorkflowNodeType.action,
    label: 'GLS: Courier pickup',
    description: 'Create parcel and schedule courier collection.',
    accent: ConnectorAccent.cyan,
    icon: Icons.local_shipping_outlined,
  ),
  ConnectorTemplate(
    connector: WorkflowConnector.instagram,
    type: WorkflowNodeType.trigger,
    label: 'Instagram: New DM',
    description: 'Classify incoming social message and map it to customer context.',
    accent: ConnectorAccent.purple,
    icon: Icons.camera_alt_outlined,
  ),
  ConnectorTemplate(
    connector: WorkflowConnector.agent,
    type: WorkflowNodeType.approval,
    label: 'AI Guardrail: Human approval',
    description: 'Pause on risky operations like refunds or accounting changes.',
    accent: ConnectorAccent.amber,
    icon: Icons.smart_toy_outlined,
  ),
];
