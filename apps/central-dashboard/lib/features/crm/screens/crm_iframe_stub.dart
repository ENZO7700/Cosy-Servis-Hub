import 'package:flutter/material.dart';
import '../../../core/ui/theme.dart';

Widget createCrmIFrameWidget(String url) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CRM modul je dostupný vo webovej verzii aplikácie.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SelectableText(
            url,
            style: const TextStyle(color: AppTheme.primary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
