import '../domain/progression_data.dart';
import '../domain/progression_repository.dart';
import 'progression_api.dart';

class ProgressionRepositoryImpl implements ProgressionRepository {
  const ProgressionRepositoryImpl({required this.api});
  final ProgressionApi api;
  @override
  Future<List<ProgressionQuest>> loadQuests(String token) =>
      api.getQuests(token);
  @override
  Future<ProgressionStructure> loadStructure(String token) =>
      api.getStructure(token);
  @override
  Future<List<QuestTemplate>> loadTemplates(String token) =>
      api.getTemplates(token);
  @override
  Future<void> activateTemplate(String token, String templateId) =>
      api.activateTemplate(token, templateId);
  @override
  Future<void> completeObjective(
    String token,
    String questId,
    String objectiveId,
  ) => api.completeObjective(token, questId, objectiveId);
  @override
  Future<void> completeQuest(String token, String questId) =>
      api.completeQuest(token, questId);
  @override
  Future<void> createGoal(
    String token, {
    required String title,
    required String description,
    String? primarySkillId,
    String? skillName,
    List<Map<String, Object?>> milestones = const [],
  }) => api.createGoal(
    token,
    title: title,
    description: description,
    primarySkillId: primarySkillId,
    skillName: skillName,
    milestones: milestones,
  );
  @override
  Future<void> updateGoal(
    String token, {
    required String goalId,
    required String title,
    required String description,
  }) => api.updateGoal(
    token,
    goalId: goalId,
    title: title,
    description: description,
  );
  @override
  Future<void> deleteGoal(String token, String goalId) =>
      api.deleteGoal(token, goalId);
  @override
  Future<void> createMilestone(
    String token, {
    required String goalId,
    required String title,
    required String description,
  }) => api.createMilestone(
    token,
    goalId: goalId,
    title: title,
    description: description,
  );
  @override
  Future<void> updateMilestone(
    String token, {
    required String goalId,
    required String milestoneId,
    required String title,
    required String description,
  }) => api.updateMilestone(
    token,
    goalId: goalId,
    milestoneId: milestoneId,
    title: title,
    description: description,
  );
  @override
  Future<void> deleteMilestone(
    String token,
    String goalId,
    String milestoneId,
  ) => api.deleteMilestone(token, goalId, milestoneId);
  @override
  Future<void> createGoalQuest(
    String token, {
    required String goalId,
    required String title,
    required String description,
    required String difficulty,
    String? milestoneId,
    List<String> objectives = const [],
    List<String> statContributions = const [],
  }) => api.createGoalQuest(
    token,
    goalId: goalId,
    title: title,
    description: description,
    difficulty: difficulty,
    milestoneId: milestoneId,
    objectives: objectives,
    statContributions: statContributions,
  );
  @override
  Future<void> updateGoalQuest(
    String token, {
    required String goalId,
    required String questId,
    required String title,
    required String description,
    required String difficulty,
    String? milestoneId,
    List<String> objectives = const [],
    List<String> statContributions = const [],
  }) => api.updateGoalQuest(
    token,
    goalId: goalId,
    questId: questId,
    title: title,
    description: description,
    difficulty: difficulty,
    milestoneId: milestoneId,
    objectives: objectives,
    statContributions: statContributions,
  );
  @override
  Future<void> deleteGoalQuest(String token, String goalId, String questId) =>
      api.deleteGoalQuest(token, goalId, questId);
  @override
  Future<void> createSideQuest(
    String token, {
    required String title,
    required String description,
    required String difficulty,
    String? primarySkillId,
    String? skillName,
    List<String> objectives = const [],
    List<String> statContributions = const [],
  }) => api.createSideQuest(
    token,
    title: title,
    description: description,
    difficulty: difficulty,
    primarySkillId: primarySkillId,
    skillName: skillName,
    objectives: objectives,
    statContributions: statContributions,
  );
  @override
  Future<List<LibrarySkill>> loadSkillLibrary(String token) =>
      api.getSkillLibrary(token);
  @override
  Future<void> acquireSkill(
    String token, {
    String? skillId,
    String? name,
    String? description,
    String? category,
  }) => api.acquireSkill(
    token,
    skillId: skillId,
    name: name,
    description: description,
    category: category,
  );
}
