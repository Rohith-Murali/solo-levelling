import '../../../core/network/api_client.dart';

class CharacterAvatar {
  const CharacterAvatar({
    required this.id,
    required this.name,
    required this.imagePath,
  });

  final String id;
  final String name;
  final String imagePath;

  factory CharacterAvatar.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final imagePath = json['imagePath'];
    if (id is! String || name is! String || imagePath is! String) {
      throw const ApiException(
        'The server returned invalid character options.',
      );
    }

    return CharacterAvatar(id: id, name: name, imagePath: imagePath);
  }
}

class StartingSkill {
  const StartingSkill({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;

  factory StartingSkill.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final description = json['description'];
    if (id is! String || name is! String || description is! String) {
      throw const ApiException('The server returned invalid starting skills.');
    }

    return StartingSkill(id: id, name: name, description: description);
  }
}

class InitialProgression {
  const InitialProgression({
    required this.level,
    required this.xp,
    required this.rank,
    required this.skillUnlockTokens,
    required this.skillLevel,
    required this.skillXp,
  });

  final int level;
  final int xp;
  final String rank;
  final int skillUnlockTokens;
  final int skillLevel;
  final int skillXp;

  factory InitialProgression.fromJson(Map<String, dynamic> json) {
    final level = json['level'];
    final xp = json['xp'];
    final rank = json['rank'];
    final skillUnlockTokens = json['skillUnlockTokens'];
    final skillLevel = json['skillLevel'];
    final skillXp = json['skillXp'];
    if (level is! int ||
        xp is! int ||
        rank is! String ||
        skillUnlockTokens is! int ||
        skillLevel is! int ||
        skillXp is! int) {
      throw const ApiException(
        'The server returned invalid character progression defaults.',
      );
    }

    return InitialProgression(
      level: level,
      xp: xp,
      rank: rank,
      skillUnlockTokens: skillUnlockTokens,
      skillLevel: skillLevel,
      skillXp: skillXp,
    );
  }
}

class CharacterOptions {
  const CharacterOptions({
    required this.avatars,
    required this.startingSkills,
    required this.initialProgression,
  });

  final List<CharacterAvatar> avatars;
  final List<StartingSkill> startingSkills;
  final InitialProgression initialProgression;

  factory CharacterOptions.fromJson(Map<String, dynamic> json) {
    final avatars = json['avatars'];
    final startingSkills = json['startingSkills'];
    final progression = json['initialProgression'];
    if (avatars is! List ||
        startingSkills is! List ||
        progression is! Map<String, dynamic>) {
      throw const ApiException(
        'The server returned invalid character options.',
      );
    }

    return CharacterOptions(
      avatars: avatars
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const ApiException(
                'The server returned invalid character options.',
              );
            }
            return CharacterAvatar.fromJson(item);
          })
          .toList(growable: false),
      startingSkills: startingSkills
          .map((item) {
            if (item is! Map<String, dynamic>) {
              throw const ApiException(
                'The server returned invalid starting skills.',
              );
            }
            return StartingSkill.fromJson(item);
          })
          .toList(growable: false),
      initialProgression: InitialProgression.fromJson(progression),
    );
  }
}
