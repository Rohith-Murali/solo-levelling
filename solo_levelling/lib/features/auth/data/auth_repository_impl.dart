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
    final storedRefreshToken = await tokenStorage.read();
    if (storedRefreshToken == null) {
      return null;
    }
    var refreshToken = storedRefreshToken;

    ApiException? lastTransientError;
    AuthSession? session;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        session ??= await api.refresh(refreshToken);
        if (_accessToken != session.accessToken) {
          await tokenStorage.write(session.refreshToken);
          _accessToken = session.accessToken;
        }
        return await api.getCurrentUser(session.accessToken);
      } on ApiException catch (error) {
        if (error.statusCode == 401) {
          // Another app instance may have rotated the token while this
          // startup was restoring its session. Prefer the newer persisted
          // token before treating the session as invalid.
          final latestToken = await tokenStorage.read();
          if (latestToken != null && latestToken != refreshToken) {
            refreshToken = latestToken;
            session = null;
            continue;
          }
          _accessToken = null;
          await tokenStorage.clear();
          return null;
        }

        final isTransient =
            error.statusCode == null || error.statusCode! >= 500;
        if (!isTransient || attempt == 2) {
          rethrow;
        }
        lastTransientError = error;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }

    throw lastTransientError ??
        const ApiException('Unable to restore your session.');
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
