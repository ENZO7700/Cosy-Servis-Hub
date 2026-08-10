import 'package:flutter/material.dart';

import '../../../core/ui/theme.dart';
import '../../../domain/autoops/domain.dart';
import '../data/autoops_integrations_repository.dart';

class AutoOpsIntegrationsScreen extends StatefulWidget {
  const AutoOpsIntegrationsScreen({super.key});

  @override
  State<AutoOpsIntegrationsScreen> createState() => _AutoOpsIntegrationsScreenState();
}

class _AutoOpsIntegrationsScreenState extends State<AutoOpsIntegrationsScreen> {
  final AutoOpsIntegrationsRepository _integrationsRepo = AutoOpsIntegrationsRepository();
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
                      'E-commerce & API Integrácie',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prepojenie e-shopov, účtovníctva, dopravy a sociálnych sietí s AutoOps AI',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Obnoviť stav'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Integrations Grid
            FutureBuilder<List<Integration>>(
              future: _integrationsRepo.list(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || _loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data!;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 1100
                        ? 3
                        : constraints.maxWidth > 700
                            ? 2
                            : 1;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: AppTheme.glassDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Row: Title & Connected/Health Badge
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  _buildHealthBadge(item.connected, item.health),
                                ],
                              ),

                              // Description
                              Text(
                                item.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),

                              // Stats (Actions/Month & Latency)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Akcie: ${item.monthlyActions}/mes.',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                  Text(
                                    'Odozva: ${item.latencyMs} ms',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),

                              // Action Button
                              SizedBox(
                                width: double.infinity,
                                child: item.connected
                                    ? OutlinedButton.icon(
                                        onPressed: null,
                                        icon: const Icon(Icons.check, size: 14, color: AppTheme.success),
                                        label: const Text(
                                          'Pripojené',
                                          style: TextStyle(color: AppTheme.success),
                                        ),
                                      )
                                    : ElevatedButton.icon(
                                        onPressed: () async {
                                          setState(() => _loading = true);
                                          await _integrationsRepo.connect(item.id);
                                          setState(() => _loading = false);
                                        },
                                        icon: const Icon(Icons.link, size: 14),
                                        label: const Text('Pripojiť integráciu'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
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

  Widget _buildHealthBadge(bool connected, IntegrationHealth health) {
    if (!connected) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(40),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'ODPOJENÉ',
          style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      );
    }

    Color color;
    switch (health) {
      case IntegrationHealth.healthy:
        color = AppTheme.success;
        break;
      case IntegrationHealth.degraded:
        color = AppTheme.warning;
        break;
      case IntegrationHealth.offline:
        color = AppTheme.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        health.value.toUpperCase(),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
