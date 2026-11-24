import '../../../core/network/api_client.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_api.dart';
import 'refresh_token_storage.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.api, required this.tokenStorage});

  final AuthApi api;
  final RefreshTokenStorage tokenStorage;
  void Function()? onAccessTokenChanged;
  String? _accessToken;
  Future<String?>? _refreshInFlight;

  @override
  String? get accessToken => _accessToken;

  void _setAccessToken(String? token) {
    if (_accessToken == token) return;
    _accessToken = token;
    onAccessTokenChanged?.call();
  }

  @override
  Future<AuthUser> login(String email, String password) async {
    final session = await api.login(email, password);
    await tokenStorage.write(session.refreshToken);
    _setAccessToken(session.accessToken);
    return session.user;
  }

  @override
  Future<AuthUser> register(String email, String password) async {
    final session = await api.register(email, password);
    await tokenStorage.write(session.refreshToken);
    _setAccessToken(session.accessToken);
    return session.user;
  }

  @override
  Future<AuthUser?> restoreSession() async {
    ApiException? lastTransientError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final accessToken = await refreshAccessToken();
        if (accessToken == null) return null;
        return await api.getCurrentUser(accessToken);
      } on ApiException catch (error) {
        if (error.statusCode == 401) {
          _setAccessToken(null);
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

  /// Refreshes the access token once for all requests that observe an expired
  /// JWT. Refresh token rotation means concurrent refresh calls must share the
  /// same future, otherwise the first call invalidates the token used by the
  /// others.
  Future<String?> refreshAccessToken() {
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await tokenStorage.read();
    if (refreshToken == null) return null;

    try {
      final session = await api.refresh(refreshToken);
      await tokenStorage.write(session.refreshToken);
      _setAccessToken(session.accessToken);
      return session.accessToken;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        _setAccessToken(null);
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
      _setAccessToken(null);
      await tokenStorage.clear();
    }
  }
}
