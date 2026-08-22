import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/ui/theme.dart';
import '../crm/models/crm_lead.dart';
import '../crm/providers/lead_inbox_provider.dart';
import './lead_detail_screen.dart';
import './widgets/lead_parse_progress_panel.dart';

class LeadInboxScreen extends StatefulWidget {
  const LeadInboxScreen({super.key});

  @override
  State<LeadInboxScreen> createState() => _LeadInboxScreenState();
}

class _LeadInboxScreenState extends State<LeadInboxScreen> {
  String _filter = 'all';
  final TextEditingController _importController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeadInboxProvider>().refreshGmailStatus();
    });
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('AI Lead Inbox'),
        actions: [
          Consumer<LeadInboxProvider>(
            builder: (context, provider, _) => TextButton.icon(
              onPressed: () => _handleGmail(provider),
              icon: Icon(
                provider.gmail.connected
                    ? LucideIcons.mailCheck
                    : LucideIcons.mailPlus,
                size: 18,
                color: provider.gmail.connected
                    ? AppTheme.success
                    : AppTheme.primary,
              ),
              label: Text(
                provider.gmail.connected
                    ? provider.gmail.email
                    : 'Prepojiť Gmail',
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('open_lead_import'),
        onPressed: _showImportDialog,
        icon: const Icon(LucideIcons.clipboardPaste),
        label: const Text('Vložiť report'),
      ),
      body: Consumer<LeadInboxProvider>(
        builder: (context, provider, _) {
          final leads = provider.leads
              .where(
                (lead) => _filter == 'all' || lead.pipelineStatus == _filter,
              )
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (provider.error != null)
                MaterialBanner(
                  content: Text(provider.error!),
                  actions: [
                    TextButton(
                      onPressed: provider.load,
                      child: const Text('Skúsiť znova'),
                    ),
                  ],
                ),
              _buildOverview(provider.leads),
              _buildFilters(),
              Expanded(
                child: provider.loading
                    ? const Center(child: CircularProgressIndicator())
                    : leads.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                        itemCount: leads.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildLeadCard(leads[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverview(List<CrmLead> leads) {
    final due = leads
        .where((lead) => lead.pipelineStatus == 'follow_up_due')
        .length;
    final waiting = leads
        .where((lead) => lead.pipelineStatus == 'waiting')
        .length;
    final highScore = leads.where((lead) => lead.score >= 8).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _metric('Leady', '${leads.length}', AppTheme.primary),
          _metric('Skóre 8+', '$highScore', AppTheme.warning),
          _metric('Čakáme', '$waiting', Colors.blue),
          _metric('Follow-up', '$due', AppTheme.error),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    const filters = <String, String>{
      'all': 'Všetky',
      'new': 'Nové',
      'draft_ready': 'Drafty',
      'waiting': 'Čakáme',
      'follow_up_due': 'Follow-up',
      'won': 'Vyhrané',
    };
    return SizedBox(
      height: 52,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        scrollDirection: Axis.horizontal,
        children: filters.entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(entry.value),
                  selected: _filter == entry.key,
                  onSelected: (_) => setState(() => _filter = entry.key),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.inbox,
              size: 48,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _filter == 'all'
                  ? 'Zatiaľ tu nie sú žiadne leady.'
                  : 'V tomto stave nie sú žiadne leady.',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vlož celý text denného reportu a pred uložením ho skontroluj.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadCard(CrmLead lead) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LeadDetailScreen(leadId: lead.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _scoreColor(lead.score).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                lead.score.toStringAsFixed(lead.score % 1 == 0 ? 0 : 1),
                style: TextStyle(
                  color: _scoreColor(lead.score),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.companyName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      lead.contactName,
                      lead.sector,
                    ].where((value) => value.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  if (lead.uncertainFields.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Doplniť: ${lead.uncertainFields.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _statusChip(lead.pipelineStatus),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'waiting' => Colors.blue,
      'follow_up_due' => AppTheme.error,
      'won' => AppTheme.success,
      'lost' => AppTheme.textSecondary,
      'draft_ready' => AppTheme.warning,
      _ => AppTheme.primary,
    };
    final label = switch (status) {
      'draft_ready' => 'Draft',
      'follow_up_due' => 'Follow-up',
      'waiting' => 'Čakáme',
      'won' => 'Vyhrané',
      'lost' => 'Stratené',
      _ => 'Nový',
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
      visualDensity: VisualDensity.compact,
    );
  }

  Color _scoreColor(double score) {
    if (score >= 8) return AppTheme.success;
    if (score >= 7) return AppTheme.warning;
    return AppTheme.error;
  }

  Future<void> _showImportDialog() async {
    _importController.clear();
    final provider = context.read<LeadInboxProvider>()..clearPreview();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Consumer<LeadInboxProvider>(
        builder: (context, state, _) => AlertDialog(
          insetPadding: const EdgeInsets.all(20),
          title: const Text('Denný import leadov'),
          content: SizedBox(
            width: 760,
            height: 620,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('lead_import_text'),
                  controller: _importController,
                  enabled: !state.parsing,
                  minLines: 8,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Text z iMessage',
                    hintText:
                        'Vlož jednu alebo viac celých správ (min. ~40 znakov)...',
                    alignLabelWithHint: true,
                    helperText:
                        'Server parsuje text cez Mistral. Musíš byť prihlásený (Firebase).',
                  ),
                ),
                const SizedBox(height: 12),
                if (state.error != null)
                  Text(
                    state.error!,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                if (state.parseWarning != null && !state.parsing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      state.parseWarning!,
                      style: const TextStyle(color: AppTheme.warning),
                    ),
                  ),
                if (state.parsing)
                  Expanded(
                    child: LeadParseProgressPanel(
                      progress: state.parseProgress,
                      onCancel: state.cancelParse,
                    ),
                  )
                else if (state.preview.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.preview.length,
                      itemBuilder: (context, index) {
                        final item = state.preview[index];
                        return CheckboxListTile(
                          value: item.selected,
                          onChanged: item.duplicate
                              ? null
                              : (value) => state.setCandidateSelected(
                                  index,
                                  value ?? false,
                                ),
                          title: Text(item.lead.companyName),
                          subtitle: Text(
                            item.duplicate
                                ? 'Možná duplicita – nebude importovaná'
                                : '${item.lead.contactName} · skóre ${item.lead.score}/10'
                                      '${item.lead.uncertainFields.isEmpty ? '' : ' · chýba ${item.lead.uncertainFields.join(', ')}'}',
                          ),
                          secondary: item.duplicate
                              ? const Icon(
                                  LucideIcons.copyX,
                                  color: AppTheme.warning,
                                )
                              : null,
                        );
                      },
                    ),
                  )
                else
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Text sa najprv iba analyzuje. Nič sa neuloží bez potvrdenia.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.parsing
                  ? state.cancelParse
                  : () {
                      state.clearPreview();
                      Navigator.pop(dialogContext);
                    },
              child: Text(state.parsing ? 'Zrušiť parse' : 'Zavrieť'),
            ),
            if (state.hasFailedChunks && !state.parsing)
              TextButton.icon(
                key: const Key('retry_failed_chunks'),
                onPressed: () => state.retryFailedChunks(),
                icon: const Icon(LucideIcons.refreshCw, size: 16),
                label: const Text('Zopakovať zlyhané'),
              ),
            if (state.preview.isEmpty && !state.parsing)
              FilledButton.icon(
                key: const Key('parse_leads_button'),
                onPressed: () =>
                    provider.parseForPreview(_importController.text),
                icon: const Icon(LucideIcons.sparkles, size: 16),
                label: const Text('Rozdeliť leady'),
              )
            else if (!state.parsing)
              FilledButton.icon(
                key: const Key('confirm_lead_import'),
                onPressed: state.preview.any((item) => item.selected)
                    ? () async {
                        final count = await provider.confirmImport();
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Importovaných leadov: $count'),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(LucideIcons.import, size: 16),
                label: const Text('Potvrdiť import'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGmail(LeadInboxProvider provider) async {
    if (provider.gmail.connected) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Gmail je prepojený'),
          content: Text(provider.gmail.email),
          actions: [
            TextButton(
              onPressed: () async {
                await provider.refreshGmailStatus();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Obnoviť stav'),
            ),
            TextButton(
              onPressed: () async {
                await provider.disconnectGmail();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('Odpojiť Gmail'),
            ),
          ],
        ),
      );
      return;
    }
    try {
      final url = await provider.getGmailConnectUrl();
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gmail prepojenie sa nedá otvoriť.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Gmail prepojenie zlyhalo.')),
      );
    }
  }
}
