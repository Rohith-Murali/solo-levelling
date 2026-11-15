import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/data/refresh_token_storage.dart';

void main() {
  AppConfig.validate();
  const secureStorage = FlutterSecureStorage();
  final authRepository = AuthRepositoryImpl(
    api: AuthApi(ApiClient()),
    tokenStorage: SecureRefreshTokenStorage(storage: secureStorage),
  );
  runApp(SoloLevelingApp(authController: AuthController(authRepository)));
}
