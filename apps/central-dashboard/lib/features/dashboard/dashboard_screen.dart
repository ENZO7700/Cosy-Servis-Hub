import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/database/data_provider.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/responsive.dart';
import '../../core/database/models.dart';
import '../../shared/widgets/badges.dart';
import '../bugs/bug_create_screen.dart';
import '../bugs/bug_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _searchQuery = '';
  String _viewMode = 'table'; // table or kanban

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);

    if (dataProvider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredBugs = dataProvider.filteredBugs.where((bug) {
      final matchesSearch =
          bug.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          bug.trackingId.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    // Stats calculations
    final totalCount = filteredBugs.length;
    final criticalCount = filteredBugs
        .where((b) => b.severity == 'critical')
        .length;
    final openCount = filteredBugs
        .where((b) => b.status != 'resolved' && b.status != 'closed')
        .length;
    final resolvedCount = filteredBugs
        .where((b) => b.status == 'resolved' || b.status == 'closed')
        .length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0x0AFFFFFF),
              border: Border(bottom: BorderSide(color: Color(0x15FFFFFF))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prehľad',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Rýchly prehľad projektov a chýb',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: const Text(
                    'Nahlásiť chybu',
                    style: TextStyle(fontSize: 12),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BugCreateScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  _buildStatsRow(
                    totalCount,
                    criticalCount,
                    openCount,
                    resolvedCount,
                  ),
                  const SizedBox(height: 24),

                  // Balíčky Zdravia (Health & Service Packages - Minimum 8)
                  _buildHealthPackagesSection(context),
                  const SizedBox(height: 24),

                  // Projects Selector
                  const Text(
                    'Projekty',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildProjectsSelector(dataProvider),
                  const SizedBox(height: 24),

                  // Charts Row
                  Responsive(
                    mobile: Column(
                      children: [
                        _buildStatusChartCard(filteredBugs),
                        const SizedBox(height: 16),
                        _buildSeverityChartCard(filteredBugs),
                      ],
                    ),
                    desktop: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildStatusChartCard(filteredBugs)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSeverityChartCard(filteredBugs)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Search and View switch
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0x0AFFFFFF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0x15FFFFFF)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(
                                LucideIcons.search,
                                size: 16,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textPrimary,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Hľadať chyby...',
                                    hintStyle: TextStyle(
                                      color: Color(0x44FFFFFF),
                                      fontSize: 12,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0x0AFFFFFF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x15FFFFFF)),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          children: [
                            _buildViewModeButton('table', LucideIcons.list),
                            _buildViewModeButton(
                              'kanban',
                              LucideIcons.layoutGrid,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Bugs table/list or kanban
                  _viewMode == 'table'
                      ? _buildBugsTableView(filteredBugs)
                      : _buildBugsKanbanView(filteredBugs, dataProvider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(String mode, IconData icon) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x15FFFFFF)),
              )
            : null,
        child: Icon(
          icon,
          size: 14,
          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStatsRow(int total, int critical, int open, int resolved) {
    final stats = [
      {
        'label': 'Všetky chyby',
        'value': '$total',
        'color': AppTheme.textPrimary,
      },
      {'label': 'Kritické', 'value': '$critical', 'color': AppTheme.error},
      {'label': 'Otvorené', 'value': '$open', 'color': AppTheme.warning},
      {'label': 'Vyriešené', 'value': '$resolved', 'color': AppTheme.success},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: constraints.maxWidth < 600 ? 1.6 : 1.7,
          ),
          itemCount: stats.length,
          itemBuilder: (context, i) {
            return Container(
              decoration: AppTheme.glassDecoration(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stats[i]['label'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stats[i]['value'] as String,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: stats[i]['color'] as Color,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProjectsSelector(DataProvider provider) {
    final projects = provider.projects;
    final bugs = provider.bugs;

    // Build the "All Projects" and "Unassigned" options
    final projectCards = [
      {
        'id': '__all_projects__',
        'name': 'Všetky projekty',
        'description': 'Celkový prehľad naprieč projektmi.',
        'total': bugs.length,
        'open': bugs
            .where((b) => b.status != 'resolved' && b.status != 'closed')
            .length,
        'critical': bugs.where((b) => b.severity == 'critical').length,
      },
      ...projects.map((p) {
        final pBugs = bugs.where((b) => b.projectId == p.id).toList();
        return {
          'id': p.id,
          'name': p.name,
          'description': p.description ?? 'Bez popisu.',
          'total': pBugs.length,
          'open': pBugs
              .where((b) => b.status != 'resolved' && b.status != 'closed')
              .length,
          'critical': pBugs.where((b) => b.severity == 'critical').length,
        };
      }),
    ];

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: projectCards.length,
        itemBuilder: (context, index) {
          final p = projectCards[index];
          final isSelected = provider.selectedProjectId == p['id'];

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => provider.selectProject(p['id'] as String),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 250,
                decoration: isSelected
                    ? AppTheme.activeGlassDecoration()
                    : AppTheme.glassDecoration(),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            p['name'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x0EFFFFFF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${p['total']}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p['description'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Otvorené: ${p['open']}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Kritické: ${p['critical']}',
                            style: TextStyle(
                              fontSize: 10,
                              color: (p['critical'] as int) > 0
                                  ? AppTheme.error
                                  : AppTheme.textSecondary,
                              fontWeight: (p['critical'] as int) > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChartCard(List<Bug> bugs) {
    // Group bugs by status
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
              width: 14,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
      index++;
    });

    return Container(
      height: 240,
      decoration: AppTheme.glassDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chyby podľa stavu',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Rozdelenie podľa krokov workflow',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(enabled: true),
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

  Widget _buildSeverityChartCard(List<Bug> bugs) {
    // Group bugs by severity
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
            radius: 40,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    });

    return Container(
      height: 240,
      decoration: AppTheme.glassDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rozdelenie podľa závažnosti',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Prehľad podľa úrovne závažnosti',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: sections.isEmpty
                ? const Center(
                    child: Text(
                      'Žiadne dáta',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: sections,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBugsTableView(List<Bug> bugs) {
    if (bugs.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: AppTheme.glassDecoration(),
        child: const Center(
          child: Text(
            'Nenašli sa žiadne chyby',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Responsive(
      mobile: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: bugs.length,
        itemBuilder: (context, i) {
          final bug = bugs[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                bug.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Row(
                  children: [
                    StatusBadge(status: bug.status),
                    const SizedBox(width: 8),
                    SeverityBadge(severity: bug.severity),
                  ],
                ),
              ),
              trailing: Text(
                bug.trackingId,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: AppTheme.textSecondary,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BugDetailScreen(bugId: bug.id),
                  ),
                );
              },
            ),
          );
        },
      ),
      desktop: Container(
        width: double.infinity,
        decoration: AppTheme.glassDecoration(),
        child: Theme(
          data: Theme.of(
            context,
          ).copyWith(dividerColor: const Color(0x15FFFFFF)),
          child: DataTable(
            showCheckboxColumn: false,
            columns: const [
              DataColumn(
                label: Text(
                  'ID',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              DataColumn(
                label: Text(
                  'Názov',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              DataColumn(
                label: Text(
                  'Stav',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
              DataColumn(
                label: Text(
                  'Priorita',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ],
            rows: bugs.map((bug) {
              return DataRow(
                onSelectChanged: (selected) {
                  if (selected == true) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BugDetailScreen(bugId: bug.id),
                      ),
                    );
                  }
                },
                cells: [
                  DataCell(
                    Text(
                      bug.trackingId,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      bug.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(StatusBadge(status: bug.status)),
                  DataCell(SeverityBadge(severity: bug.severity)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBugsKanbanView(List<Bug> bugs, DataProvider provider) {
    final List<String> columns = [
      'new',
      'assigned',
      'in_progress',
      'testing',
      'resolved',
      'closed',
    ];

    return SizedBox(
      height: 400,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: columns.length,
        itemBuilder: (context, index) {
          final colStatus = columns[index];
          final colBugs = bugs.where((b) => b.status == colStatus).toList();

          return Container(
            width: 250,
            margin: const EdgeInsets.only(right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatusBadge(status: colStatus),
                    Text(
                      '${colBugs.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Kanban card list
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x05FFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x08FFFFFF)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: colBugs.isEmpty
                        ? const Center(
                            child: Text(
                              'Žiadne chyby',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: colBugs.length,
                            itemBuilder: (context, i) {
                              final bug = colBugs[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            BugDetailScreen(bugId: bug.id),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bug.trackingId,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          bug.title,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 10),
                                        SeverityBadge(severity: bug.severity),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHealthPackagesSection(BuildContext context) {
    final packages = [
      {
        'id': 'pkg-1',
        'title': 'Dentálny Balíček Premium',
        'subtitle': 'Stomatológia & Dentálna Hygiena',
        'icon': LucideIcons.sparkles,
        'badge': 'Najobľúbenejší',
        'color': const Color(0xFF00E5FF),
        'features': [
          'Online rezervačný kalendár pacientov',
          'SMS & E-mail pripomienkovač preventívok',
          'GDPR Anamnéza & Digitálny podpis',
        ],
        'leadsCount': '19+ kliník',
      },
      {
        'id': 'pkg-2',
        'title': 'Estetická Medicína & Skin',
        'subtitle': 'Dermatológia & Klientská Zóna',
        'icon': LucideIcons.heart,
        'badge': 'Vysoká Marža',
        'color': const Color(0xFFFF4081),
        'features': [
          'Fotodokumentácia zákrokov pred/po',
          'VIP klientsky portal & Konzultácie',
          'Automatické zľavové balíčky',
        ],
        'leadsCount': '12+ kliník',
      },
      {
        'id': 'pkg-3',
        'title': 'Fyzioterapia & Rehabilitácia',
        'subtitle': 'Pohybové Centrum & Physio',
        'icon': LucideIcons.activity,
        'badge': 'Rastúci Sektor',
        'color': const Color(0xFF69F0AE),
        'features': [
          'Plán cvičení & Video návody pre pacienta',
          'Online vstupná diagnostika',
          'Predplatné balíčky terapií',
        ],
        'leadsCount': '15+ centier',
      },
      {
        'id': 'pkg-4',
        'title': 'Veterinárna Starostlivosť',
        'subtitle': 'Vet Kliniky & Grooming Spa',
        'icon': LucideIcons.shieldCheck,
        'badge': '24/7 Emergency',
        'color': const Color(0xFFFFAB40),
        'features': [
          'Digitálny zdravotný preukaz zvierat',
          'Pripomienky očkovaní & odčervenia',
          'Urgentný príjem & PWA dispatching',
        ],
        'leadsCount': '8+ veterinárov',
      },
      {
        'id': 'pkg-5',
        'title': 'Boutique Fitness & Wellness',
        'subtitle': 'Pilates, Gyms & Recovery',
        'icon': LucideIcons.dumbbell,
        'badge': 'Franchise Ready',
        'color': const Color(0xFFE040FB),
        'features': [
          'Kreditové & Členské PWA lístky',
          'Automatický vstupný QR kód',
          'Sledovanie kapacity lekcií v reálnom čase',
        ],
        'leadsCount': '22+ gymov',
      },
      {
        'id': 'pkg-6',
        'title': '24/7 Havarijná Služba & Dispatch',
        'subtitle': 'Inštalatéri, Elektrikári & HVAC',
        'icon': LucideIcons.siren,
        'badge': 'High Priority',
        'color': const Color(0xFFFF5252),
        'features': [
          'Okamžitý výjazdový dispatching',
          'GPS sledovanie technika na mape',
          'SLA reporting & Automatická fakturácia',
        ],
        'leadsCount': '10+ fariem',
      },
      {
        'id': 'pkg-7',
        'title': 'Pohrebné Služby & Dignity',
        'subtitle': 'Pohrebníctvo & Digital Intake',
        'icon': LucideIcons.heartHandshake,
        'badge': 'Tier 1 Ziskovosť',
        'color': const Color(0xFFB0BEC5),
        'features': [
          'Citlivý online výber pietnych služieb',
          'Rodinný prehľad vybavovania v PWA',
          'Automatizácia dokumentácie',
        ],
        'leadsCount': '6+ skupín',
      },
      {
        'id': 'pkg-8',
        'title': 'Premium Transport & Fleet',
        'subtitle': 'Private Hire & Chauffeur Fleet',
        'icon': LucideIcons.car,
        'badge': 'Scale Ready',
        'color': const Color(0xFFFFD740),
        'features': [
          'PWA rezervácia transferov & VIP flotíl',
          'Sledovanie vodičov v reálnom čase',
          'Partnering API pre hotely a firmy',
        ],
        'leadsCount': '14+ operátorov',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    LucideIcons.packageCheck,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balíčky Zdravia & Služieb (8 Balíčkov)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Špecializované PWA riešenia pripravené na nasadenie pre leady',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Text(
                '8/8 Aktívnych',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final isMedium = constraints.maxWidth > 600;
            final crossAxisCount = isWide ? 4 : (isMedium ? 2 : 1);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: packages.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: isWide ? 1.15 : (isMedium ? 1.3 : 1.5),
              ),
              itemBuilder: (context, index) {
                final pkg = packages[index];
                final Color color = pkg['color'] as Color;
                final List<String> features = pkg['features'] as List<String>;

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0x0AFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              pkg['icon'] as IconData,
                              color: color,
                              size: 18,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              pkg['badge'] as String,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        pkg['title'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        pkg['subtitle'] as String,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: features
                              .map(
                                (f) => Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        LucideIcons.check,
                                        size: 10,
                                        color: color,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          f,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xCCFFFFFF),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const Divider(color: Color(0x10FFFFFF), height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Lead cieľ: ${pkg['leadsCount']}',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Aktivovaný ${pkg['title']} pre outreach.',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Text(
                                  'Aktivovať',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  LucideIcons.arrowRight,
                                  size: 10,
                                  color: color,
                                ),
                              ],
                            ),
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
    );
  }
}
