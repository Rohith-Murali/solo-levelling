import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/domain/dashboard_data.dart';
import '../../dashboard/domain/dashboard_repository.dart';
import '../../../shared/widgets/holographic_dialog.dart';
import '../../../shared/widgets/system_notification.dart';
import '../domain/progression_data.dart';
import '../domain/progression_repository.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    required this.repository,
    required this.dashboardRepository,
    required this.accessToken,
    required this.isActive,
    required this.onDataChanged,
    super.key,
  });
  final ProgressionRepository? repository;
  final DashboardRepository dashboardRepository;
  final String? accessToken;
  final bool isActive;
  final VoidCallback onDataChanged;
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<ProgressionGoal> _goals = const [];
  List<ProgressionMilestone> _milestones = const [];
  List<ProgressionQuest> _quests = const [];
  bool _loading = true;
  DashboardData? _dashboard;
  final _structureTick = ValueNotifier(0);

  @override
  void dispose() {
    _structureTick.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant GoalsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _load();
  }

  Future<void> _load() async {
    // This method is called from initState, refresh, and async action handlers.
    // It may therefore finish after this screen has been removed.
    if (!mounted) return;

    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      final data = await repo.loadStructure(token);
      if (!mounted) return;

      final dashboard = await widget.dashboardRepository.load(token);
      if (!mounted) return;

      setState(() {
        _goals = data.goals;
        _milestones = data.milestones;
        _quests = data.quests;
        _dashboard = dashboard;
      });
      _structureTick.value++;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final input = await showDialog<_GoalInput>(
      context: context,
      builder: (_) => _GoalDialog(skills: _dashboard?.skills ?? const []),
    );
    if (!mounted) return;
    final repo = widget.repository;
    final token = widget.accessToken;
    if (input == null || repo == null || token == null) return;
    try {
      await repo.createGoal(
        token,
        title: input.title,
        description: input.description,
        primarySkillId: input.skillId,
        statContributions: input.statContributions,
      );
      await _load();
      if (!mounted) return;
      await SystemNotification.show(
        context,
        icon: Icons.flag,
        message: 'GOAL UNLOCKED\n\n${input.title}',
      );
      if (!mounted) return;
      widget.onDataChanged();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _edit(ProgressionGoal goal) async {
    final input = await showDialog<_GoalInput>(
      context: context,
      builder: (_) =>
          _GoalDialog(goal: goal, skills: _dashboard?.skills ?? const []),
    );
    if (!mounted) return;
    final repo = widget.repository;
    final token = widget.accessToken;
    if (input == null || repo == null || token == null) return;
    await repo.updateGoal(
      token,
      goalId: goal.id,
      title: input.title,
      description: input.description,
      primarySkillId: input.skillId,
      statContributions: input.statContributions,
    );
    await _load();
    if (!mounted) return;
    widget.onDataChanged();
  }

  Future<void> _delete(ProgressionGoal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => HolographicDialog(
        title: 'Delete goal',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
        child: Text('Remove “${goal.title}” and its linked quests?'),
      ),
    );
    if (!mounted) return;
    final repo = widget.repository;
    final token = widget.accessToken;
    if (ok != true || repo == null || token == null) return;
    await repo.deleteGoal(token, goal.id);
    await _load();
    if (!mounted) return;
    widget.onDataChanged();
  }

  Future<void> _openGoal(ProgressionGoal goal) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ValueListenableBuilder<int>(
        valueListenable: _structureTick,
        builder: (context, _, __) {
          final current = _goals
              .where((item) => item.id == goal.id)
              .firstOrNull;
          if (current == null) {
            return HolographicDialog(
              title: goal.title,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
              child: const Text('This goal is no longer available.'),
            );
          }
          return _GoalDetailDialog(
            goal: current,
            milestones: _milestones
                .where(
                  (milestone) => current.milestoneIds.contains(milestone.id),
                )
                .toList(growable: false),
            quests: _quests
                .where((quest) => quest.goalId == current.id)
                .toList(growable: false),
            onEditMilestone: _editMilestone,
            onDeleteMilestone: _deleteMilestone,
            onAddMilestone: () => _addMilestone(current),
            onAddQuest: () => _addQuest(current),
            onEditQuest: (quest) => _editQuest(current, quest),
            onDeleteQuest: (quest) => _deleteQuest(current, quest),
            onCompleteQuest: _completeQuest,
            onCompleteMilestone: _completeMilestone,
            onCompleteGoal: _completeGoal,
          );
        },
      ),
    );
  }

  Future<void> _editMilestone(ProgressionMilestone milestone) async {
    final input = await showDialog<_PairInput>(
      context: context,
      builder: (_) => _PairDialog(
        title: 'Edit milestone',
        firstLabel: 'Milestone title',
        secondLabel: 'Description',
        first: milestone.title,
        second: milestone.description,
      ),
    );
    if (!mounted) return;
    final repo = widget.repository;
    final token = widget.accessToken;
    if (input == null || repo == null || token == null) return;
    final goal = _goals.firstWhere(
      (item) => item.milestoneIds.contains(milestone.id),
    );
    await repo.updateMilestone(
      token,
      goalId: goal.id,
      milestoneId: milestone.id,
      title: input.first,
      description: input.second,
    );
    await _load();
    if (!mounted) return;
    widget.onDataChanged();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _addMilestone(ProgressionGoal goal) async {
    final input = await showDialog<_PairInput>(
      context: context,
      builder: (_) => const _PairDialog(
        title: 'Add milestone',
        firstLabel: 'Milestone title',
        secondLabel: 'Description',
      ),
    );
    if (!mounted) return;
    final repo = widget.repository;
    final token = widget.accessToken;
    if (input == null || repo == null || token == null) return;
    await repo.createMilestone(
      token,
      goalId: goal.id,
      title: input.first,
      description: input.second,
    );
    await _load();
    if (!mounted) return;
    await SystemNotification.show(
      context,
      icon: Icons.flag_outlined,
      message: 'MILESTONE UNLOCKED\n\n${input.first}',
    );
    if (!mounted) return;
    widget.onDataChanged();
  }

  Future<void> _deleteMilestone(ProgressionMilestone milestone) async {
    final ok = await _confirm(
      'Delete milestone',
      'Delete “${milestone.title}”?',
    );
    if (!mounted) return;
    final repo = widget.repository;
    final token = widget.accessToken;
    if (!ok || repo == null || token == null) return;
    final goal = _goals.firstWhere(
      (item) => item.milestoneIds.contains(milestone.id),
    );
    await repo.deleteMilestone(token, goal.id, milestone.id);
    await _load();
    if (!mounted) return;
    widget.onDataChanged();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _editQuest(ProgressionGoal goal, ProgressionQuest quest) async {
    final goalMilestones = _milestones
        .where((milestone) => goal.milestoneIds.contains(milestone.id))
        .toList(growable: false);
    final input = await showDialog<_QuestInput>(
      context: context,
      builder: (_) => _QuestDialog(quest: quest, milestones: goalMilestones),
    );
    if (!mounted) return;
    final repo = widget.repository;
    final token = widget.accessToken;
    if (input == null || repo == null || token == null) return;
    await repo.updateGoalQuest(
      token,
      goalId: goal.id,
      questId: quest.id,
      title: input.title,
      description: input.description,
      difficulty: input.difficulty,
      milestoneId: input.milestoneId,
      statContributions: quest.statContributions,
    );
    await _load();
    if (!mounted) return;
    widget.onDataChanged();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _addQuest(ProgressionGoal goal) async {
    final goalMilestones = _milestones
        .where((milestone) => goal.milestoneIds.contains(milestone.id))
        .toList(growable: false);
    final input = await showDialog<_QuestInput>(
      context: context,
      builder: (_) => _QuestDialog(milestones: goalMilestones),
    );
    if (!mounted) return;
    final repo = widget.repository;
    final token = widget.accessToken;
    if (input == null || repo == null || token == null) return;
    try {
      await repo.createGoalQuest(
        token,
        goalId: goal.id,
        title: input.title,
        description: input.description,
        difficulty: input.difficulty,
        milestoneId: input.milestoneId,
      );
      await _load();
      if (!mounted) return;
      await SystemNotification.show(
        context,
        icon: Icons.add_task,
        message: 'QUEST UNLOCKED\n\n${input.title}',
      );
      if (!mounted) return;
      widget.onDataChanged();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _deleteQuest(
    ProgressionGoal goal,
    ProgressionQuest quest,
  ) async {
    final ok = await _confirm('Delete quest', 'Delete “${quest.title}”?');
    if (!mounted) return;
    final repo = widget.repository;
    final token = widget.accessToken;
    if (!ok || repo == null || token == null) return;
    await repo.deleteGoalQuest(token, goal.id, quest.id);
    await _load();
    if (!mounted) return;
    widget.onDataChanged();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _completeQuest(ProgressionQuest quest) async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    final before = _dashboard;
    try {
      await repo.completeQuest(token, quest.id);
      await _load();
      if (!mounted) return;
      final after = _dashboard;
      if (after == null) return;
      final xp = before == null
          ? 0
          : (after.character.totalXp - before.character.totalXp).clamp(
              0,
              1 << 30,
            );
      final notifications = <SystemNotificationData>[
        SystemNotificationData(
          icon: Icons.check_circle_outline,
          message: 'QUEST COMPLETED\n\n+$xp XP EARNED',
        ),
      ];
      final previousActivityIds = {
        for (final activity in before?.recentActivity ?? const []) activity.id,
      };
      final characterLevelledUp = after.recentActivity.any(
        (activity) =>
            !previousActivityIds.contains(activity.id) &&
            activity.type == 'CHARACTER_LEVEL_INCREASED',
      );
      if (characterLevelledUp ||
          (before != null && after.character.level > before.character.level)) {
        final levelsGained = before == null
            ? 1
            : after.character.level - before.character.level;
        notifications.add(
          SystemNotificationData(
            icon: Icons.trending_up,
            message: before != null && levelsGained > 1
                ? 'LEVELLED UP\n\nLV ${before.character.level} -> ${after.character.level} (+$levelsGained)'
                : 'LEVELLED UP\n\nLV ${after.character.level}',
          ),
        );
      }
      if (before != null) {
        final tokensEarned =
            after.character.skillUnlockTokens -
            before.character.skillUnlockTokens;
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
          final skillXpGained = (skill.totalXp - (oldSkill?.totalXp ?? 0))
              .clamp(0, 1 << 30);
          if (skillXpGained > 0) {
            notifications.add(
              SystemNotificationData(
                icon: Icons.auto_awesome,
                message:
                    '${skill.name.toUpperCase()}\n+$skillXpGained SKILL XP',
              ),
            );
          }
          final skillLevelledUp = after.recentActivity.any(
            (activity) =>
                !previousActivityIds.contains(activity.id) &&
                activity.type == 'SKILL_LEVEL_INCREASED' &&
                activity.relatedEntityId == skill.id,
          );
          if (skillLevelledUp ||
              (oldSkill != null && skill.level > oldSkill.level)) {
            notifications.add(
              SystemNotificationData(
                icon: Icons.auto_awesome,
                message: oldSkill != null && skill.level - oldSkill.level > 1
                    ? 'SKILL ${skill.name.toUpperCase()} LEVELLED UP\n\nLV ${oldSkill.level} -> ${skill.level}'
                    : 'SKILL ${skill.name.toUpperCase()} LEVELLED UP\n\nLV ${skill.level}',
              ),
            );
          }
        }
      }
      await SystemNotification.showStack(context, notifications);
      if (!mounted) return;
      widget.onDataChanged();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _completeMilestone(
    ProgressionGoal goal,
    ProgressionMilestone milestone,
  ) async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    final before = _dashboard;
    try {
      await repo.completeMilestone(token, goal.id, milestone.id);
      await _load();
      if (!mounted) return;
      final gainedXp =
          ((_dashboard?.character.totalXp ?? 0) -
                  (before?.character.totalXp ?? 0))
              .clamp(0, 1 << 30);
      await SystemNotification.show(
        context,
        icon: Icons.flag,
        message: 'MILESTONE COMPLETED\n\n${milestone.title}\n+$gainedXp XP',
      );
      if (!mounted) return;
      widget.onDataChanged();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _completeGoal(ProgressionGoal goal) async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    final before = _dashboard;
    try {
      await repo.completeGoal(token, goal.id);
      await _load();
      if (!mounted) return;
      final gainedXp =
          ((_dashboard?.character.totalXp ?? 0) -
                  (before?.character.totalXp ?? 0))
              .clamp(0, 1 << 30);
      await SystemNotification.show(
        context,
        icon: Icons.emoji_events,
        message: 'GOAL COMPLETED\n\n${goal.title}\n+$gainedXp XP',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDataChanged();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => HolographicDialog(
          title: title,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
          child: Text(message),
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    color: AppColors.accent,
    backgroundColor: AppColors.surface,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GOALS', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 5),
                  const Text(
                    'Choose the milestones and quests that shape your next level.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('New goal'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_loading && _goals.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_goals.isEmpty)
          const Text(
            'No goals created yet.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else ...[
          if (_goals.any((goal) => !goal.completed)) ...[
            const _GoalSectionTitle('ACTIVE GOALS'),
            for (final goal in _goals.where((goal) => !goal.completed)) ...[
              _GoalCard(
                goal: goal,
                questCount: _quests.where((q) => q.goalId == goal.id).length,
                onOpen: () => _openGoal(goal),
                onEdit: () => _edit(goal),
                onDelete: () => _delete(goal),
              ),
              const SizedBox(height: 12),
            ],
          ],
          if (_goals.any((goal) => goal.completed)) ...[
            const _GoalSectionTitle('COMPLETED GOALS'),
            for (final goal in _goals.where((goal) => goal.completed)) ...[
              _GoalCard(
                goal: goal,
                questCount: _quests.where((q) => q.goalId == goal.id).length,
                onOpen: () => _openGoal(goal),
                onEdit: () => _edit(goal),
                onDelete: () => _delete(goal),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ],
    ),
  );
}

const _goalStats = [
  'strength',
  'intelligence',
  'vitality',
  'discipline',
  'perception',
];

String _statLabel(String stat) => stat[0].toUpperCase() + stat.substring(1);

class _GoalInput {
  const _GoalInput(
    this.title,
    this.description,
    this.skillId,
    this.statContributions,
  );
  final String title;
  final String description;
  final String skillId;
  final List<String> statContributions;
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.skills, this.goal});
  final ProgressionGoal? goal;
  final List<DashboardSkill> skills;
  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final TextEditingController title = TextEditingController(
    text: widget.goal?.title,
  );
  late final TextEditingController description = TextEditingController(
    text: widget.goal?.description,
  );
  late String? skillId =
      widget.goal?.primarySkillId ??
      (widget.skills.isNotEmpty ? widget.skills.first.id : null);
  late final Set<String> statContributions = {
    ...(widget.goal?.statContributions ?? const <String>[]),
  };
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HolographicDialog(
    title: widget.goal == null ? 'New goal' : 'Edit goal',
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: skillId == null
            ? null
            : () {
                if (title.text.trim().isNotEmpty) {
                  Navigator.pop(
                    context,
                    _GoalInput(
                      title.text.trim(),
                      description.text.trim(),
                      skillId!,
                      statContributions.toList(growable: false),
                    ),
                  );
                }
              },
        child: Text(widget.goal == null ? 'Create' : 'Save'),
      ),
    ],
    child: Column(
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Goal title'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: skillId,
          decoration: const InputDecoration(labelText: 'Associated skill'),
          items: [
            for (final skill in widget.skills)
              DropdownMenuItem(value: skill.id, child: Text(skill.name)),
          ],
          onChanged: widget.skills.isEmpty
              ? null
              : (value) => setState(() => skillId = value),
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Stats increased by completing quests'),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final stat in _goalStats)
              FilterChip(
                label: Text(_statLabel(stat)),
                selected: statContributions.contains(stat),
                onSelected: (selected) {
                  setState(() {
                    if (selected && statContributions.length < 2) {
                      statContributions.add(stat);
                    } else if (!selected) {
                      statContributions.remove(stat);
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
      ],
    ),
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.questCount,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final ProgressionGoal goal;
  final int questCount;
  final VoidCallback onOpen;
  final VoidCallback onEdit, onDelete;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xCC12345A), Color(0x99202B55)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primaryGlow),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryGlow.withOpacity(.18),
          blurRadius: 18,
        ),
      ],
    ),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flag, color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                if (goal.description.isNotEmpty)
                  Text(
                    goal.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  '${goal.status}  •  $questCount quests',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 10,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit goal',
            iconSize: 15,
            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: AppColors.accent),
          ),
          IconButton(
            tooltip: 'Delete goal',
            iconSize: 15,
            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
    ),
  );
}

class _GoalSectionTitle extends StatelessWidget {
  const _GoalSectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(
      title,
      style: const TextStyle(
        color: AppColors.accent,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _PairInput {
  const _PairInput(this.first, this.second);
  final String first, second;
}

class _PairDialog extends StatefulWidget {
  const _PairDialog({
    required this.title,
    required this.firstLabel,
    required this.secondLabel,
    this.first,
    this.second,
  });
  final String title, firstLabel, secondLabel;
  final String? first, second;
  @override
  State<_PairDialog> createState() => _PairDialogState();
}

class _PairDialogState extends State<_PairDialog> {
  late final TextEditingController first = TextEditingController(
    text: widget.first,
  );
  late final TextEditingController second = TextEditingController(
    text: widget.second,
  );
  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HolographicDialog(
    title: widget.title,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (first.text.trim().isNotEmpty) {
            Navigator.pop(
              context,
              _PairInput(first.text.trim(), second.text.trim()),
            );
          }
        },
        child: const Text('Save'),
      ),
    ],
    child: Column(
      children: [
        TextField(
          controller: first,
          decoration: InputDecoration(labelText: widget.firstLabel),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: second,
          maxLines: 3,
          decoration: InputDecoration(labelText: widget.secondLabel),
        ),
      ],
    ),
  );
}

class _QuestInput {
  const _QuestInput(
    this.title,
    this.description,
    this.difficulty,
    this.milestoneId,
  );
  final String title, description, difficulty;
  final String? milestoneId;
}

class _QuestDialog extends StatefulWidget {
  const _QuestDialog({this.quest, required this.milestones});
  final ProgressionQuest? quest;
  final List<ProgressionMilestone> milestones;
  @override
  State<_QuestDialog> createState() => _QuestDialogState();
}

class _QuestDialogState extends State<_QuestDialog> {
  late final TextEditingController title = TextEditingController(
    text: widget.quest?.title,
  );
  late final TextEditingController description = TextEditingController(
    text: widget.quest?.description,
  );
  late String difficulty = widget.quest?.difficulty ?? 'NORMAL';
  late String milestoneId = widget.quest?.milestoneId ?? '';
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HolographicDialog(
    title: 'Edit quest',
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (title.text.trim().isNotEmpty) {
            Navigator.pop(
              context,
              _QuestInput(
                title.text.trim(),
                description.text.trim(),
                difficulty,
                milestoneId.isEmpty ? null : milestoneId,
              ),
            );
          }
        },
        child: const Text('Save'),
      ),
    ],
    child: Column(
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Quest title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: difficulty,
          decoration: const InputDecoration(labelText: 'Difficulty'),
          items: const [
            DropdownMenuItem(value: 'EASY', child: Text('EASY')),
            DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL')),
            DropdownMenuItem(value: 'HARD', child: Text('HARD')),
          ],
          onChanged: (value) =>
              setState(() => difficulty = value ?? difficulty),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: milestoneId,
          decoration: const InputDecoration(labelText: 'Milestone (optional)'),
          items: [
            const DropdownMenuItem(value: '', child: Text('No milestone')),
            for (final milestone in widget.milestones)
              DropdownMenuItem(
                value: milestone.id,
                child: Text(milestone.title),
              ),
          ],
          onChanged: (value) => setState(() => milestoneId = value ?? ''),
        ),
      ],
    ),
  );
}

enum _GoalFilter { active, completed, all }

class _GoalDetailDialog extends StatefulWidget {
  const _GoalDetailDialog({
    required this.goal,
    required this.milestones,
    required this.quests,
    required this.onEditMilestone,
    required this.onDeleteMilestone,
    required this.onAddMilestone,
    required this.onAddQuest,
    required this.onEditQuest,
    required this.onDeleteQuest,
    required this.onCompleteQuest,
    required this.onCompleteMilestone,
    required this.onCompleteGoal,
  });
  final ProgressionGoal goal;
  final List<ProgressionMilestone> milestones;
  final List<ProgressionQuest> quests;
  final ValueChanged<ProgressionMilestone> onEditMilestone, onDeleteMilestone;
  final VoidCallback onAddMilestone, onAddQuest;
  final ValueChanged<ProgressionQuest> onEditQuest, onDeleteQuest;
  final Future<void> Function(ProgressionQuest) onCompleteQuest;
  final Future<void> Function(ProgressionGoal, ProgressionMilestone)
  onCompleteMilestone;
  final Future<void> Function(ProgressionGoal) onCompleteGoal;

  @override
  State<_GoalDetailDialog> createState() => _GoalDetailDialogState();
}

class _GoalDetailDialogState extends State<_GoalDetailDialog> {
  _GoalFilter _filter = _GoalFilter.active;

  bool _matches(bool completed) => switch (_filter) {
    _GoalFilter.active => !completed,
    _GoalFilter.completed => completed,
    _GoalFilter.all => true,
  };

  @override
  Widget build(BuildContext context) => HolographicDialog(
    title: widget.goal.title,
    compact: true,
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.goal.description.isNotEmpty)
          Text(
            widget.goal.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onAddMilestone();
              },
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text('Add milestone'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onAddQuest();
              },
              icon: const Icon(Icons.add_task, size: 16),
              label: const Text('Add quest'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text(
              'SHOW',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            const SizedBox(width: 8),
            DropdownButton<_GoalFilter>(
              value: _filter,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: _GoalFilter.active,
                  child: Text('Active'),
                ),
                DropdownMenuItem(
                  value: _GoalFilter.completed,
                  child: Text('Completed'),
                ),
                DropdownMenuItem(value: _GoalFilter.all, child: Text('All')),
              ],
              onChanged: (value) =>
                  setState(() => _filter = value ?? _GoalFilter.active),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'MILESTONES',
          style: TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 5),
        if (widget.milestones.isEmpty)
          const Text(
            'No milestones yet.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        for (final milestone in widget.milestones.where((milestone) {
          final milestoneQuests = widget.quests.where(
            (quest) => quest.milestoneId == milestone.id,
          );
          return _matches(milestone.completed) ||
              milestoneQuests.any((quest) => _matches(quest.completed));
        }))
          _MilestoneTile(
            milestone: milestone,
            quests: widget.quests
                .where(
                  (quest) =>
                      quest.milestoneId == milestone.id &&
                      _matches(quest.completed),
                )
                .toList(growable: false),
            canComplete:
                !milestone.completed &&
                widget.quests.any(
                  (quest) => quest.milestoneId == milestone.id,
                ) &&
                widget.quests
                    .where((quest) => quest.milestoneId == milestone.id)
                    .every((quest) => quest.completed),
            onEdit: () => widget.onEditMilestone(milestone),
            onDelete: () => widget.onDeleteMilestone(milestone),
            onEditQuest: widget.onEditQuest,
            onDeleteQuest: widget.onDeleteQuest,
            onCompleteQuest: widget.onCompleteQuest,
            onCompleteMilestone: () =>
                widget.onCompleteMilestone(widget.goal, milestone),
          ),
        if (widget.quests.any(
          (quest) => quest.milestoneId == null && _matches(quest.completed),
        )) ...[
          const SizedBox(height: 12),
          const Text(
            'SIDE QUESTS',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          for (final quest in widget.quests.where(
            (quest) => quest.milestoneId == null && _matches(quest.completed),
          ))
            _QuestTile(
              quest: quest,
              onEdit: () => widget.onEditQuest(quest),
              onDelete: () => widget.onDeleteQuest(quest),
              onComplete: () => widget.onCompleteQuest(quest),
            ),
        ],
        if (!widget.goal.completed &&
            widget.milestones.isNotEmpty &&
            widget.milestones.every((milestone) => milestone.completed) &&
            widget.quests.every((quest) => quest.completed))
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                visualDensity: const VisualDensity(
                  horizontal: -3,
                  vertical: -3,
                ),
              ),
              onPressed: () => widget.onCompleteGoal(widget.goal),
              child: const Text('Complete goal'),
            ),
          ),
      ],
    ),
  );
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({
    required this.milestone,
    required this.quests,
    required this.onEdit,
    required this.onDelete,
    required this.onEditQuest,
    required this.onDeleteQuest,
    required this.onCompleteQuest,
    required this.onCompleteMilestone,
    required this.canComplete,
  });
  final ProgressionMilestone milestone;
  final List<ProgressionQuest> quests;
  final VoidCallback onEdit, onDelete;
  final ValueChanged<ProgressionQuest> onEditQuest, onDeleteQuest;
  final Future<void> Function(ProgressionQuest) onCompleteQuest;
  final Future<void> Function() onCompleteMilestone;
  final bool canComplete;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                milestone.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            IconButton(
              iconSize: 15,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.accent,
              ),
            ),
            IconButton(
              iconSize: 15,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
        if (milestone.description.isNotEmpty)
          Text(
            milestone.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        if (canComplete)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
              ),
              onPressed: onCompleteMilestone,
              icon: const Icon(Icons.check, size: 13),
              label: const Text(
                'Complete milestone',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ),
        for (final quest in quests)
          _QuestTile(
            quest: quest,
            onEdit: () => onEditQuest(quest),
            onDelete: () => onDeleteQuest(quest),
            onComplete: () => onCompleteQuest(quest),
          ),
      ],
    ),
  );
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({
    required this.quest,
    required this.onEdit,
    required this.onDelete,
    required this.onComplete,
  });
  final ProgressionQuest quest;
  final VoidCallback onEdit, onDelete;
  final Future<void> Function() onComplete;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
      leading: Icon(
        quest.completed ? Icons.check_circle : Icons.track_changes,
        color: quest.completed ? Colors.greenAccent : AppColors.accent,
      ),
      title: Text(
        quest.title,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${quest.difficulty} • ${quest.completed ? 'Completed' : 'Active'}',
      ),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => HolographicDialog(
          title: 'Quest details',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
          child: _DashboardStyleQuestCard(quest: quest, onComplete: onComplete),
        ),
      ),
      trailing: Wrap(
        children: [
          IconButton(
            tooltip: 'Edit quest',
            iconSize: 15,
            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: AppColors.accent),
          ),
          IconButton(
            tooltip: 'Delete quest',
            iconSize: 15,
            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
    ),
  );
}

class _DashboardStyleQuestCard extends StatelessWidget {
  const _DashboardStyleQuestCard({
    required this.quest,
    required this.onComplete,
  });
  final ProgressionQuest quest;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final progress = quest.completed ? 1.0 : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
                quest.type == 'MAIN' ? 'MAIN QUEST' : 'SIDE QUEST',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                quest.difficulty,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            quest.title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            quest.description.isEmpty ? 'No description.' : quest.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: AppColors.surfaceElevated,
            color: AppColors.primaryGlow,
          ),
          const SizedBox(height: 4),
          Text(
            quest.completed ? 'COMPLETED' : 'ACTIVE',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          if (!quest.completed) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await onComplete();
                },
                child: const Text('Complete quest'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
