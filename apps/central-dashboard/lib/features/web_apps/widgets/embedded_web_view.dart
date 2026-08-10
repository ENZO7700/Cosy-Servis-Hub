import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workspace_web_app.dart';

/// Widget for displaying embedded web content with toolbar
class EmbeddedWebView extends StatefulWidget {
  final WorkspaceWebApp app;
  final String? initialUrl;

  const EmbeddedWebView({super.key, required this.app, this.initialUrl});

  @override
  State<EmbeddedWebView> createState() => _EmbeddedWebViewState();
}

class _EmbeddedWebViewState extends State<EmbeddedWebView> {
  String? _currentUrl;
  bool _isLoading = true;
  String? _error;
  final bool _canGoBack = false;
  final bool _canGoForward = false;
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl ?? widget.app.fullUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        const Divider(height: 1),
        Expanded(child: _buildWebContent()),
      ],
    );
  }

  Widget _buildToolbar() {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          // App icon and name
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Row(
              children: [
                _buildAppIcon(),
                const SizedBox(width: 8),
                Text(
                  widget.app.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // URL bar
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.language, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentUrl ?? widget.app.fullUrl,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Navigation buttons
          _buildNavigationButton(
            icon: Icons.home,
            tooltip: 'Home',
            onPressed: _goHome,
          ),
          _buildNavigationButton(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            onPressed: _canGoBack ? _goBack : null,
          ),
          _buildNavigationButton(
            icon: Icons.arrow_forward,
            tooltip: 'Forward',
            onPressed: _canGoForward ? _goForward : null,
          ),
          // Refresh
          _buildNavigationButton(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          // External open
          _buildNavigationButton(
            icon: Icons.open_in_new,
            tooltip: 'Open in new tab',
            onPressed: _openInNewTab,
          ),
          // Status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildStatusIndicator(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon() {
    final isEmoji = WorkspaceWebApp.isEmoji(widget.app.icon);
    return isEmoji
        ? Text(widget.app.icon, style: const TextStyle(fontSize: 20))
        : Icon(WebAppIcons.getIconData(widget.app.icon) ?? Icons.web, size: 20);
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      disabledColor: Colors.grey.shade400,
    );
  }

  Widget _buildStatusIndicator() {
    if (_error != null) {
      return Tooltip(
        message: _error!,
        child: Icon(Icons.error_outline, color: Colors.red, size: 20),
      );
    }
    if (_isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(Icons.check_circle, color: Colors.green, size: 20);
  }

  Widget _buildWebContent() {
    // Web implementation would use HtmlElementView
    // For mobile, would use webview_flutter

    // For now, show a placeholder
    // In production, implement platform-specific web view

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            if (widget.app.openExternallyWhenBlocked)
              TextButton.icon(
                onPressed: _openInNewTab,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in new tab'),
              ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.web, size: 64, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            widget.app.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            widget.app.fullUrl,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          const Text(
            'Web View will be displayed here',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openInNewTab,
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open in Browser'),
          ),
        ],
      ),
    );
  }

  void _goHome() {
    setState(() {
      _currentUrl = widget.app.fullUrl;
      _history.clear();
      _error = null;
      _isLoading = true;
    });
    // In production: call web view controller goHome
  }

  void _goBack() {
    if (!_canGoBack) return;
    setState(() {
      _isLoading = true;
    });
    // In production: call web view controller goBack
  }

  void _goForward() {
    if (!_canGoForward) return;
    setState(() {
      _isLoading = true;
    });
    // In production: call web view controller goForward
  }

  void _refresh() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    // In production: call web view controller reload
  }

  Future<void> _openInNewTab() async {
    final url = _currentUrl ?? widget.app.fullUrl;
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      setState(() {
        _error = 'Could not open URL';
      });
    }
  }
}

/// Widget for displaying workspace web app content
class WorkspaceWebAppView extends StatelessWidget {
  final WorkspaceWebApp app;

  const WorkspaceWebAppView({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(app.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in new tab',
            onPressed: () async {
              if (await canLaunchUrl(Uri.parse(app.fullUrl))) {
                await launchUrl(Uri.parse(app.fullUrl));
              }
            },
          ),
        ],
      ),
      body: EmbeddedWebView(app: app),
    );
  }
}
