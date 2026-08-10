import 'package:flutter/material.dart';

import '../../../core/ui/theme.dart';
import '../../../domain/autoops/domain.dart';
import '../data/autoops_analytics_repository.dart';

class AutoOpsAnalyticsScreen extends StatefulWidget {
  const AutoOpsAnalyticsScreen({super.key});

  @override
  State<AutoOpsAnalyticsScreen> createState() => _AutoOpsAnalyticsScreenState();
}

class _AutoOpsAnalyticsScreenState extends State<AutoOpsAnalyticsScreen> {
  final AutoOpsAnalyticsRepository _analyticsRepo = const AutoOpsAnalyticsRepository();

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
                      'AI Analytika & Návratnosť (ROI)',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kvantitatívne vyhodnotenie ušetreného času, nákladov a presnosti autonómneho agenta',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Obnoviť dáta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Analytics Data Table / Cards
            FutureBuilder<List<AnalyticsPoint>>(
              future: _analyticsRepo.points(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final points = snapshot.data!;
                final totalHours = points.fold<double>(0, (sum, p) => sum + p.savedHours);
                final totalCost = points.fold<double>(0, (sum, p) => sum + p.costSaved);
                final avgAccuracy = points.fold<double>(0, (sum, p) => sum + p.accuracy) / points.length;

                return Column(
                  children: [
                    // Summary Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: 'Celkovo ušetrený čas',
                            value: '${totalHours.toStringAsFixed(1)} hodín',
                            icon: Icons.access_time_filled,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: 'Celkovo ušetrené náklady',
                            value: '${totalCost.toStringAsFixed(0)} €',
                            icon: Icons.payments,
                            color: AppTheme.success,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: 'Priemerná presnosť AI',
                            value: '${avgAccuracy.toStringAsFixed(1)} %',
                            icon: Icons.verified,
                            color: AppTheme.info,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Daily Points List
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.glassDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.show_chart, color: AppTheme.primary),
                              SizedBox(width: 8),
                              Text(
                                'Denný prehľad výkonu (Posledných 14 dní)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: points.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final point = points[index];
                              return Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      point.date,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: point.accuracy / 100,
                                      backgroundColor: AppTheme.cardBg,
                                      color: AppTheme.primary,
                                      minHeight: 8,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '${point.savedHours.toStringAsFixed(1)}h | ${point.costSaved.toInt()}€ | ${point.accuracy.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withAlpha(40),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
