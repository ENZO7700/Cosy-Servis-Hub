import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/ui/theme.dart';
import '../crm/models/crm_lead.dart';
import '../crm/providers/lead_inbox_provider.dart';

class LeadDetailScreen extends StatefulWidget {
  final String leadId;

  const LeadDetailScreen({super.key, required this.leadId});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  bool _generatingOutreach = false;
  bool _generatingOffer = false;
  bool _english = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<LeadInboxProvider>(
      builder: (context, provider, _) {
        final matching = provider.leads.where(
          (lead) => lead.id == widget.leadId,
        );
        if (matching.isEmpty) {
          return const Scaffold(body: Center(child: Text('Lead sa nenašiel.')));
        }
        final lead = matching.first;
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            title: Text(lead.companyName),
            actions: [
              IconButton(
                tooltip: 'Upraviť lead',
                onPressed: () => _editLead(lead, provider),
                icon: const Icon(LucideIcons.pencil),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: lead.pipelineStatus,
                    items: CrmLead.pipelineStatuses
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(_statusLabel(status)),
                          ),
                        )
                        .toList(),
                    onChanged: (status) {
                      if (status != null) {
                        provider.updateLead(
                          lead.copyWith(pipelineStatus: status),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    provider.error!,
                    style: const TextStyle(color: AppTheme.error),
                  ),
                ),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _section('Firma', LucideIcons.building2, [
                    _row('Firma', lead.companyName),
                    _row('Sektor', lead.sector),
                    _row('Web', lead.website),
                    _row('Lokácia', lead.location),
                    _row('Veľkosť', lead.companySize),
                    _row('Skóre', '${lead.score}/10'),
                  ]),
                  _section('Kontakt', LucideIcons.contact, [
                    _row('Meno', lead.contactName),
                    _row('Pozícia', lead.contactRole),
                    _row('E-mail', lead.email),
                    _row('Telefón', lead.phone),
                    _row('LinkedIn', lead.linkedIn),
                  ]),
                  _section('Príležitosť', LucideIcons.target, [
                    _longText('Problém', lead.problem),
                    _longText('Decision maker', lead.decisionMaker),
                    _longText('Revenue', lead.revenueEstimate),
                  ], wide: true),
                  _section('Trigger', LucideIcons.zap, [
                    _longText('Aktuálny signál', lead.trigger),
                  ], wide: true),
                  _section(
                    'Zdroje',
                    LucideIcons.link,
                    lead.sources.isEmpty
                        ? [const Text('Bez zdrojov')]
                        : lead.sources
                              .map((source) => SelectableText(source))
                              .toList(),
                    wide: true,
                  ),
                  _buildOutreachSection(lead, provider),
                  _buildOfferSection(lead, provider),
                  _section('Aktivita', LucideIcons.activity, [
                    _row(
                      'Import',
                      DateFormat('dd.MM.yyyy HH:mm').format(lead.importedAt),
                    ),
                    _row(
                      'Odoslané',
                      lead.sentAt == null
                          ? ''
                          : DateFormat('dd.MM.yyyy HH:mm').format(lead.sentAt!),
                    ),
                    _row(
                      'Follow-up',
                      lead.followUpAt == null
                          ? ''
                          : DateFormat('dd.MM.yyyy').format(lead.followUpAt!),
                    ),
                  ], wide: true),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOutreachSection(CrmLead lead, LeadInboxProvider provider) {
    final hasDraft =
        lead.outreach.emailEn.isNotEmpty || lead.outreach.emailSk.isNotEmpty;
    return _section('Outreach', LucideIcons.send, [
      Row(
        children: [
          Expanded(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('EN')),
                ButtonSegment(value: false, label: Text('SK')),
              ],
              selected: {_english},
              onSelectionChanged: (value) =>
                  setState(() => _english = value.first),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _generatingOutreach
                ? null
                : () => _generateOutreach(lead, provider),
            icon: _generatingOutreach
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.sparkles, size: 16),
            label: Text(hasDraft ? 'Regenerovať' : 'Vygenerovať outreach'),
          ),
        ],
      ),
      if (hasDraft) ...[
        const SizedBox(height: 12),
        _longText(
          'Predmet',
          _english ? lead.outreach.subjectEn : lead.outreach.subjectSk,
        ),
        _longText(
          'E-mail',
          _english ? lead.outreach.emailEn : lead.outreach.emailSk,
        ),
        const Divider(height: 28),
        _longText('LinkedIn', lead.outreach.linkedInMessage),
        _longText('Follow-up deň 5', lead.outreach.followUpDay5),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _editDraft(lead, provider),
              icon: const Icon(LucideIcons.pencil, size: 16),
              label: const Text('Upraviť'),
            ),
            OutlinedButton.icon(
              onPressed: lead.outreach.linkedInMessage.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(
                        ClipboardData(text: lead.outreach.linkedInMessage),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('LinkedIn správa skopírovaná.'),
                        ),
                      );
                    },
              icon: const Icon(LucideIcons.copy, size: 16),
              label: const Text('Kopírovať LinkedIn'),
            ),
            FilledButton.icon(
              onPressed: lead.hasValidEmail
                  ? () => _confirmSend(lead, provider)
                  : null,
              icon: const Icon(LucideIcons.mailCheck, size: 16),
              label: const Text('Skontrolovať a odoslať'),
            ),
          ],
        ),
        if (!lead.hasValidEmail)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Odoslanie je zablokované, kým lead nemá platný e-mail.',
              style: TextStyle(color: AppTheme.warning),
            ),
          ),
      ],
    ], wide: true);
  }

  Widget _buildOfferSection(CrmLead lead, LeadInboxProvider provider) {
    final offer = lead.offer;
    return _section('Čo im vieme spraviť', LucideIcons.lightbulb, [
      FilledButton.icon(
        onPressed: _generatingOffer
            ? null
            : () => _generateOffer(lead, provider),
        icon: _generatingOffer
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(LucideIcons.wandSparkles, size: 16),
        label: Text(offer == null ? 'Vytvoriť návrh' : 'Regenerovať návrh'),
      ),
      if (offer != null) ...[
        const SizedBox(height: 12),
        _longText('Riešenie', offer.recommendedSolution),
        _longText('Prínos', offer.problemAndBenefit),
        _list('Hlavné funkcie', offer.coreFeatures),
        _list('MVP', offer.mvpScope),
        _list('Voliteľné', offer.optionalExtensions),
        _row('Cena', offer.priceRange),
        _row('Trvanie', offer.duration),
        _longText('Ďalší krok', offer.nextStep),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Interný orientačný návrh – nejde o záväznú cenovú ponuku.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      ],
    ], wide: true);
  }

  Widget _section(
    String title,
    IconData icon,
    List<Widget> children, {
    bool wide = false,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    return Container(
      width: wide || width < 900 ? double.infinity : (width - 56) / 2,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 19),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Widget _longText(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );
  }

  Widget _list(String label, List<String> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          ...values.map((value) => Text('• $value')),
        ],
      ),
    );
  }

  Future<void> _generateOutreach(
    CrmLead lead,
    LeadInboxProvider provider,
  ) async {
    setState(() => _generatingOutreach = true);
    try {
      await provider.generateOutreach(lead);
    } catch (_) {
      // The provider exposes a user-safe error in the page.
    } finally {
      if (mounted) setState(() => _generatingOutreach = false);
    }
  }

  Future<void> _generateOffer(CrmLead lead, LeadInboxProvider provider) async {
    setState(() => _generatingOffer = true);
    try {
      await provider.generateOffer(lead);
    } catch (_) {
      // The provider exposes a user-safe error in the page.
    } finally {
      if (mounted) setState(() => _generatingOffer = false);
    }
  }

  Future<void> _editDraft(CrmLead lead, LeadInboxProvider provider) async {
    final subject = TextEditingController(
      text: _english ? lead.outreach.subjectEn : lead.outreach.subjectSk,
    );
    final body = TextEditingController(
      text: _english ? lead.outreach.emailEn : lead.outreach.emailSk,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Upraviť ${_english ? 'EN' : 'SK'} draft'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subject,
                decoration: const InputDecoration(labelText: 'Predmet'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                minLines: 8,
                maxLines: 14,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Zrušiť'),
          ),
          FilledButton(
            onPressed: () async {
              final outreach = _english
                  ? lead.outreach.copyWith(
                      subjectEn: subject.text.trim(),
                      emailEn: body.text.trim(),
                    )
                  : lead.outreach.copyWith(
                      subjectSk: subject.text.trim(),
                      emailSk: body.text.trim(),
                    );
              await provider.updateLead(lead.copyWith(outreach: outreach));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Uložiť'),
          ),
        ],
      ),
    );
    subject.dispose();
    body.dispose();
  }

  Future<void> _editLead(CrmLead lead, LeadInboxProvider provider) async {
    final company = TextEditingController(text: lead.companyName);
    final contact = TextEditingController(text: lead.contactName);
    final role = TextEditingController(text: lead.contactRole);
    final email = TextEditingController(text: lead.email);
    final phone = TextEditingController(text: lead.phone);
    final website = TextEditingController(text: lead.website);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Upraviť lead'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _editField(company, 'Firma'),
                _editField(contact, 'Kontakt'),
                _editField(role, 'Pozícia'),
                _editField(email, 'E-mail'),
                _editField(phone, 'Telefón'),
                _editField(website, 'Web'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Zrušiť'),
          ),
          FilledButton(
            onPressed: company.text.trim().isEmpty
                ? null
                : () async {
                    final values = <String, String>{
                      'company_name': company.text.trim(),
                      'contact_name': contact.text.trim(),
                      'contact_role': role.text.trim(),
                      'email': email.text.trim(),
                      'phone': phone.text.trim(),
                      'website': website.text.trim(),
                    };
                    final uncertain = lead.uncertainFields
                        .where(
                          (field) =>
                              values[field] == null || values[field]!.isEmpty,
                        )
                        .toList();
                    await provider.updateLead(
                      lead.copyWith(
                        companyName: values['company_name'],
                        contactName: values['contact_name'],
                        contactRole: values['contact_role'],
                        email: values['email'],
                        phone: values['phone'],
                        website: values['website'],
                        uncertainFields: uncertain,
                      ),
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
            child: const Text('Uložiť'),
          ),
        ],
      ),
    );
    company.dispose();
    contact.dispose();
    role.dispose();
    email.dispose();
    phone.dispose();
    website.dispose();
  }

  Widget _editField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _confirmSend(CrmLead lead, LeadInboxProvider provider) async {
    final subject = TextEditingController(
      text: _english ? lead.outreach.subjectEn : lead.outreach.subjectSk,
    );
    final body = TextEditingController(
      text: _english ? lead.outreach.emailEn : lead.outreach.emailSk,
    );
    var sending = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Potvrdiť odoslanie'),
          content: SizedBox(
            width: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Komu: ${lead.email}'),
                const SizedBox(height: 12),
                TextField(
                  controller: subject,
                  enabled: !sending,
                  decoration: const InputDecoration(labelText: 'Predmet'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: body,
                  enabled: !sending,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(labelText: 'Obsah'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(dialogContext),
              child: const Text('Zrušiť'),
            ),
            FilledButton.icon(
              onPressed:
                  sending ||
                      subject.text.trim().isEmpty ||
                      body.text.trim().isEmpty
                  ? null
                  : () async {
                      setDialogState(() => sending = true);
                      try {
                        await provider.sendEmail(
                          lead: lead,
                          subject: subject.text.trim(),
                          body: body.text.trim(),
                          idempotencyKey: const Uuid().v4(),
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'E-mail bol odoslaný. Follow-up je o 5 dní.',
                            ),
                          ),
                        );
                      } catch (_) {
                        if (dialogContext.mounted) {
                          setDialogState(() => sending = false);
                        }
                      }
                    },
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.send, size: 16),
              label: const Text('Odoslať'),
            ),
          ],
        ),
      ),
    );
    subject.dispose();
    body.dispose();
  }

  String _statusLabel(String status) {
    return switch (status) {
      'new' => 'Nový',
      'draft_ready' => 'Draft pripravený',
      'approved' => 'Schválený',
      'sent' => 'Odoslaný',
      'waiting' => 'Čakáme',
      'follow_up_due' => 'Follow-up',
      'replied' => 'Odpovedal',
      'won' => 'Vyhrané',
      'lost' => 'Stratené',
      _ => status,
    };
  }
}
