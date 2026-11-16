part of 'dashboard_screen.dart';

class _ActiveQuestsSection extends StatelessWidget {
  const _ActiveQuestsSection({required this.quests});

  final List<DashboardQuest> quests;

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      title: 'ACTIVE QUESTS',
      trailing: '${quests.length}',
      child: quests.isEmpty
          ? const _EmptySectionMessage(
              icon: Icons.assignment_outlined,
              title: 'No active quests detected.',
              detail: 'Active quests will appear here when quest tracking is available.',
            )
          : Column(
              children: [
                for (final quest in quests) ...[
                  _QuestCard(quest: quest),
                  if (quest != quests.last) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.quest});

  final DashboardQuest quest;

  @override
  Widget build(BuildContext context) {
    final progress = quest.totalObjectives == 0
        ? 0.0
        : (quest.completedObjectives / quest.totalObjectives)
              .clamp(0.0, 1.0)
              .toDouble();
    final type = quest.type == 'MAIN' ? 'MAIN QUEST' : 'SIDE QUEST';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                type,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                quest.difficulty,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            quest.title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: AppColors.surfaceElevated,
            color: AppColors.primaryGlow,
          ),
          const SizedBox(height: 6),
          Text(
            '${quest.completedObjectives} / ${quest.totalObjectives} objectives',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _RewardLabel(
                icon: Icons.bolt,
                text: '+${quest.characterXpReward} XP',
              ),
              if (quest.primarySkillName != null)
                _RewardLabel(
                  icon: Icons.auto_awesome,
                  text:
                      '${quest.primarySkillName} +${quest.skillXpReward ?? 0} XP',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AcquiredSkillsSection extends StatelessWidget {
  const _AcquiredSkillsSection({required this.skills});

  final List<DashboardSkill> skills;

  @override
  Widget build(BuildContext context) {
    return _DashboardSection(
      title: 'ACQUIRED SKILLS',
      trailing: '${skills.length}',
      child: skills.isEmpty
          ? const _EmptySectionMessage(
              icon: Icons.auto_awesome_outlined,
              title: 'No skills acquired yet.',
              detail: 'Your acquired skill progression will appear here.',
            )
          : Column(
              children: [
                for (final skill in skills) ...[
                  _SkillProgressCard(skill: skill),
                  if (skill != skills.last) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _SkillProgressCard extends StatelessWidget {
  const _SkillProgressCard({required this.skill});

  final DashboardSkill skill;

  @override
  Widget build(BuildContext context) {
    final progress = skill.xpToNextLevel <= 0
        ? 0.0
        : (skill.currentLevelXp / skill.xpToNextLevel)
              .clamp(0.0, 1.0)
              .toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _skillIcon(skill.id),
              color: AppColors.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        skill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      'LV ${skill.level}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: AppColors.background,
                    color: AppColors.primaryGlow,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${skill.currentLevelXp} / ${skill.xpToNextLevel} Skill XP',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
