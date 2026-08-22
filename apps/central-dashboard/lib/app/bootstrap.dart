import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/auth/auth_provider.dart';
import '../core/database/data_provider.dart';
import '../features/crm/providers/crm_provider.dart';
import '../features/crm/providers/lead_inbox_provider.dart';
import '../features/web_apps/providers/web_apps_provider.dart';
import '../features/crm/providers/lead_pipeline_provider.dart';
import 'app.dart';

/// Bootstrap function to initialize and run the application
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services directly inside the Providers lazy loaders or constructor,
  // but to prevent race conditions on startup, we do it in the provider.

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<DataProvider>(create: (_) => DataProvider()),
        ChangeNotifierProvider<CrmProvider>(create: (_) => CrmProvider()),
        ChangeNotifierProvider<LeadInboxProvider>(
          create: (_) => LeadInboxProvider(),
        ),
        ChangeNotifierProvider<WebAppsProvider>(
          create: (_) => WebAppsProvider(),
        ),
        ChangeNotifierProvider<LeadPipelineProvider>(
          create: (_) => LeadPipelineProvider(),
        ),
      ],
      child: const CentralnyDashboardApp(),
    ),
  );
}
