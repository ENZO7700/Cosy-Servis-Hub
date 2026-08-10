import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import 'package:centralny_dashboard/core/ui/theme.dart';
import 'package:centralny_dashboard/core/database/isar_service.dart';
import 'package:centralny_dashboard/features/crm/providers/crm_provider.dart';
import 'package:centralny_dashboard/features/crm/screens/crm_dashboard_screen.dart';

void main() {
  group('CRM UI & Widget Tests', () {
    setUpAll(() async {
      GoogleFonts.config.allowRuntimeFetching = false;
      IsarService.isMock = true;
      const MethodChannel channel = MethodChannel(
        'plugins.flutter.io/path_provider',
      );
      final tempDir = Directory.systemTemp.createTempSync('isar_test_crm_ui_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            return tempDir.path;
          });
      await Isar.initializeIsarCore(download: true);

      // Initialize Isar default DB
      final isarService = IsarService();
      await isarService.init();
    });

    tearDownAll(() {
      IsarService.isMock = false;
    });

    testWidgets(
      'CRM Dashboard renders and handles client CRUD/Tasks/Timeline workflows',
      (WidgetTester tester) async {
        // Set desktop-like size
        tester.view.physicalSize = const Size(1280, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Wrap with provider
        final crmProvider = CrmProvider();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: ChangeNotifierProvider<CrmProvider>.value(
              value: crmProvider,
              child: const Scaffold(body: CrmDashboardScreen()),
            ),
          ),
        );

        // Wait until initial loading is complete to avoid CircularProgressIndicator animation timeout
        await tester.runAsync(() async {
          while (crmProvider.loading) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        });
        await tester.pumpAndSettle();

        // 1. Verify dashboard initial state renders successfully
        expect(find.textContaining('CRM'), findsAtLeastNWidgets(1));
        expect(find.text('Pridať klienta'), findsOneWidget);

        // 2. Open Create Client Dialog
        final addClientBtn = find.byKey(const Key('add_client_button'));
        expect(addClientBtn, findsOneWidget);
        await tester.tap(addClientBtn);
        await tester.pumpAndSettle();

        // Verify dialog is opened
        expect(find.text('Pridať nového klienta'), findsOneWidget);

        // Fill in details
        await tester.enterText(
          find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.hintText == 'Napr. Acme Corp s.r.o.',
          ),
          'Nexify Test Company',
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (w) =>
                w is TextField && w.decoration?.hintText == 'Napr. Ján Kováč',
          ),
          'John Doe',
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.hintText == 'Napr. Web Development',
          ),
          'Test Web Development',
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.hintText == 'Napr. info@firma.sk',
          ),
          'john@nexify.test',
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.hintText == 'Napr. 2500',
          ),
          '4500',
        );
        await tester.pumpAndSettle();

        // Submit Dialog
        final submitBtn = find.widgetWithText(
          ElevatedButton,
          'Vytvoriť klienta',
        );
        await tester.tap(submitBtn);

        await tester.runAsync(() async {
          while (crmProvider.clients.isEmpty) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        });
        await tester.pumpAndSettle();
        // Switch to CRM Klienti tab
        await tester.tap(find.text('CRM Klienti'));
        await tester.pumpAndSettle();

        // Verify client added to the list
        expect(find.text('Nexify Test Company'), findsOneWidget);

        // 3. Select Client to open Detail Pane
        await tester.tap(find.text('Nexify Test Company'));
        await tester.pumpAndSettle();

        // Verify Detail Pane content
        expect(find.text('Karta Klienta'), findsOneWidget);
        expect(find.text('Firma: '), findsOneWidget);
        expect(
          find.text('Nexify Test Company'),
          findsNWidgets(2),
        ); // Card + Detail Pane

        // 4. Add Task checklist item
        final taskInput = find.byKey(const Key('add_task_input'));
        expect(taskInput, findsOneWidget);
        await tester.enterText(taskInput, 'Zmluva a záloha');
        await tester.pumpAndSettle();

        final taskSubmitBtn = find.byKey(const Key('add_task_submit'));
        await tester.tap(taskSubmitBtn);

        await tester.runAsync(() async {
          while (crmProvider.clients.first.tasks.isEmpty) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        });
        await tester.pumpAndSettle();

        // Verify task appeared
        expect(find.text('Zmluva a záloha'), findsOneWidget);

        // Toggle checkbox
        final checkbox = find.byType(Checkbox).first;
        await tester.tap(checkbox);
        await tester.pumpAndSettle();

        // 5. Add Activity Log
        final activityInput = find.byKey(const Key('add_activity_input'));
        expect(activityInput, findsOneWidget);
        await tester.enterText(
          activityInput,
          'Telefonát ohľadom zmluvy - dohodnuté podmienky.',
        );
        await tester.pumpAndSettle();

        // Select 'call' chip
        final callChip = find.text('Hovor');
        await tester.tap(callChip);
        await tester.pumpAndSettle();

        final activitySubmitBtn = find.byKey(const Key('add_activity_submit'));
        await tester.tap(activitySubmitBtn);

        // Wait for asynchronous DB operations and timeline update
        await tester.runAsync(() async {
          final client = crmProvider.clients.first;
          while (true) {
            final acts = await crmProvider.getActivitiesForClient(client.id);
            if (acts.any(
              (a) =>
                  a.content ==
                  'Telefonát ohľadom zmluvy - dohodnuté podmienky.',
            )) {
              break;
            }
            await Future.delayed(const Duration(milliseconds: 50));
          }
        });
        await tester.pumpAndSettle();

        // 6. Search filtering
        final searchInput = find.byKey(const Key('crm_search_input'));
        await tester.enterText(searchInput, 'NonExistentCompany');
        await tester.pumpAndSettle();

        // Verify list is empty (only 1 widget remains in Detail Pane, card is hidden)
        expect(find.text('Nexify Test Company'), findsOneWidget);

        // Clear search
        await tester.enterText(searchInput, '');
        await tester.pumpAndSettle();
        // Both card and Detail Pane should be visible now
        expect(find.text('Nexify Test Company'), findsNWidgets(2));
      },
    );
  });
}
