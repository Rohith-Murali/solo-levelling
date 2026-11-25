import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/holographic_dialog.dart';
import '../../../shared/widgets/system_notification.dart';
import '../../dashboard/domain/dashboard_repository.dart';
import '../domain/progression_data.dart';
import '../domain/progression_repository.dart';

class QuestOverviewScreen extends StatefulWidget {
  const QuestOverviewScreen({
    required this.repository,
    required this.dashboardRepository,
    required this.accessToken,
    required this.isActive,
    required this.onDataChanged,
    this.goalId,
    this.onClearGoal,
    super.key,
  });

  final ProgressionRepository? repository;
  final DashboardRepository dashboardRepository;
  final String? accessToken;
  final bool isActive;
  final VoidCallback onDataChanged;
  final String? goalId;
  final VoidCallback? onClearGoal;

  @override
  State<QuestOverviewScreen> createState() => _QuestOverviewScreenState();
}

class _QuestOverviewScreenState extends State<QuestOverviewScreen> {
  List<ProgressionQuest> _quests = const [];
  List<ProgressionGoal> _goals = const [];
  List<ProgressionMilestone> _milestones = const [];
  bool _loading = true;
  String? _errorMessage;
  String? _selectedGoalId;

  @override
  void initState() {
    super.initState();
    _selectedGoalId = widget.goalId;
    _load();
  }

  @override
  void didUpdateWidget(covariant QuestOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.goalId != widget.goalId) {
      _selectedGoalId = widget.goalId;
    }
    if (!oldWidget.isActive && widget.isActive) _load();
  }

  Future<void> _load() async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final structure = await repo.loadStructure(token);
      if (!mounted) return;
      setState(() {
        _quests = structure.quests;
        _goals = structure.goals;
        _milestones = structure.milestones;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _completeQuest(ProgressionQuest quest) async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    await _completeAndNotify(
      token: token,
      title: quest.title,
      notificationTitle: 'QUEST COMPLETED',
      icon: Icons.check_circle_outline,
      complete: () => repo.completeQuest(token, quest.id),
    );
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

  Future<void> _openGoal(ProgressionGoal goal) async {
    setState(() => _selectedGoalId = goal.id);
  }

  Future<void> _addMilestone(ProgressionGoal goal) async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    var title = '';
    var description = '';
    final input = await showDialog<({String title, String description})>(
      context: context,
      builder: (_) => HolographicDialog(
        title: 'Add milestone',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (title.trim().isNotEmpty) {
                Navigator.pop(context, (
                  title: title.trim(),
                  description: description.trim(),
                ));
              }
            },
            child: const Text('Save'),
          ),
        ],
        child: Column(
          children: [
            TextFormField(
              initialValue: title,
              onChanged: (value) => title = value,
              decoration: const InputDecoration(labelText: 'Milestone title'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: description,
              onChanged: (value) => description = value,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || input == null) return;
    try {
      await repo.createMilestone(
        token,
        goalId: goal.id,
        title: input.title,
        description: input.description,
      );
      await _load();
      if (!mounted) return;
      await SystemNotification.show(
        context,
        icon: Icons.flag_outlined,
        message: 'MILESTONE UNLOCKED\n\n${input.title}',
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

  Future<void> _editMilestone(
    ProgressionGoal goal,
    ProgressionMilestone milestone,
  ) async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    var title = milestone.title;
    var description = milestone.description;
    final input = await showDialog<({String title, String description})>(
      context: context,
      builder: (_) => HolographicDialog(
        title: 'Edit milestone',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (title.trim().isNotEmpty) {
                Navigator.pop(context, (
                  title: title.trim(),
                  description: description.trim(),
                ));
              }
            },
            child: const Text('Save'),
          ),
        ],
        child: Column(
          children: [
            TextFormField(
              initialValue: title,
              onChanged: (value) => title = value,
              decoration: const InputDecoration(labelText: 'Milestone title'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: description,
              onChanged: (value) => description = value,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || input == null) return;
    await repo.updateMilestone(
      token,
      goalId: goal.id,
      milestoneId: milestone.id,
      title: input.title,
      description: input.description,
    );
    await _load();
  }

  Future<void> _deleteMilestone(
    ProgressionGoal goal,
    ProgressionMilestone milestone,
  ) async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    final ok = await _confirm(
      'Delete milestone',
      'Delete “${milestone.title}”?',
    );
    if (!mounted || !ok) return;
    await repo.deleteMilestone(token, goal.id, milestone.id);
    await _load();
  }

  Future<void> _addQuest(ProgressionGoal goal) async {
    await _editQuestDialog(goal, null);
  }

  Future<void> _editQuest(ProgressionGoal goal, ProgressionQuest quest) async {
    await _editQuestDialog(goal, quest);
  }

  Future<void> _editQuestDialog(
    ProgressionGoal goal,
    ProgressionQuest? quest,
  ) async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    var title = quest?.title ?? '';
    var description = quest?.description ?? '';
    var difficulty = quest?.difficulty ?? 'NORMAL';
    var milestoneId = quest?.milestoneId ?? '';
    final input =
        await showDialog<
          ({
            String title,
            String description,
            String difficulty,
            String? milestoneId,
          })
        >(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => HolographicDialog(
              title: quest == null ? 'Add quest' : 'Edit quest',
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (title.trim().isNotEmpty) {
                      Navigator.pop(dialogContext, (
                        title: title.trim(),
                        description: description.trim(),
                        difficulty: difficulty,
                        milestoneId: milestoneId.isEmpty ? null : milestoneId,
                      ));
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
              child: Column(
                children: [
                  TextFormField(
                    initialValue: title,
                    onChanged: (value) => title = value,
                    decoration: const InputDecoration(labelText: 'Quest title'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: description,
                    onChanged: (value) => description = value,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: difficulty,
                    decoration: const InputDecoration(labelText: 'Difficulty'),
                    items: const [
                      DropdownMenuItem(value: 'EASY', child: Text('EASY')),
                      DropdownMenuItem(value: 'NORMAL', child: Text('NORMAL')),
                      DropdownMenuItem(value: 'HARD', child: Text('HARD')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => difficulty = value ?? difficulty),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: milestoneId,
                    decoration: const InputDecoration(
                      labelText: 'Milestone (optional)',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('No milestone'),
                      ),
                      for (final item in _milestones.where(
                        (item) => goal.milestoneIds.contains(item.id),
                      ))
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(item.title),
                        ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => milestoneId = value ?? ''),
                  ),
                ],
              ),
            ),
          ),
        );
    if (!mounted || input == null) return;
    try {
      if (quest == null) {
        await repo.createGoalQuest(
          token,
          goalId: goal.id,
          title: input.title,
          description: input.description,
          difficulty: input.difficulty,
          milestoneId: input.milestoneId,
        );
      } else {
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
      }
      await _load();
      if (!mounted) return;
      if (quest == null) {
        await SystemNotification.show(
          context,
          icon: Icons.add_task,
          message: 'QUEST UNLOCKED\n\n${input.title}',
        );
        if (!mounted) return;
        widget.onDataChanged();
      }
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
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    final ok = await _confirm('Delete quest', 'Delete “${quest.title}”?');
    if (!mounted || !ok) return;
    await repo.deleteGoalQuest(token, goal.id, quest.id);
    await _load();
  }

  Future<void> _completeMilestone(
    ProgressionGoal goal,
    ProgressionMilestone milestone,
  ) async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    await _completeAndNotify(
      token: token,
      title: milestone.title,
      notificationTitle: 'MILESTONE COMPLETED',
      icon: Icons.flag,
      complete: () => repo.completeMilestone(token, goal.id, milestone.id),
    );
  }

  Future<void> _completeGoal(ProgressionGoal goal) async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    await _completeAndNotify(
      token: token,
      title: goal.title,
      notificationTitle: 'GOAL COMPLETED',
      icon: Icons.emoji_events,
      complete: () => repo.completeGoal(token, goal.id),
    );
  }

  Future<void> _completeAndNotify({
    required String token,
    required String title,
    required String notificationTitle,
    required IconData icon,
    required Future<void> Function() complete,
  }) async {
    try {
      final before = await widget.dashboardRepository.load(token);
      await complete();
      await _load();
      if (!mounted) return;
      final after = await widget.dashboardRepository.load(token);
      if (!mounted) return;
      final gainedXp = (after.character.totalXp - before.character.totalXp)
          .clamp(0, 1 << 30);
      await SystemNotification.show(
        context,
        icon: icon,
        message: '$notificationTitle\n\n$title\n+$gainedXp XP',
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

  @override
  Widget build(BuildContext context) {
    final activeQuests = _quests
        .where((quest) => !quest.completed)
        .toList(growable: false);
    final completedQuests = _quests
        .where((quest) => quest.completed)
        .toList(growable: false);
    if (_selectedGoalId != null) {
      final selectedGoal = _goals
          .where((goal) => goal.id == _selectedGoalId)
          .firstOrNull;
      if (selectedGoal != null) {
        return QuestsScreen(
          goal: selectedGoal,
          milestones: _milestones
              .where(
                (milestone) => selectedGoal.milestoneIds.contains(milestone.id),
              )
              .toList(growable: false),
          quests: _quests
              .where((quest) => quest.goalId == selectedGoal.id)
              .toList(growable: false),
          onEditMilestone: (milestone) =>
              _editMilestone(selectedGoal, milestone),
          onDeleteMilestone: (milestone) =>
              _deleteMilestone(selectedGoal, milestone),
          onAddMilestone: () => _addMilestone(selectedGoal),
          onAddQuest: () => _addQuest(selectedGoal),
          onEditQuest: (quest) => _editQuest(selectedGoal, quest),
          onDeleteQuest: (quest) => _deleteQuest(selectedGoal, quest),
          onCompleteQuest: _completeQuest,
          onCompleteMilestone: (milestone) =>
              _completeMilestone(selectedGoal, milestone),
          onCompleteGoal: () => _completeGoal(selectedGoal),
          onRefresh: _load,
          onBack: () {
            setState(() => _selectedGoalId = null);
            widget.onClearGoal?.call();
          },
        );
      }
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xCC12345A), Color(0xCC08142B)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.75),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGlow.withValues(alpha: 0.16),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QUEST MATRIX',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${activeQuests.length} active • ${completedQuests.length} completed',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (!_loading && _errorMessage == null && activeQuests.isEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xAA12345A), Color(0x66050B18)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryGlow),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGlow.withValues(alpha: 0.12),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      color: AppColors.accent,
                      size: 28,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'NO ACTIVE QUESTS',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.textSecondary),
              )
            else ...[
              const Text(
                'GOALS',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              if (_goals.isEmpty)
                const Text(
                  'No goals created yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                for (final goal in _goals) ...[
                  _GoalOverviewCard(
                    goal: goal,
                    quests: _quests
                        .where((quest) => quest.goalId == goal.id)
                        .toList(growable: false),
                    onTap: () => _openGoal(goal),
                  ),
                  const SizedBox(height: 12),
                ],
              if (_quests.any((quest) => quest.goalId == null)) ...[
                const SizedBox(height: 6),
                const Text(
                  'SIDE QUESTS',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                for (final quest in _quests.where(
                  (quest) => quest.goalId == null,
                )) ...[
                  _OverviewQuestCard(
                    quest: quest,
                    onComplete: () => _completeQuest(quest),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

enum QuestFilter { active, completed, all }

class _GoalOverviewCard extends StatelessWidget {
  const _GoalOverviewCard({
    required this.goal,
    required this.quests,
    required this.onTap,
  });

  final ProgressionGoal goal;
  final List<ProgressionQuest> quests;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeCount = quests.where((quest) => !quest.completed).length;
    final completedCount = quests.where((quest) => quest.completed).length;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE012345A), Color(0xC908142B)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow.withValues(alpha: 0.12),
            blurRadius: 18,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent),
                ),
                child: Icon(
                  goal.completed ? Icons.check_circle : Icons.flag,
                  color: goal.completed ? Colors.greenAccent : AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
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
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '$activeCount active • $completedCount completed',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewQuestCard extends StatelessWidget {
  const _OverviewQuestCard({required this.quest, required this.onComplete});

  final ProgressionQuest quest;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) => Container(
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
          color: AppColors.primaryGlow.withValues(alpha: 0.16),
          blurRadius: 14,
        ),
      ],
    ),
    child: InkWell(
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
          child: _QuestDetails(
            quest: quest,
            onComplete: () async {
              Navigator.pop(context);
              await onComplete();
            },
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
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
                  fontWeight: FontWeight.w700,
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
          const SizedBox(height: 5),
          Text(
            quest.title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: quest.completed ? 1 : 0,
            minHeight: 4,
            backgroundColor: AppColors.surfaceElevated,
            color: AppColors.primaryGlow,
          ),
          const SizedBox(height: 4),
          Text(
            quest.completed ? 'COMPLETED' : 'ACTIVE',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '+${quest.characterXpReward} XP',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({
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
    required this.onRefresh,
    this.onBack,
    super.key,
  });

  final ProgressionGoal goal;
  final List<ProgressionMilestone> milestones;
  final List<ProgressionQuest> quests;
  final ValueChanged<ProgressionMilestone> onEditMilestone;
  final ValueChanged<ProgressionMilestone> onDeleteMilestone;
  final VoidCallback onAddMilestone;
  final VoidCallback onAddQuest;
  final ValueChanged<ProgressionQuest> onEditQuest;
  final ValueChanged<ProgressionQuest> onDeleteQuest;
  final Future<void> Function(ProgressionQuest) onCompleteQuest;
  final Future<void> Function(ProgressionMilestone) onCompleteMilestone;
  final Future<void> Function() onCompleteGoal;
  final Future<void> Function() onRefresh;
  final VoidCallback? onBack;

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  QuestFilter _filter = QuestFilter.active;

  bool _matches(bool completed) => switch (_filter) {
    QuestFilter.active => !completed,
    QuestFilter.completed => completed,
    QuestFilter.all => true,
  };

  @override
  Widget build(BuildContext context) {
    final filteredMilestones = widget.milestones
        .where((milestone) {
          final milestoneQuests = widget.quests.where(
            (quest) => quest.milestoneId == milestone.id,
          );
          return _matches(milestone.completed) ||
              milestoneQuests.any((quest) => _matches(quest.completed));
        })
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.goal.title),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack ?? () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            if (widget.goal.description.isNotEmpty)
              Text(
                widget.goal.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onAddMilestone,
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: const Text('Add milestone'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onAddQuest,
                  icon: const Icon(Icons.add_task, size: 16),
                  label: const Text('Add quest'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'SHOW',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<QuestFilter>(
                  value: _filter,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(
                      value: QuestFilter.active,
                      child: Text('Active'),
                    ),
                    DropdownMenuItem(
                      value: QuestFilter.completed,
                      child: Text('Completed'),
                    ),
                    DropdownMenuItem(
                      value: QuestFilter.all,
                      child: Text('All'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _filter = value ?? QuestFilter.active),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_filter == QuestFilter.active &&
                !widget.quests.any((quest) => !quest.completed))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xAA12345A), Color(0x66050B18)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryGlow),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      color: AppColors.accent,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'NO ACTIVE QUESTS',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'There are no active quests for this goal.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
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
            for (final milestone in filteredMilestones)
              _MilestoneCard(
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
                    widget.onCompleteMilestone(milestone),
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
              const SizedBox(height: 6),
              for (final quest in widget.quests.where(
                (quest) =>
                    quest.milestoneId == null && _matches(quest.completed),
              ))
                _QuestCard(
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
                  onPressed: widget.onCompleteGoal,
                  child: const Text('Complete goal'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ProgressionQuest> onEditQuest;
  final ValueChanged<ProgressionQuest> onDeleteQuest;
  final Future<void> Function(ProgressionQuest) onCompleteQuest;
  final Future<void> Function() onCompleteMilestone;
  final bool canComplete;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xE012345A), Color(0xC908142B)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.55)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryGlow.withValues(alpha: 0.10),
          blurRadius: 16,
        ),
      ],
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
                  fontSize: 14,
                ),
              ),
            ),
            if (milestone.completed)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent),
                ),
                child: const Text(
                  'COMPLETED',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Edit milestone',
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.accent,
              ),
            ),
            IconButton(
              tooltip: 'Delete milestone',
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
              fontSize: 12,
            ),
          ),
        if (canComplete)
          TextButton.icon(
            onPressed: onCompleteMilestone,
            icon: const Icon(Icons.check, size: 14),
            label: const Text('Complete milestone'),
          ),
        for (final quest in quests) ...[
          const SizedBox(height: 8),
          _QuestCard(
            quest: quest,
            onEdit: () => onEditQuest(quest),
            onDelete: () => onDeleteQuest(quest),
            onComplete: () => onCompleteQuest(quest),
          ),
        ],
      ],
    ),
  );
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.onEdit,
    required this.onDelete,
    required this.onComplete,
  });

  final ProgressionQuest quest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xAA12345A), Color(0x66050B18)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primaryGlow),
    ),
    child: InkWell(
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
          child: _QuestDetails(
            quest: quest,
            onComplete: () async {
              Navigator.pop(context);
              await onComplete();
            },
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
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
            const SizedBox(height: 7),
            LinearProgressIndicator(
              value: quest.completed ? 1 : 0,
              minHeight: 4,
              backgroundColor: AppColors.surfaceElevated,
              color: AppColors.primaryGlow,
            ),
            const SizedBox(height: 4),
            Text(
              quest.completed ? 'COMPLETED' : 'ACTIVE',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '+${quest.characterXpReward} XP',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit quest',
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.accent,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete quest',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuestDetails extends StatelessWidget {
  const _QuestDetails({required this.quest, required this.onComplete});

  final ProgressionQuest quest;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xAA12345A), Color(0x66050B18)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primaryGlow),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          quest.description.isEmpty ? 'No description.' : quest.description,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Text(
          '+${quest.characterXpReward} XP',
          style: const TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (!quest.completed) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onComplete,
              child: const Text('Complete quest'),
            ),
          ),
        ],
      ],
    ),
  );
}
