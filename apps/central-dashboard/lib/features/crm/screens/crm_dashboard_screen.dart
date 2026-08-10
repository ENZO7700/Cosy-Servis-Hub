import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/ui/theme.dart';
import '../models/crm_models.dart';
import '../models/crm_lead.dart';
import '../providers/crm_provider.dart';
import '../providers/lead_inbox_provider.dart';
import '../widgets/crm_client_card.dart';
import '../widgets/crm_project_window.dart';
import '../widgets/crm_detail_pane.dart';
import '../../leads/lead_card.dart';
import '../../leads/lead_detail_screen.dart';
import './crm_client_dialog.dart';

class CrmDashboardScreen extends StatefulWidget {
  final String? selectedClientId;

  const CrmDashboardScreen({super.key, this.selectedClientId});

  @override
  State<CrmDashboardScreen> createState() => _CrmDashboardScreenState();
}

class _CrmDashboardScreenState extends State<CrmDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'lead', 'active', 'inactive'
  String _leadFilter =
      'all'; // 'all', 'new', 'draft_ready', 'waiting', 'follow_up_due'
  CrmClient? _selectedClient;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<LeadInboxProvider?>()?.load();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final crmProvider = Provider.of<CrmProvider>(context);
    final leadProvider = Provider.of<LeadInboxProvider?>(context);

    final allClients = crmProvider.clients
        .where((c) => c.deletedAt == null)
        .toList();

    // Filtered clients list
    final filteredClients = allClients.where((c) {
      final query = _searchQuery.toLowerCase();
      final matchQuery =
          c.companyName.toLowerCase().contains(query) ||
          (c.contactName?.toLowerCase().contains(query) ?? false) ||
          (c.email?.toLowerCase().contains(query) ?? false);

      final matchStatus = _statusFilter == 'all' || c.status == _statusFilter;

      return matchQuery && matchStatus;
    }).toList();

    // Filtered leads list
    final allLeads = leadProvider?.leads ?? [];
    final filteredLeads = allLeads.where((l) {
      final query = _searchQuery.toLowerCase();
      final matchQuery =
          l.companyName.toLowerCase().contains(query) ||
          l.contactName.toLowerCase().contains(query) ||
          l.email.toLowerCase().contains(query) ||
          l.sector.toLowerCase().contains(query);

      final matchFilter =
          _leadFilter == 'all' || l.pipelineStatus == _leadFilter;

      return matchQuery && matchFilter;
    }).toList();

    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Section
          Expanded(
            flex: isLargeScreen ? 6 : 10,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, crmProvider, leadProvider),
                  const SizedBox(height: 16),
                  CrmProjectWindow(isLargeScreen: isLargeScreen),
                  const SizedBox(height: 20),
                  _buildTabs(),
                  const SizedBox(height: 16),
                  _buildSearchAndFilters(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: AI Leads from Reports
                        _buildLeadsView(leadProvider, filteredLeads),

                        // Tab 2: Existing CRM Clients
                        _buildClientsView(crmProvider, filteredClients),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Detail Pane View (For Desktop Client selection)
          if (isLargeScreen && _selectedClient != null)
            Expanded(
              flex: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0F0F12),
                  border: Border(
                    left: BorderSide(color: AppTheme.border, width: 1),
                  ),
                ),
                child: CrmDetailPane(
                  client: _selectedClient!,
                  onClose: () {
                    setState(() {
                      _selectedClient = null;
                    });
                  },
                  onEdit: () =>
                      _openEditClientDialog(_selectedClient!, crmProvider),
                  onDelete: () =>
                      _confirmDeleteClient(_selectedClient!, crmProvider),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    CrmProvider crmProvider,
    LeadInboxProvider? leadProvider,
  ) {
    final leadCount = leadProvider?.leads.length ?? 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CRM & AI Lead Pipeline',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Centralizovaná správa leadov ($leadCount leadov, ${crmProvider.clients.where((c) => c.deletedAt == null).length} klientov)',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          key: const Key('add_client_button'),
          onPressed: () => _openCreateClientDialog(crmProvider),
          icon: const Icon(LucideIcons.userPlus, size: 16),
          label: const Text('Pridať klienta'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 3,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(
            icon: Icon(LucideIcons.sparkles, size: 18),
            text: 'AI Leady z Reportov',
          ),
          Tab(icon: Icon(LucideIcons.users, size: 18), text: 'CRM Klienti'),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          key: const Key('crm_search_input'),
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Hľadať podľa názvu, emailu, sektoru alebo kontaktu...',
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
            prefixIcon: const Icon(
              LucideIcons.search,
              color: AppTheme.textSecondary,
              size: 18,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppTheme.textSecondary,
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'Všetky leady', isLeadFilter: true),
              const SizedBox(width: 8),
              _buildFilterChip(
                'new',
                'Nové',
                isLeadFilter: true,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'draft_ready',
                'Pripravené drafty',
                isLeadFilter: true,
                color: Colors.purple,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'waiting',
                'Čakajú na odpoveď',
                isLeadFilter: true,
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'follow_up_due',
                'Vyžadujú Follow-up',
                isLeadFilter: true,
                color: AppTheme.error,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    String filterVal,
    String label, {
    bool isLeadFilter = false,
    Color? color,
  }) {
    final isSelected = isLeadFilter
        ? _leadFilter == filterVal
        : _statusFilter == filterVal;

    return ChoiceChip(
      key: Key('filter_chip_${isLeadFilter ? "lead_" : ""}$filterVal'),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primary.withValues(alpha: 0.3),
      backgroundColor: Colors.white.withValues(alpha: 0.02),
      onSelected: (val) {
        if (val) {
          setState(() {
            if (isLeadFilter) {
              _leadFilter = filterVal;
            } else {
              _statusFilter = filterVal;
            }
          });
        }
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primary : AppTheme.border,
          width: 1,
        ),
      ),
    );
  }

  Widget _buildLeadsView(LeadInboxProvider? provider, List<CrmLead> leads) {
    if (provider != null && provider.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (leads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.sparkles,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _leadFilter != 'all'
                  ? 'Nenašli sa žiadne vyhovujúce leady'
                  : 'Žiadne leady v systéme',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: leads.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final lead = leads[index];
        return LeadCard(
          lead: lead,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LeadDetailScreen(leadId: lead.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClientsView(CrmProvider crmProvider, List<CrmClient> clients) {
    if (crmProvider.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (clients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.users,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _statusFilter != 'all'
                  ? 'Nenašli sa žiadni vyhovujúci klienti'
                  : 'Žiadni CRM klienti v systéme',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: clients.length,
      itemBuilder: (context, index) {
        final client = clients[index];
        final isSelected = _selectedClient?.id == client.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: CrmClientCard(
            client: client,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedClient = client;
              });
            },
          ),
        );
      },
    );
  }

  void _openCreateClientDialog(CrmProvider crmProvider) async {
    final results = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CrmClientDialog(),
    );

    if (results != null) {
      await crmProvider.createClient(
        companyName: results['companyName'],
        contactName: results['contactName'],
        email: results['email'],
        phone: results['phone'],
        website: results['website'],
        service: results['service'],
        status: results['status'],
        budget: results['budget'],
        notes: results['notes'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Klient bol úspešne pridaný'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _openEditClientDialog(CrmClient client, CrmProvider crmProvider) async {
    final results = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CrmClientDialog(client: client),
    );

    if (results != null) {
      final updated = client.copyWith(
        companyName: results['companyName'],
        contactName: results['contactName'],
        email: results['email'],
        phone: results['phone'],
        website: results['website'],
        service: results['service'],
        status: results['status'],
        budget: results['budget'],
        notes: results['notes'],
      );
      await crmProvider.updateClient(updated);
      if (!mounted) return;
      setState(() {
        _selectedClient = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Klient bol úspešne upravený'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  void _confirmDeleteClient(CrmClient client, CrmProvider crmProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text(
          'Vymazať klienta?',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Naozaj chcete presunúť klienta "${client.companyName}" do koša?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Zrušiť',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Vymazať', style: TextStyle(color: Colors.white)),
            onPressed: () async {
              final scaffoldContext = context;
              Navigator.of(context).pop();
              await crmProvider.softDeleteClient(client.id);
              if (!scaffoldContext.mounted) return;
              setState(() {
                _selectedClient = null;
              });
              ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                const SnackBar(
                  content: Text('Klient bol vymazaný (presunutý do koša)'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
