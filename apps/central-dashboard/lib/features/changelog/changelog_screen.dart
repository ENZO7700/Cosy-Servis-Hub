import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/ui/theme.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = [
      {
        'version': 'v1.1.0',
        'date': '21.05.2026',
        'title': 'AI Assistant & Realtime Updates',
        'changes': [
          'Pridaný inteligentný AI asistent pre analýzu chýb na základe Supabase dát.',
          'Implementované realtime websocket pripojenie na databázu (okamžité zmeny bez načítania).',
          'Vytvorený nový dashboard s vizualizáciou stavov cez stĺpcové a koláčové grafy.',
        ],
        'color': AppTheme.primary,
      },
      {
        'version': 'v1.0.1',
        'date': '15.05.2026',
        'title': 'WordPress REST Gateway',
        'changes': [
          'Integrovaná synchronizácia projektov a notifikácií cez WordPress verejné REST API.',
          'Opravené ukladanie profilov pri prihlasovaní cez Google Authentication.',
          'Vylepšený filter projektov v hornej časti hlavného prehľadu.',
        ],
        'color': AppTheme.success,
      },
      {
        'version': 'v1.0.0',
        'date': '10.05.2026',
        'title': 'Počiatočné vydanie (Release)',
        'changes': [
          'Spustený plne funkčný Issue Shepherd Pro s Firebase Authentication.',
          'Pridaný Kanban board pre riadenie stavu chýb (Nová, Priradená, V riešení, Testovanie, Vyriešená).',
          'Podpora pre detailné nahlasovanie s krokmi reprodukcie, prostredím a závažnosťou.',
        ],
        'color': AppTheme.info,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Changelog',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'História verzií a prehľad zmien vykonaných v systéme.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 24),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              itemBuilder: (context, i) {
                final log = logs[i];
                final changes = log['changes'] as List<String>;
                final color = log['color'] as Color;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timeline indicator
                      Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 2,
                              color: i == logs.length - 1
                                  ? Colors.transparent
                                  : const Color(0x15FFFFFF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),

                      // Content Card
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Container(
                            decoration: AppTheme.glassDecoration(),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: color.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        log['version'] as String,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      log['date'] as String,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  log['title'] as String,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...changes.map(
                                  (c) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(
                                            top: 4.0,
                                            right: 8.0,
                                          ),
                                          child: Icon(
                                            LucideIcons.check,
                                            size: 10,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            c,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.textSecondary,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
