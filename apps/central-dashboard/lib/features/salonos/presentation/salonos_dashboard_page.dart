import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/ui/responsive.dart';
import '../../../core/ui/theme.dart';

/// SALONOS AI cockpit for the PAPI HAIR DESIGN pilot.
///
/// The first screen is intentionally useful without a live API connection:
/// owners can review the revenue attribution and preview the next actions.
/// The action callbacks are ready to be replaced with the API client when the
/// shared provider environment is connected.
class SalonosDashboardPage extends StatefulWidget {
  const SalonosDashboardPage({super.key});

  @override
  State<SalonosDashboardPage> createState() => _SalonosDashboardPageState();
}

class _SalonosDashboardPageState extends State<SalonosDashboardPage> {
  bool _outreachStarted = false;
  bool _slotMessageSent = false;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeading(context),
              const SizedBox(height: 20),
              _buildRevenueCard(context),
              const SizedBox(height: 24),
              const Text(
                'Dnes AI odporúča 3 akcie',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'SALONOS sleduje príležitosti, ktoré môžu priniesť ďalšie rezervácie.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Responsive(
                mobile: Column(
                  children: _actionCards(context),
                ),
                desktop: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _actionCards(context)
                      .map((card) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: card,
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              _buildEngineStatus(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeading(BuildContext context) {
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
              const Text(
                'PAPI HAIR DESIGN · Košice',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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

  Widget _buildRevenueCard(BuildContext context) {
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
            '+ €2 740 EUR',
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
              _revenueSource('€1 420', 'Reaktivovaní klienti'),
              _revenueSource('€820', 'Zaplnené sloty'),
              _revenueSource('€500', 'Zálohy'),
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

  List<Widget> _actionCards(BuildContext context) {
    return [
      _buildActionCard(
        icon: LucideIcons.bot,
        title: 'Osloviť 12 klientov, ktorí neboli >28 dní',
        detail: 'Return engine pripravil personalizovaný outreach batch.',
        buttonLabel: _outreachStarted ? 'Outreach pripravený' : 'Spustiť AI Outreach',
        isComplete: _outreachStarted,
        onPressed: () {
          setState(() => _outreachStarted = true);
          _showAction('Outreach batch je pripravený na odoslanie.');
        },
      ),
      _buildActionCard(
        icon: LucideIcons.calendarClock,
        title: 'Zaplniť dnešný slot o 15:00 u Papiho',
        detail: 'Slot filler našiel vhodný segment klientov.',
        buttonLabel: _slotMessageSent ? 'SMS pripravená' : 'Odoslať SMS',
        isComplete: _slotMessageSent,
        onPressed: () {
          setState(() => _slotMessageSent = true);
          _showAction('SMS návrh bol vytvorený pre voľný slot.');
        },
      ),
      _buildActionCard(
        icon: LucideIcons.users,
        title: '4 VIP klienti v riziku odchodu',
        detail: 'Klienti prekročili svoj obvyklý interval návštevy.',
        buttonLabel: 'Zobraziť detail',
        onPressed: () => _showAction('Detail VIP segmentu bude otvorený v CRM.'),
      ),
    ];
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

  Widget _buildEngineStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassDecoration(borderRadius: 14),
      child: const Row(
        children: [
          Icon(LucideIcons.activity, size: 18, color: AppTheme.success),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Posledná synchronizácia: dnes o 09:42 · Dáta sú pripravené pre PAPI HAIR DESIGN.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}