import 'auth_user.dart';

abstract interface class AuthRepository {
  String? get accessToken;

  Future<AuthUser?> restoreSession();

  Future<AuthUser> login(String email, String password);

  Future<AuthUser> register(String email, String password);

  Future<void> logout();
}
