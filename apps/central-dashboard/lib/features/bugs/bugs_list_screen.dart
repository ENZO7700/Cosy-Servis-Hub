import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/database/data_provider.dart';
import '../../core/ui/theme.dart';
import '../../core/database/models.dart';
import '../../shared/widgets/badges.dart';
import './bug_detail_screen.dart';
import './bug_create_screen.dart';

class BugsListScreen extends StatefulWidget {
  const BugsListScreen({super.key});

  @override
  State<BugsListScreen> createState() => _BugsListScreenState();
}

class _BugsListScreenState extends State<BugsListScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _selectedSeverity = 'all';

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);

    if (dataProvider.loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final filteredBugs = dataProvider.filteredBugs.where((bug) {
      final matchesSearch =
          bug.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          bug.trackingId.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus =
          _selectedStatus == 'all' || bug.status == _selectedStatus;
      final matchesSeverity =
          _selectedSeverity == 'all' || bug.severity == _selectedSeverity;

      return matchesSearch && matchesStatus && matchesSeverity;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Filter Bar Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0x0AFFFFFF),
              border: Border(bottom: BorderSide(color: Color(0x15FFFFFF))),
            ),
            child: Column(
              children: [
                // Search Input & Action Button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 38,
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
                                  hintText:
                                      'Vyhľadať chybu podľa názvu alebo ID...',
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
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(LucideIcons.plus, size: 14),
                      label: const Text(
                        'Nahlásiť',
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
                const SizedBox(height: 12),

                // Horizontal Filters row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Status filters
                      const Text(
                        'Stav: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        'Všetky',
                        'all',
                        _selectedStatus,
                        (val) => setState(() => _selectedStatus = val),
                      ),
                      ...AppTheme.statusLabels.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _buildFilterChip(
                            e.value,
                            e.key,
                            _selectedStatus,
                            (val) => setState(() => _selectedStatus = val),
                          ),
                        );
                      }),

                      const SizedBox(width: 16),
                      const Text(
                        '|',
                        style: TextStyle(color: Color(0x15FFFFFF)),
                      ),
                      const SizedBox(width: 16),

                      // Severity filters
                      const Text(
                        'Priorita: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        'Všetky',
                        'all',
                        _selectedSeverity,
                        (val) => setState(() => _selectedSeverity = val),
                      ),
                      ...AppTheme.severityLabels.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _buildFilterChip(
                            e.value,
                            e.key,
                            _selectedSeverity,
                            (val) => setState(() => _selectedSeverity = val),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bug list results
          Expanded(
            child: filteredBugs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.smile,
                          size: 40,
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nenašli sa žiadne nahlásené chyby',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: filteredBugs.length,
                    itemBuilder: (context, index) {
                      final bug = filteredBugs[index];
                      final pName = dataProvider.projects
                          .firstWhere(
                            (p) => p.id == bug.projectId,
                            orElse: () => Project(
                              id: '',
                              name: 'Bez projektu',
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ),
                          )
                          .name;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: AppTheme.glassDecoration(),
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
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      bug.trackingId,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontFamily: 'monospace',
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      pName,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  bug.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  bug.description,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    StatusBadge(status: bug.status),
                                    const SizedBox(width: 8),
                                    SeverityBadge(severity: bug.severity),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String selectedValue,
    Function(String) onSelected,
  ) {
    final isSelected = value == selectedValue;
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.2)
              : const Color(0x08FFFFFF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.5)
                : const Color(0x10FFFFFF),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
