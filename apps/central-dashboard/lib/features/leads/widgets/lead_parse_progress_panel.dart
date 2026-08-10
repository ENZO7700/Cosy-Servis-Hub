import 'package:flutter/material.dart';

import '../../../core/ui/theme.dart';
import '../../crm/providers/lead_inbox_provider.dart';

/// Animated progress surface for chunked Mistral lead parsing.
class LeadParseProgressPanel extends StatefulWidget {
  final ParseProgress progress;
  final VoidCallback? onCancel;

  const LeadParseProgressPanel({
    super.key,
    required this.progress,
    this.onCancel,
  });

  @override
  State<LeadParseProgressPanel> createState() => _LeadParseProgressPanelState();
}

class _LeadParseProgressPanelState extends State<LeadParseProgressPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    final value = p.value.clamp(0.0, 1.0);

    return Semantics(
      liveRegion: true,
      label: p.statusLine.isEmpty
          ? 'Rozdeľovanie leadov'
          : 'Rozdeľovanie leadov: ${p.statusLine}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.08).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.18),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.55),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppTheme.primary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Rozdeľovanie leadov',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: value),
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            builder: (context, animated, _) {
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: animated <= 0 ? null : animated,
                      minHeight: 8,
                      backgroundColor: AppTheme.border,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(animated * 100).round()}%',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0, 0.15),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: Text(
              p.statusLine.isEmpty ? 'Mistral rozdeľuje leady…' : p.statusLine,
              key: ValueKey(p.statusLine),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _metric(
                Icons.check_circle_outline,
                'Nájdených: ${p.leadsFound}',
                AppTheme.success,
              ),
              if (p.chunkTotal > 0)
                _metric(
                  Icons.view_agenda_outlined,
                  'Blok ${p.chunkIndex.clamp(0, p.chunkTotal)}/${p.chunkTotal}',
                  AppTheme.primary,
                ),
              if (p.chunksFailed > 0)
                _metric(
                  Icons.warning_amber_rounded,
                  'Zlyhané: ${p.chunksFailed}',
                  AppTheme.warning,
                ),
            ],
          ),
          if (widget.onCancel != null && p.isActive) ...[
            const SizedBox(height: 18),
            TextButton(
              key: const Key('cancel_lead_parse'),
              onPressed: widget.onCancel,
              child: const Text('Zrušiť'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
