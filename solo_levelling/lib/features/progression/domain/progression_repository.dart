import 'progression_data.dart';

abstract interface class ProgressionRepository {
  Future<List<ProgressionQuest>> loadQuests(String accessToken);
  Future<List<QuestTemplate>> loadTemplates(String accessToken);
  Future<void> activateTemplate(String accessToken, String templateId);
  Future<void> completeObjective(
    String accessToken,
    String questId,
    String objectiveId,
  );
  Future<void> completeQuest(String accessToken, String questId);
  Future<List<LibrarySkill>> loadSkillLibrary(String accessToken);
  Future<void> acquireSkill(
    String accessToken, {
    String? skillId,
    String? name,
    String? description,
    String? category,
  });
}
