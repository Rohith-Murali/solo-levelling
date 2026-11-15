import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/',
  );

  static void validate() {
    if (!kReleaseMode) {
      return;
    }

    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError('Release builds require an HTTPS API_BASE_URL.');
    }
  }
}
