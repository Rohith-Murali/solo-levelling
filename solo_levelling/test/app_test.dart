import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:solo_levelling/app/app.dart';
import 'package:solo_levelling/app/theme/app_colors.dart';
import 'package:solo_levelling/core/network/api_client.dart';
import 'package:solo_levelling/features/auth/application/auth_controller.dart';
import 'package:solo_levelling/features/auth/domain/auth_repository.dart';
import 'package:solo_levelling/features/auth/domain/auth_user.dart';

void main() {
  test('resolves API paths below the configured base URI', () async {
    final mockClient = MockClient((request) async {
      expect(request.url.path, '/api/auth/login');
      expect(request.method, 'POST');
      expect(request.headers['authorization'], 'Bearer access-token');
      expect(jsonDecode(request.body), {
        'email': 'hunter@example.com',
        'password': 'password123',
      });
      return http.Response(
        jsonEncode({
          'data': {'status': 'ok'},
        }),
        200,
      );
    });
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:3000/api/'),
      client: mockClient,
    );

    await apiClient.postJson(
      'auth/login',
      body: {'email': 'hunter@example.com', 'password': 'password123'},
      bearerToken: 'access-token',
    );
    mockClient.close();
  });

  test('maps API error responses to ApiException', () async {
    final mockClient = MockClient((_) async {
      return http.Response(
        jsonEncode({
          'error': {
            'code': 'INVALID_CREDENTIALS',
            'message': 'Invalid email or password.',
          },
        }),
        401,
      );
    });
    final apiClient = ApiClient(
      baseUri: Uri.parse('http://localhost:3000/api/'),
      client: mockClient,
    );

    await expectLater(
      apiClient.getJson('auth/me'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.code, 'code', 'INVALID_CREDENTIALS'),
      ),
    );
    mockClient.close();
  });

  testWidgets('renders login and opens registration', (tester) async {
    final controller = AuthController(_FakeAuthRepository());
    await tester.pumpWidget(SoloLevelingApp(authController: controller));
    await tester.pumpAndSettle();

    expect(find.text('SYSTEM ACCESS'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      AppColors.background,
    );

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('register-confirm-password')),
      findsOneWidget,
    );
  });

  testWidgets('successful registration opens the welcome screen', (
    tester,
  ) async {
    final controller = AuthController(_FakeAuthRepository());
    await tester.pumpWidget(SoloLevelingApp(authController: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('register-email')),
      'hunter@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-password')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const ValueKey('register-confirm-password')),
      'password123',
    );
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('WELCOME, HUNTER'), findsOneWidget);
    expect(find.text('hunter@example.com'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  String? get accessToken => null;

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser> login(String email, String password) async {
    return AuthUser(id: 'test-user', email: email);
  }

  @override
  Future<AuthUser> register(String email, String password) async {
    return AuthUser(id: 'test-user', email: email);
  }

  @override
  Future<void> logout() async {}
}
