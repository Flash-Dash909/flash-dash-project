import 'package:flutter/foundation.dart';

class ApiConfig {
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _productionBaseUrl =
      'https://flash-dash-project-7.onrender.com';

  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured.replaceFirst(RegExp(r'/+$'), '');
    }

    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      final isLocal = host.isEmpty || host == 'localhost' || host == '127.0.0.1';
      if (!isLocal) return _productionBaseUrl;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }
}
