import 'package:flutter/material.dart';

import '../crm/models/crm_lead.dart';

/// Lead card widget for displaying lead information
class LeadCard extends StatelessWidget {
  final CrmLead lead;
  final bool showStage;
  final bool showActions;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const LeadCard({
    super.key,
    required this.lead,
    this.showStage = true,
    this.showActions = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildCompanyInfo(),
              if (lead.email.isNotEmpty || lead.phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                _buildContactInfo(),
              ],
              const SizedBox(height: 8),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (showStage) ...[_buildStageBadge(), const SizedBox(width: 8)],
            _buildScoreIndicator(),
          ],
        ),
        if (showActions) _buildActionsRow(),
      ],
    );
  }

  Widget _buildStageBadge() {
    final stageDisplay = _getStageDisplay(lead.stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStageColor(lead.stage),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        stageDisplay,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _getStageDisplay(String stage) {
    switch (stage) {
      case 'new':
        return 'New';
      case 'qualified':
        return 'Qualified';
      case 'contacted':
        return 'Contacted';
      case 'proposal':
        return 'Proposal';
      case 'negotiation':
        return 'Negotiation';
      case 'won':
        return 'Won';
      case 'lost':
        return 'Lost';
      default:
        return stage;
    }
  }

  Color _getStageColor(String stage) {
    switch (stage) {
      case 'new':
        return Colors.blue;
      case 'qualified':
        return Colors.green;
      case 'contacted':
        return Colors.orange;
      case 'proposal':
        return Colors.deepOrange;
      case 'negotiation':
        return Colors.purple;
      case 'won':
        return Colors.green.shade800;
      case 'lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildScoreIndicator() {
    if (lead.score <= 0) return const SizedBox();

    final scoreColor = _getScoreColor(lead.score);

    return Tooltip(
      message: 'Score: ${lead.score.toStringAsFixed(0)}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: scoreColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scoreColor),
        ),
        child: Text(
          lead.score.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: scoreColor,
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildActionsRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit, size: 16),
            onPressed: onEdit,
            tooltip: 'Edit',
          ),
        if (onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete, size: 16),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
      ],
    );
  }

  Widget _buildCompanyInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lead.companyName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (lead.contactName.isNotEmpty)
          Text(
            lead.contactName,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildContactInfo() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (lead.email.isNotEmpty)
          Tooltip(
            message: lead.email,
            child: Icon(Icons.email, size: 16, color: Colors.grey.shade600),
          ),
        if (lead.phone.isNotEmpty)
          Tooltip(
            message: lead.phone,
            child: Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
          ),
        if (lead.website.isNotEmpty)
          Tooltip(
            message: lead.website,
            child: Icon(Icons.language, size: 16, color: Colors.grey.shade600),
          ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (lead.tags.isNotEmpty)
          Wrap(
            spacing: 4,
            children: lead.tags
                .take(3)
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        Text(
          _formatDate(lead.updatedAt),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()}w ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
