import 'progression_data.dart';

abstract interface class ProgressionRepository {
  Future<List<ProgressionQuest>> loadQuests(String accessToken);
  Future<ProgressionStructure> loadStructure(String accessToken);
  Future<List<QuestTemplate>> loadTemplates(String accessToken);
  Future<void> activateTemplate(String accessToken, String templateId);
  Future<void> completeQuest(String accessToken, String questId);
  Future<void> createGoal(
    String accessToken, {
    required String title,
    required String description,
    String? primarySkillId,
    String? skillName,
    List<Map<String, Object?>> milestones,
  });
  Future<void> updateGoal(
    String accessToken, {
    required String goalId,
    required String title,
    required String description,
  });
  Future<void> deleteGoal(String accessToken, String goalId);
  Future<void> createMilestone(
    String accessToken, {
    required String goalId,
    required String title,
    required String description,
  });
  Future<void> updateMilestone(
    String accessToken, {
    required String goalId,
    required String milestoneId,
    required String title,
    required String description,
  });
  Future<void> deleteMilestone(
    String accessToken,
    String goalId,
    String milestoneId,
  );
  Future<void> createGoalQuest(
    String accessToken, {
    required String goalId,
    required String title,
    required String description,
    required String difficulty,
    String? milestoneId,
    List<String> statContributions,
  });
  Future<void> updateGoalQuest(
    String accessToken, {
    required String goalId,
    required String questId,
    required String title,
    required String description,
    required String difficulty,
    String? milestoneId,
    List<String> statContributions,
  });
  Future<void> deleteGoalQuest(
    String accessToken,
    String goalId,
    String questId,
  );
  Future<void> createSideQuest(
    String accessToken, {
    required String title,
    required String description,
    required String difficulty,
    String? primarySkillId,
    String? skillName,
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
