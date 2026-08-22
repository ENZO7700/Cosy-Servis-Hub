/// State and repository providers for AutoOps AI using package:provider.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/autoops/domain.dart';
import '../data/autoops_agent_repository.dart';
import '../data/autoops_analytics_repository.dart';
import '../data/autoops_dashboard_repository.dart';
import '../data/autoops_inbox_repository.dart';
import '../data/autoops_integrations_repository.dart';
import '../data/autoops_workflows_repository.dart';

const String _persistKey = 'autoops-app-store-v1';

class AutoOpsAppUiProvider extends ChangeNotifier {
  AgentMode _agentMode = AgentMode.fullyAutonomous;
  bool _sidebarCollapsed = false;
  String? _installPromptDismissedAt;

  AgentMode get agentMode => _agentMode;
  bool get sidebarCollapsed => _sidebarCollapsed;
  String? get installPromptDismissedAt => _installPromptDismissedAt;

  AutoOpsAppUiProvider() {
    _hydrate();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_persistKey);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _agentMode = AgentMode.fromValue(json['agentMode'] as String? ?? AgentMode.fullyAutonomous.value);
        _sidebarCollapsed = json['sidebarCollapsed'] as bool? ?? false;
        _installPromptDismissedAt = json['installPromptDismissedAt'] as String?;
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'agentMode': _agentMode.value,
      'sidebarCollapsed': _sidebarCollapsed,
      if (_installPromptDismissedAt != null) 'installPromptDismissedAt': _installPromptDismissedAt,
    };
    await prefs.setString(_persistKey, jsonEncode(data));
  }

  void setAgentMode(AgentMode mode) {
    _agentMode = mode;
    notifyListeners();
    _persist();
  }

  void toggleSidebar() {
    _sidebarCollapsed = !_sidebarCollapsed;
    notifyListeners();
    _persist();
  }

  void dismissInstallPrompt() {
    _installPromptDismissedAt = DateTime.now().toIso8601String();
    notifyListeners();
    _persist();
  }
}

class AutoOpsStateProvider extends ChangeNotifier {
  InboxCategory? _selectedInboxCategory;
  WorkflowNode? _selectedWorkflowNode;
  WorkflowGraph? _activeWorkflow;
  bool _agentSidebarOpen = true;

  InboxCategory? get selectedInboxCategory => _selectedInboxCategory;
  WorkflowNode? get selectedWorkflowNode => _selectedWorkflowNode;
  WorkflowGraph? get activeWorkflow => _activeWorkflow;
  bool get agentSidebarOpen => _agentSidebarOpen;

  final AutoOpsAgentRepository agentRepository = const AutoOpsAgentRepository();
  final AutoOpsAnalyticsRepository analyticsRepository = const AutoOpsAnalyticsRepository();
  final AutoOpsDashboardRepository dashboardRepository = const AutoOpsDashboardRepository();
  final AutoOpsInboxRepository inboxRepository = AutoOpsInboxRepository();
  final AutoOpsIntegrationsRepository integrationsRepository = AutoOpsIntegrationsRepository();
  final AutoOpsWorkflowsRepository workflowsRepository = AutoOpsWorkflowsRepository();

  void setSelectedInboxCategory(InboxCategory? category) {
    _selectedInboxCategory = category;
    notifyListeners();
  }

  void setSelectedWorkflowNode(WorkflowNode? node) {
    _selectedWorkflowNode = node;
    notifyListeners();
  }

  void setActiveWorkflow(WorkflowGraph? graph) {
    _activeWorkflow = graph;
    notifyListeners();
  }

  void toggleAgentSidebar() {
    _agentSidebarOpen = !_agentSidebarOpen;
    notifyListeners();
  }
}
