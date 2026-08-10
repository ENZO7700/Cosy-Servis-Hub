import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/responsive.dart';
import '../../app/router.dart';
import '../web_apps/providers/web_apps_provider.dart';

class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final webAppsProvider = Provider.of<WebAppsProvider>(context);
    final userProfile = authProvider.profile;
    final enabledWebApps = webAppsProvider.enabledWebApps;

    final String currentRoute = GoRouterState.of(context).matchedLocation;

    // Define core items
    final List<Map<String, dynamic>> coreItems = [
      {
        'title': 'Prehľad',
        'icon': LucideIcons.layoutDashboard,
        'route': AppRoutes.dashboard,
      },
      {
        'title': 'Projekty',
        'icon': LucideIcons.folderKanban,
        'route': AppRoutes.projects,
      },
      {'title': 'Chyby', 'icon': LucideIcons.bug, 'route': AppRoutes.bugs},
      {'title': 'CRM', 'icon': LucideIcons.users, 'route': AppRoutes.crm},
      {'title': 'Leady', 'icon': LucideIcons.inbox, 'route': AppRoutes.leads},
      {'title': 'SEO AI', 'icon': LucideIcons.search, 'route': AppRoutes.seoAi},
      {
        'title': 'Analytika',
        'icon': LucideIcons.barChart2,
        'route': AppRoutes.analytics,
      },
      {
        'title': 'AI Asistent',
        'icon': LucideIcons.bot,
        'route': AppRoutes.aiAssistant,
      },
      {
        'title': 'AutoOps AI',
        'icon': LucideIcons.cpu,
        'route': AppRoutes.autoops,
      },
      {
        'title': 'SALONOS AI',
        'icon': LucideIcons.trendingUp,
        'route': AppRoutes.salonos,
      },
      {
        'title': 'Nastavenia',
        'icon': LucideIcons.settings,
        'route': AppRoutes.settings,
      },
      {
        'title': 'Changelog',
        'icon': LucideIcons.history,
        'route': AppRoutes.changelog,
      },
    ];

    // Determine selection
    int selectedIndex = -1;
    for (int i = 0; i < coreItems.length; i++) {
      final route = coreItems[i]['route'] as String;
      if (route == AppRoutes.dashboard) {
        if (currentRoute == AppRoutes.dashboard) {
          selectedIndex = i;
        }
      } else if (currentRoute.startsWith(route)) {
        selectedIndex = i;
      }
    }

    String? selectedWebAppId;
    if (currentRoute.startsWith('/web-app/')) {
      selectedWebAppId = currentRoute.split('/').last;
    }

    // Active title
    String activeTitle = 'Dashboard';
    if (selectedIndex >= 0) {
      activeTitle = coreItems[selectedIndex]['title'] as String;
    } else if (selectedWebAppId != null) {
      final activeApp = enabledWebApps.firstWhere(
        (app) => app.id == selectedWebAppId,
        orElse: () => enabledWebApps.first,
      );
      activeTitle = activeApp.name;
    }

    return Scaffold(
      body: Responsive(
        mobile: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.35),
            elevation: 0,
            title: Text(
              activeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.logOut, size: 20),
                onPressed: () => authProvider.signOut(),
              ),
            ],
          ),
          drawer: _buildDrawer(
            authProvider,
            webAppsProvider,
            coreItems,
            selectedIndex,
            selectedWebAppId,
          ),
          body: widget.child,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: selectedIndex == 7
                ? 4
                : (selectedIndex > 3
                      ? 0
                      : (selectedIndex < 0 ? 0 : selectedIndex)),
            onTap: (index) {
              if (index == 4) {
                context.go(AppRoutes.aiAssistant);
              } else {
                context.go(coreItems[index]['route'] as String);
              }
            },
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            selectedItemColor: AppTheme.primary,
            unselectedItemColor: AppTheme.textSecondary,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.layoutDashboard),
                label: 'Prehľad',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.folderKanban),
                label: 'Projekty',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.bug),
                label: 'Chyby',
              ),
              BottomNavigationBarItem(
                icon: Icon(LucideIcons.users),
                label: 'CRM',
              ),
              BottomNavigationBarItem(icon: Icon(LucideIcons.bot), label: 'AI'),
            ],
          ),
        ),
        desktop: Row(
          children: [
            // Desktop Sidebar
            Container(
              width: 250,
              decoration: const BoxDecoration(
                color: Color(0x0EFFFFFF),
                border: Border(
                  right: BorderSide(color: Color(0x15FFFFFF), width: 1.0),
                ),
              ),
              child: Column(
                children: [
                  // App logo / header
                  SafeArea(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.shield,
                            color: AppTheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Dashboard',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontSize: 20, letterSpacing: 0.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: Color(0x15FFFFFF)),

                  // Sidebar List
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // Core Items
                        ...List.generate(coreItems.length, (index) {
                          final item = coreItems[index];
                          final isSelected = selectedIndex == index;
                          return _buildSidebarTile(
                            title: item['title'] as String,
                            icon: item['icon'] as IconData,
                            isSelected: isSelected,
                            onTap: () => context.go(item['route'] as String),
                          );
                        }),

                        if (enabledWebApps.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.only(
                              left: 28,
                              top: 16,
                              bottom: 8,
                            ),
                            child: Text(
                              'WEB APLIKÁCIE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          ...enabledWebApps.map((app) {
                            final isSelected = selectedWebAppId == app.id;
                            return _buildSidebarTile(
                              title: app.name,
                              customIcon: app.iconWidget,
                              isSelected: isSelected,
                              onTap: () =>
                                  context.go(AppRoutes.webAppPath(app.id)),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const Divider(color: Color(0x15FFFFFF)),

                  // User Profile card & Sign Out
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.primary.withValues(
                            alpha: 0.2,
                          ),
                          radius: 18,
                          child: Text(
                            (userProfile?.fullName ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userProfile?.fullName ?? 'Používateľ',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                userProfile?.jobTitle ?? 'Vývojár',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            LucideIcons.logOut,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () => authProvider.signOut(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: Scaffold(
                backgroundColor: AppTheme.background,
                body: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarTile({
    required String title,
    IconData? icon,
    Widget? customIcon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: isSelected
              ? AppTheme.activeGlassDecoration(borderRadius: 8)
              : null,
          child: Row(
            children: [
              customIcon ??
                  Icon(
                    icon,
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    size: 18,
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(
    AuthProvider auth,
    WebAppsProvider webApps,
    List<Map<String, dynamic>> coreItems,
    int selectedIndex,
    String? selectedWebAppId,
  ) {
    final userProfile = auth.profile;
    final enabledWebApps = webApps.enabledWebApps;

    return Drawer(
      backgroundColor: const Color(0xFF0F0F11),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.transparent),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppTheme.primary,
              child: Text(
                (userProfile?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
            accountName: Text(userProfile?.fullName ?? 'Používateľ'),
            accountEmail: Text(auth.user?.email ?? ''),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...List.generate(coreItems.length, (index) {
                  final item = coreItems[index];
                  final isSelected = selectedIndex == index;
                  return ListTile(
                    leading: Icon(
                      item['icon'] as IconData,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                    title: Text(
                      item['title'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () {
                      context.go(item['route'] as String);
                      Navigator.pop(context);
                    },
                  );
                }),
                if (enabledWebApps.isNotEmpty) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text(
                      'WEB APLIKÁCIE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  ...enabledWebApps.map((app) {
                    final isSelected = selectedWebAppId == app.id;
                    return ListTile(
                      leading: app.iconWidget,
                      title: Text(
                        app.name,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
                      selected: isSelected,
                      onTap: () {
                        context.go(AppRoutes.webAppPath(app.id));
                        Navigator.pop(context);
                      },
                    );
                  }),
                ],
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(LucideIcons.logOut, color: Colors.redAccent),
            title: const Text(
              'Odhlásiť sa',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () {
              Navigator.pop(context);
              auth.signOut();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
