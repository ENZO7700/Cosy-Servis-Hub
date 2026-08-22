import 'package:flutter/material.dart';
import '../../../core/ui/theme.dart';
import '../models/crm_models.dart';

class CrmClientCard extends StatelessWidget {
  final CrmClient client;
  final bool isSelected;
  final VoidCallback onTap;

  const CrmClientCard({
    super.key,
    required this.client,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Task Completion Progress calculations
    final totalTasks = client.tasks.length;
    final doneTasks = client.tasks.where((t) => t.done).length;
    final progress = totalTasks == 0 ? 0.0 : doneTasks / totalTasks;

    Color statusColor = AppTheme.textSecondary;
    String statusLabel = 'Neaktívny';
    if (client.status == 'lead') {
      statusColor = Colors.blue;
      statusLabel = 'Lead';
    } else if (client.status == 'active') {
      statusColor = AppTheme.success;
      statusLabel = 'Aktívny';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: isSelected
            ? AppTheme.activeGlassDecoration(borderRadius: 12)
            : AppTheme.glassDecoration(
                borderRadius: 12,
                borderColor: Colors.white.withValues(alpha: 0.05),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    client.companyName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (client.service.isNotEmpty) ...[
                  Text(
                    client.service,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Colors.white24)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    client.contactName ?? 'Bez kontaktnej osoby',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Task progress bar
            if (totalTasks > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Úlohy: $doneTasks/$totalTasks',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white10,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
