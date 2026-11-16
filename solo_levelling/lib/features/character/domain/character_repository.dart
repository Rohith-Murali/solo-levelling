import 'character_options.dart';

abstract interface class CharacterRepository {
  Future<CharacterOptions> getOptions(String accessToken);

  Future<void> createCharacter({
    required String accessToken,
    required String name,
    required String avatarId,
    required String startingSkillId,
  });
}
