import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../domain/dashboard_data.dart';
import '../domain/dashboard_repository.dart';
import '../../progression/domain/progression_data.dart';
import '../../progression/domain/progression_repository.dart';
import '../../../shared/widgets/system_notification.dart';
import '../../../shared/widgets/holographic_dialog.dart';

part 'dashboard_header_widgets.dart';
part 'dashboard_quest_skill_widgets.dart';
part 'dashboard_progression_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.repository,
    required this.accessToken,
    required this.onCharacterRequired,
    this.onCharacterLoaded,
    this.onViewActivity,
    this.onProgressionChanged,
    this.progressionRepository,
    super.key,
  });

  final DashboardRepository repository;
  final String? accessToken;
  final VoidCallback onCharacterRequired;
  final ValueChanged<DashboardCharacter>? onCharacterLoaded;
  final VoidCallback? onViewActivity;
  final VoidCallback? onProgressionChanged;
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
  List<ProgressionGoal>? _goals;

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
      final structure = progressionRepository == null
          ? null
          : await progressionRepository.loadStructure(token);
      if (!mounted) return;
      setState(() {
        _data = data;
        _errorMessage = null;
        _quests = quests;
        _goals = structure?.goals;
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
                    onTokensTap: () =>
                        _showTokenDetails(context, data.character),
                  ),
                ),
                const SizedBox(height: 22),
                _ActiveQuestsSection(
                  quests: _quests ?? const [],
                  goals: _goals ?? const [],
                  skills: data.skills,
                  onQuestComplete: _completeQuest,
                ),
                const SizedBox(height: 22),
                _AcquiredSkillsSection(skills: data.skills),
                const SizedBox(height: 22),
                _ProgressionOverviewSection(
                  statistics: data.statistics,
                  overview: data.progressionOverview,
                ),
                const SizedBox(height: 22),
                _RecentActivitySection(
                  activities: data.recentActivity,
                  onViewAll: widget.onViewActivity,
                ),
              ],
            ],
          ),
        ),
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
                    if (snapshot.hasError) {
                      return const Text(
                        'The skill library could not be loaded.',
                      );
                    }
                    final skills = snapshot.data ?? const <LibrarySkill>[];
                    if (character.skillUnlockTokens == 0) {
                      return const Text(
                        'No skill unlock tokens are available yet.',
                      );
                    }
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
      kind: _ProgressionActionKind.skill,
    );
  }

  Future<void> _completeQuest(String questId) async {
    await _runProgressionAction(
      (repository, token) => repository.completeQuest(token, questId),
      kind: _ProgressionActionKind.quest,
    );
  }

  Future<void> _runProgressionAction(
    Future<void> Function(ProgressionRepository repository, String token)
    action, {
    _ProgressionActionKind? kind,
  }) async {
    final repository = widget.progressionRepository;
    final token = widget.accessToken;
    if (repository == null || token == null) return;
    final before = _data;
    try {
      await action(repository, token);
      await _loadDashboard(refresh: true);
      if (!mounted) return;
      final after = _data;
      if (after == null) return;
      if (kind == _ProgressionActionKind.skill) {
        final oldIds = {
          for (final skill in before?.skills ?? const []) skill.id,
        };
        final added = after.skills.where((skill) => !oldIds.contains(skill.id));
        final skill = added.isEmpty ? null : added.first;
        if (skill != null) {
          await SystemNotification.showStack(context, [
            SystemNotificationData(
              icon: Icons.auto_awesome,
              message: 'NEW SKILL UNLOCKED\n\n${skill.name}',
            ),
          ]);
        }
        if (mounted) widget.onProgressionChanged?.call();
      } else if (kind == _ProgressionActionKind.quest) {
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
          for (final activity in before?.recentActivity ?? const [])
            activity.id,
        };
        final characterLevelledUp = after.recentActivity.any(
          (activity) =>
              !previousActivityIds.contains(activity.id) &&
              activity.type == 'CHARACTER_LEVEL_INCREASED',
        );
        if (characterLevelledUp ||
            (before != null &&
                after.character.level > before.character.level)) {
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
          final oldSkills = {
            for (final skill in before.skills) skill.id: skill,
          };
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
        if (mounted) widget.onProgressionChanged?.call();
      }
    } on ApiException catch (error) {
      if (error.code == 'CONCURRENT_UPDATE') {
        await _loadDashboard(refresh: true);
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

enum _ProgressionActionKind { skill, quest }
