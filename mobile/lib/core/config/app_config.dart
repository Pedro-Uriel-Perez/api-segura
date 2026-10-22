/// Provides environment-specific API configuration.
///
/// Values passed with `--dart-define` are app configuration, not secret storage.
library;

import 'package:flutter/foundation.dart';

/// Holds the base URL for the selected development environment.
class AppConfig {
  /// Prevents creating configuration instances.
  const AppConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Returns the API base URL supplied at build or run time.
  ///
  /// Defaults to the host machine as seen from the Android emulator
  /// (`10.0.2.2`), or `localhost` when running on the web.
  /// Use an HTTPS URL outside local development.
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    return kIsWeb
        ? 'http://localhost:3000/api/v1'
        : 'http://10.0.2.2:3000/api/v1';
  }
}
