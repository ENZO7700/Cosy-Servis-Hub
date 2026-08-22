import 'package:flutter/material.dart';
import '../models/workspace_web_app.dart';

class WebAppWorkspace extends StatefulWidget {
  final WorkspaceWebApp app;
  final String? initialUrl;

  const WebAppWorkspace({super.key, required this.app, this.initialUrl});

  @override
  State<WebAppWorkspace> createState() => _WebAppWorkspaceState();
}

class _WebAppWorkspaceState extends State<WebAppWorkspace> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Web aplikácia "${widget.app.name}" nie je na tejto platforme podporovaná.',
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}
