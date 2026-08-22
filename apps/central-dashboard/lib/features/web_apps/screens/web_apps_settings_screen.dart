import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workspace_web_app.dart';
import '../providers/web_apps_provider.dart';

/// Screen for managing workspace web applications
class WebAppsSettingsScreen extends StatefulWidget {
  const WebAppsSettingsScreen({super.key});

  @override
  State<WebAppsSettingsScreen> createState() => _WebAppsSettingsScreenState();
}

class _WebAppsSettingsScreenState extends State<WebAppsSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _homePathController = TextEditingController();

  String _selectedIcon = WebAppIcons.allIcons.first;
  bool _showForm = false;
  String? _editingId;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _homePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WebAppsProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Web Apps Settings'),
            actions: [
              if (provider.enabledWebApps.length < maxWebApps)
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add Web App',
                  onPressed: () => _showAddForm(provider),
                ),
            ],
          ),
          body: _buildBody(provider),
        );
      },
    );
  }

  Widget _buildBody(WebAppsProvider provider) {
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final webApps = provider.webApps;

    if (webApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.web, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No web apps configured',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add web apps to display them in the sidebar',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddForm(provider),
              icon: const Icon(Icons.add),
              label: const Text('Add Web App'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (provider.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  provider.error!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ),
          ),
        if (_showForm) _buildWebAppForm(provider),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: webApps.length,
            itemBuilder: (context, index) {
              final app = webApps[index];
              return _buildWebAppItem(context, provider, app, index);
            },
            onReorderItem: (oldIndex, newIndex) async {
              final orderedIds = List<String>.from(
                webApps.map((app) => app.id),
              );
              orderedIds.insert(newIndex, orderedIds.removeAt(oldIndex));
              await provider.reorderWebApps(orderedIds);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWebAppItem(
    BuildContext context,
    WebAppsProvider provider,
    WorkspaceWebApp app,
    int index,
  ) {
    return Card(
      key: ValueKey(app.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildAppIcon(app),
        title: Text(app.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              app.url,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (app.homePath != null && app.homePath!.isNotEmpty)
              Text(
                'Home: ${app.homePath}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: app.enabled,
              onChanged: (value) => provider.setEnabled(app.id, value),
              activeThumbColor: Colors.blue,
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              tooltip: 'Edit',
              onPressed: () => _showEditForm(provider, app),
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              tooltip: 'Delete',
              color: Colors.red,
              onPressed: () => _confirmDelete(context, provider, app),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppIcon(WorkspaceWebApp app) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: _isEmoji(app.icon)
            ? Text(app.icon, style: const TextStyle(fontSize: 24))
            : Icon(WebAppIcons.getIconData(app.icon) ?? Icons.web, size: 24),
      ),
    );
  }

  bool _isEmoji(String text) {
    return WorkspaceWebApp.isEmoji(text);
  }

  void _showAddForm(WebAppsProvider provider) {
    setState(() {
      _showForm = true;
      _editingId = null;
      _nameController.clear();
      _urlController.clear();
      _homePathController.clear();
      _selectedIcon = WebAppIcons.allIcons.first;
    });
  }

  void _showEditForm(WebAppsProvider provider, WorkspaceWebApp app) {
    setState(() {
      _showForm = true;
      _editingId = app.id;
      _nameController.text = app.name;
      _urlController.text = app.url;
      _homePathController.text = app.homePath ?? '';
      _selectedIcon = app.icon;
    });
  }

  Widget _buildWebAppForm(WebAppsProvider provider) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _editingId == null ? 'Add Web App' : 'Edit Web App',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _showForm = false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g., My CRM',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.help_outline),
                    tooltip: 'Must start with https:// (except localhost)',
                    onPressed: () {},
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a URL';
                  }
                  final testApp = WorkspaceWebApp.create(
                    name: 'test',
                    url: value,
                    icon: 'web',
                    position: 0,
                  );
                  return testApp.urlValidationError;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _homePathController,
                decoration: const InputDecoration(
                  labelText: 'Home Path (optional)',
                  hintText: '/dashboard',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Icon', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildIconSelector(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _showForm = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _submitForm(provider),
                    child: Text(_editingId == null ? 'Add' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: WebAppIcons.allIcons.map((icon) {
        final isSelected = _selectedIcon == icon;
        return GestureDetector(
          onTap: () => setState(() => _selectedIcon = icon),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected ? Colors.blue.shade50 : Colors.transparent,
            ),
            child: Center(
              child: _isEmoji(icon)
                  ? Text(icon, style: const TextStyle(fontSize: 20))
                  : Icon(WebAppIcons.getIconData(icon) ?? Icons.web, size: 20),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _submitForm(WebAppsProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (_editingId == null) {
        // Add new
        final position = provider.getNextPosition();
        await provider.addWebApp(
          name: _nameController.text.trim(),
          url: _urlController.text.trim(),
          icon: _selectedIcon,
          position: position,
          homePath: _homePathController.text.trim().isEmpty
              ? null
              : _homePathController.text.trim(),
        );
      } else {
        // Update existing
        await provider.updateWebAppById(
          id: _editingId!,
          name: _nameController.text.trim(),
          url: _urlController.text.trim(),
          icon: _selectedIcon,
          homePath: _homePathController.text.trim().isEmpty
              ? null
              : _homePathController.text.trim(),
        );
      }

      setState(() => _showForm = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WebAppsProvider provider,
    WorkspaceWebApp app,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Web App'),
          content: Text('Are you sure you want to delete "${app.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await provider.deleteWebApp(app.id);
    }
  }
}
