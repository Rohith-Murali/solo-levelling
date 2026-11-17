import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../domain/progression_data.dart';
import '../domain/progression_repository.dart';

class QuestCenterScreen extends StatefulWidget {
  const QuestCenterScreen({
    required this.repository,
    required this.accessToken,
    required this.isActive,
    required this.onDataChanged,
    super.key,
  });

  final ProgressionRepository? repository;
  final String? accessToken;
  final bool isActive;
  final VoidCallback onDataChanged;

  @override
  State<QuestCenterScreen> createState() => _QuestCenterScreenState();
}

class _QuestCenterScreenState extends State<QuestCenterScreen> {
  List<ProgressionQuest> _quests = const [];
  List<QuestTemplate> _templates = const [];
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
      final quests = await repository.loadQuests(token);
      final templates = await repository.loadTemplates(token);
      if (!mounted) return;
      setState(() {
        _quests = quests;
        _templates = templates;
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

  Future<void> _performMutation(Future<void> Function() action) async {
    if (_isMutating) return;
    setState(() {
      _isMutating = true;
      _errorMessage = null;
    });
    try {
      await action();
      await _load();
      widget.onDataChanged();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'CONCURRENT_UPDATE') {
        await _load();
      }
      if (error.code == 'TEMPLATE_ALREADY_ACTIVE') {
        await _load();
        return;
      }
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (error, stackTrace) {
      AppLogger.unexpected('quest-center-update', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'The quest could not be updated. Try again.';
      });
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

  Future<void> _completeQuest(String questId) async {
    final repository = widget.repository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    await _performMutation(() => repository.completeQuest(token, questId));
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
            title: 'ACTIVE QUESTS',
            child: activeQuests.isEmpty
                ? const _QuestEmptyMessage('No active quests.')
                : Column(
                    children: [
                      for (final quest in activeQuests) ...[
                        _QuestEntry(
                          quest: quest,
                          isMutating: _isMutating,
                          onCompleteObjective: _completeObjective,
                          onCompleteQuest: _completeQuest,
                        ),
                        if (quest != activeQuests.last)
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

class _QuestEntry extends StatelessWidget {
  const _QuestEntry({
    required this.quest,
    required this.isMutating,
    required this.onCompleteObjective,
    required this.onCompleteQuest,
  });
  final ProgressionQuest quest;
  final bool isMutating;
  final Future<void> Function(String, String) onCompleteObjective;
  final Future<void> Function(String) onCompleteQuest;

  @override
  Widget build(BuildContext context) {
    final completedCount = quest.objectives
        .where((objective) => objective.completed)
        .length;
    final canComplete = quest.objectives.every(
      (objective) => objective.completed,
    );

    return _QuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            quest.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${quest.type} · ${quest.difficulty} · $completedCount/${quest.objectives.length} objectives',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
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
                onPressed: isMutating ? null : () => onCompleteQuest(quest.id),
                child: const Text('Complete quest'),
              ),
            ),
        ],
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
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
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
