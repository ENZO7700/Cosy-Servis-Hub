import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ui/theme.dart';
import '../../../domain/autoops/domain.dart';
import '../data/autoops_dashboard_repository.dart';
import '../providers/autoops_providers.dart';

class AutoOpsDashboardScreen extends StatefulWidget {
  const AutoOpsDashboardScreen({super.key});

  @override
  State<AutoOpsDashboardScreen> createState() => _AutoOpsDashboardScreenState();
}

class _AutoOpsDashboardScreenState extends State<AutoOpsDashboardScreen> {
  final AutoOpsDashboardRepository _dashboardRepo = const AutoOpsDashboardRepository();

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
                      'AutoOps AI Control Center',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Autonómna správa e-commerce operácií a workflow zákaziek',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                // Agent Mode Selector using Provider
                Consumer<AutoOpsAppUiProvider>(
                  builder: (context, uiProvider, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: AppTheme.glassDecoration(),
                      child: DropdownButton<AgentMode>(
                        value: uiProvider.agentMode,
                        dropdownColor: const Color(0xFF121212),
                        underline: const SizedBox(),
                        items: AgentMode.values.map((mode) {
                          return DropdownMenuItem(
                            value: mode,
                            child: Text(
                              mode.value.toUpperCase(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                        onChanged: (newMode) {
                          if (newMode != null) {
                            uiProvider.setAgentMode(newMode);
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Async Dashboard Data
            FutureBuilder<DashboardStats>(
              future: _dashboardRepo.stats(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final stats = snapshot.data!;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 900;
                    return GridView.count(
                      crossAxisCount: isDesktop ? 4 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: isDesktop ? 1.8 : 1.4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStatCard(
                          context,
                          title: 'Ušetrené hodiny dnes',
                          value: '${stats.savedHoursToday}h',
                          subtitle: 'Tento týždeň: ${stats.savedHoursWeek}h',
                          icon: Icons.timer_outlined,
                          color: AppTheme.primary,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Spracované objednávky',
                          value: '${stats.ordersProcessed}',
                          subtitle: 'Faktúry: ${stats.invoicesSent}',
                          icon: Icons.shopping_bag_outlined,
                          color: AppTheme.success,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Priemerná istota AI',
                          value: '${stats.avgConfidence}%',
                          subtitle: 'Emaily: ${stats.emailsAnswered}',
                          icon: Icons.auto_awesome,
                          color: AppTheme.info,
                        ),
                        _buildStatCard(
                          context,
                          title: 'Ušetrené náklady dnes',
                          value: '${stats.costSavedToday} €',
                          subtitle: 'Rizikové udalosti: ${stats.riskEvents}',
                          icon: Icons.euro_symbol,
                          color: AppTheme.warning,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),

            // Agent Status & Activity Feed Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Agent Status Card
                Expanded(
                  flex: 1,
                  child: FutureBuilder<AgentStatus>(
                    future: _dashboardRepo.agentStatus(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final status = snapshot.data!;
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.glassDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.psychology, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'Status Autonómneho Agenta',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text('Aktuálna úloha:', style: Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text(
                              status.currentTask,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Uptime: ${status.uptimePercent}%'),
                                Text('Queue depth: ${status.queueDepth}'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Bezpečnostné pravidlá (Guardrails):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            ...status.guardrails.map(
                              (g) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.shield_outlined, size: 14, color: AppTheme.success),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        g,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Recent Activity Feed
                Expanded(
                  flex: 1,
                  child: FutureBuilder<List<ActivityItem>>(
                    future: _dashboardRepo.activity(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final feed = snapshot.data!;
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: AppTheme.glassDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.history, color: AppTheme.info),
                                const SizedBox(width: 8),
                                Text(
                                  'Posledná AI aktivita',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: feed.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = feed[index];
                                return Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.cardBg,
                                      child: Icon(
                                        _getActivityIcon(item.type),
                                        size: 16,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            item.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${item.confidence.toInt()}%',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.email:
        return Icons.email_outlined;
      case ActivityType.invoice:
        return Icons.receipt_long_outlined;
      case ActivityType.shipping:
        return Icons.local_shipping_outlined;
      case ActivityType.order:
        return Icons.shopping_bag_outlined;
      case ActivityType.workflow:
        return Icons.account_tree_outlined;
      case ActivityType.risk:
        return Icons.warning_amber_outlined;
    }
  }
}
