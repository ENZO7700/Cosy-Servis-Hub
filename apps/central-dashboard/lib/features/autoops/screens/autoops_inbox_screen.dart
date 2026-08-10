import 'package:flutter/material.dart';

import '../../../core/ui/theme.dart';
import '../../../domain/autoops/domain.dart';
import '../data/autoops_inbox_repository.dart';

class AutoOpsInboxScreen extends StatefulWidget {
  const AutoOpsInboxScreen({super.key});

  @override
  State<AutoOpsInboxScreen> createState() => _AutoOpsInboxScreenState();
}

class _AutoOpsInboxScreenState extends State<AutoOpsInboxScreen> {
  final AutoOpsInboxRepository _inboxRepo = AutoOpsInboxRepository();
  InboxCategory? _selectedCategory;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unifikovaný AI Inbox',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Centrálna správa e-mailov, správ a požiadaviek s AI návrhmi odpovedí',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Obnoviť'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Category Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterPill(label: 'Všetky', category: null),
                  _buildFilterPill(label: 'Doručenie', category: InboxCategory.shipping),
                  _buildFilterPill(label: 'Faktúry', category: InboxCategory.invoice),
                  _buildFilterPill(label: 'Leady', category: InboxCategory.lead),
                  _buildFilterPill(label: 'Reklamácie', category: InboxCategory.complaint),
                  _buildFilterPill(label: 'VIP', category: InboxCategory.vip),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Inbox List
            FutureBuilder<List<UnifiedInboxItem>>(
              future: _inboxRepo.list(_selectedCategory),
              builder: (context, snapshot) {
                if (!snapshot.hasData || _loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: AppTheme.glassDecoration(),
                    child: const Center(
                      child: Text('Žiadne správy v tejto kategórii.'),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.glassDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Sender & Source badge & Priority
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppTheme.cardBg,
                                    child: Icon(
                                      _getSourceIcon(item.source),
                                      size: 14,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.sender,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  _buildPriorityBadge(item.priority),
                                  const SizedBox(width: 8),
                                  _buildStatusBadge(item.status),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Subject & Preview
                          Text(
                            item.subject,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.preview,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),

                          // AI Draft Section (if available)
                          if (item.aiDraft != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0x1A6366F1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0x336366F1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary),
                                      SizedBox(width: 6),
                                      Text(
                                        'AI Návrh odpovede:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.aiDraft!,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (item.orderRef != null)
                                Chip(
                                  label: Text('Objednávka: ${item.orderRef}'),
                                  backgroundColor: AppTheme.cardBg,
                                  labelStyle: const TextStyle(fontSize: 11),
                                )
                              else
                                const SizedBox(),

                              if (item.status == InboxStatus.queued ||
                                  item.status == InboxStatus.needsHuman)
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    setState(() => _loading = true);
                                    await _inboxRepo.autoReply(item.id);
                                    setState(() => _loading = false);
                                  },
                                  icon: const Icon(Icons.send, size: 14),
                                  label: const Text('Odoslať AI odpoveď'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                )
                              else if (item.status == InboxStatus.autoReplied)
                                const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Odpovedané',
                                      style: TextStyle(color: AppTheme.success, fontSize: 12),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({required String label, required InboxCategory? category}) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _selectedCategory = category);
          }
        },
        selectedColor: AppTheme.primary,
        backgroundColor: AppTheme.cardBg,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(InboxPriority priority) {
    Color bg;
    switch (priority) {
      case InboxPriority.critical:
        bg = AppTheme.error;
        break;
      case InboxPriority.high:
        bg = AppTheme.warning;
        break;
      case InboxPriority.medium:
        bg = AppTheme.info;
        break;
      case InboxPriority.low:
        bg = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg.withAlpha(50),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: bg, width: 0.8),
      ),
      child: Text(
        priority.value.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bg),
      ),
    );
  }

  Widget _buildStatusBadge(InboxStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.value.replaceAll('_', ' ').toUpperCase(),
        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
      ),
    );
  }

  IconData _getSourceIcon(InboxSource source) {
    switch (source) {
      case InboxSource.gmail:
        return Icons.mail_outline;
      case InboxSource.shopify:
        return Icons.shopping_bag_outlined;
      case InboxSource.woocommerce:
        return Icons.storefront;
      case InboxSource.instagram:
        return Icons.camera_alt_outlined;
      case InboxSource.support:
        return Icons.support_agent;
    }
  }
}
