import 'package:flutter/foundation.dart';

class AppConfig {
  /// Priority:
  /// 1) --dart-define=SERVERPOD_URL=...
  /// 2) Auto local URL when app is opened from localhost/127.0.0.1/0.0.0.0
  /// 3) Production default URL
  static String get apiBaseUrl {
    const fromDefine = String.fromEnvironment('SERVERPOD_URL');
    if (fromDefine.isNotEmpty) return fromDefine;

    if (!kIsWeb) {
      if (!kReleaseMode) {
        return 'http://localhost:8080/';
      }

      return 'https://api.nstu-medical.com/';
    }

    final host = Uri.base.host.toLowerCase();
    final isLocalHost =
        host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';

    if (isLocalHost) {
      return 'http://localhost:8080/';
    }

    return 'https://api.nstu-medical.com/';
  }
}
