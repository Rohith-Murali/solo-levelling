import '../domain/character_options.dart';
import '../domain/character_repository.dart';
import 'character_api.dart';

class CharacterRepositoryImpl implements CharacterRepository {
  const CharacterRepositoryImpl({required this.api});

  final CharacterApi api;

  @override
  Future<CharacterOptions> getOptions(String accessToken) {
    return api.getOptions(accessToken);
  }

  @override
  Future<void> createCharacter({
    required String accessToken,
    required String name,
    required String avatarId,
    required String startingSkillId,
  }) {
    return api.createCharacter(
      accessToken: accessToken,
      name: name,
      avatarId: avatarId,
      startingSkillId: startingSkillId,
    );
  }
}
