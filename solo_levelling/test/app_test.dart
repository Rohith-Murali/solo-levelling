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
import 'package:solo_levelling/features/character/domain/character_options.dart';
import 'package:solo_levelling/features/character/domain/character_repository.dart';

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
    await tester.pumpWidget(
      SoloLevelingApp(
        authController: controller,
        characterRepository: _FakeCharacterRepository(),
      ),
    );
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

  testWidgets('new account completes character creation before welcome', (
    tester,
  ) async {
    final repository = _FakeCharacterRepository();
    final controller = AuthController(_FakeAuthRepository());
    await tester.pumpWidget(
      SoloLevelingApp(
        authController: controller,
        characterRepository: repository,
      ),
    );
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

    expect(find.text('CHARACTER INITIALIZATION'), findsOneWidget);
    expect(find.text('WELCOME, HUNTER'), findsNothing);

    await tester.tap(find.text('Initialize Character'));
    await tester.pumpAndSettle();
    final nameField = find.byKey(const ValueKey('character-name'));
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, 'Sung');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final focusSkill = find.text('Focus');
    await tester.ensureVisible(focusSkill);
    await tester.tap(focusSkill);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Review your character'), findsOneWidget);
    expect(find.text('Sung'), findsOneWidget);
    expect(find.text('E'), findsOneWidget);

    final createButton = find.text('Create Character');
    await tester.ensureVisible(createButton);
    await tester.tap(createButton);
    await tester.pumpAndSettle();

    expect(repository.createdName, 'Sung');
    expect(repository.createdAvatarId, 'avatar-01');
    expect(repository.createdSkillId, 'focus');
    expect(find.text('WELCOME, HUNTER'), findsOneWidget);
  });

  testWidgets('returning account with a character opens welcome directly', (
    tester,
  ) async {
    final controller = AuthController(_FakeAuthRepository());
    await tester.pumpWidget(
      SoloLevelingApp(
        authController: controller,
        characterRepository: _FakeCharacterRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('login-email')),
      'hunter@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'password123',
    );
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('WELCOME, HUNTER'), findsOneWidget);
    expect(find.text('CHARACTER INITIALIZATION'), findsNothing);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  String? get accessToken => 'access-token';

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser> login(String email, String password) async {
    return AuthUser(id: 'test-user', email: email, hasCharacter: true);
  }

  @override
  Future<AuthUser> register(String email, String password) async {
    return AuthUser(id: 'test-user', email: email);
  }

  @override
  Future<void> logout() async {}
}

class _FakeCharacterRepository implements CharacterRepository {
  String? createdName;
  String? createdAvatarId;
  String? createdSkillId;

  @override
  Future<CharacterOptions> getOptions(String accessToken) async {
    return const CharacterOptions(
      avatars: [
        CharacterAvatar(
          id: 'avatar-01',
          name: 'Avatar 1',
          imagePath: 'avatars/Avatar 1.png',
        ),
      ],
      startingSkills: [
        StartingSkill(
          id: 'programming',
          name: 'Programming',
          description: 'Build software.',
        ),
        StartingSkill(
          id: 'focus',
          name: 'Focus',
          description: 'Train attention.',
        ),
      ],
      initialProgression: InitialProgression(
        level: 1,
        xp: 0,
        rank: 'E',
        skillUnlockTokens: 0,
        skillLevel: 1,
        skillXp: 0,
      ),
    );
  }

  @override
  Future<void> createCharacter({
    required String accessToken,
    required String name,
    required String avatarId,
    required String startingSkillId,
  }) async {
    createdName = name;
    createdAvatarId = avatarId;
    createdSkillId = startingSkillId;
  }
}
