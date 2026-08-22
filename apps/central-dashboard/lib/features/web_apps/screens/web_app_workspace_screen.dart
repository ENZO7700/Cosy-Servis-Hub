import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/web_apps_provider.dart';
import '../widgets/web_app_workspace.dart';
import '../../../core/ui/theme.dart';

class WebAppWorkspaceScreen extends StatelessWidget {
  final String appId;

  const WebAppWorkspaceScreen({super.key, required this.appId});

  @override
  Widget build(BuildContext context) {
    return Consumer<WebAppsProvider>(
      builder: (context, provider, child) {
        final app = provider.getWebAppById(appId);

        if (app == null) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                  SizedBox(height: 16),
                  Text(
                    'Aplikácia sa nenašla',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: WebAppWorkspace(app: app),
        );
      },
    );
  }
}
