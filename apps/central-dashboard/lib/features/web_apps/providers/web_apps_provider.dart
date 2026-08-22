import 'package:flutter/foundation.dart';

import '../models/workspace_web_app.dart';

/// Provider for managing workspace web applications
class WebAppsProvider extends ChangeNotifier {
  List<WorkspaceWebApp> _webApps = [];
  bool _loading = false;
  String? _error;

  WebAppsProvider() {
    _loadFromStorage();
  }

  /// All web apps sorted by position
  List<WorkspaceWebApp> get webApps => List.unmodifiable(
    _webApps..sort((a, b) => a.position.compareTo(b.position)),
  );

  /// Enabled web apps sorted by position
  List<WorkspaceWebApp> get enabledWebApps =>
      webApps.where((app) => app.enabled).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  /// Whether loading
  bool get loading => _loading;

  /// Error message
  String? get error => _error;

  /// Whether there are any web apps
  bool get hasWebApps => _webApps.isNotEmpty;

  /// Whether maximum number of web apps reached
  bool get isMaxReached => enabledWebApps.length >= maxWebApps;

  /// Load web apps from local storage
  Future<void> _loadFromStorage() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Note: Implement actual storage
      // For now, use in-memory storage
      // In production, use shared_preferences or similar
      _webApps = [];
    } catch (e) {
      _error = 'Failed to load web apps: ${e.toString()}';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Save web apps to storage
  Future<void> _saveToStorage() async {
    // Note: Implement actual storage
    // In production, use shared_preferences:
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString(_storageKey, jsonEncode(_webApps.map((app) => app.toJson()).toList()));
  }

  /// Add a new web app
  Future<WorkspaceWebApp?> addWebApp({
    required String name,
    required String url,
    required String icon,
    int? position,
    bool enabled = true,
    bool openExternallyWhenBlocked = true,
    String? homePath,
  }) async {
    if (isMaxReached && enabled) {
      _error = 'Maximum number of web apps ($maxWebApps) reached';
      notifyListeners();
      return null;
    }

    // Validate URL
    final validationError = WorkspaceWebApp.create(
      name: name,
      url: url,
      icon: icon,
      position: position ?? _webApps.length,
      enabled: enabled,
      homePath: homePath,
    ).urlValidationError;

    if (validationError != null) {
      _error = validationError;
      notifyListeners();
      return null;
    }

    final newApp = WorkspaceWebApp.create(
      name: name,
      url: url,
      icon: icon,
      position: position ?? _webApps.length,
      enabled: enabled,
      openExternallyWhenBlocked: openExternallyWhenBlocked,
      homePath: homePath,
    );

    _webApps.add(newApp);
    await _saveToStorage();
    _error = null;
    notifyListeners();

    return newApp;
  }

  /// Update an existing web app
  Future<void> updateWebApp(WorkspaceWebApp updatedApp) async {
    final index = _webApps.indexWhere((app) => app.id == updatedApp.id);
    if (index < 0) return;

    // Validate URL if changed
    if (_webApps[index].url != updatedApp.url) {
      final validationError = updatedApp.urlValidationError;
      if (validationError != null) {
        _error = validationError;
        notifyListeners();
        return;
      }
    }

    _webApps[index] = updatedApp.copyWith(
      updatedAt: DateTime.now(),
      isLocalDev: WorkspaceWebApp.isLocalUrl(updatedApp.url),
    );

    await _saveToStorage();
    _error = null;
    notifyListeners();
  }

  /// Update web app by ID
  Future<void> updateWebAppById({
    required String id,
    String? name,
    String? url,
    String? icon,
    int? position,
    bool? enabled,
    bool? openExternallyWhenBlocked,
    String? homePath,
  }) async {
    final matches = _webApps.where((app) => app.id == id);
    if (matches.isEmpty) return;
    final app = matches.first;

    await updateWebApp(
      app.copyWith(
        name: name,
        url: url,
        icon: icon,
        position: position,
        enabled: enabled,
        openExternallyWhenBlocked: openExternallyWhenBlocked,
        homePath: homePath,
      ),
    );
  }

  /// Delete a web app
  Future<void> deleteWebApp(String id) async {
    _webApps.removeWhere((app) => app.id == id);
    await _saveToStorage();
    notifyListeners();
  }

  /// Get web app by ID
  WorkspaceWebApp? getWebAppById(String id) {
    try {
      return _webApps.firstWhere((app) => app.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get web app by position
  WorkspaceWebApp? getWebAppAtPosition(int position) {
    try {
      return _webApps.firstWhere((app) => app.position == position);
    } catch (_) {
      return null;
    }
  }

  /// Get next available position
  int getNextPosition() {
    if (_webApps.isEmpty) return 0;
    return _webApps.map((app) => app.position).reduce((a, b) => a > b ? a : b) +
        1;
  }

  /// Reorder web apps
  Future<void> reorderWebApps(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      final matches = _webApps.where((app) => app.id == orderedIds[i]);
      if (matches.isNotEmpty) {
        final app = matches.first;
        _webApps[_webApps.indexOf(app)] = app.copyWith(position: i);
      }
    }
    await _saveToStorage();
    notifyListeners();
  }

  /// Enable/disable web app
  Future<void> setEnabled(String id, bool enabled) async {
    if (enabled && isMaxReached) {
      _error = 'Maximum number of enabled web apps ($maxWebApps) reached';
      notifyListeners();
      return;
    }

    final matches = _webApps.where((app) => app.id == id);
    if (matches.isEmpty) return;
    final app = matches.first;

    _webApps[_webApps.indexOf(app)] = app.copyWith(
      enabled: enabled,
      updatedAt: DateTime.now(),
    );

    await _saveToStorage();
    _error = null;
    notifyListeners();
  }

  /// Get web apps as JSON list
  List<Map<String, dynamic>> toJsonList() {
    return _webApps.map((app) => app.toJson()).toList();
  }

  /// Load from JSON list
  void fromJsonList(List<Map<String, dynamic>> jsonList) {
    _webApps = jsonList.map((json) => WorkspaceWebApp.fromJson(json)).toList();
    notifyListeners();
  }

  /// Clear all web apps
  Future<void> clearAll() async {
    _webApps.clear();
    await _saveToStorage();
    notifyListeners();
  }

  /// Get default web apps for new installations
  static List<WorkspaceWebApp> get defaultWebApps {
    return [];
  }

  @override
  void dispose() {
    _webApps.clear();
    super.dispose();
  }
}
