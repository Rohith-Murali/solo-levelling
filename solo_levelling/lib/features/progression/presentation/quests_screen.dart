import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/holographic_dialog.dart';
import '../domain/progression_data.dart';

enum QuestFilter { active, completed, all }

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
