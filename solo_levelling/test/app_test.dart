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
import 'package:solo_levelling/features/dashboard/domain/dashboard_data.dart';
import 'package:solo_levelling/features/dashboard/domain/dashboard_repository.dart';
import 'package:solo_levelling/features/progression/domain/progression_data.dart';
import 'package:solo_levelling/features/progression/domain/progression_repository.dart';

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
        dashboardRepository: _FakeDashboardRepository(),
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

  testWidgets('new account completes character creation before dashboard', (
    tester,
  ) async {
    final repository = _FakeCharacterRepository();
    final controller = AuthController(_FakeAuthRepository());
    await tester.pumpWidget(
      SoloLevelingApp(
        authController: controller,
        characterRepository: repository,
        dashboardRepository: _FakeDashboardRepository(),
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
    expect(find.text('PLAYER STATUS'), findsOneWidget);
    expect(find.text('ACTIVE QUESTS'), findsOneWidget);
    expect(find.text('No active quests detected.'), findsOneWidget);
    final recentActivity = find.text('RECENT ACTIVITY');
    await tester.scrollUntilVisible(
      recentActivity,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(recentActivity, findsOneWidget);
  });

  testWidgets('returning account with a character opens dashboard directly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AuthController(_FakeAuthRepository());
    await tester.pumpWidget(
      SoloLevelingApp(
        authController: controller,
        characterRepository: _FakeCharacterRepository(),
        dashboardRepository: _FakeDashboardRepository(),
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

    expect(find.text('PLAYER STATUS'), findsOneWidget);
    expect(find.text('Hunter'), findsNWidgets(2));
    expect(find.text('CHARACTER INITIALIZATION'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary navigation screens use the connected repositories', (
    tester,
  ) async {
    final progressionRepository = _FakeProgressionRepository();
    final controller = AuthController(_FakeAuthRepository());
    await tester.pumpWidget(
      SoloLevelingApp(
        authController: controller,
        characterRepository: _FakeCharacterRepository(),
        dashboardRepository: _FakeDashboardRepository(),
        progressionRepository: progressionRepository,
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

    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    expect(find.text('GOALS'), findsOneWidget);
    expect(find.text('COMPLETED QUESTS'), findsNothing);

    await tester.tap(find.text('Skills'));
    await tester.pumpAndSettle();
    expect(find.text('SKILL LIBRARY'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);

    await tester.tap(find.text('Character'));
    await tester.pumpAndSettle();
    expect(find.text('CHARACTER STATUS'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('HISTORY & ANALYTICS'), findsOneWidget);
    expect(find.text('COMPLETED QUESTS'), findsNothing);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardData> load(String accessToken) async {
    return const DashboardData(
      character: DashboardCharacter(
        id: 'character-id',
        name: 'Hunter',
        avatarId: 'avatar-01',
        avatarImagePath: 'avatars/Avatar 1.png',
        rank: 'E',
        level: 1,
        totalXp: 0,
        currentLevelXp: 0,
        xpToNextLevel: 100,
        skillUnlockTokens: 0,
        stats: DashboardStats(),
      ),
      statistics: DashboardStatistics(
        completedQuestCount: 0,
        activeQuestCount: 0,
        acquiredSkillCount: 1,
        achievementCount: 0,
        completedGoalCount: 0,
        completedMilestoneCount: 0,
      ),
      activeQuests: [],
      skills: [
        DashboardSkill(
          id: 'focus',
          name: 'Focus',
          level: 1,
          currentLevelXp: 0,
          xpToNextLevel: 100,
        ),
      ],
      progressionOverview: DashboardProgressionOverview(
        period: 'LAST_30_DAYS',
        characterXpEarned: null,
        questsCompleted: null,
        goalsCompleted: null,
        milestonesCompleted: null,
        xpTrend: [],
      ),
      recentActivity: [],
    );
  }
}

class _FakeProgressionRepository implements ProgressionRepository {
  List<ProgressionQuest> quests = const [];

  @override
  Future<List<ProgressionQuest>> loadQuests(String accessToken) async => quests;

  @override
  Future<ProgressionStructure> loadStructure(String accessToken) async =>
      ProgressionStructure(
        goals: const [],
        milestones: const [],
        quests: quests,
      );

  @override
  Future<void> completeQuest(String accessToken, String questId) async {
    quests = quests
        .map(
          (quest) => quest.id == questId
              ? ProgressionQuest(
                  id: quest.id,
                  title: quest.title,
                  description: quest.description,
                  type: quest.type,
                  difficulty: quest.difficulty,
                  primarySkillId: quest.primarySkillId,
                  completed: true,
                )
              : quest,
        )
        .toList(growable: false);
  }

  @override
  Future<void> createGoal(
    String accessToken, {
    required String title,
    required String description,
    String? primarySkillId,
    String? skillName,
    List<String> statContributions = const [],
    List<Map<String, Object?>> milestones = const [],
  }) async {}

  @override
  Future<void> updateGoal(
    String accessToken, {
    required String goalId,
    required String title,
    required String description,
    String? primarySkillId,
    List<String> statContributions = const [],
  }) async {}

  @override
  Future<void> deleteGoal(String accessToken, String goalId) async {}

  @override
  Future<void> completeGoal(String accessToken, String goalId) async {}

  @override
  Future<void> completeMilestone(
    String accessToken,
    String goalId,
    String milestoneId,
  ) async {}

  @override
  Future<void> createMilestone(
    String accessToken, {
    required String goalId,
    required String title,
    required String description,
  }) async {}

  @override
  Future<void> updateMilestone(
    String accessToken, {
    required String goalId,
    required String milestoneId,
    required String title,
    required String description,
  }) async {}

  @override
  Future<void> deleteMilestone(
    String accessToken,
    String goalId,
    String milestoneId,
  ) async {}

  @override
  Future<void> createGoalQuest(
    String accessToken, {
    required String goalId,
    required String title,
    required String description,
    required String difficulty,
    String? milestoneId,
    List<String> statContributions = const [],
  }) async {}

  @override
  Future<void> updateGoalQuest(
    String accessToken, {
    required String goalId,
    required String questId,
    required String title,
    required String description,
    required String difficulty,
    String? milestoneId,
    List<String> statContributions = const [],
  }) async {}

  @override
  Future<void> deleteGoalQuest(
    String accessToken,
    String goalId,
    String questId,
  ) async {}

  @override
  Future<void> createSideQuest(
    String accessToken, {
    required String title,
    required String description,
    required String difficulty,
    String? primarySkillId,
    String? skillName,
    List<String> statContributions = const [],
  }) async {}

  @override
  Future<List<LibrarySkill>> loadSkillLibrary(
    String accessToken,
  ) async => const [
    LibrarySkill(id: 'focus', name: 'Focus', description: 'Train attention.'),
    LibrarySkill(
      id: 'fitness',
      name: 'Fitness',
      description: 'Build physical health.',
    ),
  ];

  @override
  Future<void> acquireSkill(
    String accessToken, {
    String? skillId,
    String? name,
    String? description,
    String? category,
  }) async {}
}
