import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/holographic_dialog.dart';
import '../../../shared/widgets/system_notification.dart';
import '../domain/progression_data.dart';
import '../domain/progression_repository.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    required this.repository,
    required this.accessToken,
    required this.isActive,
    super.key,
  });
  final ProgressionRepository? repository;
  final String? accessToken;
  final bool isActive;
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<ProgressionGoal> _goals = const [];
  List<ProgressionMilestone> _milestones = const [];
  List<ProgressionQuest> _quests = const [];
  bool _loading = true;

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
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await repo.loadStructure(token);
      if (mounted)
        setState(() {
          _goals = data.goals;
          _milestones = data.milestones;
          _quests = data.quests;
        });
    } on ApiException {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final input = await showDialog<_GoalInput>(
      context: context,
      builder: (_) => const _GoalDialog(),
    );
    final repo = widget.repository;
    final token = widget.accessToken;
    if (input == null || repo == null || token == null) return;
    await repo.createGoal(
      token,
      title: input.title,
      description: input.description,
    );
    _load();
  }

  Future<void> _edit(ProgressionGoal goal) async {
    final input = await showDialog<_GoalInput>(
      context: context,
      builder: (_) => _GoalDialog(goal: goal),
    );
    final repo = widget.repository;
    final token = widget.accessToken;
    if (input == null || repo == null || token == null) return;
    await repo.updateGoal(
      token,
      goalId: goal.id,
      title: input.title,
      description: input.description,
    );
    _load();
  }

  Future<void> _delete(ProgressionGoal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => HolographicDialog(
        title: 'Delete goal',
        child: Text('Remove “${goal.title}” and its linked quests?'),
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
      ),
    );
    final repo = widget.repository;
    final token = widget.accessToken;
    if (ok != true || repo == null || token == null) return;
    await repo.deleteGoal(token, goal.id);
    _load();
  }

  Future<void> _openGoal(ProgressionGoal goal) async {
    final quests = _quests
        .where((quest) => quest.goalId == goal.id)
        .toList(growable: false);
    final milestones = _milestones
        .where((milestone) => goal.milestoneIds.contains(milestone.id))
        .toList(growable: false);
    await showDialog<void>(
      context: context,
      builder: (_) => _GoalDetailDialog(
        goal: goal,
        milestones: milestones,
        quests: quests,
        onEditMilestone: _editMilestone,
        onDeleteMilestone: _deleteMilestone,
        onAddMilestone: () => _addMilestone(goal),
        onAddQuest: () => _addQuest(goal),
        onEditQuest: (quest) => _editQuest(goal, quest),
        onDeleteQuest: (quest) => _deleteQuest(goal, quest),
        onCompleteQuest: _completeQuest,
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
    _load();
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
    final repo = widget.repository;
    final token = widget.accessToken;
    if (input == null || repo == null || token == null) return;
    await repo.createMilestone(
      token,
      goalId: goal.id,
      title: input.first,
      description: input.second,
    );
    _load();
  }

  Future<void> _deleteMilestone(ProgressionMilestone milestone) async {
    final ok = await _confirm(
      'Delete milestone',
      'Delete “${milestone.title}”?',
    );
    final repo = widget.repository;
    final token = widget.accessToken;
    if (!ok || repo == null || token == null) return;
    final goal = _goals.firstWhere(
      (item) => item.milestoneIds.contains(milestone.id),
    );
    await repo.deleteMilestone(token, goal.id, milestone.id);
    _load();
  }

  Future<void> _editQuest(ProgressionGoal goal, ProgressionQuest quest) async {
    final goalMilestones = _milestones
        .where((milestone) => goal.milestoneIds.contains(milestone.id))
        .toList(growable: false);
    final input = await showDialog<_QuestInput>(
      context: context,
      builder: (_) => _QuestDialog(quest: quest, milestones: goalMilestones),
    );
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
      objectives: quest.objectives
          .map((item) => item.title)
          .toList(growable: false),
      statContributions: quest.statContributions,
    );
    _load();
  }

  Future<void> _addQuest(ProgressionGoal goal) async {
    final goalMilestones = _milestones
        .where((milestone) => goal.milestoneIds.contains(milestone.id))
        .toList(growable: false);
    final input = await showDialog<_QuestInput>(
      context: context,
      builder: (_) => _QuestDialog(milestones: goalMilestones),
    );
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
      _load();
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
    final repo = widget.repository;
    final token = widget.accessToken;
    if (!ok || repo == null || token == null) return;
    await repo.deleteGoalQuest(token, goal.id, quest.id);
    _load();
  }

  Future<void> _completeQuest(ProgressionQuest quest) async {
    final repo = widget.repository;
    final token = widget.accessToken;
    if (repo == null || token == null) return;
    try {
      await repo.completeQuest(token, quest.id);
      await _load();
      if (mounted) {
        await SystemNotification.show(
          context,
          icon: Icons.assignment_turned_in,
          message: 'QUEST COMPLETED\n\n${quest.title}',
        );
      }
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
          child: Text(message),
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
                    'Choose the objectives that shape your next level.',
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

class _GoalInput {
  const _GoalInput(this.title, this.description);
  final String title;
  final String description;
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({this.goal});
  final ProgressionGoal? goal;
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
  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HolographicDialog(
    title: widget.goal == null ? 'New goal' : 'Edit goal',
    child: Column(
      children: [
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Goal title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: description,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (title.text.trim().isNotEmpty)
            Navigator.pop(
              context,
              _GoalInput(title.text.trim(), description.text.trim()),
            );
        },
        child: Text(widget.goal == null ? 'Create' : 'Save'),
      ),
    ],
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (first.text.trim().isNotEmpty)
            Navigator.pop(
              context,
              _PairInput(first.text.trim(), second.text.trim()),
            );
        },
        child: const Text('Save'),
      ),
    ],
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
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (title.text.trim().isNotEmpty)
            Navigator.pop(
              context,
              _QuestInput(
                title.text.trim(),
                description.text.trim(),
                difficulty,
                milestoneId.isEmpty ? null : milestoneId,
              ),
            );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _GoalDetailDialog extends StatelessWidget {
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
  });
  final ProgressionGoal goal;
  final List<ProgressionMilestone> milestones;
  final List<ProgressionQuest> quests;
  final ValueChanged<ProgressionMilestone> onEditMilestone, onDeleteMilestone;
  final VoidCallback onAddMilestone, onAddQuest;
  final ValueChanged<ProgressionQuest> onEditQuest, onDeleteQuest;
  final Future<void> Function(ProgressionQuest) onCompleteQuest;
  @override
  Widget build(BuildContext context) => HolographicDialog(
    title: goal.title,
    compact: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (goal.description.isNotEmpty)
          Text(
            goal.description,
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
                onAddMilestone();
              },
              icon: const Icon(Icons.flag_outlined, size: 16),
              label: const Text('Add milestone'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onAddQuest();
              },
              icon: const Icon(Icons.add_task, size: 16),
              label: const Text('Add quest'),
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
        if (milestones.isEmpty)
          const Text(
            'No milestones yet.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        for (final milestone in milestones)
          _MilestoneTile(
            milestone: milestone,
            quests: quests
                .where((quest) => quest.milestoneId == milestone.id)
                .toList(growable: false),
            onEdit: () => onEditMilestone(milestone),
            onDelete: () => onDeleteMilestone(milestone),
            onEditQuest: onEditQuest,
            onDeleteQuest: onDeleteQuest,
            onCompleteQuest: onCompleteQuest,
          ),
        if (quests.any((quest) => quest.milestoneId == null)) ...[
          const SizedBox(height: 12),
          const Text(
            'UNLINKED QUESTS',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          for (final quest in quests.where(
            (quest) => quest.milestoneId == null,
          ))
            _QuestTile(
              quest: quest,
              onEdit: () => onEditQuest(quest),
              onDelete: () => onDeleteQuest(quest),
              onComplete: () => onCompleteQuest(quest),
            ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
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
  });
  final ProgressionMilestone milestone;
  final List<ProgressionQuest> quests;
  final VoidCallback onEdit, onDelete;
  final ValueChanged<ProgressionQuest> onEditQuest, onDeleteQuest;
  final Future<void> Function(ProgressionQuest) onCompleteQuest;
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
          child: _DashboardStyleQuestCard(quest: quest, onComplete: onComplete),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (!quest.completed)
              FilledButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await onComplete();
                },
                child: const Text('Complete quest'),
              ),
          ],
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
    final completed = quest.objectives.where((item) => item.completed).length;
    final total = quest.objectives.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final canComplete = quest.objectives.every((item) => item.completed);
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
            '$completed / $total objectives',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          if (quest.objectives.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final objective in quest.objectives)
              Text(
                '${objective.completed ? '✓' : '○'} ${objective.title}',
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
          ],
          if (!quest.completed) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: canComplete
                    ? () async {
                        Navigator.pop(context);
                        await onComplete();
                      }
                    : null,
                child: Text(
                  canComplete ? 'Complete quest' : 'Complete objectives',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
