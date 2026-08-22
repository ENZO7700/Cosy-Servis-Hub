import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/ui/theme.dart';
import '../models/crm_models.dart';
import '../providers/crm_provider.dart';

class CrmDetailPane extends StatefulWidget {
  final CrmClient client;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CrmDetailPane({
    super.key,
    required this.client,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<CrmDetailPane> createState() => _CrmDetailPaneState();
}

class _CrmDetailPaneState extends State<CrmDetailPane> {
  List<CrmClientActivity> _activities = [];
  bool _loadingActivities = false;

  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _activityController = TextEditingController();
  String _newActivityType = 'note'; // 'note', 'call', 'email', 'meeting'

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  @override
  void didUpdateWidget(CrmDetailPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client.id != widget.client.id) {
      _loadActivities();
    }
  }

  @override
  void dispose() {
    _taskController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    if (!mounted) return;
    setState(() {
      _loadingActivities = true;
    });

    final crmProvider = Provider.of<CrmProvider>(context, listen: false);
    final acts = await crmProvider.getActivitiesForClient(widget.client.id);

    if (mounted) {
      setState(() {
        _activities = acts..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _loadingActivities = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final crmProvider = Provider.of<CrmProvider>(context);

    // Get the most up-to-date client info from the provider if available
    final client = crmProvider.clients.firstWhere(
      (c) => c.id == widget.client.id,
      orElse: () => widget.client,
    );

    final totalTasks = client.tasks.length;
    final doneTasks = client.tasks.where((t) => t.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Detail Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Karta Klienta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      LucideIcons.edit,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    tooltip: 'Upraviť',
                    onPressed: widget.onEdit,
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.trash2,
                      size: 16,
                      color: AppTheme.error,
                    ),
                    tooltip: 'Vymazať',
                    onPressed: widget.onDelete,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),

        // Scrollable Details
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Client Core Info Card
              _buildSectionTitle('ZÁKLADNÉ ÚDAJE'),
              const SizedBox(height: 12),
              _buildDetailInfoTile(
                LucideIcons.home,
                'Firma',
                client.companyName,
              ),
              if (client.contactName != null)
                _buildDetailInfoTile(
                  LucideIcons.user,
                  'Kontakt',
                  client.contactName!,
                ),
              if (client.email != null)
                _buildDetailInfoTile(LucideIcons.mail, 'E-mail', client.email!),
              if (client.phone != null)
                _buildDetailInfoTile(
                  LucideIcons.phone,
                  'Telefón',
                  client.phone!,
                ),
              if (client.website != null)
                _buildDetailInfoTile(LucideIcons.globe, 'Web', client.website!),
              if (client.budget != null)
                _buildDetailInfoTile(
                  LucideIcons.dollarSign,
                  'Rozpočet',
                  '${client.budget} €',
                ),
              if (client.notes != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Poznámky:',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    client.notes!,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Checklist Section
              _buildSectionTitle('CHECKLIST ÚLOH ($doneTasks/$totalTasks)'),
              const SizedBox(height: 12),
              _buildTaskInputWidget(client.id, crmProvider),
              const SizedBox(height: 8),
              if (client.tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'Žiadne úlohy pre tohto klienta.',
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                )
              else
                ...client.tasks.map(
                  (task) => _buildTaskItem(client.id, task, crmProvider),
                ),

              const SizedBox(height: 24),

              // Activity Timeline Section
              _buildSectionTitle('ČASOVÁ OS AKTIVÍT'),
              const SizedBox(height: 12),
              _buildActivityLoggerWidget(client.id, crmProvider),
              const SizedBox(height: 16),
              if (_loadingActivities)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_activities.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'Žiadne zaznamenané aktivity.',
                    style: TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activities.length,
                  itemBuilder: (context, idx) {
                    return _buildActivityTimelineTile(_activities[idx]);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppTheme.primary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildDetailInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskInputWidget(String clientId, CrmProvider crmProvider) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _taskController,
            key: const Key('add_task_input'),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Pridať novú úlohu...',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const Key('add_task_submit'),
          icon: const Icon(Icons.add_circle, color: AppTheme.primary, size: 24),
          onPressed: () async {
            final txt = _taskController.text.trim();
            if (txt.isNotEmpty) {
              await crmProvider.addTask(clientId, txt, null);
              _taskController.clear();
            }
          },
        ),
      ],
    );
  }

  Widget _buildTaskItem(
    String clientId,
    CrmClientTask task,
    CrmProvider crmProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Checkbox(
            value: task.done,
            activeColor: AppTheme.success,
            onChanged: (val) {
              if (val != null) {
                crmProvider.updateTask(clientId, task.id, done: val);
              }
            },
          ),
          Expanded(
            child: Text(
              task.text,
              style: TextStyle(
                color: task.done
                    ? AppTheme.textSecondary
                    : AppTheme.textPrimary,
                fontSize: 13,
                decoration: task.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppTheme.error,
              size: 18,
            ),
            onPressed: () => crmProvider.deleteTask(clientId, task.id),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLoggerWidget(String clientId, CrmProvider crmProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _buildTypeSelectChip('note', 'Poznámka'),
            const SizedBox(width: 6),
            _buildTypeSelectChip('call', 'Hovor'),
            const SizedBox(width: 6),
            _buildTypeSelectChip('email', 'E-mail'),
            const SizedBox(width: 6),
            _buildTypeSelectChip('meeting', 'Stretnutie'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _activityController,
                key: const Key('add_activity_input'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Zapísať priebeh aktivity...',
                  hintStyle: const TextStyle(
                    color: Colors.white24,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('add_activity_submit'),
              icon: const Icon(Icons.send, color: AppTheme.primary, size: 20),
              onPressed: () async {
                final text = _activityController.text.trim();
                if (text.isNotEmpty) {
                  String title = 'Zaznamenaná aktivita';
                  if (_newActivityType == 'call') {
                    title = 'Telefonát';
                  }
                  if (_newActivityType == 'email') {
                    title = 'E-mail odoslaný';
                  }
                  if (_newActivityType == 'meeting') {
                    title = 'Osobné stretnutie';
                  }
                  if (_newActivityType == 'note') {
                    title = 'Interná poznámka';
                  }

                  await crmProvider.addActivity(
                    clientId: clientId,
                    type: _newActivityType,
                    title: title,
                    content: text,
                  );
                  _activityController.clear();
                  _loadActivities();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeSelectChip(String type, String label) {
    final isSelected = _newActivityType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _newActivityType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTimelineTile(CrmClientActivity activity) {
    IconData icon = LucideIcons.stickyNote;
    Color iconColor = AppTheme.primary;

    if (activity.type == 'call') {
      icon = LucideIcons.phone;
      iconColor = AppTheme.success;
    } else if (activity.type == 'email') {
      icon = LucideIcons.mail;
      iconColor = Colors.orange;
    } else if (activity.type == 'meeting') {
      icon = LucideIcons.calendar;
      iconColor = Colors.purple;
    }

    final timeStr =
        '${activity.createdAt.day}.${activity.createdAt.month}.${activity.createdAt.year} ${activity.createdAt.hour.toString().padLeft(2, '0')}:${activity.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                if (activity.content != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    activity.content!,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
