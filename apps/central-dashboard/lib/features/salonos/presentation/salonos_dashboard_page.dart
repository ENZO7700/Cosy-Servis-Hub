import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/ui/responsive.dart';
import '../../../core/ui/theme.dart';
import '../models/salonos_stats.dart';
import '../services/salonos_stats_service.dart';

/// SALONOS AI cockpit backed by the authenticated ServisHub stats API.
class SalonosDashboardPage extends StatefulWidget {
  final SalonosStatsGateway? service;

  const SalonosDashboardPage({super.key, this.service});

  @override
  State<SalonosDashboardPage> createState() => _SalonosDashboardPageState();
}

class _SalonosDashboardPageState extends State<SalonosDashboardPage> {
  late final SalonosStatsGateway _service;
  final Set<String> _reviewedActions = <String>{};
  late Future<SalonosStats> _stats;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? SalonosStatsService();
    _stats = _service.fetchStats();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _stats = _service.fetchStats());
  }

  void _showAction(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.cardBg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: FutureBuilder<SalonosStats>(
          future: _stats,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error);
            }

            final stats = snapshot.data!;
            if (stats.isEmpty) return _buildEmptyState(context, stats);
            return _buildSuccessState(context, stats);
          },
        ),
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context, SalonosStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeading(context, stats),
          const SizedBox(height: 20),
          _buildRevenueCard(context, stats),
          const SizedBox(height: 24),
          Text(
            'Dnes AI odporúča ${stats.dailyActions.length} akcie',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'SALONOS sleduje príležitosti pre nové zákazky, termíny a opakované služby.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Responsive(
            mobile: Column(children: _actionCards(stats.dailyActions)),
            desktop: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _actionCards(stats.dailyActions)
                  .map(
                    (card) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: card,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 24),
          _buildEngineStatus(stats),
        ],
      ),
    );
  }

  Widget _buildHeading(BuildContext context, SalonosStats stats) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SALONOS AI',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.success,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Revenue cockpit',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stats.businessName,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.35)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.circleCheck, size: 14, color: AppTheme.success),
              SizedBox(width: 6),
              Text(
                'Engine aktívny',
                style: TextStyle(
                  color: AppTheme.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueCard(BuildContext context, SalonosStats stats) {
    final currency = NumberFormat.currency(
      locale: 'sk_SK',
      symbol: stats.currency,
      decimalDigits: 2,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.success.withValues(alpha: 0.22),
            const Color(0xFF0B3028).withValues(alpha: 0.84),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.success.withValues(alpha: 0.10),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.trendingUp, color: AppTheme.success, size: 18),
              SizedBox(width: 8),
              Text(
                'AI GENERATED REVENUE',
                style: TextStyle(
                  color: AppTheme.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currency.format(stats.totalAiRevenue),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Príspevok AI engine za aktuálny mesiac',
            style: TextStyle(color: Color(0xB8FFFFFF), fontSize: 12),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _revenueSource(
                currency.format(stats.breakdown.returnEngine),
                'Návrat klientov',
              ),
              _revenueSource(
                currency.format(stats.breakdown.slotFiller),
                'Využitá kapacita',
              ),
              _revenueSource(
                currency.format(stats.breakdown.noShowGuards),
                'Ochrana pred výpadkom',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _revenueSource(String amount, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xB8FFFFFF), fontSize: 11),
          ),
        ],
      ),
    );
  }

  List<Widget> _actionCards(List<SalonosDailyAction> actions) {
    return actions.map((action) {
      final reviewed = _reviewedActions.contains(action.id);
      return _buildActionCard(
        icon: switch (action.id) {
          'return-engine' => LucideIcons.bot,
          'slot-filler' => LucideIcons.calendarClock,
          _ => LucideIcons.users,
        },
        title: '${action.title} (${action.count})',
        detail: action.detail,
        buttonLabel: reviewed ? 'Skontrolované' : 'Označiť ako skontrolované',
        isComplete: reviewed,
        onPressed: () {
          setState(() => _reviewedActions.add(action.id));
          _showAction('Odporúčanie bolo označené ako skontrolované.');
        },
      );
    }).toList();
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String detail,
    required String buttonLabel,
    required VoidCallback onPressed,
    bool isComplete = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(borderRadius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: (isComplete ? AppTheme.success : AppTheme.primary)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isComplete ? LucideIcons.circleCheck : icon,
              size: 18,
              color: isComplete ? AppTheme.success : AppTheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: isComplete ? AppTheme.success : Colors.white,
                side: BorderSide(
                  color: isComplete ? AppTheme.success : AppTheme.border,
                ),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(buttonLabel, style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineStatus(SalonosStats stats) {
    final start = stats.periodStart.toLocal();
    final period = '${start.day}. ${start.month}. ${start.year}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(borderRadius: 14),
      child: Row(
        children: [
          const Icon(LucideIcons.activity, size: 18, color: AppTheme.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dáta za obdobie od $period · ${stats.businessName}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.success),
          SizedBox(height: 14),
          Text('Načítavam reálne SALONOS dáta…'),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, SalonosStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeading(context, stats),
          const SizedBox(height: 24),
          _buildStateCard(
            icon: LucideIcons.inbox,
            title: 'Zatiaľ bez SALONOS dát',
            message:
                'Pre aktuálny mesiac nie sú evidované AI výnosy ani odporúčané akcie.',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildStateCard(
          icon: LucideIcons.triangleAlert,
          title: 'SALONOS dáta sa nepodarilo načítať',
          message: error is SalonosStatsException
              ? error.message
              : 'Skontroluj pripojenie a skús to znova.',
          action: OutlinedButton.icon(
            onPressed: _retry,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Skúsiť znova'),
          ),
        ),
      ),
    );
  }

  Widget _buildStateCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassDecoration(borderRadius: 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: AppTheme.textSecondary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
          if (action != null) ...[const SizedBox(height: 18), action],
        ],
      ),
    );
  }
}
