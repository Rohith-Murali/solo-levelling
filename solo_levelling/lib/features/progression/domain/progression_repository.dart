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
  Future<void> createGoal(
    String accessToken, {
    required String title,
    required String description,
    String? primarySkillId,
    String? skillName,
    List<Map<String, Object?>> milestones,
  });
  Future<void> createSideQuest(
    String accessToken, {
    required String title,
    required String description,
    required String difficulty,
    String? primarySkillId,
    String? skillName,
    List<String> objectives,
    List<String> statContributions,
  });
  Future<List<LibrarySkill>> loadSkillLibrary(String accessToken);
  Future<void> acquireSkill(
    String accessToken, {
    String? skillId,
    String? name,
    String? description,
    String? category,
  });
}
