import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:centralny_dashboard/features/ai/ai_assistant_screen.dart';
import 'package:centralny_dashboard/core/auth/auth_provider.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ],
      child: const MaterialApp(
        home: AIAssistantScreen(),
      ),
    );
  }

  group('AI Assistant & AnythingLLM Frame UI Tests', () {
    testWidgets('Renders AnythingLLM 1:1 Frame Mode by default with controls', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Verify Header Titles
      expect(find.text('AI Asistent / AnythingLLM'), findsOneWidget);
      expect(find.text('AnythingLLM 1:1 Embedded Frame Mode'), findsOneWidget);

      // Verify Mode Toggle Buttons
      expect(find.text('🤖 AnythingLLM (1:1 Frame)'), findsOneWidget);
      expect(find.text('💬 Native Chat'), findsOneWidget);

      // Verify AnythingLLM URL Input and Toolbar
      expect(find.text('URL:'), findsOneWidget);
      expect(find.text('http://localhost:3001'), findsOneWidget);

      // Pump pending timers before test completes
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('Toggles between AnythingLLM 1:1 Frame Mode and Native Chat Mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap on Native Chat tab button
      final nativeChatBtn = find.text('💬 Native Chat');
      expect(nativeChatBtn, findsOneWidget);
      await tester.tap(nativeChatBtn);
      await tester.pumpAndSettle();

      // Verify subtitle switched to Native Supabase Chat Mode
      expect(find.text('Native Supabase Chat Mode'), findsOneWidget);
      expect(find.text('Nový chat'), findsWidgets);

      // Tap back to AnythingLLM Frame Mode
      final anythingLlmBtn = find.text('🤖 AnythingLLM (1:1 Frame)');
      expect(anythingLlmBtn, findsOneWidget);
      await tester.tap(anythingLlmBtn);
      await tester.pumpAndSettle();

      // Verify subtitle switched back to AnythingLLM Frame Mode
      expect(find.text('AnythingLLM 1:1 Embedded Frame Mode'), findsOneWidget);
      expect(find.text('URL:'), findsOneWidget);

      // Pump pending timers before test completes
      await tester.pump(const Duration(milliseconds: 300));
    });
  });
}
