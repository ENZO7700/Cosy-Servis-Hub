import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_provider.dart';

// Screens
import '../features/auth/auth_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/bugs/bugs_list_screen.dart';
import '../features/bugs/bug_detail_screen.dart';
import '../features/bugs/bug_create_screen.dart';
import '../features/crm/screens/crm_dashboard_screen.dart';
import '../features/seo_ai/seo_ai_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/ai/ai_assistant_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/changelog/changelog_screen.dart';
import '../features/leads/lead_pipeline_screen.dart';
import '../features/leads/lead_inbox_screen.dart';
import '../features/leads/lead_detail_screen.dart';
import '../features/web_apps/screens/web_app_workspace_screen.dart';

import '../features/autoops/screens/autoops_dashboard_screen.dart';
import '../features/autoops/screens/autoops_inbox_screen.dart';
import '../features/autoops/screens/autoops_workflow_builder_screen.dart';
import '../features/autoops/screens/autoops_integrations_screen.dart';
import '../features/autoops/screens/autoops_analytics_screen.dart';
import '../features/salonos/presentation/salonos_dashboard_page.dart';

// ignore_for_file: constant_identifier_names

/// Application route configuration
class AppRoutes {
  static const String auth = '/auth';
  static const String dashboard = '/';
  static const String autoops = '/autoops';
  static const String salonos = '/salonos';

  static const String projects = '/projects';
  static const String bugs = '/bugs';
  static const String bugDetail = '/bugs/:id';
  static const String bugCreate = '/bugs/create';

  static const String crm = '/crm';
  static const String crmClient = '/crm/clients/:id';

  static const String leads = '/leads';
  static const String leadInbox = '/leads/inbox';
  static const String leadDetail = '/leads/:id';

  static const String seoAi = '/seo-ai';
  static const String analytics = '/analytics';
  static const String aiAssistant = '/ai-assistant';
  static const String settings = '/settings';
  static const String changelog = '/changelog';
  static const String webApp = '/web-app/:appId';

  static String leadDetailPath(String leadId) => '/leads/$leadId';
  static String crmClientPath(String clientId) => '/crm/clients/$clientId';
  static String bugDetailPath(String bugId) => '/bugs/$bugId';
  static String webAppPath(String appId) => '/web-app/$appId';
}

class NavigationIndex {
  static const int dashboard = 0;
  static const int projects = 1;
  static const int bugs = 2;
  static const int crm = 3;
  static const int seoAi = 4;
  static const int analytics = 5;
  static const int aiAssistant = 6;
  static const int settings = 7;
  static const int changelog = 8;
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

/// Create router configuration
GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.dashboard,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final bool isAuthenticated = authProvider.isAuthenticated;
      final bool isLoggingIn = state.matchedLocation == AppRoutes.auth;

      if (!isAuthenticated && !isLoggingIn) {
        return AppRoutes.auth;
      }

      if (isAuthenticated && isLoggingIn) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.auth,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AuthScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.projects,
            builder: (context, state) => const ProjectsScreen(),
          ),
          GoRoute(
            path: AppRoutes.bugs,
            builder: (context, state) => const BugsListScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const BugCreateScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return BugDetailScreen(bugId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.crm,
            builder: (context, state) => const CrmDashboardScreen(),
            routes: [
              GoRoute(
                path: 'clients/:id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return CrmDashboardScreen(selectedClientId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.leads,
            builder: (context, state) => const LeadPipelineScreen(),
            routes: [
              GoRoute(
                path: 'inbox',
                builder: (context, state) => const LeadInboxScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return LeadDetailScreen(leadId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.seoAi,
            builder: (context, state) => const SeoAiScreen(),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: AppRoutes.aiAssistant,
            builder: (context, state) => const AIAssistantScreen(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.changelog,
            builder: (context, state) => const ChangelogScreen(),
          ),
          GoRoute(
            path: AppRoutes.autoops,
            builder: (context, state) => const AutoOpsDashboardScreen(),
            routes: [
              GoRoute(
                path: 'inbox',
                builder: (context, state) => const AutoOpsInboxScreen(),
              ),
              GoRoute(
                path: 'builder',
                builder: (context, state) => const AutoOpsWorkflowBuilderScreen(),
              ),
              GoRoute(
                path: 'integrations',
                builder: (context, state) => const AutoOpsIntegrationsScreen(),
              ),
              GoRoute(
                path: 'analytics',
                builder: (context, state) => const AutoOpsAnalyticsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.salonos,
            builder: (context, state) => const SalonosDashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.webApp,
            builder: (context, state) {
              final appId = state.pathParameters['appId']!;
              return WebAppWorkspaceScreen(appId: appId);
            },
          ),
        ],
      ),
    ],
  );
}
