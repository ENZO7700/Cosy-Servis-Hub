// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:centralny_dashboard/core/database/isar_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel = MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '.';
        });
  });

  test(
    'Test Isar initialization in headless environment with mocked path',
    () async {
      final isarService = IsarService();
      try {
        await isarService.init();
        final instance = isarService.isar;
        print('Isar instance opened successfully: $instance');
      } catch (e) {
        print('Isar failed to open: $e');
      }
    },
  );
}
