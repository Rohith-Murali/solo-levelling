import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/domain/dashboard_data.dart';
import '../../dashboard/domain/dashboard_repository.dart';
import '../../../shared/widgets/holographic_dialog.dart';
import '../../notifications/notification_service.dart';
import '../domain/progression_data.dart';
import '../domain/progression_repository.dart';
import 'quests_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    required this.repository,
    required this.dashboardRepository,
    required this.accessToken,
    required this.isActive,
    required this.onDataChanged,
    this.onOpenQuest,
    super.key,
  });

  final ProgressionRepository? repository;
  final DashboardRepository dashboardRepository;
  final String? accessToken;
  final bool isActive;
  final VoidCallback onDataChanged;
  final ValueChanged<String>? onOpenQuest;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<ProgressionGoal> _goals = const [];
  List<ProgressionMilestone> _milestones = const [];
  List<ProgressionQuest> _quests = const [];
  bool _loading = true;
  DashboardData? _dashboard;
  String? _errorMessage;
  String? _selectedGoalId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant GoalsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;

    final repo = widget.repository;
    final token = widget.accessToken;

    if (repo == null || token == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Progression service is unavailable.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final structure = await repo.loadStructure(token);
      if (!mounted) return;

      final dashboard = await widget.dashboardRepository.load(token);
      if (!mounted) return;

      setState(() {
        _goals = structure.goals;
        _milestones = structure.milestones;
        _quests = structure.quests;
        _dashboard = dashboard;
        _loading = false;

        // If the currently selected goal was removed, return to the goals list.
        if (_selectedGoalId != null &&
            !_goals.any((goal) => goal.id == _selectedGoalId)) {
          _selectedGoalId = null;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to load goals. Please try again.';
      });
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    final message = error is ApiException
        ? error.message
        : 'Something went wrong. Please try again.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => HolographicDialog(
        title: title,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
        child: Text(message),
      ),
    );
    return result ?? false;
  }

  Future<void> _create() async {
    final input = await showDialog<_GoalInput>(
      context: context,
      builder: (_) => _GoalDialog(skills: _dashboard?.skills ?? const []),
    );
    if (!mounted || input == null) return;

    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;

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
      await NotificationService.showGoalUnlocked(context, input.title);
      if (!mounted) return;
      widget.onDataChanged();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _edit(ProgressionGoal goal) async {
    final input = await showDialog<_GoalInput>(
      context: context,
      builder: (_) =>
          _GoalDialog(goal: goal, skills: _dashboard?.skills ?? const []),
    );
    if (!mounted || input == null) return;

    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;

    try {
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
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(ProgressionGoal goal) async {
    final ok = await _confirm(
      'Delete goal',
      'Remove “${goal.title}” and its linked quests?',
    );
    if (!mounted || !ok) return;

    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;

    try {
      await repo.deleteGoal(token, goal.id);
      if (_selectedGoalId == goal.id) {
        setState(() => _selectedGoalId = null);
      }
      await _load();
      if (!mounted) return;
      widget.onDataChanged();
    } catch (error) {
      _showError(error);
    }
  }

  void _openGoal(ProgressionGoal goal) {
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
      builder: (dialogContext) => HolographicDialog(
        title: 'Add milestone',
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
                ));
              }
            },
            child: const Text('Save'),
          ),
        ],
        child: Column(
          children: [
            TextFormField(
              onChanged: (value) => title = value,
              decoration: const InputDecoration(labelText: 'Milestone title'),
            ),
            const SizedBox(height: 12),
            TextFormField(
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
      await NotificationService.showMilestoneUnlocked(context, input.title);
      if (!mounted) return;
      widget.onDataChanged();
    } catch (error) {
      _showError(error);
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
      builder: (dialogContext) => HolographicDialog(
        title: 'Edit milestone',
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
      await repo.updateMilestone(
        token,
        goalId: goal.id,
        milestoneId: milestone.id,
        title: input.title,
        description: input.description,
      );
      await _load();
      if (!mounted) return;
      widget.onDataChanged();
    } catch (error) {
      _showError(error);
    }
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

    try {
      await repo.deleteMilestone(token, goal.id, milestone.id);
      await _load();
      if (!mounted) return;
      widget.onDataChanged();
    } catch (error) {
      _showError(error);
    }
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
                      DropdownMenuItem(value: 'EPIC', child: Text('EPIC')),
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
        await NotificationService.showQuestUnlocked(context, input.title);
      }
      if (!mounted) return;
      widget.onDataChanged();
    } catch (error) {
      _showError(error);
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

    try {
      await repo.deleteGoalQuest(token, goal.id, quest.id);
      await _load();
      if (!mounted) return;
      widget.onDataChanged();
    } catch (error) {
      _showError(error);
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

      await NotificationService.showProgressionCompletion(
        context,
        before: before,
        after: after,
        completionTitle: notificationTitle,
        completionSubject: title,
        completionIcon: icon,
      );
      if (!mounted) return;
      widget.onDataChanged();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        onEditMilestone: (milestone) => _editMilestone(selectedGoal, milestone),
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
        onBack: () => setState(() => _selectedGoalId = null),
      );
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GOALS',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
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
            else if (_errorMessage != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
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
                    questCount: _quests
                        .where((q) => q.goalId == goal.id)
                        .length,
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
                    questCount: _quests
                        .where((q) => q.goalId == goal.id)
                        .length,
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
      ),
    );
  }
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
