import '../../../core/network/api_client.dart';

class ProgressionQuest {
  const ProgressionQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.difficulty,
    required this.primarySkillId,
    this.goalId,
    this.milestoneId,
    this.statContributions = const [],
    required this.completed,
    required this.sourceTemplateId,
  });
  final String id;
  final String title;
  final String description;
  final String type;
  final String difficulty;
  final String? primarySkillId;
  final String? goalId;
  final String? milestoneId;
  final List<String> statContributions;
  final bool completed;
  final String? sourceTemplateId;

  factory ProgressionQuest.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    final type = json['type'];
    final difficulty = json['difficulty'];
    final primarySkillId = json['primarySkillId'];
    final completed = json['completed'];
    final sourceTemplateId = json['sourceTemplateId'];
    if (id is! String ||
        title is! String ||
        description is! String ||
        (type != 'MAIN' && type != 'SIDE') ||
        difficulty is! String ||
        (primarySkillId != null && primarySkillId is! String) ||
        (sourceTemplateId != null && sourceTemplateId is! String) ||
        completed is! bool) {
      throw const ApiException('The server returned invalid quest data.');
    }
    return ProgressionQuest(
      id: id,
      title: title,
      description: description,
      type: type as String,
      difficulty: difficulty,
      primarySkillId: primarySkillId as String?,
      goalId: json['goalId'] is String ? json['goalId'] as String : null,
      milestoneId: json['milestoneId'] is String
          ? json['milestoneId'] as String
          : null,
      statContributions: json['statContributions'] is List
          ? (json['statContributions'] as List).whereType<String>().toList(
              growable: false,
            )
          : const [],
      completed: completed,
      sourceTemplateId: sourceTemplateId as String?,
    );
  }
}

class QuestTemplate {
  const QuestTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.minimumLevel,
    required this.milestoneCount,
    required this.questCount,
  });
  final String id;
  final String name;
  final String description;
  final int minimumLevel;
  final int milestoneCount;
  final int questCount;

  factory QuestTemplate.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final description = json['description'];
    final minimumLevel = json['minimumLevel'];
    final milestoneCount = json['milestoneCount'];
    final questCount = json['questCount'];
    if (id is! String ||
        name is! String ||
        description is! String ||
        minimumLevel is! int ||
        milestoneCount is! int ||
        questCount is! int) {
      throw const ApiException(
        'The server returned invalid quest template data.',
      );
    }
    return QuestTemplate(
      id: id,
      name: name,
      description: description,
      minimumLevel: minimumLevel,
      milestoneCount: milestoneCount,
      questCount: questCount,
    );
  }
}

class ProgressionGoal {
  const ProgressionGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.primarySkillId,
    required this.milestoneIds,
    required this.completed,
    required this.status,
  });
  final String id;
  final String title;
  final String description;
  final String primarySkillId;
  final List<String> milestoneIds;
  final bool completed;
  final String status;

  factory ProgressionGoal.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    final primarySkillId = json['primarySkillId'];
    final milestoneIds = json['milestoneIds'];
    final completed = json['completed'];
    var status = json['status'];
    if (id is! String ||
        title is! String ||
        description is! String ||
        primarySkillId is! String ||
        milestoneIds is! List ||
        completed is! bool) {
      throw const ApiException('The server returned invalid goal data.');
    }
    status = status is String
        ? status
        : completed == true
        ? 'COMPLETED'
        : 'ACTIVE';
    return ProgressionGoal(
      id: id,
      title: title,
      description: description,
      primarySkillId: primarySkillId,
      milestoneIds: milestoneIds.whereType<String>().toList(growable: false),
      completed: completed,
      status: status,
    );
  }
}

class ProgressionMilestone {
  const ProgressionMilestone({
    required this.id,
    required this.title,
    required this.description,
    required this.questIds,
    required this.completed,
  });
  final String id;
  final String title;
  final String description;
  final List<String> questIds;
  final bool completed;

  factory ProgressionMilestone.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    final questIds = json['questIds'];
    final completed = json['completed'];
    if (id is! String ||
        title is! String ||
        description is! String ||
        questIds is! List ||
        completed is! bool) {
      throw const ApiException('The server returned invalid milestone data.');
    }
    return ProgressionMilestone(
      id: id,
      title: title,
      description: description,
      questIds: questIds.whereType<String>().toList(growable: false),
      completed: completed,
    );
  }
}

class ProgressionStructure {
  const ProgressionStructure({
    required this.goals,
    required this.milestones,
    required this.quests,
  });
  final List<ProgressionGoal> goals;
  final List<ProgressionMilestone> milestones;
  final List<ProgressionQuest> quests;
}

class LibrarySkill {
  const LibrarySkill({
    required this.id,
    required this.name,
    required this.description,
  });
  final String id;
  final String name;
  final String description;

  factory LibrarySkill.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final description = json['description'];
    if (id is! String || name is! String || description is! String)
      throw const ApiException('The server returned invalid skill data.');
    return LibrarySkill(id: id, name: name, description: description);
  }
}
