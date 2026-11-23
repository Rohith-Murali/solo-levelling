import '../../../core/network/api_client.dart';
import '../domain/progression_data.dart';

class ProgressionApi {
  const ProgressionApi(this._client);
  final ApiClient _client;

  Future<List<ProgressionQuest>> getQuests(String token) async {
    final response = await _client.getJson('quests', bearerToken: token);
    final data = response['data'];
    if (data is! Map<String, dynamic> || data['quests'] is! List)
      throw const ApiException('The server returned invalid quest data.');
    return _read(data['quests'], ProgressionQuest.fromJson);
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

  Future<void> completeObjective(
    String token,
    String questId,
    String objectiveId,
  ) async {
    await _client.postJson(
      'quests/$questId/objectives/$objectiveId/complete',
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

  Future<void> createGoal(
    String token, {
    required String title,
    required String description,
    String? primarySkillId,
    String? skillName,
    List<Map<String, Object?>> milestones = const [],
  }) async {
    await _client.postJson(
      'quests/goals',
      body: {
        'title': title,
        'description': description,
        if (primarySkillId != null) 'primarySkillId': primarySkillId,
        if (skillName != null) 'skillName': skillName,
        'milestones': milestones,
      },
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
    List<String> objectives = const [],
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
        'objectives': objectives,
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
