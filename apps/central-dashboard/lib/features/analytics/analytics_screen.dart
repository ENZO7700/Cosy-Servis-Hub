import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/database/data_provider.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/responsive.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final bugs = dataProvider.bugs;
    final projects = dataProvider.projects;

    if (dataProvider.loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Calculations
    final totalCount = bugs.length;
    final resolvedCount = bugs
        .where((b) => b.status == 'resolved' || b.status == 'closed')
        .length;
    final openCount = totalCount - resolvedCount;
    final criticalCount = bugs.where((b) => b.severity == 'critical').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytika & Štatistiky',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Podrobná analýza vývoja nahlásených chýb, priorít a stavov.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // Top Stats Summary
            _buildStatsRow(totalCount, openCount, resolvedCount, criticalCount),
            const SizedBox(height: 24),

            // Responsive Charts Grid
            Responsive(
              mobile: Column(
                children: [
                  _buildStatusChart(bugs),
                  const SizedBox(height: 16),
                  _buildSeverityChart(bugs),
                ],
              ),
              desktop: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildStatusChart(bugs)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSeverityChart(bugs)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Project Breakdown Card
            _buildProjectBreakdownCard(bugs, projects),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(int total, int open, int resolved, int critical) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth < 600 ? 2 : 4;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cols,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _buildStatCard(
              'Nahlásené chyby',
              '$total',
              LucideIcons.bug,
              AppTheme.textPrimary,
            ),
            _buildStatCard(
              'Aktívne / Nedoriešené',
              '$open',
              LucideIcons.activity,
              AppTheme.warning,
            ),
            _buildStatCard(
              'Vyriešené celkovo',
              '$resolved',
              LucideIcons.checkCircle,
              AppTheme.success,
            ),
            _buildStatCard(
              'Kritické incidenty',
              '$critical',
              LucideIcons.alertTriangle,
              AppTheme.error,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color) {
    return Container(
      decoration: AppTheme.glassDecoration(),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.08),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  val,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChart(List<dynamic> bugs) {
    final counts = <String, double>{};
    for (var bug in bugs) {
      counts[bug.status] = (counts[bug.status] ?? 0.0) + 1.0;
    }

    final barGroups = <BarChartGroupData>[];
    int index = 0;
    AppTheme.statusLabels.forEach((statusKey, label) {
      final val = counts[statusKey] ?? 0.0;
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: val,
              color: AppTheme.statusColors[statusKey] ?? Colors.grey,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
      index++;
    });

    return Container(
      height: 280,
      decoration: AppTheme.glassDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workflow Distribúcia',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Počet chýb v jednotlivých fázach riešenia.',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        final keys = AppTheme.statusLabels.values.toList();
                        if (val.toInt() < 0 || val.toInt() >= keys.length) {
                          return const Text('');
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            keys[val.toInt()],
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityChart(List<dynamic> bugs) {
    final counts = <String, double>{};
    for (var bug in bugs) {
      counts[bug.severity] = (counts[bug.severity] ?? 0.0) + 1.0;
    }

    final sections = <PieChartSectionData>[];
    AppTheme.severityLabels.forEach((sevKey, label) {
      final val = counts[sevKey] ?? 0.0;
      if (val > 0) {
        sections.add(
          PieChartSectionData(
            color: AppTheme.severityColors[sevKey] ?? Colors.grey,
            value: val,
            title: '${val.toInt()}',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    });

    return Container(
      height: 280,
      decoration: AppTheme.glassDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Incidenty podľa Závažnosti',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Rozdelenie nahlásených chýb podľa priority dopadu.',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: sections.isEmpty
                ? const Center(
                    child: Text(
                      'Žiadne dáta na zobrazenie',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 50,
                      sections: sections,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectBreakdownCard(
    List<dynamic> bugs,
    List<dynamic> projects,
  ) {
    return Container(
      decoration: AppTheme.glassDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chybovosť podľa Projektov',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: projects.length,
            itemBuilder: (context, i) {
              final proj = projects[i];
              final projBugs = bugs
                  .where((b) => b.projectId == proj.id)
                  .toList();
              final total = projBugs.length;
              final open = projBugs
                  .where((b) => b.status != 'resolved' && b.status != 'closed')
                  .length;
              final ratio = total == 0 ? 0.0 : (open / total);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          proj.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Aktívne: $open z $total',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: const Color(0x10FFFFFF),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ratio > 0.5 ? AppTheme.error : AppTheme.warning,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
