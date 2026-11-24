import '../../../core/network/api_client.dart';
import '../domain/progression_data.dart';

class ProgressionApi {
  const ProgressionApi(this._client);
  final ApiClient _client;

  Future<List<ProgressionQuest>> getQuests(String token) async {
    final response = await _client.getJson('quests', bearerToken: token);
    final data = response['data'];
    if (data is! Map<String, dynamic> || data['quests'] is! List) {
      throw const ApiException('The server returned invalid quest data.');
    }
    return _read(data['quests'], ProgressionQuest.fromJson);
  }

  Future<ProgressionStructure> getStructure(String token) async {
    final response = await _client.getJson('quests', bearerToken: token);
    final data = response['data'];
    if (data is! Map<String, dynamic> ||
        data['goals'] is! List ||
        data['milestones'] is! List ||
        data['quests'] is! List)
      throw const ApiException('The server returned invalid quest data.');
    return ProgressionStructure(
      goals: _read(data['goals'], ProgressionGoal.fromJson),
      milestones: _read(data['milestones'], ProgressionMilestone.fromJson),
      quests: _read(data['quests'], ProgressionQuest.fromJson),
    );
  }

  Future<List<QuestTemplate>> getTemplates(String token) async {
    final response = await _client.getJson(
      'quests/templates',
      bearerToken: token,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic> || data['templates'] is! List)
      throw const ApiException(
        'The server returned invalid quest template data.',
      );
    return _read(data['templates'], QuestTemplate.fromJson);
  }

  Future<void> activateTemplate(String token, String templateId) async {
    await _client.postJson(
      'quests/templates/$templateId/activate',
      body: const {},
      bearerToken: token,
    );
  }

  Future<void> completeQuest(String token, String questId) async {
    await _client.postJson(
      'quests/$questId/complete',
      body: const {},
      bearerToken: token,
    );
  }

  Future<void> completeMilestone(
    String token,
    String goalId,
    String milestoneId,
  ) async {
    await _client.postJson(
      'quests/goals/$goalId/milestones/$milestoneId/complete',
      body: const {},
      bearerToken: token,
    );
  }

  Future<void> completeGoal(String token, String goalId) async {
    await _client.postJson(
      'quests/goals/$goalId/complete',
      body: const {},
      bearerToken: token,
    );
  }

  Future<void> createGoal(
    String token, {
    required String title,
    required String description,
    String? primarySkillId,
    String? skillName,
    List<String> statContributions = const [],
    List<Map<String, Object?>> milestones = const [],
  }) async {
    await _client.postJson(
      'quests/goals',
      body: {
        'title': title,
        'description': description,
        if (primarySkillId != null) 'primarySkillId': primarySkillId,
        if (skillName != null) 'skillName': skillName,
        if (statContributions.isNotEmpty)
          'statContributions': statContributions,
        'milestones': milestones,
      },
      bearerToken: token,
    );
  }

  Future<void> updateGoal(
    String token, {
    required String goalId,
    required String title,
    required String description,
    String? primarySkillId,
    List<String> statContributions = const [],
  }) async {
    await _client.patchJson(
      'quests/goals/$goalId',
      body: {
        'title': title,
        'description': description,
        if (primarySkillId != null) 'primarySkillId': primarySkillId,
        if (statContributions.isNotEmpty)
          'statContributions': statContributions,
      },
      bearerToken: token,
    );
  }

  Future<void> deleteGoal(String token, String goalId) async {
    await _client.deleteJson('quests/goals/$goalId', bearerToken: token);
  }

  Future<void> createMilestone(
    String token, {
    required String goalId,
    required String title,
    required String description,
  }) async {
    await _client.postJson(
      'quests/goals/$goalId/milestones',
      body: {'title': title, 'description': description, 'quests': const []},
      bearerToken: token,
    );
  }

  Future<void> updateMilestone(
    String token, {
    required String goalId,
    required String milestoneId,
    required String title,
    required String description,
  }) async {
    await _client.patchJson(
      'quests/goals/$goalId/milestones/$milestoneId',
      body: {'title': title, 'description': description},
      bearerToken: token,
    );
  }

  Future<void> deleteMilestone(
    String token,
    String goalId,
    String milestoneId,
  ) async {
    await _client.deleteJson(
      'quests/goals/$goalId/milestones/$milestoneId',
      bearerToken: token,
    );
  }

  Future<void> createGoalQuest(
    String token, {
    required String goalId,
    required String title,
    required String description,
    required String difficulty,
    String? milestoneId,
    List<String> statContributions = const [],
  }) async {
    await _client.postJson(
      'quests/goals/$goalId/quests',
      body: {
        'title': title,
        'description': description,
        'difficulty': difficulty,
        if (milestoneId != null) 'milestoneId': milestoneId,
        if (statContributions.isNotEmpty)
          'statContributions': statContributions,
      },
      bearerToken: token,
    );
  }

  Future<void> updateGoalQuest(
    String token, {
    required String goalId,
    required String questId,
    required String title,
    required String description,
    required String difficulty,
    String? milestoneId,
    List<String> statContributions = const [],
  }) async {
    await _client.patchJson(
      'quests/goals/$goalId/quests/$questId',
      body: {
        'title': title,
        'description': description,
        'difficulty': difficulty,
        'milestoneId': milestoneId,
        if (statContributions.isNotEmpty)
          'statContributions': statContributions,
      },
      bearerToken: token,
    );
  }

  Future<void> deleteGoalQuest(
    String token,
    String goalId,
    String questId,
  ) async {
    await _client.deleteJson(
      'quests/goals/$goalId/quests/$questId',
      bearerToken: token,
    );
  }

  Future<void> createSideQuest(
    String token, {
    required String title,
    required String description,
    required String difficulty,
    String? primarySkillId,
    String? skillName,
    List<String> statContributions = const [],
  }) async {
    await _client.postJson(
      'quests/side',
      body: {
        'title': title,
        'description': description,
        'difficulty': difficulty,
        if (primarySkillId != null) 'primarySkillId': primarySkillId,
        if (skillName != null) 'skillName': skillName,
        if (statContributions.isNotEmpty)
          'statContributions': statContributions,
      },
      bearerToken: token,
    );
  }

  Future<List<LibrarySkill>> getSkillLibrary(String token) async {
    final response = await _client.getJson(
      'skills/library',
      bearerToken: token,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic> || data['skills'] is! List)
      throw const ApiException('The server returned invalid skill data.');
    return _read(data['skills'], LibrarySkill.fromJson);
  }

  Future<void> acquireSkill(
    String token, {
    String? skillId,
    String? name,
    String? description,
    String? category,
  }) async {
    await _client.postJson(
      'skills/acquire',
      body: {
        if (skillId != null) 'skillId': skillId,
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
      },
      bearerToken: token,
    );
  }
}

List<T> _read<T>(Object? value, T Function(Map<String, dynamic>) read) {
  if (value is! List)
    throw const ApiException('The server returned invalid progression data.');
  return value
      .map((item) {
        if (item is! Map<String, dynamic>)
          throw const ApiException(
            'The server returned invalid progression data.',
          );
        return read(item);
      })
      .toList(growable: false);
}
