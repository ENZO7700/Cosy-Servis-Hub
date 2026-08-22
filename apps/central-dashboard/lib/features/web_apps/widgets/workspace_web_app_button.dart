import 'package:flutter/material.dart';

import '../models/workspace_web_app.dart';

/// Widget for displaying a web app button in the sidebar
class WorkspaceWebAppButton extends StatelessWidget {
  final WorkspaceWebApp app;
  final bool isSelected;
  final VoidCallback? onTap;

  const WorkspaceWebAppButton({
    super.key,
    required this.app,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmoji = WorkspaceWebApp.isEmoji(app.icon);

    return Tooltip(
      message: app.name,
      child: ListTile(
        leading: _buildIcon(isEmoji),
        title: Text(
          app.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        selected: isSelected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        onTap: onTap,
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildIcon(bool isEmoji) {
    if (isEmoji) {
      return Text(app.icon, style: const TextStyle(fontSize: 20));
    }

    // For Material icons
    return Icon(WebAppIcons.getIconData(app.icon) ?? Icons.web, size: 20);
  }
}

/// Widget for displaying the web apps section in sidebar
class WebAppsSidebarSection extends StatelessWidget {
  final List<WorkspaceWebApp> webApps;
  final String? selectedAppId;
  final Function(String) onAppSelected;

  const WebAppsSidebarSection({
    super.key,
    required this.webApps,
    this.selectedAppId,
    required this.onAppSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (webApps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Web Apps',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...webApps.map((app) {
          return WorkspaceWebAppButton(
            key: ValueKey('web_app_${app.id}'),
            app: app,
            isSelected: app.id == selectedAppId,
            onTap: () => onAppSelected(app.id),
          );
        }),
      ],
    );
  }
}
