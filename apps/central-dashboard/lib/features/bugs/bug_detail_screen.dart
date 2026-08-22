import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/database/data_provider.dart';
import '../../core/network/supabase_service.dart';
import '../../core/database/models.dart';
import '../../core/ui/theme.dart';
import '../../shared/widgets/badges.dart';

class BugDetailScreen extends StatefulWidget {
  final String bugId;
  const BugDetailScreen({super.key, required this.bugId});

  @override
  State<BugDetailScreen> createState() => _BugDetailScreenState();
}

class _BugDetailScreenState extends State<BugDetailScreen> {
  final SupabaseService _supabase = SupabaseService();
  bool _updatingStatus = false;
  bool _updatingSeverity = false;

  @override
  Widget build(BuildContext context) {
    final dataProvider = Provider.of<DataProvider>(context);
    final bug = dataProvider.bugs.firstWhere(
      (b) => b.id == widget.bugId,
      orElse: () => Bug(
        id: '',
        trackingId: 'UNKNOWN',
        title: 'Chyba nenájdená',
        description: 'Chyba s týmto ID nebola v databáze nájdená.',
        reporterId: '',
        severity: 'low',
        status: 'new',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (bug.id.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text(
            'Chyba nebola nájdená',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    final project = dataProvider.projects.firstWhere(
      (p) => p.id == bug.projectId,
      orElse: () => Project(
        id: '',
        name: 'Žiadny projekt',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final df = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          bug.trackingId,
          style: const TextStyle(
            fontSize: 14,
            fontFamily: 'monospace',
            color: AppTheme.textSecondary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
            Text(
              bug.title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // BADGES and metadata row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBadge(status: bug.status),
                SeverityBadge(severity: bug.severity),
                if (project.id.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x0EFFFFFF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0x15FFFFFF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.folder,
                          size: 10,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Grid for dropdown changes and core stats
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return Container(
                  decoration: AppTheme.glassDecoration(),
                  padding: const EdgeInsets.all(16),
                  child: isWide
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: _buildQuickControls(bug, dataProvider),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildQuickControls(
                            bug,
                            dataProvider,
                            isVertical: true,
                          ),
                        ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Main details block
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description Card
                      _buildSectionHeader('Popis problému'),
                      _buildGlassCard(
                        child: Text(
                          bug.description,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reproduction Card if any
                      if (bug.stepsToReproduce != null &&
                          bug.stepsToReproduce!.isNotEmpty) ...[
                        _buildSectionHeader('Kroky na reprodukciu'),
                        _buildGlassCard(
                          child: Text(
                            bug.stepsToReproduce!,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Expected vs Actual Behaviour if any
                      if ((bug.expectedBehavior != null &&
                              bug.expectedBehavior!.isNotEmpty) ||
                          (bug.actualBehavior != null &&
                              bug.actualBehavior!.isNotEmpty)) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (bug.expectedBehavior != null &&
                                bug.expectedBehavior!.isNotEmpty)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader('Očakávané správanie'),
                                    _buildGlassCard(
                                      child: Text(
                                        bug.expectedBehavior!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (bug.expectedBehavior != null &&
                                bug.expectedBehavior!.isNotEmpty &&
                                bug.actualBehavior != null &&
                                bug.actualBehavior!.isNotEmpty)
                              const SizedBox(width: 16),
                            if (bug.actualBehavior != null &&
                                bug.actualBehavior!.isNotEmpty)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader('Skutočné správanie'),
                                    _buildGlassCard(
                                      child: Text(
                                        bug.actualBehavior!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Metadata card (Reporter, dates, environment)
            _buildSectionHeader('Detaily a Audit log'),
            Container(
              decoration: AppTheme.glassDecoration(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDetailRow(
                    'Nahlásil/a',
                    FutureBuilder<Profile?>(
                      future: _supabase.getProfile(bug.reporterId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Text(
                            'Načítava sa...',
                            style: TextStyle(fontSize: 12),
                          );
                        }
                        final name =
                            snapshot.data?.fullName ?? 'Neznámy používateľ';
                        return Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(color: Color(0x10FFFFFF), height: 24),
                  _buildDetailRow(
                    'Priradený vývojár',
                    bug.assigneeId == null || bug.assigneeId!.isEmpty
                        ? const Text(
                            'Nepriradené',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          )
                        : FutureBuilder<Profile?>(
                            future: _supabase.getProfile(bug.assigneeId!),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Text(
                                  'Načítava sa...',
                                  style: TextStyle(fontSize: 12),
                                );
                              }
                              final name =
                                  snapshot.data?.fullName ?? 'Neznámy vývojár';
                              return Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(color: Color(0x10FFFFFF), height: 24),
                  _buildDetailRow(
                    'Dátum nahlásenia',
                    Text(
                      df.format(bug.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const Divider(color: Color(0x10FFFFFF), height: 24),
                  _buildDetailRow(
                    'Posledná úprava',
                    Text(
                      df.format(bug.updatedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (bug.environment != null &&
                      bug.environment!.isNotEmpty) ...[
                    const Divider(color: Color(0x10FFFFFF), height: 24),
                    _buildDetailRow(
                      'Prostredie',
                      Text(
                        bug.environment!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 2.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.glassDecoration(),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _buildDetailRow(String label, Widget valueWidget) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        valueWidget,
      ],
    );
  }

  List<Widget> _buildQuickControls(
    Bug bug,
    DataProvider provider, {
    bool isVertical = false,
  }) {
    final List<Widget> controls = [
      // Status update dropdown
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zmeniť stav',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 160,
            height: 36,
            child: _updatingStatus
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      initialValue: bug.status,
                      dropdownColor: const Color(0xFF1E1E22),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0x15FFFFFF)),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      items: AppTheme.statusLabels.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(
                            e.value,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val != null && val != bug.status) {
                          setState(() => _updatingStatus = true);
                          await provider.updateBugStatus(bug.id, val);
                          setState(() => _updatingStatus = false);
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
      if (isVertical) const SizedBox(height: 16) else const SizedBox(width: 24),
      // Severity update dropdown
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Zmeniť závažnosť',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 160,
            height: 36,
            child: _updatingSeverity
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      initialValue: bug.severity,
                      dropdownColor: const Color(0xFF1E1E22),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 0,
                        ),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0x15FFFFFF)),
                        ),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      items: AppTheme.severityLabels.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(
                            e.value,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) async {
                        if (val != null && val != bug.severity) {
                          setState(() => _updatingSeverity = true);
                          await provider.updateBugSeverity(bug.id, val);
                          setState(() => _updatingSeverity = false);
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
    ];
    return controls;
  }
}
