import '../../../core/network/api_client.dart';

class DashboardCharacter {
  const DashboardCharacter({
    required this.id,
    required this.name,
    required this.avatarId,
    required this.avatarImagePath,
    required this.rank,
    required this.title,
    required this.level,
    required this.totalXp,
    required this.currentLevelXp,
    required this.xpToNextLevel,
    required this.skillUnlockTokens,
    required this.stats,
  });

  final String id;
  final String name;
  final String avatarId;
  final String? avatarImagePath;
  final String rank;
  final String title;
  final int level;
  final int totalXp;
  final int currentLevelXp;
  final int xpToNextLevel;
  final int skillUnlockTokens;
  final DashboardStats stats;

  factory DashboardCharacter.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final avatarId = json['avatarId'];
    final avatarImagePath = json['avatarImagePath'];
    final rank = json['rank'];
    final title = json['title'];
    final level = json['level'];
    final totalXp = json['totalXp'];
    final currentLevelXp = json['currentLevelXp'];
    final xpToNextLevel = json['xpToNextLevel'];
    final skillUnlockTokens = json['skillUnlockTokens'];
    final stats = json['stats'];
    if (id is! String ||
        name is! String ||
        avatarId is! String ||
        (avatarImagePath != null && avatarImagePath is! String) ||
        rank is! String ||
        title is! String ||
        level is! int ||
        totalXp is! int ||
        currentLevelXp is! int ||
        xpToNextLevel is! int ||
        skillUnlockTokens is! int) {
      throw const ApiException('The server returned invalid dashboard data.');
    }

    return DashboardCharacter(
      id: id,
      name: name,
      avatarId: avatarId,
      avatarImagePath: avatarImagePath as String?,
      rank: rank,
      title: title,
      level: level,
      totalXp: totalXp,
      currentLevelXp: currentLevelXp,
      xpToNextLevel: xpToNextLevel,
      skillUnlockTokens: skillUnlockTokens,
      stats: stats is Map<String, dynamic>
          ? DashboardStats.fromJson(stats)
          : const DashboardStats(),
    );
  }
}

class DashboardStats {
  const DashboardStats({
    this.strength = 1,
    this.intelligence = 1,
    this.vitality = 1,
    this.discipline = 1,
    this.perception = 1,
  });
  final int strength;
  final int intelligence;
  final int vitality;
  final int discipline;
  final int perception;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    strength: json['strength'] is int ? json['strength'] as int : 1,
    intelligence: json['intelligence'] is int ? json['intelligence'] as int : 1,
    vitality: json['vitality'] is int ? json['vitality'] as int : 1,
    discipline: json['discipline'] is int ? json['discipline'] as int : 1,
    perception: json['perception'] is int ? json['perception'] as int : 1,
  );
}

class DashboardStatistics {
  const DashboardStatistics({
    required this.completedQuestCount,
    required this.activeQuestCount,
    required this.acquiredSkillCount,
    required this.achievementCount,
    required this.completedGoalCount,
    required this.completedMilestoneCount,
  });

  final int completedQuestCount;
  final int activeQuestCount;
  final int acquiredSkillCount;
  final int achievementCount;
  final int completedGoalCount;
  final int completedMilestoneCount;

  factory DashboardStatistics.fromJson(Map<String, dynamic> json) {
    final completedQuestCount = json['completedQuestCount'];
    final activeQuestCount = json['activeQuestCount'];
    final acquiredSkillCount = json['acquiredSkillCount'];
    final achievementCount = json['achievementCount'];
    final completedGoalCount = json['completedGoalCount'];
    final completedMilestoneCount = json['completedMilestoneCount'];
    if (completedQuestCount is! int ||
        activeQuestCount is! int ||
        acquiredSkillCount is! int ||
        achievementCount is! int ||
        completedGoalCount is! int ||
        completedMilestoneCount is! int) {
      throw const ApiException('The server returned invalid dashboard data.');
    }

    return DashboardStatistics(
      completedQuestCount: completedQuestCount,
      activeQuestCount: activeQuestCount,
      acquiredSkillCount: acquiredSkillCount,
      achievementCount: achievementCount,
      completedGoalCount: completedGoalCount,
      completedMilestoneCount: completedMilestoneCount,
    );
  }
}

class DashboardQuest {
  const DashboardQuest({
    required this.id,
    required this.title,
    required this.type,
    required this.difficulty,
    required this.characterXpReward,
    required this.primarySkillName,
    required this.skillXpReward,
  });

  final String id;
  final String title;
  final String type;
  final String difficulty;
  final int characterXpReward;
  final String? primarySkillName;
  final int? skillXpReward;

  factory DashboardQuest.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final type = json['type'];
    final difficulty = json['difficulty'];
    final characterXpReward = json['characterXpReward'];
    final primarySkillName = json['primarySkillName'];
    final skillXpReward = json['skillXpReward'];
    if (id is! String ||
        title is! String ||
        (type != 'MAIN' && type != 'SIDE') ||
        difficulty is! String ||
        characterXpReward is! int ||
        (primarySkillName != null && primarySkillName is! String) ||
        (skillXpReward != null && skillXpReward is! int)) {
      throw const ApiException('The server returned invalid dashboard data.');
    }

    return DashboardQuest(
      id: id,
      title: title,
      type: type as String,
      difficulty: difficulty,
      characterXpReward: characterXpReward,
      primarySkillName: primarySkillName as String?,
      skillXpReward: skillXpReward as int?,
    );
  }
}

class DashboardSkill {
  const DashboardSkill({
    required this.id,
    required this.name,
    required this.level,
    required this.currentLevelXp,
    required this.xpToNextLevel,
  });

  final String id;
  final String name;
  final int level;
  final int currentLevelXp;
  final int xpToNextLevel;

  factory DashboardSkill.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final level = json['level'];
    final currentLevelXp = json['currentLevelXp'];
    final xpToNextLevel = json['xpToNextLevel'];
    if (id is! String ||
        name is! String ||
        level is! int ||
        currentLevelXp is! int ||
        xpToNextLevel is! int) {
      throw const ApiException('The server returned invalid dashboard data.');
    }

    return DashboardSkill(
      id: id,
      name: name,
      level: level,
      currentLevelXp: currentLevelXp,
      xpToNextLevel: xpToNextLevel,
    );
  }
}

class DashboardProgressionOverview {
  const DashboardProgressionOverview({
    required this.period,
    required this.characterXpEarned,
    required this.questsCompleted,
    required this.goalsCompleted,
    required this.milestonesCompleted,
    required this.xpTrend,
  });

  final String period;
  final int? characterXpEarned;
  final int? questsCompleted;
  final int? goalsCompleted;
  final int? milestonesCompleted;
  final List<DashboardXpPoint> xpTrend;

  factory DashboardProgressionOverview.fromJson(Map<String, dynamic> json) {
    final period = json['period'];
    final characterXpEarned = json['characterXpEarned'];
    final questsCompleted = json['questsCompleted'];
    final goalsCompleted = json['goalsCompleted'];
    final milestonesCompleted = json['milestonesCompleted'];
    if (period is! String ||
        (characterXpEarned != null && characterXpEarned is! int) ||
        (questsCompleted != null && questsCompleted is! int) ||
        (goalsCompleted != null && goalsCompleted is! int) ||
        (milestonesCompleted != null && milestonesCompleted is! int) ||
        json['xpTrend'] is! List) {
      throw const ApiException('The server returned invalid dashboard data.');
    }

    return DashboardProgressionOverview(
      period: period,
      characterXpEarned: characterXpEarned as int?,
      questsCompleted: questsCompleted as int?,
      goalsCompleted: goalsCompleted as int?,
      milestonesCompleted: milestonesCompleted as int?,
      xpTrend: _readList(json['xpTrend'], DashboardXpPoint.fromJson),
    );
  }
}

class DashboardXpPoint {
  const DashboardXpPoint({required this.date, required this.xp});

  final String date;
  final int xp;

  factory DashboardXpPoint.fromJson(Map<String, dynamic> json) {
    final date = json['date'];
    final xp = json['xp'];
    if (date is! String || xp is! int) {
      throw const ApiException('The server returned invalid dashboard data.');
    }
    return DashboardXpPoint(date: date, xp: xp);
  }
}

class DashboardActivity {
  const DashboardActivity({
    required this.id,
    required this.type,
    required this.relatedEntityId,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.xpGained,
  });

  final String id;
  final String type;
  final String? relatedEntityId;
  final String title;
  final String description;
  final String createdAt;
  final int? xpGained;

  factory DashboardActivity.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final relatedEntityId = json['relatedEntityId'];
    final title = json['title'];
    final description = json['description'];
    final createdAt = json['createdAt'];
    final xpGained = json['xpGained'];
    if (id is! String ||
        type is! String ||
        (relatedEntityId != null && relatedEntityId is! String) ||
        title is! String ||
        description is! String ||
        createdAt is! String ||
        (xpGained != null && xpGained is! int)) {
      throw const ApiException('The server returned invalid dashboard data.');
    }
    return DashboardActivity(
      id: id,
      type: type,
      relatedEntityId: relatedEntityId as String?,
      title: title,
      description: description,
      createdAt: createdAt,
      xpGained: xpGained as int?,
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.character,
    required this.statistics,
    required this.activeQuests,
    required this.skills,
    required this.progressionOverview,
    required this.recentActivity,
  });

  final DashboardCharacter character;
  final DashboardStatistics statistics;
  final List<DashboardQuest> activeQuests;
  final List<DashboardSkill> skills;
  final DashboardProgressionOverview progressionOverview;
  final List<DashboardActivity> recentActivity;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final character = json['character'];
    final statistics = json['statistics'];
    final progressionOverview = json['progressionOverview'];
    if (character is! Map<String, dynamic> ||
        statistics is! Map<String, dynamic> ||
        progressionOverview is! Map<String, dynamic> ||
        json['activeQuests'] is! List ||
        json['skills'] is! List ||
        json['recentActivity'] is! List) {
      throw const ApiException('The server returned invalid dashboard data.');
    }

    return DashboardData(
      character: DashboardCharacter.fromJson(character),
      statistics: DashboardStatistics.fromJson(statistics),
      activeQuests: _readList(json['activeQuests'], DashboardQuest.fromJson),
      skills: _readList(json['skills'], DashboardSkill.fromJson),
      progressionOverview: DashboardProgressionOverview.fromJson(
        progressionOverview,
      ),
      recentActivity: _readList(
        json['recentActivity'],
        DashboardActivity.fromJson,
      ),
    );
  }
}

List<T> _readList<T>(Object? value, T Function(Map<String, dynamic>) readItem) {
  if (value is! List) {
    throw const ApiException('The server returned invalid dashboard data.');
  }
  return value
      .map((item) {
        if (item is! Map<String, dynamic>) {
          throw const ApiException(
            'The server returned invalid dashboard data.',
          );
        }
        return readItem(item);
      })
      .toList(growable: false);
}
