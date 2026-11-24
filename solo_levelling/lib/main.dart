import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/data/refresh_token_storage.dart';
import 'features/character/data/character_api.dart';
import 'features/character/data/character_repository_impl.dart';
import 'features/dashboard/data/dashboard_api.dart';
import 'features/dashboard/data/dashboard_repository_impl.dart';
import 'features/progression/data/progression_api.dart';
import 'features/progression/data/progression_repository_impl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  const secureStorage = FlutterSecureStorage(
    wOptions: WindowsOptions(useBackwardCompatibility: true),
  );
  final apiClient = ApiClient();
  final authRepository = AuthRepositoryImpl(
    api: AuthApi(apiClient),
    tokenStorage: SecureRefreshTokenStorage(storage: secureStorage),
  );
  apiClient.onAccessTokenExpired = authRepository.refreshAccessToken;
  final characterRepository = CharacterRepositoryImpl(
    api: CharacterApi(apiClient),
  );
  final dashboardRepository = DashboardRepositoryImpl(
    api: DashboardApi(apiClient),
  );
  final progressionRepository = ProgressionRepositoryImpl(
    api: ProgressionApi(apiClient),
  );
  runApp(
    SoloLevelingApp(
      authController: AuthController(authRepository),
      characterRepository: characterRepository,
      dashboardRepository: dashboardRepository,
      progressionRepository: progressionRepository,
    ),
  );
}
