import '../../../core/network/api_client.dart';

class QuestObjective {
  const QuestObjective({
    required this.id,
    required this.title,
    required this.completed,
  });
  final String id;
  final String title;
  final bool completed;

  factory QuestObjective.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final completed = json['completed'];
    if (id is! String || title is! String || completed is! bool) {
      throw const ApiException(
        'The server returned invalid quest objective data.',
      );
    }
    return QuestObjective(id: id, title: title, completed: completed);
  }
}

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
    required this.objectives,
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
  final List<QuestObjective> objectives;
  final bool completed;
  final String? sourceTemplateId;

  factory ProgressionQuest.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    final type = json['type'];
    final difficulty = json['difficulty'];
    final primarySkillId = json['primarySkillId'];
    final objectives = json['objectives'];
    final completed = json['completed'];
    final sourceTemplateId = json['sourceTemplateId'];
    if (id is! String ||
        title is! String ||
        description is! String ||
        (type != 'MAIN' && type != 'SIDE') ||
        difficulty is! String ||
        (primarySkillId != null && primarySkillId is! String) ||
        (sourceTemplateId != null && sourceTemplateId is! String) ||
        objectives is! List ||
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
      milestoneId: json['milestoneId'] is String ? json['milestoneId'] as String : null,
      statContributions: json['statContributions'] is List
          ? (json['statContributions'] as List)
              .whereType<String>()
              .toList(growable: false)
          : const [],
      objectives: _readList(objectives, QuestObjective.fromJson),
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

List<T> _readList<T>(Object? value, T Function(Map<String, dynamic>) read) {
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
