import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:centralny_dashboard/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Centralny Dashboard E2E Tests', () {
    testWidgets(
      'Complete user workflow: login, create bug, chat with AI, update profile, and logout',
      (WidgetTester tester) async {
        // 1. Start the application
        app.main();
        await tester.pumpAndSettle();

        // Verify we are on the login screen
        expect(find.text('Prihlásenie'), findsOneWidget);
        expect(find.text('Registrácia'), findsOneWidget);

        // 2. Fill login details (mocked automatically under INTEGRATION_TEST flag)
        final emailField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'you@example.com',
        );
        final passwordField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '••••••••',
        );

        expect(emailField, findsOneWidget);
        expect(passwordField, findsOneWidget);

        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'password123');
        await tester.pumpAndSettle();

        // Tap login button
        final loginBtn = find.widgetWithText(ElevatedButton, 'Prihlásiť sa');
        expect(loginBtn, findsOneWidget);
        await tester.tap(loginBtn);

        // Wait for login process and transition to Dashboard
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Verify we are now logged in and looking at the Dashboard
        expect(find.text('Prehľad'), findsOneWidget);
        expect(find.text('Nahlásiť chybu'), findsOneWidget);

        // 3. Create a new bug
        final reportBugBtn = find.widgetWithText(
          ElevatedButton,
          'Nahlásiť chybu',
        );
        await tester.tap(reportBugBtn);
        await tester.pumpAndSettle();

        // Fill bug form details
        final titleField = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Stručný popis problému...',
        );
        final descField = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Detailný popis chyby, čo sa deje...',
        );

        await tester.enterText(titleField, 'E2E Test Bug Title');
        await tester.enterText(
          descField,
          'This bug was created automatically by our E2E test suite.',
        );
        await tester.pumpAndSettle();

        // Submit bug
        final submitBugBtn = find.widgetWithText(
          ElevatedButton,
          'Odoslať chybu',
        );
        await tester.tap(submitBugBtn);
        await tester.pumpAndSettle();

        // Verify toast snackbar appears and screen is popped back to Dashboard
        expect(find.text('Chyba bola úspešne nahlásená'), findsOneWidget);
        await tester.pumpAndSettle(
          const Duration(seconds: 3),
        ); // Wait for snackbar to disappear

        // Verify the new bug is displayed in the list/table
        expect(find.text('E2E Test Bug Title'), findsOneWidget);

        // 4. Navigate to AI Assistant
        final aiSidebarItem = find.descendant(
          of: find.byType(ListView),
          matching: find.text('AI Asistent'),
        );
        await tester.tap(aiSidebarItem);
        await tester.pumpAndSettle();

        // Verify we are in AI Assistant view
        expect(find.text('AI Asistent'), findsOneWidget);

        // Select the first conversation, which gets automatically loaded in mock mode
        expect(find.text('Optimalizácia Isar databázy'), findsOneWidget);

        // Find prompt input and type a question
        final aiInputField = find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.hintText == 'Položte otázku...',
        );
        await tester.enterText(
          aiInputField,
          'How do I optimize local storage?',
        );
        await tester.pumpAndSettle();

        // Send the message
        final sendBtn = find.byIcon(LucideIcons.send);
        await tester.tap(sendBtn);
        await tester.pumpAndSettle();

        // Wait for mock AI response delay
        await tester.pumpAndSettle(const Duration(milliseconds: 1000));

        // Verify mock response is visible on the screen
        expect(
          find.textContaining('How do I optimize local storage?'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Toto je simulovaná odpoveď na:'),
          findsOneWidget,
        );

        // 5. Navigate to Settings
        final settingsSidebarItem = find.descendant(
          of: find.byType(ListView),
          matching: find.text('Nastavenia'),
        );
        await tester.tap(settingsSidebarItem);
        await tester.pumpAndSettle();

        // Verify settings screen is active
        expect(find.text('Nastavenia'), findsOneWidget);
        expect(find.text('Môj profil'), findsOneWidget);

        // Update Full Name in settings
        final nameField = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Meno a priezvisko...',
        );
        await tester.enterText(nameField, 'E2E Updated User Name');
        await tester.pumpAndSettle();

        // Click save profile button
        final saveSettingsBtn = find.widgetWithText(
          ElevatedButton,
          'Uložiť zmeny',
        );
        await tester.tap(saveSettingsBtn);
        await tester.pumpAndSettle();

        // Verify success snackbar
        expect(find.text('Profil úspešne uložený'), findsOneWidget);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // 6. Sign out
        final logoutBtn = find.byIcon(LucideIcons.logOut);
        await tester.tap(logoutBtn.first);
        await tester.pumpAndSettle();

        // Verify we are back to the AuthScreen
        expect(find.text('Prihlásenie'), findsOneWidget);
      },
    );
    group('Navigation and Layout validation', () {
      testWidgets('Side menu tabs rendering', (WidgetTester tester) async {
        app.main();
        await tester.pumpAndSettle();

        // Perform login
        final emailField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'you@example.com',
        );
        final passwordField = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == '••••••••',
        );
        await tester.enterText(emailField, 'test@example.com');
        await tester.enterText(passwordField, 'password123');
        await tester.pumpAndSettle();

        final loginBtn = find.widgetWithText(ElevatedButton, 'Prihlásiť sa');
        await tester.tap(loginBtn);
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Verify side navigation is populated with all sections
        final sidebarListView = find.byType(ListView).first;
        expect(
          find.descendant(of: sidebarListView, matching: find.text('Prehľad')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sidebarListView, matching: find.text('Projekty')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sidebarListView,
            matching: find.text('Zoznam chýb'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sidebarListView,
            matching: find.text('Analytika'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sidebarListView,
            matching: find.text('AI Asistent'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sidebarListView,
            matching: find.text('Nastavenia'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: sidebarListView,
            matching: find.text('Changelog'),
          ),
          findsOneWidget,
        );
      });
    });
  });
}
