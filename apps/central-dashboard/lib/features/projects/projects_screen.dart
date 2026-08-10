import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/database/data_provider.dart';
import '../../core/ui/theme.dart';
import '../../core/config/config.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final projects = dataProvider.projects;
    final bugs = dataProvider.bugs;

    if (dataProvider.loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Projekty', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            const Text(
              'Zoznam všetkých monitorovaných softvérových projektov a ich aktuálny stav.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 24),

            if (AppConfig.wordpressPublicSiteUrl.isNotEmpty) ...[
              // WordPress Integration banner
              Container(
                decoration: AppTheme.glassDecoration(
                  bgColor: AppTheme.primary.withValues(alpha: 0.05),
                  borderColor: AppTheme.primary.withValues(alpha: 0.2),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.globe,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WordPress Integrácia aktívna',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            'Verejný portál: ${AppConfig.wordpressPublicSiteUrl}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            projects.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(32),
                    decoration: AppTheme.glassDecoration(),
                    child: const Center(
                      child: Text(
                        'Neboli nájdené žiadne projekty.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth < 600
                          ? 1
                          : (constraints.maxWidth < 1000 ? 2 : 3);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.6,
                        ),
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          final projectBugs = bugs
                              .where((b) => b.projectId == project.id)
                              .toList();
                          final totalBugs = projectBugs.length;
                          final openBugs = projectBugs
                              .where(
                                (b) =>
                                    b.status != 'resolved' &&
                                    b.status != 'closed',
                              )
                              .length;
                          final criticalBugs = projectBugs
                              .where((b) => b.severity == 'critical')
                              .length;

                          return Container(
                            decoration: AppTheme.glassDecoration(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.primary
                                          .withValues(alpha: 0.1),
                                      child: const Icon(
                                        LucideIcons.folder,
                                        color: AppTheme.primary,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        project.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Text(
                                    project.description ??
                                        'Bez dodatočného popisu.',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Divider(
                                  color: Color(0x10FFFFFF),
                                  height: 20,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildStatItem(
                                      'Chyby celkovo',
                                      '$totalBugs',
                                    ),
                                    _buildStatItem(
                                      'Aktívne chyby',
                                      '$openBugs',
                                      color: openBugs > 0
                                          ? AppTheme.warning
                                          : AppTheme.textSecondary,
                                    ),
                                    _buildStatItem(
                                      'Kritické',
                                      '$criticalBugs',
                                      color: criticalBugs > 0
                                          ? AppTheme.error
                                          : AppTheme.textSecondary,
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

  Widget _buildStatItem(
    String label,
    String value, {
    Color color = AppTheme.textSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
