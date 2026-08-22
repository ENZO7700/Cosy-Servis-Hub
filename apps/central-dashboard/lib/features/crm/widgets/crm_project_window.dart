import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/ui/theme.dart';
import '../../leads/lead_inbox_screen.dart';

class CrmProjectWindow extends StatelessWidget {
  final bool isLargeScreen;

  const CrmProjectWindow({super.key, required this.isLargeScreen});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.panelTopOpen,
                    color: AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CRM Lead Management & Workflow',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Správa leadov, kategorizácia podľa skóre, outreach drafty a automatizácie',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildCrmActionCard(
                  context,
                  LucideIcons.upload,
                  'Denný import leadov',
                  emphasize: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeadInboxScreen(),
                    ),
                  ),
                ),
                _buildCrmActionCard(
                  context,
                  LucideIcons.sparkles,
                  'Všetky leady (99+)',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeadInboxScreen(),
                    ),
                  ),
                ),
                _buildCrmActionCard(
                  context,
                  LucideIcons.fileText,
                  'Lead reporty',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeadInboxScreen(),
                    ),
                  ),
                ),
                _buildCrmActionCard(
                  context,
                  LucideIcons.calendarClock,
                  'Follow-up úlohy',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeadInboxScreen(),
                    ),
                  ),
                ),
                _buildCrmActionCard(
                  context,
                  LucideIcons.send,
                  'Outreach drafty',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeadInboxScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrmActionCard(
    BuildContext context,
    IconData icon,
    String label, {
    bool emphasize = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: emphasize
              ? AppTheme.primary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: emphasize
                ? AppTheme.primary.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: emphasize ? AppTheme.primary : AppTheme.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: emphasize
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
