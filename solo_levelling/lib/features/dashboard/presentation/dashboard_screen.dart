import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../domain/dashboard_data.dart';
import '../domain/dashboard_repository.dart';
import '../../progression/domain/progression_data.dart';
import '../../progression/domain/progression_repository.dart';

part 'dashboard_header_widgets.dart';
part 'dashboard_quest_skill_widgets.dart';
part 'dashboard_progression_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.repository,
    required this.accessToken,
    required this.onCharacterRequired,
    this.onCharacterLoaded,
    this.progressionRepository,
    super.key,
  });

  final DashboardRepository repository;
  final String? accessToken;
  final VoidCallback onCharacterRequired;
  final ValueChanged<DashboardCharacter>? onCharacterLoaded;
  final ProgressionRepository? progressionRepository;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<ProgressionQuest>? _quests;
  List<QuestTemplate>? _templates;
  final Set<String> _activatingTemplateIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard({bool refresh = false}) async {
    if (refresh && _data != null) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final token = widget.accessToken;
      if (token == null) {
        throw const ApiException('Your session expired. Please sign in again.');
      }
      final data = await widget.repository.load(token);
      final progressionRepository = widget.progressionRepository;
      final quests = progressionRepository == null
          ? null
          : await progressionRepository.loadQuests(token);
      final templates = progressionRepository == null
          ? null
          : await progressionRepository.loadTemplates(token);
      if (!mounted) return;
      setState(() {
        _data = data;
        _errorMessage = null;
        _quests = quests;
        _templates = templates;
      });
      widget.onCharacterLoaded?.call(data.character);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'CHARACTER_REQUIRED') {
        widget.onCharacterRequired();
        return;
      }
      setState(() {
        _errorMessage = error.statusCode != null && error.statusCode! >= 500
            ? 'The system could not load your status. Try again.'
            : error.message;
      });
    } catch (error, stackTrace) {
      AppLogger.unexpected('dashboard-load', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'The system could not load your status. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadDashboard(refresh: true),
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
            children: [
              const SizedBox(height: 12),
              if (_isLoading && data == null)
                const _DashboardLoadingState()
              else if (_errorMessage != null && data == null)
                _DashboardErrorState(
                  message: _errorMessage!,
                  onRetry: () => _loadDashboard(),
                )
              else if (data != null) ...[
                if (_isRefreshing) ...[
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.accent,
                    backgroundColor: AppColors.surface,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_errorMessage != null) ...[
                  _InlineError(
                    message: _errorMessage!,
                    onRetry: () => _loadDashboard(),
                  ),
                  const SizedBox(height: 14),
                ],
                _AnimatedSection(
                  child: _CharacterStatusPanel(
                    character: data.character,
                    onRankTap: () => _showRankDetails(context, data.character),
                    onTokensTap: () =>
                        _showTokenDetails(context, data.character),
                  ),
                ),
                const SizedBox(height: 22),
                _ActiveQuestsSection(
                  quests: _quests ?? const [],
                  templates: _templates ?? const [],
                  onObjectiveComplete: _completeObjective,
                  onQuestComplete: _completeQuest,
                  onActivateTemplate: _activateTemplate,
                  activatingTemplateIds: _activatingTemplateIds,
                ),
                const SizedBox(height: 22),
                _AcquiredSkillsSection(skills: data.skills),
                const SizedBox(height: 22),
                _ProgressionOverviewSection(
                  statistics: data.statistics,
                  overview: data.progressionOverview,
                ),
                const SizedBox(height: 22),
                _RecentActivitySection(activities: data.recentActivity),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRankDetails(BuildContext context, DashboardCharacter character) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${character.rank} Rank'),
        content: Text(
          'Rank is assigned by the system based on character progression. '
          'Your current rank is ${character.rank}.',
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

  void _showTokenDetails(BuildContext context, DashboardCharacter character) {
    final repository = widget.progressionRepository;
    final token = widget.accessToken;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Skill Unlock Tokens'),
        content: repository == null || token == null
            ? const Text(
                'Tokens are system rewards used to unlock additional skills.',
              )
            : SizedBox(
                width: 360,
                child: FutureBuilder<List<LibrarySkill>>(
                  future: repository.loadSkillLibrary(token),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError)
                      return const Text(
                        'The skill library could not be loaded.',
                      );
                    final skills = snapshot.data ?? const <LibrarySkill>[];
                    if (character.skillUnlockTokens == 0)
                      return const Text(
                        'No skill unlock tokens are available yet.',
                      );
                    return ListView(
                      shrinkWrap: true,
                      children: [
                        Text(
                          '${character.skillUnlockTokens} token${character.skillUnlockTokens == 1 ? '' : 's'} available.',
                        ),
                        const SizedBox(height: 10),
                        for (final skill in skills)
                          ListTile(
                            title: Text(skill.name),
                            subtitle: Text(skill.description),
                            trailing: TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await _acquireSkill(skill.id);
                              },
                              child: const Text('Unlock'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
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

  Future<void> _acquireSkill(String skillId) async {
    await _runProgressionAction(
      (repository, token) => repository.acquireSkill(token, skillId: skillId),
    );
  }

  Future<void> _completeObjective(String questId, String objectiveId) async {
    await _runProgressionAction(
      (repository, token) =>
          repository.completeObjective(token, questId, objectiveId),
    );
  }

  Future<void> _completeQuest(String questId) async {
    await _runProgressionAction(
      (repository, token) => repository.completeQuest(token, questId),
    );
  }

  Future<void> _activateTemplate(String templateId) async {
    if (_activatingTemplateIds.contains(templateId)) return;
    setState(() => _activatingTemplateIds.add(templateId));
    try {
      await _runProgressionAction(
        (repository, token) => repository.activateTemplate(token, templateId),
        reconcileAlreadyActive: true,
      );
    } finally {
      if (mounted) {
        setState(() => _activatingTemplateIds.remove(templateId));
      }
    }
  }

  Future<void> _runProgressionAction(
    Future<void> Function(ProgressionRepository repository, String token)
    action, {
    bool reconcileAlreadyActive = false,
  }) async {
    final repository = widget.progressionRepository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    try {
      await action(repository, token);
      await _loadDashboard(refresh: true);
    } on ApiException catch (error) {
      if (error.code == 'CONCURRENT_UPDATE' ||
          (reconcileAlreadyActive && error.code == 'TEMPLATE_ALREADY_ACTIVE')) {
        await _loadDashboard(refresh: true);
      }
      if (reconcileAlreadyActive && error.code == 'TEMPLATE_ALREADY_ACTIVE') {
        return;
      }
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (error, stackTrace) {
      AppLogger.unexpected('dashboard-progression-update', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'The progression update failed. Try again.';
      });
    }
  }
}
