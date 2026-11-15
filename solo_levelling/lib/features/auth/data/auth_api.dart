import '../../../core/network/api_client.dart';
import '../domain/auth_user.dart';

class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  Future<AuthSession> register(String email, String password) async {
    final response = await _client.postJson(
      'auth/register',
      body: {'email': email, 'password': password},
    );
    return _readSession(response);
  }

  Future<AuthSession> login(String email, String password) async {
    final response = await _client.postJson(
      'auth/login',
      body: {'email': email, 'password': password},
    );
    return _readSession(response);
  }

  Future<AuthSession> refresh(String refreshToken) async {
    final response = await _client.postJson(
      'auth/refresh',
      body: {'refreshToken': refreshToken},
    );
    return _readSession(response);
  }

  Future<void> logout(String refreshToken) async {
    await _client.postJson('auth/logout', body: {'refreshToken': refreshToken});
  }

  Future<AuthUser> getCurrentUser(String accessToken) async {
    final response = await _client.getJson('auth/me', bearerToken: accessToken);
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('The server returned an invalid user response.');
    }
    final userData = data['user'];
    if (userData is! Map<String, dynamic>) {
      throw const ApiException('The server returned an invalid user response.');
    }

    return AuthUser.fromJson(userData);
  }

  AuthSession _readSession(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        'The server returned an invalid session response.',
      );
    }

    final userData = data['user'];
    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];
    if (userData is! Map<String, dynamic> ||
        accessToken is! String ||
        refreshToken is! String) {
      throw const ApiException(
        'The server returned an invalid session response.',
      );
    }

    return AuthSession(
      user: AuthUser.fromJson(userData),
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;
}
