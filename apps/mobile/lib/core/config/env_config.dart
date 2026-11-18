import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppEnvConfig {
  const AppEnvConfig._();

  static const String appName = 'Nam Cinema';
  static const String appTagline = 'Your Cinema. Anywhere.';

  /// Resolves the backend API URL.
  /// Can be overridden at build/run time with `--dart-define=API_BASE_URL=http://192.168.1.100:8000`
  /// Defaults to `http://10.0.2.2:8000` on Android emulators so host machine FastAPI is reachable,
  /// and `http://localhost:8000` on iOS Simulator / desktop.
  static String get apiBaseUrl {
    const defined = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (defined.isNotEmpty) {
      return defined;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  static String get apiV1BaseUrl => '$apiBaseUrl/api/v1';

  static const Duration connectTimeout = Duration(seconds: 12);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration searchDebounceDuration = Duration(milliseconds: 420);
  static const Duration progressSyncInterval = Duration(seconds: 15);
}
