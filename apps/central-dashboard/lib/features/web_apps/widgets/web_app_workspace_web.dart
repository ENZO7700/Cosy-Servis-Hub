// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/workspace_web_app.dart';

/// Web-specific implementation for embedded web apps
/// Uses HtmlElementView with unique element IDs per app
class WebAppWorkspace extends StatefulWidget {
  final WorkspaceWebApp app;
  final String? initialUrl;

  const WebAppWorkspace({super.key, required this.app, this.initialUrl});

  @override
  State<WebAppWorkspace> createState() => _WebAppWorkspaceState();
}

class _WebAppWorkspaceState extends State<WebAppWorkspace> {
  String? _currentUrl;
  bool _isLoading = true;
  String? _error;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isBlocked = false;
  final List<String> _history = [];
  int _historyIndex = -1;

  // Unique element ID for this web app
  late String _elementId;

  // Iframe element reference
  web.HTMLIFrameElement? _iframeElement;

  @override
  void initState() {
    super.initState();
    _elementId = 'web_app_frame_${widget.app.id}';
    _currentUrl = widget.initialUrl ?? widget.app.fullUrl;
    _setupIframe();
  }

  @override
  void didUpdateWidget(WebAppWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app.id != widget.app.id) {
      _elementId = 'web_app_frame_${widget.app.id}';
      _reloadIframe();
    }
  }

  @override
  void dispose() {
    _cleanupIframe();
    super.dispose();
  }

  /// Setup iframe with unique ID
  void _setupIframe() {
    try {
      // Create a unique iframe element
      _iframeElement = web.HTMLIFrameElement()
        ..id = _elementId
        ..setAttribute('style', 'border: none; width: 100%; height: 100%;')
        ..allow = _getSandboxAllow()
        ..setAttribute('sandbox', _getSandboxAttributes())
        ..referrerPolicy = 'no-referrer-when-downgrade';

      // Set initial source
      _loadUrl(_currentUrl ?? widget.app.fullUrl);

      // Setup load event listener
      _iframeElement?.addEventListener(
        'load',
        ((web.Event event) {
          setState(() {
            _isLoading = false;
          });
        }).toJS,
      );

      // Setup error event listener
      _iframeElement?.addEventListener(
        'error',
        ((web.Event event) {
          setState(() {
            _isLoading = false;
            _error = 'Failed to load content';
          });
        }).toJS,
      );

      // Setup message listener for postMessage
      web.window.addEventListener('message', _handleMessage.toJS);
    } catch (e) {
      setState(() {
        _error = 'Error initializing web view: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Get sandbox attributes
  String _getSandboxAttributes() {
    // Start with restrictive sandbox
    final attributes = [
      'allow-same-origin', // Allow same-origin content
      'allow-scripts', // Allow scripts to run
      'allow-forms', // Allow form submission
    ];

    // If the app needs more permissions, they should be explicitly added
    // For maximum security, we start restrictive and only enable what's needed

    return attributes.join(' ');
  }

  /// Get allow attributes for iframe
  String _getSandboxAllow() {
    // These are the permissions granted to the iframe
    // Start with minimal permissions
    final permissions = [
      // 'accelerometer',
      // 'camera',
      // 'geolocation',
      // 'gyroscope',
      // 'magnetometer',
      // 'microphone',
      // 'midi',
      // 'payment',
      // 'usb',
      // 'vr',
    ];

    return permissions.join(';');
  }

  /// Load URL in iframe
  void _loadUrl(String url) {
    try {
      _currentUrl = url;
      _iframeElement?.src = url;
      setState(() {
        _isLoading = true;
        _error = null;
        _isBlocked = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading URL: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Reload iframe
  void _reloadIframe() {
    if (_currentUrl != null) {
      _loadUrl(_currentUrl!);
    }
  }

  /// Cleanup iframe
  void _cleanupIframe() {
    try {
      _iframeElement?.remove();
      _iframeElement = null;
      web.window.removeEventListener('message', _handleMessage.toJS);
    } catch (_) {
      // Ignore cleanup errors
    }
  }

  /// Handle postMessage events
  void _handleMessage(web.Event event) {
    try {
      final messageEvent = event as web.MessageEvent;
      final origin = messageEvent.origin;

      // Validate origin against allowlist
      if (!_isOriginAllowed(origin)) {
        return; // Silently ignore messages from untrusted origins
      }

      final data = messageEvent.data as JSObject;
      final typeJs = data.getProperty('type'.toJS);
      final type = typeJs.isUndefinedOrNull
          ? null
          : (typeJs as JSString).toDart;

      // Handle specific message types
      if (type == 'navigation') {
        final pathJs = data.getProperty('path'.toJS);
        final path = pathJs.isUndefinedOrNull
            ? null
            : (pathJs as JSString).toDart;
        if (path != null) {
          setState(() {
            _currentUrl = _getFullUrl(path);
          });
        }
      }

      if (type == 'canGoBack') {
        final valJs = data.getProperty('value'.toJS);
        setState(() {
          _canGoBack = valJs.isUndefinedOrNull
              ? false
              : (valJs as JSBoolean).toDart;
        });
      }

      if (type == 'canGoForward') {
        final valJs = data.getProperty('value'.toJS);
        setState(() {
          _canGoForward = valJs.isUndefinedOrNull
              ? false
              : (valJs as JSBoolean).toDart;
        });
      }

      if (type == 'pageTitle') {
        // Could update tab title if needed
      }

      if (type == 'error') {
        final msgJs = data.getProperty('message'.toJS);
        setState(() {
          _error = msgJs.isUndefinedOrNull ? null : (msgJs as JSString).toDart;
        });
      }
    } catch (_) {
      // Ignore invalid messages
    }
  }

  /// Check if origin is allowed
  bool _isOriginAllowed(String origin) {
    // Parse origin
    try {
      final uri = Uri.parse(origin);
      final host = uri.host.toLowerCase();

      // Allow messages from the app's own origin
      try {
        final appUri = Uri.parse(widget.app.url);
        final appHost = appUri.host.toLowerCase();
        if (host == appHost || host.endsWith('.$appHost')) {
          return true;
        }
      } catch (_) {
        // If app URL is invalid, don't allow any messages
      }

      // Allow localhost for development
      if (host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '[::1]' ||
          host == '0.0.0.0') {
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get full URL from path
  String _getFullUrl(String path) {
    try {
      final baseUri = Uri.parse(widget.app.url);
      final fullUrl =
          '${baseUri.scheme}://${baseUri.host}${path.isEmpty ? '' : (path.startsWith('/') ? path : '/$path')}';
      return fullUrl;
    } catch (_) {
      return widget.app.fullUrl;
    }
  }

  /// Go to home
  void _goHome() {
    _loadUrl(widget.app.fullUrl);
    _history.clear();
    _historyIndex = -1;
  }

  /// Send message to iframe
  void _sendMessage(Map<String, dynamic> message) {
    try {
      if (_iframeElement != null && _iframeElement?.contentWindow != null) {
        final origin = widget.app.fullUrl;
        _iframeElement!.contentWindow!.postMessage(
          message.jsify(),
          origin.toJS,
        );
      }
    } catch (_) {
      // Ignore message send errors
    }
  }

  /// Go back
  void _goBack() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _loadUrl(_history[_historyIndex]);
    }
    // Also send message to iframe
    _sendMessage({'type': 'navigate', 'direction': 'back'});
  }

  /// Go forward
  void _goForward() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _loadUrl(_history[_historyIndex]);
    }
    // Also send message to iframe
    _sendMessage({'type': 'navigate', 'direction': 'forward'});
  }

  /// Refresh
  void _refresh() {
    _sendMessage({'type': 'reload'});
  }

  /// Open in new tab
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

  /// Toggle fullscreen
  void _toggleFullscreen() {
    // In production, implement fullscreen logic
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fullscreen not implemented yet')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only build for web platform
    // For mobile, return a message

    // Check if we're on web
    if (kIsWeb) {
      // We're on web, but iframe element might not be ready yet
      if (_iframeElement == null) {
        return const Center(child: CircularProgressIndicator());
      }

      return Column(
        children: [
          _buildToolbar(),
          const Divider(height: 1),
          Expanded(child: _buildWebView()),
        ],
      );
    }

    // For non-web platforms, show fallback
    return Column(
      children: [
        _buildToolbar(),
        const Divider(height: 1),
        Expanded(
          child: Center(
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
                const Text(
                  'Web view is only available on web platform',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _openInNewTab,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in Browser'),
                ),
              ],
            ),
          ),
        ),
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
          _buildNavigationButton(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          _buildNavigationButton(
            icon: Icons.open_in_new,
            tooltip: 'Open in new tab',
            onPressed: _openInNewTab,
          ),
          _buildNavigationButton(
            icon: Icons.fullscreen,
            tooltip: 'Fullscreen',
            onPressed: _toggleFullscreen,
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
    if (_isBlocked) {
      return Tooltip(
        message: 'Iframe blocked by CSP/X-Frame-Options',
        child: Icon(Icons.block, color: Colors.orange, size: 20),
      );
    }
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

  Widget _buildWebView() {
    try {
      // Register the iframe element
      ui_web.platformViewRegistry.registerViewFactory(_elementId, (int viewId) {
        return _iframeElement!;
      });

      return HtmlElementView(
        viewType: _elementId,
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Web view is not available',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'This web app may be blocking iframe embedding',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (widget.app.openExternallyWhenBlocked)
              FilledButton.icon(
                onPressed: _openInNewTab,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in Browser'),
              ),
          ],
        ),
      );
    }
  }

  void _onPlatformViewCreated(int id) {
    // View created, we can now safely set state
    setState(() {
      _isLoading = false;
    });
  }
}
