import 'package:flutter/widgets.dart';

class AppConfig {
  static bool get isTest {
    return const bool.fromEnvironment(
          'INTEGRATION_TEST',
          defaultValue: false,
        ) ||
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
  }

  static const String supabaseUrl = String.fromEnvironment(
    'VITE_SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'VITE_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String firebaseApiKey = String.fromEnvironment(
    'VITE_FIREBASE_API_KEY',
    defaultValue: '',
  );
  static const String firebaseAuthDomain = String.fromEnvironment(
    'VITE_FIREBASE_AUTH_DOMAIN',
    defaultValue: '',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'VITE_FIREBASE_PROJECT_ID',
    defaultValue: '',
  );
  static const String firebaseStorageBucket = String.fromEnvironment(
    'VITE_FIREBASE_STORAGE_BUCKET',
    defaultValue: '',
  );
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'VITE_FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '',
  );
  static const String firebaseAppId = String.fromEnvironment(
    'VITE_FIREBASE_APP_ID',
    defaultValue: '',
  );
  static const String firebaseMeasurementId = String.fromEnvironment(
    'VITE_FIREBASE_MEASUREMENT_ID',
    defaultValue: '',
  );

  static const String wordpressPublicSiteUrl = String.fromEnvironment(
    'VITE_WORDPRESS_PUBLIC_SITE_URL',
    defaultValue: '',
  );

  static const String salonosApiBaseUrl = String.fromEnvironment(
    'VITE_SALONOS_API_BASE_URL',
    defaultValue: '',
  );
  static const String salonosProviderId = String.fromEnvironment(
    'VITE_SALONOS_PROVIDER_ID',
    defaultValue: '',
  );

  static const String crmFrameUrl = String.fromEnvironment(
    'CRM_FRAME_URL',
    defaultValue: 'https://nexify-crm-clean-v1.vercel.app/crm',
  );

  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }
}
