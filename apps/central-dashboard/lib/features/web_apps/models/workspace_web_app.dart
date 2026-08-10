import 'package:flutter/material.dart';

/// Model for workspace web applications
/// These are user-configurable web apps that appear in the sidebar
class WorkspaceWebApp {
  /// Unique identifier
  final String id;

  /// Display name of the web app
  final String name;

  /// URL of the web app
  final String url;

  /// Icon identifier (Material icon name or emoji)
  final String icon;

  /// Position in the sidebar (lower = higher)
  final int position;

  /// Whether this web app is enabled
  final bool enabled;

  /// Whether to open in new tab when iframe is blocked
  final bool openExternallyWhenBlocked;

  /// Home path for the web app
  final String? homePath;

  /// Whether this is a local development URL
  final bool isLocalDev;

  /// Timestamp when created
  final DateTime createdAt;

  /// Timestamp when last updated
  final DateTime updatedAt;

  const WorkspaceWebApp({
    required this.id,
    required this.name,
    required this.url,
    required this.icon,
    required this.position,
    required this.enabled,
    this.openExternallyWhenBlocked = true,
    this.homePath,
    this.isLocalDev = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new web app with current timestamps
  factory WorkspaceWebApp.create({
    String? id,
    required String name,
    required String url,
    required String icon,
    required int position,
    bool enabled = true,
    bool openExternallyWhenBlocked = true,
    String? homePath,
  }) {
    return WorkspaceWebApp(
      id: id ?? _generateId(name),
      name: name,
      url: url,
      icon: icon,
      position: position,
      enabled: enabled,
      openExternallyWhenBlocked: openExternallyWhenBlocked,
      homePath: homePath,
      isLocalDev: isLocalUrl(url),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Generate ID from name
  static String _generateId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'__+'), '_')
        .trim();
  }

  /// Check if URL is local development
  static bool isLocalUrl(String url) {
    final normalized = url.toLowerCase().trim();
    return normalized.startsWith('http://localhost') ||
        normalized.startsWith('http://127.0.0.1') ||
        normalized.startsWith('https://localhost') ||
        normalized.startsWith('https://127.0.0.1') ||
        normalized.startsWith('http://[::1]') ||
        normalized.startsWith('https://[::1]') ||
        normalized.startsWith('http://0.0.0.0') ||
        normalized.startsWith('https://0.0.0.0');
  }

  /// Create from JSON
  factory WorkspaceWebApp.fromJson(Map<String, dynamic> json) {
    return WorkspaceWebApp(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      openExternallyWhenBlocked:
          json['open_externally_when_blocked'] as bool? ?? true,
      homePath: json['home_path'] as String?,
      isLocalDev: json['is_local_dev'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'icon': icon,
      'position': position,
      'enabled': enabled,
      'open_externally_when_blocked': openExternallyWhenBlocked,
      'home_path': homePath,
      'is_local_dev': isLocalDev,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  WorkspaceWebApp copyWith({
    String? id,
    String? name,
    String? url,
    String? icon,
    int? position,
    bool? enabled,
    bool? openExternallyWhenBlocked,
    String? homePath,
    bool? isLocalDev,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkspaceWebApp(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      icon: icon ?? this.icon,
      position: position ?? this.position,
      enabled: enabled ?? this.enabled,
      openExternallyWhenBlocked:
          openExternallyWhenBlocked ?? this.openExternallyWhenBlocked,
      homePath: homePath ?? this.homePath,
      isLocalDev: isLocalDev ?? this.isLocalDev,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Get full URL (url + homePath)
  String get fullUrl {
    if (homePath == null || homePath!.isEmpty) return url;
    final normalizedUrl = url.endsWith('/') ? url : '$url/';
    final normalizedPath = homePath!.startsWith('/')
        ? homePath!.substring(1)
        : homePath!;
    return '$normalizedUrl$normalizedPath';
  }

  /// Validate URL
  bool get isValidUrl {
    // Allow empty for new apps
    if (url.isEmpty) return false;

    // Allow localhost for development
    if (isLocalDev) return true;

    // Must start with https://
    if (!url.startsWith('https://')) return false;

    // Must have a valid domain
    try {
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) return false;
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get URL validation error message
  String? get urlValidationError {
    if (url.isEmpty) return 'URL is required';
    if (!isLocalDev && !url.startsWith('https://')) {
      return 'URL must start with https://';
    }

    try {
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) return 'Invalid URL format';
    } catch (_) {
      return 'Invalid URL format';
    }

    return null;
  }

  /// Get icon widget
  Widget get iconWidget {
    // If icon is an emoji, display as text
    if (isEmoji(icon)) {
      return Text(icon, style: const TextStyle(fontSize: 20));
    }

    // Otherwise, treat as Material icon name
    return Icon(WebAppIcons.getIconData(icon) ?? Icons.web);
  }

  /// Check if string is emoji
  static bool isEmoji(String text) {
    // Simple check: if it's a single character that's not alphanumeric
    if (text.length == 1) {
      final code = text.runes.first;
      // Emoji ranges
      return (code >= 0x1F300 && code <= 0x1F6FF) ||
          (code >= 0x1F1E0 && code <= 0x1F1FF) ||
          (code >= 0x2600 && code <= 0x26FF) ||
          (code >= 0x2700 && code <= 0x27BF);
    }
    return false;
  }

  @override
  String toString() {
    return 'WorkspaceWebApp{'
        'id: $id, '
        'name: $name, '
        'url: $url, '
        'enabled: $enabled, '
        'position: $position'
        '}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkspaceWebApp && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Predefined icon options for web apps
class WebAppIcons {
  static IconData? getIconData(String name) {
    switch (name) {
      case 'dashboard':
        return Icons.dashboard;
      case 'people':
        return Icons.people;
      case 'work':
        return Icons.work;
      case 'business':
        return Icons.business;
      case 'analytics':
        return Icons.analytics;
      case 'insert_chart':
        return Icons.insert_chart;
      case 'code':
        return Icons.code;
      case 'developer_mode':
        return Icons.developer_mode;
      case 'design_services':
        return Icons.design_services;
      case 'web':
        return Icons.web;
      case 'computer':
        return Icons.computer;
      case 'build':
        return Icons.build;
      case 'settings':
        return Icons.settings;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'store':
        return Icons.store;
      case 'description':
        return Icons.description;
      case 'assignment':
        return Icons.assignment;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'email':
        return Icons.email;
      case 'chat':
        return Icons.chat;
      case 'forum':
        return Icons.forum;
      default:
        return null;
    }
  }

  static const List<String> materialIcons = [
    'dashboard',
    'people',
    'work',
    'business',
    'analytics',
    'insert_chart',
    'code',
    'developer_mode',
    'design_services',
    'web',
    'computer',
    'build',
    'settings',
    'shopping_cart',
    'store',
    'description',
    'assignment',
    'calendar_today',
    'email',
    'chat',
    'forum',
  ];

  static const List<String> emojiIcons = [
    '📊',
    '👥',
    '💼',
    '🏢',
    '📈',
    '📉',
    '💻',
    '👨‍💻',
    '🎨',
    '🌐',
    '🖥️',
    '🔧',
    '⚙️',
    '🛒',
    '🏪',
    '📄',
    '📝',
    '📅',
    '✉️',
    '💬',
    '🗣️',
  ];

  static List<String> get allIcons => [...materialIcons, ...emojiIcons];
}

/// Maximum number of web apps
const maxWebApps = 3;
