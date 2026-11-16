import '../../../core/network/api_client.dart';
import '../domain/character_options.dart';

class CharacterApi {
  const CharacterApi(this._client);

  final ApiClient _client;

  Future<CharacterOptions> getOptions(String accessToken) async {
    final response = await _client.getJson(
      'characters/options',
      bearerToken: accessToken,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        'The server returned invalid character options.',
      );
    }
    return CharacterOptions.fromJson(data);
  }

  Future<void> createCharacter({
    required String accessToken,
    required String name,
    required String avatarId,
    required String startingSkillId,
  }) async {
    final response = await _client.postJson(
      'characters',
      bearerToken: accessToken,
      body: {
        'name': name,
        'avatarId': avatarId,
        'startingSkillId': startingSkillId,
      },
    );
    final data = response['data'];
    final character = data is Map<String, dynamic> ? data['character'] : null;
    final startingSkill = data is Map<String, dynamic>
        ? data['startingSkill']
        : null;
    if (character is! Map<String, dynamic> ||
        startingSkill is! Map<String, dynamic> ||
        character['id'] is! String ||
        character['name'] is! String ||
        character['avatarId'] is! String ||
        character['level'] is! int ||
        character['xp'] is! int ||
        character['rank'] is! String ||
        character['skillUnlockTokens'] is! int ||
        startingSkill['id'] is! String ||
        startingSkill['name'] is! String ||
        startingSkill['level'] is! int ||
        startingSkill['xp'] is! int) {
      throw const ApiException(
        'The server returned an invalid character response.',
      );
    }
  }
}
