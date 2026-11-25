import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/system_notification.dart';
import '../dashboard/domain/dashboard_data.dart';

class NotificationService {
  const NotificationService._();

  static Future<void> showCharacterCreated(
    BuildContext context,
  ) => SystemNotification.show(
    context,
    icon: Icons.auto_awesome,
    message:
        'Character initialized!\n\nLevel 1 unlocked\nStarting skill acquired',
  );

  static Future<void> showSkillUnlocked(
    BuildContext context,
    String skillName,
  ) => SystemNotification.show(
    context,
    icon: Icons.auto_awesome,
    message: 'NEW SKILL UNLOCKED\n\n$skillName',
  );

  static Future<void> showGoalUnlocked(BuildContext context, String title) =>
      SystemNotification.show(
        context,
        icon: Icons.flag,
        message: 'GOAL UNLOCKED\n\n$title',
      );

  static Future<void> showMilestoneUnlocked(
    BuildContext context,
    String title,
  ) => SystemNotification.show(
    context,
    icon: Icons.flag_outlined,
    message: 'MILESTONE UNLOCKED\n\n$title',
  );

  static Future<void> showQuestUnlocked(BuildContext context, String title) =>
      SystemNotification.show(
        context,
        icon: Icons.add_task,
        message: 'QUEST UNLOCKED\n\n$title',
      );

  static Future<void> showProgressionCompletion(
    BuildContext context, {
    required DashboardData? before,
    required DashboardData after,
    required String completionTitle,
    required IconData completionIcon,
    String? completionSubject,
  }) {
    final gainedXp = before == null
        ? 0
        : (after.character.totalXp - before.character.totalXp).clamp(
            0,
            1 << 30,
          );
    final completionMessage = completionSubject == null
        ? '$completionTitle\n\n+$gainedXp XP EARNED'
        : '$completionTitle\n\n$completionSubject\n+$gainedXp XP';
    return SystemNotification.showStack(
      context,
      _buildProgressionNotifications(
        before: before,
        after: after,
        completionMessage: completionMessage,
        completionIcon: completionIcon,
      ),
    );
  }

  static List<SystemNotificationData> _buildProgressionNotifications({
    required DashboardData? before,
    required DashboardData after,
    required String completionMessage,
    required IconData completionIcon,
  }) {
    final notifications = <SystemNotificationData>[
      SystemNotificationData(icon: completionIcon, message: completionMessage),
    ];
    final previousActivityIds = {
      for (final activity in before?.recentActivity ?? const []) activity.id,
    };

    final characterLevelledUp = after.recentActivity.any(
      (activity) =>
          !previousActivityIds.contains(activity.id) &&
          activity.type == 'CHARACTER_LEVEL_INCREASED',
    );
    final levelsGained = before == null
        ? 0
        : after.character.level - before.character.level;
    if (characterLevelledUp || levelsGained > 0) {
      notifications.add(
        SystemNotificationData(
          icon: Icons.trending_up,
          message: before != null && levelsGained > 1
              ? 'LEVELLED UP\n\nLV ${before.character.level} -> ${after.character.level} (+$levelsGained)'
              : 'LEVELLED UP\n\nLV ${after.character.level}',
        ),
      );
    }

    if (before == null) return notifications;

    final titleUnlocked = after.recentActivity.any(
      (activity) =>
          !previousActivityIds.contains(activity.id) &&
          activity.type == 'TITLE_UNLOCKED',
    );
    if (titleUnlocked || after.character.title != before.character.title) {
      notifications.add(
        SystemNotificationData(
          icon: Icons.workspace_premium,
          message: 'TITLE UNLOCKED\n\n${after.character.title}',
        ),
      );
    }

    final tokensEarned =
        after.character.skillUnlockTokens - before.character.skillUnlockTokens;
    if (tokensEarned > 0) {
      notifications.add(
        SystemNotificationData(
          icon: Icons.token_outlined,
          message:
              '$tokensEarned SKILL UNLOCK TOKEN${tokensEarned == 1 ? '' : 'S'} EARNED',
        ),
      );
    }

    final oldSkills = {for (final skill in before.skills) skill.id: skill};
    for (final skill in after.skills) {
      final oldSkill = oldSkills[skill.id];
      final skillXpGained = (skill.totalXp - (oldSkill?.totalXp ?? 0)).clamp(
        0,
        1 << 30,
      );
      if (skillXpGained > 0) {
        notifications.add(
          SystemNotificationData(
            icon: Icons.auto_awesome,
            message: '${skill.name.toUpperCase()}\n+$skillXpGained SKILL XP',
          ),
        );
      }

      final skillLevelledUp = after.recentActivity.any(
        (activity) =>
            !previousActivityIds.contains(activity.id) &&
            activity.type == 'SKILL_LEVEL_INCREASED' &&
            activity.relatedEntityId == skill.id,
      );
      final skillLevelsGained = oldSkill == null
          ? 0
          : skill.level - oldSkill.level;
      if (skillLevelledUp || skillLevelsGained > 0) {
        notifications.add(
          SystemNotificationData(
            icon: Icons.auto_awesome,
            message: oldSkill != null && skillLevelsGained > 1
                ? 'SKILL ${skill.name.toUpperCase()} LEVELLED UP\n\nLV ${oldSkill.level} -> ${skill.level}'
                : 'SKILL ${skill.name.toUpperCase()} LEVELLED UP\n\nLV ${skill.level}',
          ),
        );
      }
    }

    return notifications;
  }
}
