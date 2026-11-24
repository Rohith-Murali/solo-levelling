part of 'dashboard_screen.dart';

class _ActiveQuestsSection extends StatelessWidget {
  const _ActiveQuestsSection({
    required this.quests,
    required this.goals,
    required this.skills,
    required this.characterLevel,
    required this.templates,
    required this.onObjectiveComplete,
    required this.onQuestComplete,
    required this.onActivateTemplate,
    required this.activatingTemplateIds,
  });

  final List<ProgressionQuest> quests;
  final List<ProgressionGoal> goals;
  final List<DashboardSkill> skills;
  final int characterLevel;
  final List<QuestTemplate> templates;
  final Future<void> Function(String questId, String objectiveId)
  onObjectiveComplete;
  final Future<void> Function(String questId) onQuestComplete;
  final Future<void> Function(String templateId) onActivateTemplate;
  final Set<String> activatingTemplateIds;

  @override
  Widget build(BuildContext context) {
    final activeQuests = quests
        .where((quest) => !quest.completed)
        .toList(growable: false);
    final goalSections = <({String title, List<ProgressionQuest> quests})>[
      for (final goal in goals)
        (
          title: goal.title,
          quests: activeQuests
              .where((q) => q.goalId == goal.id)
              .take(2)
              .toList(growable: false),
        ),
    ];
    final unassigned = activeQuests
        .where((q) => q.goalId == null)
        .take(2)
        .toList(growable: false);
    final reward = 100 + (50 * (characterLevel - 1));
    String? skillName(ProgressionQuest quest) => skills
        .where((skill) => skill.id == quest.primarySkillId)
        .firstOrNull
        ?.name;
    Widget questColumn(String title, List<ProgressionQuest> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const _EmptySectionMessage(
            icon: Icons.assignment_outlined,
            title: 'No quests detected.',
            detail: 'Activate a progression template to begin.',
          )
        else
          for (final quest in items) ...[
            _QuestCard(
              quest: quest,
              reward: reward,
              skillName: skillName(quest),
              onObjectiveComplete: onObjectiveComplete,
              onQuestComplete: onQuestComplete,
            ),
            if (quest != items.last) const SizedBox(height: 10),
          ],
      ],
    );
    return _DashboardSection(
      title: 'ACTIVE QUESTS',
      trailing: '${activeQuests.length} active',
      child: activeQuests.isEmpty
          ? Column(
              children: [
                const _EmptySectionMessage(
                  icon: Icons.assignment_outlined,
                  title: 'No active quests detected.',
                  detail: 'Activate a progression template to begin your next quest.',
                ),
                for (final template in templates) ...[
                  _TemplateCard(
                    template: template,
                    onActivate: onActivateTemplate,
                    isActivating: activatingTemplateIds.contains(template.id),
                  ),
                  if (template != templates.last) const SizedBox(height: 10),
                ],
              ],
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final sections =
                    [
                          ...goalSections,
                          if (unassigned.isNotEmpty)
                            (title: 'SIDE QUESTS', quests: unassigned),
                        ]
                        .map(
                          (section) =>
                              questColumn(section.title, section.quests),
                        )
                        .toList();
                if (sections.isEmpty) return questColumn('QUESTS', const []);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < sections.length; index++) ...[
                      sections[index],
                      if (index != sections.length - 1)
                        const SizedBox(height: 18),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.reward,
    required this.skillName,
    required this.onObjectiveComplete,
    required this.onQuestComplete,
  });

  final ProgressionQuest quest;
  final int reward;
  final String? skillName;
  final Future<void> Function(String questId, String objectiveId)
  onObjectiveComplete;
  final Future<void> Function(String questId) onQuestComplete;

  @override
  Widget build(BuildContext context) {
    final completedObjectives = quest.objectives
        .where((objective) => objective.completed)
        .length;
    final progress = quest.objectives.isEmpty
        ? 0.0
        : (completedObjectives / quest.objectives.length)
              .clamp(0.0, 1.0)
              .toDouble();
    final type = quest.type == 'MAIN' ? 'MAIN QUEST' : 'SIDE QUEST';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.45),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xAA12345A), Color(0x66050B18)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGlow),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow.withOpacity(.16),
            blurRadius: 14,
          ),
        ],
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
          const SizedBox(height: 5),
          Text(
            quest.title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: AppColors.surfaceElevated,
            color: AppColors.primaryGlow,
          ),
          const SizedBox(height: 4),
          Text(
            '$completedObjectives / ${quest.objectives.length} objectives',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _RewardLabel(icon: Icons.bolt, text: '+$reward XP'),
              if (skillName != null)
                _RewardLabel(icon: Icons.auto_awesome, text: skillName!),
            ],
          ),
          if (quest.objectives.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final objective in quest.objectives)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: objective.completed
                      ? null
                      : () => onObjectiveComplete(quest.id, objective.id),
                  child: Text(
                    '${objective.completed ? '✓' : '○'} ${objective.title}',
                  ),
                ),
              ),
          ],
          if (quest.objectives.every((objective) => objective.completed))
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => onQuestComplete(quest.id),
                child: const Text('Complete quest'),
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onActivate,
    required this.isActivating,
  });
  final QuestTemplate template;
  final Future<void> Function(String templateId) onActivate;
  final bool isActivating;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.background.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                '${template.questCount} quests · ${template.milestoneCount} milestones',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: isActivating ? null : () => onActivate(template.id),
          child: isActivating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Activate'),
        ),
      ],
    ),
  );
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
