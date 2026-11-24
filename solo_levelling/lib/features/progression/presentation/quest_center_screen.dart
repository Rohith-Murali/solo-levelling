import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/domain/dashboard_repository.dart';
import '../../dashboard/domain/dashboard_data.dart';
import '../domain/progression_data.dart';
import '../domain/progression_repository.dart';
import '../../../shared/widgets/system_notification.dart';
import '../../../shared/widgets/holographic_dialog.dart';

class QuestCenterScreen extends StatefulWidget {
  const QuestCenterScreen({
    required this.repository,
    required this.accessToken,
    required this.isActive,
    required this.onDataChanged,
    required this.dashboardRepository,
    super.key,
  });

  final ProgressionRepository? repository;
  final String? accessToken;
  final bool isActive;
  final VoidCallback onDataChanged;
  final DashboardRepository dashboardRepository;

  @override
  State<QuestCenterScreen> createState() => _QuestCenterScreenState();
}

class _QuestCenterScreenState extends State<QuestCenterScreen> {
  List<ProgressionQuest> _quests = const [];
  List<ProgressionGoal> _goals = const [];
  List<QuestTemplate> _templates = const [];
  List<LibrarySkill> _skills = const [];
  DashboardData? _dashboard;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant QuestCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _load();
  }

  Future<void> _load() async {
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Quest services are unavailable. Sign in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final structure = await repository.loadStructure(token);
      final templates = await repository.loadTemplates(token);
      final skills = await repository.loadSkillLibrary(token);
      final dashboard = await widget.dashboardRepository.load(token);
      if (!mounted) return;
      setState(() {
        _quests = structure.quests;
        _goals = structure.goals;
        _templates = templates;
        _skills = skills;
        _dashboard = dashboard;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error, stackTrace) {
      AppLogger.unexpected('quest-center-load', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Quest data could not be loaded. Try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _performMutation(Future<void> Function() action) async {
    if (_isMutating) return false;
    setState(() {
      _isMutating = true;
      _errorMessage = null;
    });
    try {
      await action();
      await _load();
      widget.onDataChanged();
      return true;
    } on ApiException catch (error) {
      if (!mounted) return false;
      if (error.code == 'CONCURRENT_UPDATE') {
        await _load();
      }
      if (error.code == 'TEMPLATE_ALREADY_ACTIVE') {
        await _load();
        return false;
      }
      if (mounted) setState(() => _errorMessage = error.message);
      return false;
    } catch (error, stackTrace) {
      AppLogger.unexpected('quest-center-update', error, stackTrace);
      if (!mounted) return false;
      setState(() {
        _errorMessage = 'The quest could not be updated. Try again.';
      });
      return false;
    } finally {
      if (mounted) setState(() => _isMutating = false);
    }
  }

  Future<void> _activateTemplate(String templateId) async {
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    await _performMutation(
      () => repository.activateTemplate(token, templateId),
    );
  }

  Future<void> _completeObjective(String questId, String objectiveId) async {
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    await _performMutation(
      () => repository.completeObjective(token, questId, objectiveId),
    );
  }

  /* Goal editing is handled by GoalsScreen. */
  /*
  Future<void> _createMilestone(ProgressionGoal goal) async {
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    final input = await showDialog<_MilestoneInput>(
      context: context,
      builder: (_) => const _MilestoneDialog(),
    );
    if (input == null) return;
    await _performMutation(
      () => repository.createMilestone(
        token,
        goalId: goal.id,
        title: input.title,
        description: input.description,
      ),
    );
  }

  Future<void> _editMilestone(
    ProgressionGoal goal,
    ProgressionMilestone milestone,
  ) async {
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    final input = await showDialog<_MilestoneInput>(
      context: context,
      builder: (_) => _MilestoneDialog(milestone: milestone),
    );
    if (input == null) return;
    await _performMutation(
      () => repository.updateMilestone(
        token,
        goalId: goal.id,
        milestoneId: milestone.id,
        title: input.title,
        description: input.description,
      ),
    );
  }

  Future<void> _deleteMilestone(
    ProgressionGoal goal,
    ProgressionMilestone milestone,
  ) async {
    if (!await _confirmDelete(milestone.title, 'milestone')) return;
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    await _performMutation(
      () => repository.deleteMilestone(token, goal.id, milestone.id),
    );
  }

  Future<void> _createGoalQuest(ProgressionGoal goal) async {
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    final milestones = _milestones
        .where((milestone) => goal.milestoneIds.contains(milestone.id))
        .toList(growable: false);
    final input = await showDialog<_GoalQuestInput>(
      context: context,
      builder: (_) => _GoalQuestDialog(milestones: milestones),
    );
    if (input == null) return;
    await _performMutation(
      () => repository.createGoalQuest(
        token,
        goalId: goal.id,
        title: input.title,
        description: input.description,
        difficulty: input.difficulty,
        milestoneId: input.milestoneId,
        objectives: input.objectives,
        statContributions: input.stats,
      ),
    );
  }

  Future<void> _editGoalQuest(
    ProgressionGoal goal,
    ProgressionQuest quest,
  ) async {
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    final milestones = _milestones
        .where((milestone) => goal.milestoneIds.contains(milestone.id))
        .toList(growable: false);
    final input = await showDialog<_GoalQuestInput>(
      context: context,
      builder: (_) => _GoalQuestDialog(milestones: milestones, quest: quest),
    );
    if (input == null) return;
    await _performMutation(
      () => repository.updateGoalQuest(
        token,
        goalId: goal.id,
        questId: quest.id,
        title: input.title,
        description: input.description,
        difficulty: input.difficulty,
        milestoneId: input.milestoneId,
        objectives: input.objectives,
        statContributions: input.stats,
      ),
    );
  }

  Future<void> _deleteGoalQuest(
    ProgressionGoal goal,
    ProgressionQuest quest,
  ) async {
    if (!await _confirmDelete(quest.title, 'quest')) return;
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    await _performMutation(
      () => repository.deleteGoalQuest(token, goal.id, quest.id),
    );
  }

  Future<bool> _confirmDelete(String title, String type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete $type'),
        content: Text('Delete "$title"?'),
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
    return confirmed == true;
  }
  */

  Future<void> _createSideQuest() async {
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    final input = await showDialog<_SideQuestInput>(
      context: context,
      builder: (context) => _SideQuestCreatorDialog(skills: _skills),
    );
    if (input == null) return;
    await _performMutation(
      () => repository.createSideQuest(
        token,
        title: input.title,
        description: input.description,
        difficulty: input.difficulty,
        primarySkillId: input.skillId,
        skillName: input.customSkillName,
        objectives: input.objectives,
        statContributions: input.stats,
      ),
    );
  }

  void _showQuestDetail(ProgressionQuest quest) {
    showDialog<void>(
      context: context,
      builder: (_) => HolographicDialog(
        title: 'Quest details',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              quest.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              quest.description.isEmpty
                  ? 'No briefing provided.'
                  : quest.description,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              '${quest.type}  •  ${quest.difficulty}  •  ${quest.completed ? 'COMPLETED' : 'ACTIVE'}',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (quest.objectives.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'OBJECTIVES',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final objective in quest.objectives)
                Text(
                  '${objective.completed ? '✓' : '○'} ${objective.title}',
                  style: const TextStyle(height: 1.8),
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
      ),
    );
  }

  Future<void> _completeQuest(String questId) async {
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    final beforeQuest = _quests
        .where((quest) => quest.id == questId)
        .firstOrNull;
    final beforeDashboard = await widget.dashboardRepository.load(token);
    final succeeded = await _performMutation(
      () => repository.completeQuest(token, questId),
    );
    if (!succeeded) return;
    final afterDashboard = await widget.dashboardRepository.load(token);
    final xp =
        (afterDashboard.character.totalXp - beforeDashboard.character.totalXp)
            .clamp(0, 1 << 30);
    if (mounted && beforeQuest != null) {
      final notifications = <SystemNotificationData>[
        SystemNotificationData(
          icon: Icons.check_circle_outline,
          message: 'QUEST COMPLETED\n\n${beforeQuest.title}\n\n+$xp XP EARNED',
        ),
      ];
      if (afterDashboard.character.level > beforeDashboard.character.level) {
        notifications.add(
          SystemNotificationData(
            icon: Icons.trending_up,
            message: 'LEVELLED UP\n\nLV ${afterDashboard.character.level}',
          ),
        );
      }
      final oldSkills = {
        for (final skill in beforeDashboard.skills) skill.id: skill,
      };
      for (final skill in afterDashboard.skills) {
        final oldSkill = oldSkills[skill.id];
        if (oldSkill != null && skill.level > oldSkill.level) {
          notifications.add(
            SystemNotificationData(
              icon: Icons.auto_awesome,
              message:
                  'SKILL ${skill.name.toUpperCase()} LEVELLED UP\n\nLV ${skill.level}',
            ),
          );
        }
      }
      await SystemNotification.showStack(context, notifications);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activatedTemplateIds = _quests
        .map((quest) => quest.sourceTemplateId)
        .whereType<String>()
        .toSet();
    final availableTemplates = _templates
        .where((template) => !activatedTemplateIds.contains(template.id))
        .toList(growable: false);
    final activeQuests = _quests
        .where((quest) => !quest.completed)
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Text('QUEST CENTER', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Activate a template to add quests. Completing quests awards Character XP; Skill XP is awarded only to an acquired associated skill.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _isMutating ? null : _createSideQuest,
                icon: const Icon(Icons.add_task),
                label: const Text('Create side quest'),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _QuestNotice(message: _errorMessage!, onRetry: _load),
          ],
          if (_isLoading && _quests.isEmpty && _templates.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 22),
          _QuestSection(
            title: 'QUESTS BY GOAL',
            child: activeQuests.isEmpty
                ? const _QuestEmptyMessage('No active quests.')
                : Column(
                    children: [
                      for (final goal in _goals) ...[
                        if (activeQuests.any(
                          (quest) => quest.goalId == goal.id,
                        )) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                goal.title.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                          for (final quest in activeQuests.where(
                            (quest) => quest.goalId == goal.id,
                          )) ...[
                            _QuestEntry(
                              quest: quest,
                              reward:
                                  100 +
                                  (50 *
                                      ((_dashboard?.character.level ?? 1) - 1)),
                              skillName: _dashboard?.skills
                                  .where(
                                    (skill) => skill.id == quest.primarySkillId,
                                  )
                                  .firstOrNull
                                  ?.name,
                              isMutating: _isMutating,
                              onCompleteObjective: _completeObjective,
                              onCompleteQuest: _completeQuest,
                              onTap: () => _showQuestDetail(quest),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                      for (final quest in activeQuests.where(
                        (quest) => quest.goalId == null,
                      )) ...[
                        _QuestEntry(
                          quest: quest,
                          reward:
                              100 +
                              (50 * ((_dashboard?.character.level ?? 1) - 1)),
                          skillName: _dashboard?.skills
                              .where(
                                (skill) => skill.id == quest.primarySkillId,
                              )
                              .firstOrNull
                              ?.name,
                          isMutating: _isMutating,
                          onCompleteObjective: _completeObjective,
                          onCompleteQuest: _completeQuest,
                          onTap: () => _showQuestDetail(quest),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          _QuestSection(
            title: 'AVAILABLE TEMPLATES',
            child: availableTemplates.isEmpty
                ? const _QuestEmptyMessage(
                    'No new templates are available at your current level.',
                  )
                : Column(
                    children: [
                      for (final template in availableTemplates) ...[
                        _TemplateEntry(
                          template: template,
                          isMutating: _isMutating,
                          onActivate: _activateTemplate,
                        ),
                        if (template != availableTemplates.last)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/* Legacy goal dialogs moved to GoalsScreen.
class _SimpleGoalInput {
  const _SimpleGoalInput({
    required this.title,
    required this.description,
    required this.skillId,
    required this.customSkillName,
  });
  final String title;
  final String description;
  final String? skillId;
  final String? customSkillName;
}

class _TextGoalInput {
  const _TextGoalInput({required this.title, required this.description});
  final String title;
  final String description;
}

class _MilestoneInput {
  const _MilestoneInput({required this.title, required this.description});
  final String title;
  final String description;
}

class _GoalQuestInput {
  const _GoalQuestInput({
    required this.title,
    required this.description,
    required this.difficulty,
    required this.milestoneId,
    required this.objectives,
    required this.stats,
  });
  final String title;
  final String description;
  final String difficulty;
  final String? milestoneId;
  final List<String> objectives;
  final List<String> stats;
}

class _SimpleGoalDialog extends StatefulWidget {
  const _SimpleGoalDialog({required this.skills});
  final List<LibrarySkill> skills;

  @override
  State<_SimpleGoalDialog> createState() => _SimpleGoalDialogState();
}

class _SimpleGoalDialogState extends State<_SimpleGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _customSkill = TextEditingController();
  String? _skillId;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _customSkill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: const Text('Create goal'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                maxLength: 120,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a goal title.'
                    : null,
                decoration: const InputDecoration(labelText: 'Goal title'),
              ),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _skillId,
                decoration: const InputDecoration(
                  labelText: 'Associated skill',
                ),
                items: [
                  for (final skill in widget.skills)
                    DropdownMenuItem(value: skill.id, child: Text(skill.name)),
                  const DropdownMenuItem(
                    value: '__CUSTOM__',
                    child: Text('Create a new skill'),
                  ),
                ],
                validator: (value) => value == null ? 'Select a skill.' : null,
                onChanged: (value) => setState(() => _skillId = value),
              ),
              if (_skillId == '__CUSTOM__')
                TextFormField(
                  controller: _customSkill,
                  maxLength: 80,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a skill name.'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'New skill name',
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!(_formKey.currentState?.validate() ?? false)) return;
          Navigator.pop(
            context,
            _SimpleGoalInput(
              title: _title.text.trim(),
              description: _description.text.trim(),
              skillId: _skillId == '__CUSTOM__' ? null : _skillId,
              customSkillName: _skillId == '__CUSTOM__'
                  ? _customSkill.text.trim()
                  : null,
            ),
          );
        },
        child: const Text('Create'),
      ),
    ],
  );
}

class _TextGoalDialog extends StatefulWidget {
  const _TextGoalDialog({required this.goal});
  final ProgressionGoal goal;

  @override
  State<_TextGoalDialog> createState() => _TextGoalDialogState();
}

class _TextGoalDialogState extends State<_TextGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.goal.title);
    _description = TextEditingController(text: widget.goal.description);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: const Text('Edit goal'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _title,
            maxLength: 120,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a goal title.'
                : null,
            decoration: const InputDecoration(labelText: 'Goal title'),
          ),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!(_formKey.currentState?.validate() ?? false)) return;
          Navigator.pop(
            context,
            _TextGoalInput(
              title: _title.text.trim(),
              description: _description.text.trim(),
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _MilestoneDialog extends StatefulWidget {
  const _MilestoneDialog({this.milestone});
  final ProgressionMilestone? milestone;

  @override
  State<_MilestoneDialog> createState() => _MilestoneDialogState();
}

class _MilestoneDialogState extends State<_MilestoneDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.milestone?.title);
    _description = TextEditingController(text: widget.milestone?.description);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: Text(widget.milestone == null ? 'Add milestone' : 'Edit milestone'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _title,
            maxLength: 120,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a milestone title.'
                : null,
            decoration: const InputDecoration(labelText: 'Milestone title'),
          ),
          TextFormField(
            controller: _description,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!(_formKey.currentState?.validate() ?? false)) return;
          Navigator.pop(
            context,
            _MilestoneInput(
              title: _title.text.trim(),
              description: _description.text.trim(),
            ),
          );
        },
        child: Text(widget.milestone == null ? 'Add' : 'Save'),
      ),
    ],
  );
}

class _GoalQuestDialog extends StatefulWidget {
  const _GoalQuestDialog({required this.milestones, this.quest});
  final List<ProgressionMilestone> milestones;
  final ProgressionQuest? quest;

  @override
  State<_GoalQuestDialog> createState() => _GoalQuestDialogState();
}

class _GoalQuestDialogState extends State<_GoalQuestDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _objectives;
  late String _difficulty;
  String? _milestoneId;
  final Set<String> _stats = {'discipline'};

  @override
  void initState() {
    super.initState();
    final quest = widget.quest;
    _title = TextEditingController(text: quest?.title);
    _description = TextEditingController(text: quest?.description);
    _objectives = TextEditingController(
      text:
          quest?.objectives.map((objective) => objective.title).join(', ') ??
          '',
    );
    _difficulty = quest?.difficulty ?? 'NORMAL';
    _milestoneId = quest?.milestoneId;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _objectives.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: Text(widget.quest == null ? 'Add quest' : 'Edit quest'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                maxLength: 120,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a quest title.'
                    : null,
                decoration: const InputDecoration(labelText: 'Quest title'),
              ),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              DropdownButtonFormField<String?>(
                initialValue: _milestoneId,
                decoration: const InputDecoration(
                  labelText: 'Milestone (optional)',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No milestone'),
                  ),
                  for (final milestone in widget.milestones)
                    DropdownMenuItem<String?>(
                      value: milestone.id,
                      child: Text(milestone.title),
                    ),
                ],
                onChanged: (value) => setState(() => _milestoneId = value),
              ),
              DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const [
                  DropdownMenuItem(value: 'EASY', child: Text('Easy')),
                  DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                  DropdownMenuItem(value: 'HARD', child: Text('Hard')),
                  DropdownMenuItem(value: 'EPIC', child: Text('Epic')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _difficulty = value);
                },
              ),
              TextFormField(
                controller: _objectives,
                decoration: const InputDecoration(
                  labelText: 'Objectives (comma separated, optional)',
                ),
              ),
              const SizedBox(height: 10),
              _StatPicker(selected: _stats, onChanged: () => setState(() {})),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!(_formKey.currentState?.validate() ?? false)) return;
          Navigator.pop(
            context,
            _GoalQuestInput(
              title: _title.text.trim(),
              description: _description.text.trim(),
              difficulty: _difficulty,
              milestoneId: _milestoneId,
              objectives: _objectives.text
                  .split(',')
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(growable: false),
              stats: _stats.toList(growable: false),
            ),
          );
        },
        child: Text(widget.quest == null ? 'Add' : 'Save'),
      ),
    ],
  );
}

class _GoalInput {
  const _GoalInput({
    required this.title,
    required this.description,
    required this.skillId,
    required this.customSkillName,
    required this.milestoneTitle,
    required this.questTitle,
    required this.questDescription,
    required this.difficulty,
    required this.objectives,
    required this.stats,
  });
  final String title;
  final String description;
  final String? skillId;
  final String? customSkillName;
  final String milestoneTitle;
  final String questTitle;
  final String questDescription;
  final String difficulty;
  final List<String> objectives;
  final List<String> stats;
}

*/

class _GoalInput {
  const _GoalInput({
    required this.title,
    required this.description,
    required this.skillId,
    required this.customSkillName,
    required this.milestoneTitle,
    required this.questTitle,
    required this.questDescription,
    required this.difficulty,
    required this.objectives,
    required this.stats,
  });
  final String title;
  final String description;
  final String? skillId;
  final String? customSkillName;
  final String milestoneTitle;
  final String questTitle;
  final String questDescription;
  final String difficulty;
  final List<String> objectives;
  final List<String> stats;
}

class _SideQuestInput {
  const _SideQuestInput({
    required this.title,
    required this.description,
    required this.skillId,
    required this.customSkillName,
    required this.difficulty,
    required this.objectives,
    required this.stats,
  });
  final String title;
  final String description;
  final String? skillId;
  final String? customSkillName;
  final String difficulty;
  final List<String> objectives;
  final List<String> stats;
}

class _GoalCreatorDialog extends StatefulWidget {
  const _GoalCreatorDialog({required this.skills});
  final List<LibrarySkill> skills;

  @override
  State<_GoalCreatorDialog> createState() => _GoalCreatorDialogState();
}

class _GoalCreatorDialogState extends State<_GoalCreatorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _milestone = TextEditingController();
  final _questTitle = TextEditingController();
  final _questDescription = TextEditingController();
  final _objectives = TextEditingController();
  final _customSkill = TextEditingController();
  String? _skillId;
  String _difficulty = 'NORMAL';
  final Set<String> _stats = {'discipline'};

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _milestone.dispose();
    _questTitle.dispose();
    _questDescription.dispose();
    _objectives.dispose();
    _customSkill.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final objectiveList = _objectives.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    Navigator.pop(
      context,
      _GoalInput(
        title: _title.text.trim(),
        description: _description.text.trim(),
        skillId: _skillId == '__CUSTOM__' ? null : _skillId,
        customSkillName: _skillId == '__CUSTOM__'
            ? _customSkill.text.trim()
            : null,
        milestoneTitle: _milestone.text.trim(),
        questTitle: _questTitle.text.trim(),
        questDescription: _questDescription.text.trim(),
        difficulty: _difficulty,
        objectives: objectiveList,
        stats: _stats.toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: const Text('Create goal'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                maxLength: 120,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a goal title.'
                    : null,
                decoration: const InputDecoration(labelText: 'Goal title'),
              ),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _skillId,
                decoration: const InputDecoration(
                  labelText: 'Associated skill',
                ),
                items: [
                  for (final skill in widget.skills)
                    DropdownMenuItem(value: skill.id, child: Text(skill.name)),
                  const DropdownMenuItem(
                    value: '__CUSTOM__',
                    child: Text('Create a new skill'),
                  ),
                ],
                validator: (value) => value == null ? 'Select a skill.' : null,
                onChanged: (value) => setState(() => _skillId = value),
              ),
              if (_skillId == '__CUSTOM__')
                TextFormField(
                  controller: _customSkill,
                  maxLength: 80,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a skill name.'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'New skill name',
                  ),
                ),
              TextFormField(
                controller: _milestone,
                maxLength: 120,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a milestone title.'
                    : null,
                decoration: const InputDecoration(labelText: 'Milestone title'),
              ),
              TextFormField(
                controller: _questTitle,
                maxLength: 120,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a main quest title.'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Main quest title',
                ),
              ),
              TextFormField(
                controller: _questDescription,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Quest description',
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const [
                  DropdownMenuItem(value: 'EASY', child: Text('Easy')),
                  DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                  DropdownMenuItem(value: 'HARD', child: Text('Hard')),
                  DropdownMenuItem(value: 'EPIC', child: Text('Epic')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _difficulty = value);
                },
              ),
              TextFormField(
                controller: _objectives,
                decoration: const InputDecoration(
                  labelText: 'Objectives (comma separated, optional)',
                ),
              ),
              const SizedBox(height: 10),
              _StatPicker(selected: _stats, onChanged: () => setState(() {})),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Create')),
    ],
  );
}

class _SideQuestCreatorDialog extends StatefulWidget {
  const _SideQuestCreatorDialog({required this.skills});
  final List<LibrarySkill> skills;

  @override
  State<_SideQuestCreatorDialog> createState() =>
      _SideQuestCreatorDialogState();
}

class _SideQuestCreatorDialogState extends State<_SideQuestCreatorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _objectives = TextEditingController();
  final _customSkill = TextEditingController();
  String? _skillId;
  String _difficulty = 'NORMAL';
  final Set<String> _stats = {'discipline'};

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _objectives.dispose();
    _customSkill.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _SideQuestInput(
        title: _title.text.trim(),
        description: _description.text.trim(),
        skillId: _skillId == '__CUSTOM__' ? null : _skillId,
        customSkillName: _skillId == '__CUSTOM__'
            ? _customSkill.text.trim()
            : null,
        difficulty: _difficulty,
        objectives: _objectives.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        stats: _stats.toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: const Text('Create side quest'),
    content: SizedBox(
      width: 520,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                maxLength: 120,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a quest title.'
                    : null,
                decoration: const InputDecoration(labelText: 'Quest title'),
              ),
              TextFormField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _skillId,
                decoration: const InputDecoration(labelText: 'Primary skill'),
                items: [
                  for (final skill in widget.skills)
                    DropdownMenuItem(value: skill.id, child: Text(skill.name)),
                  const DropdownMenuItem(
                    value: '__CUSTOM__',
                    child: Text('Create a new skill'),
                  ),
                ],
                validator: (value) => value == null ? 'Select a skill.' : null,
                onChanged: (value) => setState(() => _skillId = value),
              ),
              if (_skillId == '__CUSTOM__')
                TextFormField(
                  controller: _customSkill,
                  maxLength: 80,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a skill name.'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'New skill name',
                  ),
                ),
              DropdownButtonFormField<String>(
                initialValue: _difficulty,
                decoration: const InputDecoration(labelText: 'Difficulty'),
                items: const [
                  DropdownMenuItem(value: 'EASY', child: Text('Easy')),
                  DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                  DropdownMenuItem(value: 'HARD', child: Text('Hard')),
                  DropdownMenuItem(value: 'EPIC', child: Text('Epic')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _difficulty = value);
                },
              ),
              TextFormField(
                controller: _objectives,
                decoration: const InputDecoration(
                  labelText: 'Objectives (comma separated, optional)',
                ),
              ),
              const SizedBox(height: 10),
              _StatPicker(selected: _stats, onChanged: () => setState(() {})),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Create')),
    ],
  );
}

class _StatPicker extends StatelessWidget {
  const _StatPicker({required this.selected, required this.onChanged});
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    const stats = [
      ('strength', 'Strength'),
      ('intelligence', 'Intelligence'),
      ('vitality', 'Vitality'),
      ('discipline', 'Discipline'),
      ('perception', 'Perception'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final stat in stats)
          FilterChip(
            label: Text(stat.$2),
            selected: selected.contains(stat.$1),
            onSelected: (value) {
              if (value) {
                if (selected.length >= 2) return;
                selected.add(stat.$1);
              } else {
                if (selected.length <= 1) return;
                selected.remove(stat.$1);
              }
              onChanged();
            },
          ),
      ],
    );
  }
}

class _QuestSection extends StatelessWidget {
  const _QuestSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _QuestEmptyMessage extends StatelessWidget {
  const _QuestEmptyMessage(this.message);
  final String message;

  @override
  Widget build(BuildContext context) =>
      Text(message, style: const TextStyle(color: AppColors.textSecondary));
}

/* Legacy goal detail widgets moved to GoalsScreen.
class _GoalEntry extends StatelessWidget {
  const _GoalEntry({
    required this.goal,
    required this.isMutating,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });
  final ProgressionGoal goal;
  final bool isMutating;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => _QuestCard(
    child: InkWell(
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (goal.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    goal.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${goal.status} · ${goal.milestoneIds.length} milestones',
                  style: const TextStyle(color: AppColors.accent, fontSize: 11),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !isMutating,
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit goal')),
              PopupMenuItem(value: 'delete', child: Text('Delete goal')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _GoalDetailDialog extends StatelessWidget {
  const _GoalDetailDialog({
    required this.goal,
    required this.milestones,
    required this.quests,
    required this.onAddMilestone,
    required this.onEditMilestone,
    required this.onDeleteMilestone,
    required this.onAddQuest,
    required this.onEditQuest,
    required this.onDeleteQuest,
  });
  final ProgressionGoal goal;
  final List<ProgressionMilestone> milestones;
  final List<ProgressionQuest> quests;
  final Future<void> Function() onAddMilestone;
  final Future<void> Function(ProgressionMilestone) onEditMilestone;
  final Future<void> Function(ProgressionMilestone) onDeleteMilestone;
  final Future<void> Function() onAddQuest;
  final Future<void> Function(ProgressionQuest) onEditQuest;
  final Future<void> Function(ProgressionQuest) onDeleteQuest;

  Future<void> _runAndClose(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    Navigator.pop(context);
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final unlinkedQuests = quests
        .where((quest) => quest.milestoneId == null)
        .toList(growable: false);
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(goal.title),
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (goal.description.isNotEmpty)
                Text(
                  goal.description,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _runAndClose(context, onAddQuest),
                    icon: const Icon(Icons.add_task),
                    label: const Text('Add quest'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _runAndClose(context, onAddMilestone),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Add milestone'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final milestone in milestones) ...[
                _MilestoneDetail(
                  milestone: milestone,
                  quests: quests
                      .where((quest) => quest.milestoneId == milestone.id)
                      .toList(growable: false),
                  onEdit: () =>
                      _runAndClose(context, () => onEditMilestone(milestone)),
                  onDelete: () =>
                      _runAndClose(context, () => onDeleteMilestone(milestone)),
                  onEditQuest: (quest) =>
                      _runAndClose(context, () => onEditQuest(quest)),
                  onDeleteQuest: (quest) =>
                      _runAndClose(context, () => onDeleteQuest(quest)),
                ),
                const SizedBox(height: 12),
              ],
              if (unlinkedQuests.isNotEmpty) ...[
                const Text(
                  'UNLINKED QUESTS',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                for (final quest in unlinkedQuests) ...[
                  _GoalQuestDetail(
                    quest: quest,
                    onEdit: () =>
                        _runAndClose(context, () => onEditQuest(quest)),
                    onDelete: () =>
                        _runAndClose(context, () => onDeleteQuest(quest)),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _MilestoneDetail extends StatelessWidget {
  const _MilestoneDetail({
    required this.milestone,
    required this.quests,
    required this.onEdit,
    required this.onDelete,
    required this.onEditQuest,
    required this.onDeleteQuest,
  });
  final ProgressionMilestone milestone;
  final List<ProgressionQuest> quests;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<ProgressionQuest> onEditQuest;
  final ValueChanged<ProgressionQuest> onDeleteQuest;

  @override
  Widget build(BuildContext context) => _QuestCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                milestone.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit milestone')),
                PopupMenuItem(value: 'delete', child: Text('Delete milestone')),
              ],
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
        const SizedBox(height: 8),
        if (quests.isEmpty)
          const Text(
            'No quests in this milestone.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          for (final quest in quests) ...[
            _GoalQuestDetail(
              quest: quest,
              onEdit: () => onEditQuest(quest),
              onDelete: () => onDeleteQuest(quest),
            ),
            const SizedBox(height: 8),
          ],
      ],
    ),
  );
}

class _GoalQuestDetail extends StatelessWidget {
  const _GoalQuestDetail({
    required this.quest,
    required this.onEdit,
    required this.onDelete,
  });
  final ProgressionQuest quest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
    decoration: BoxDecoration(
      color: AppColors.surfaceElevated,
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
                quest.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${quest.difficulty} · ${quest.completed ? 'Completed' : 'Active'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit quest')),
            PopupMenuItem(value: 'delete', child: Text('Delete quest')),
          ],
        ),
      ],
    ),
  );
}

*/

class _QuestEntry extends StatelessWidget {
  const _QuestEntry({
    required this.quest,
    required this.reward,
    required this.skillName,
    required this.isMutating,
    required this.onCompleteObjective,
    required this.onCompleteQuest,
    required this.onTap,
  });
  final ProgressionQuest quest;
  final int reward;
  final String? skillName;
  final bool isMutating;
  final Future<void> Function(String, String) onCompleteObjective;
  final Future<void> Function(String) onCompleteQuest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completedCount = quest.objectives
        .where((objective) => objective.completed)
        .length;
    final canComplete = quest.objectives.every(
      (objective) => objective.completed,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: _QuestCard(
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
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${quest.type} · ${quest.difficulty} · $completedCount/${quest.objectives.length} objectives',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: [
                _QuestMeta(icon: Icons.bolt, label: '+$reward XP'),
                if (skillName != null)
                  _QuestMeta(icon: Icons.auto_awesome, label: skillName!),
              ],
            ),
            if (quest.objectives.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final objective in quest.objectives)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: isMutating || objective.completed
                        ? null
                        : () => onCompleteObjective(quest.id, objective.id),
                    child: Text(
                      '${objective.completed ? '✓' : '○'} ${objective.title}',
                    ),
                  ),
                ),
            ],
            if (canComplete)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: isMutating
                      ? null
                      : () => onCompleteQuest(quest.id),
                  child: const Text('Complete quest'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateEntry extends StatelessWidget {
  const _TemplateEntry({
    required this.template,
    required this.isMutating,
    required this.onActivate,
  });
  final QuestTemplate template;
  final bool isMutating;
  final Future<void> Function(String) onActivate;

  @override
  Widget build(BuildContext context) => _QuestCard(
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
              const SizedBox(height: 4),
              Text(
                '${template.questCount} quests · ${template.milestoneCount} milestones',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                template.description,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: isMutating ? null : () => onActivate(template.id),
          child: const Text('Activate'),
        ),
      ],
    ),
  );
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.surface.withOpacity(.88),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xAA12345A), Color(0x66050B18)],
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.primaryGlow),
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryGlow.withOpacity(.14),
          blurRadius: 14,
        ),
      ],
    ),
    child: child,
  );
}

class _QuestMeta extends StatelessWidget {
  const _QuestMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.accent),
      const SizedBox(width: 3),
      Text(
        label,
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _QuestNotice extends StatelessWidget {
  const _QuestNotice({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
