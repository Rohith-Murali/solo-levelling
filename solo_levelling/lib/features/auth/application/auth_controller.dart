import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

enum AuthStatus { initializing, signedOut, signedIn }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.isBusy = false,
  });

  final AuthStatus status;
  final AuthUser? user;
  final String? errorMessage;
  final bool isBusy;
}

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;
  AuthState _state = const AuthState(status: AuthStatus.initializing);

  AuthState get state => _state;
  String? get accessToken => _repository.accessToken;

  void notifyAccessTokenChanged() {
    if (_repository.accessToken == null &&
        _state.status == AuthStatus.signedIn) {
      _setState(
        const AuthState(
          status: AuthStatus.signedOut,
          errorMessage: 'Your session expired. Please sign in again.',
        ),
      );
      return;
    }
    notifyListeners();
  }

  Future<void> restoreSession() async {
    try {
      final user = await _repository.restoreSession();
      _setState(
        user == null
            ? const AuthState(status: AuthStatus.signedOut)
            : AuthState(status: AuthStatus.signedIn, user: user),
      );
    } on ApiException catch (error) {
      _setState(
        AuthState(status: AuthStatus.signedOut, errorMessage: error.message),
      );
    } catch (error, stackTrace) {
      _reportUnexpectedError(error, stackTrace);
      _setState(
        const AuthState(
          status: AuthStatus.signedOut,
          errorMessage: 'Unable to restore your session. Please sign in.',
        ),
      );
    }
  }

  Future<void> login(String email, String password) {
    return _runAuthAction(() => _repository.login(email, password));
  }

  Future<void> register(String email, String password) {
    return _runAuthAction(() => _repository.register(email, password));
  }

  Future<void> logout() async {
    _setState(
      AuthState(status: _state.status, user: _state.user, isBusy: true),
    );

    try {
      await _repository.logout();
      _setState(const AuthState(status: AuthStatus.signedOut));
    } on ApiException catch (error) {
      _setState(
        AuthState(status: AuthStatus.signedOut, errorMessage: error.message),
      );
    } catch (error, stackTrace) {
      _reportUnexpectedError(error, stackTrace);
      _setState(
        const AuthState(
          status: AuthStatus.signedOut,
          errorMessage:
              'You were signed out, but the session could not be revoked.',
        ),
      );
    }
  }

  void markCharacterCreated() {
    final user = _state.user;
    if (_state.status == AuthStatus.signedIn && user != null) {
      _setState(
        AuthState(
          status: AuthStatus.signedIn,
          user: user.copyWith(hasCharacter: true),
        ),
      );
    }
  }

  void markCharacterMissing() {
    final user = _state.user;
    if (_state.status == AuthStatus.signedIn && user != null) {
      _setState(
        AuthState(
          status: AuthStatus.signedIn,
          user: user.copyWith(hasCharacter: false),
        ),
      );
    }
  }

  Future<void> _runAuthAction(Future<AuthUser> Function() action) async {
    _setState(
      AuthState(status: _state.status, user: _state.user, isBusy: true),
    );

    try {
      final user = await action();
      _setState(AuthState(status: AuthStatus.signedIn, user: user));
    } on ApiException catch (error) {
      _setState(
        AuthState(status: AuthStatus.signedOut, errorMessage: error.message),
      );
    } catch (error, stackTrace) {
      _reportUnexpectedError(error, stackTrace);
      _setState(
        const AuthState(
          status: AuthStatus.signedOut,
          errorMessage: 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  void _reportUnexpectedError(Object error, StackTrace stackTrace) {
    AppLogger.unexpected('authentication', error, stackTrace);
  }

  void _setState(AuthState value) {
    _state = value;
    notifyListeners();
  }
}
