import 'package:backend_client/backend_client.dart';

import '../core/config/app_config.dart';

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  final PrefsAuthenticationKeyManager authKeyManager =
      PrefsAuthenticationKeyManager();

  // ignore: deprecated_member_use
  late final Client client = Client(
    AppConfig.apiBaseUrl,
    // ignore: deprecated_member_use
    authenticationKeyManager: authKeyManager,
  );
}
