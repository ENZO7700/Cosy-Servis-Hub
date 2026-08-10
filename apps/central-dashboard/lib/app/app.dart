import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/auth_provider.dart';
import '../core/ui/theme.dart';
import 'router.dart';

/// Main application widget
class CentralnyDashboardApp extends StatefulWidget {
  const CentralnyDashboardApp({super.key});

  @override
  State<CentralnyDashboardApp> createState() => _CentralnyDashboardAppState();
}

class _CentralnyDashboardAppState extends State<CentralnyDashboardApp> {
  late final _router = createRouter(context.read<AuthProvider>());

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Centralny Dashboard',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
