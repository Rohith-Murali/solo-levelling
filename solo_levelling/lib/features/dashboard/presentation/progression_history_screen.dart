import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../domain/dashboard_data.dart';
import '../domain/dashboard_repository.dart';
import '../../progression/domain/progression_data.dart';
import '../../progression/domain/progression_repository.dart';

class ProgressionHistoryScreen extends StatefulWidget {
  const ProgressionHistoryScreen({
    required this.repository,
    required this.progressionRepository,
    required this.accessToken,
    required this.isActive,
    super.key,
  });

  final DashboardRepository repository;
  final ProgressionRepository? progressionRepository;
  final String? accessToken;
  final bool isActive;

  @override
  State<ProgressionHistoryScreen> createState() =>
      _ProgressionHistoryScreenState();
}

class _ProgressionHistoryScreenState extends State<ProgressionHistoryScreen> {
  DashboardData? _data;
  List<ProgressionQuest> _quests = const [];
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProgressionHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _load();
  }

  Future<void> _load() async {
    final token = widget.accessToken;
    if (token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Your session expired. Please sign in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await widget.repository.load(token);
      final progressionRepository = widget.progressionRepository;
      final quests = progressionRepository == null
          ? const <ProgressionQuest>[]
          : await progressionRepository.loadQuests(token);
      if (!mounted) return;
      setState(() {
        _data = data;
        _quests = quests;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error, stackTrace) {
      AppLogger.unexpected('progression-history-load', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Progress history could not be loaded. Try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final overview = data?.progressionOverview;
    final completedQuests = _quests
        .where((quest) => quest.completed)
        .toList(growable: false);
    final maxXp =
        overview?.xpTrend.fold<int>(
          0,
          (maximum, point) => point.xp > maximum ? point.xp : maximum,
        ) ??
        0;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Text(
            'HISTORY & ANALYTICS',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _HistoryNotice(message: _errorMessage!, onRetry: _load),
          ],
          if (_isLoading && data == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (overview != null) ...[
            const SizedBox(height: 16),
            _HistorySummary(overview: overview),
            const SizedBox(height: 20),
            Text(
              'CHARACTER XP · LAST 30 DAYS',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.accent, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            if (overview.xpTrend.isEmpty)
              const _HistoryEmpty('No Character XP earned in this period.')
            else
              for (final point in overview.xpTrend) ...[
                _XpTrendEntry(point: point, maxXp: maxXp),
                if (point != overview.xpTrend.last) const SizedBox(height: 8),
              ],
          ],
          const SizedBox(height: 20),
          Text(
            'RECENT ACTIVITY',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.accent, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          if (data != null && data.recentActivity.isEmpty)
            const _HistoryEmpty(
              'Your completed quests and rewards will appear here.',
            )
          else
            for (final activity
                in data?.recentActivity ?? const <DashboardActivity>[]) ...[
              _ActivityEntry(activity: activity),
              if (activity != data!.recentActivity.last)
                const SizedBox(height: 8),
            ],
          const SizedBox(height: 20),
          Text(
            'COMPLETED QUESTS',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.accent, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          if (!_isLoading && completedQuests.isEmpty)
            const _HistoryEmpty('Completed quests will appear here.')
          else
            for (final quest in completedQuests) ...[
              _CompletedQuestEntry(quest: quest),
              if (quest != completedQuests.last) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.overview});
  final DashboardProgressionOverview overview;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _HistoryValue(
        label: 'CHARACTER XP',
        value: '${overview.characterXpEarned ?? 0}',
      ),
      _HistoryValue(
        label: 'QUESTS CLEARED',
        value: '${overview.questsCompleted ?? 0}',
      ),
      _HistoryValue(
        label: 'GOALS CLEARED',
        value: '${overview.goalsCompleted ?? 0}',
      ),
      _HistoryValue(
        label: 'MILESTONES',
        value: '${overview.milestonesCompleted ?? 0}',
      ),
    ],
  );
}

class _HistoryValue extends StatelessWidget {
  const _HistoryValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _XpTrendEntry extends StatelessWidget {
  const _XpTrendEntry({required this.point, required this.maxXp});
  final DashboardXpPoint point;
  final int maxXp;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(point.date),
            Text(
              '+${point.xp} XP',
              style: const TextStyle(color: AppColors.accent),
            ),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: maxXp == 0 ? 0 : point.xp / maxXp,
          color: AppColors.primaryGlow,
          backgroundColor: AppColors.background,
          minHeight: 4,
        ),
      ],
    ),
  );
}

class _ActivityEntry extends StatelessWidget {
  const _ActivityEntry({required this.activity});
  final DashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(activity.createdAt)?.toLocal();
    final timestamp = createdAt == null
        ? ''
        : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bolt, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (timestamp.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    timestamp,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (activity.xpGained != null)
            Text(
              '+${activity.xpGained} XP',
              style: const TextStyle(color: AppColors.accent, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _CompletedQuestEntry extends StatelessWidget {
  const _CompletedQuestEntry({required this.quest});
  final ProgressionQuest quest;

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
        const Icon(Icons.check_circle_outline, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quest.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                '${quest.type} · ${quest.difficulty}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) =>
      Text(message, style: const TextStyle(color: AppColors.textSecondary));
}

class _HistoryNotice extends StatelessWidget {
  const _HistoryNotice({required this.message, required this.onRetry});
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
