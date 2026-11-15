import '../../../core/network/api_client.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_api.dart';
import 'refresh_token_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.api, required this.tokenStorage});

  final AuthApi api;
  final RefreshTokenStorage tokenStorage;
  String? _accessToken;

  @override
  String? get accessToken => _accessToken;

  @override
  Future<AuthUser> login(String email, String password) async {
    final session = await api.login(email, password);
    await tokenStorage.write(session.refreshToken);
    _accessToken = session.accessToken;
    return session.user;
  }

  @override
  Future<AuthUser> register(String email, String password) async {
    final session = await api.register(email, password);
    await tokenStorage.write(session.refreshToken);
    _accessToken = session.accessToken;
    return session.user;
  }

  @override
  Future<AuthUser?> restoreSession() async {
    final refreshToken = await tokenStorage.read();
    if (refreshToken == null) {
      return null;
    }

    try {
      final session = await api.refresh(refreshToken);
      await tokenStorage.write(session.refreshToken);
      _accessToken = session.accessToken;
      return await api.getCurrentUser(session.accessToken);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _accessToken = null;
        await tokenStorage.clear();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = await tokenStorage.read();
    try {
      if (refreshToken != null) {
        await api.logout(refreshToken);
      }
    } finally {
      _accessToken = null;
      await tokenStorage.clear();
    }
  }
}
