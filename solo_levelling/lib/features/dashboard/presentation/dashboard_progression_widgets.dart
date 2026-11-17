part of 'dashboard_screen.dart';

class _ProgressionOverviewSection extends StatelessWidget {
  const _ProgressionOverviewSection({
    required this.statistics,
    required this.overview,
  });

  final DashboardStatistics statistics;
  final DashboardProgressionOverview overview;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('QUESTS DONE', '${statistics.completedQuestCount}', Icons.task_alt),
      ('GOALS DONE', '${statistics.completedGoalCount}', Icons.flag_outlined),
      (
        'MILESTONES',
        '${statistics.completedMilestoneCount}',
        Icons.emoji_events_outlined,
      ),
      ('ACHIEVEMENTS', '${statistics.achievementCount}', Icons.stars_outlined),
    ];

    return _DashboardSection(
      title: 'PROGRESSION OVERVIEW',
      trailing: '30 DAYS',
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return _StatisticCard(
                label: metric.$1,
                value: metric.$2,
                icon: metric.$3,
              );
            },
          ),
          const SizedBox(height: 12),
          if (overview.xpTrend.isEmpty)
            const _EmptySectionMessage(
              icon: Icons.show_chart,
              title: 'No progression history available yet.',
              detail: 'XP trends will appear after progression events are recorded.',
            )
          else
            _XpTrendChart(points: overview.xpTrend),
        ],
      ),
    );
  }
}

class _StatisticCard extends StatelessWidget {
  const _StatisticCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _XpTrendChart extends StatelessWidget {
  const _XpTrendChart({required this.points});

  final List<DashboardXpPoint> points;

  @override
  Widget build(BuildContext context) {
    final highest = points.fold<int>(
      0,
      (maximum, point) => point.xp > maximum ? point.xp : maximum,
    );
    return Container(
      height: 128,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: highest == 0
                              ? 0
                              : (point.xp / highest).clamp(0.08, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primaryGlow,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.18,
                                  ),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      point.date.length >= 10
                          ? point.date.substring(5, 10)
                          : point.date,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({required this.activities, this.onViewAll});

  final List<DashboardActivity> activities;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final recent = activities.take(4).toList(growable: false);
    return _DashboardSection(
      title: 'RECENT ACTIVITY',
      trailing: 'ACTIVITY LOG',
      child: activities.isEmpty
          ? const _EmptySectionMessage(
              icon: Icons.history,
              title: 'No progression records available.',
              detail:
                  'Completed quests and progression events will appear here.',
            )
          : Column(
              children: [
                for (var index = 0; index < recent.length; index++) ...[
                  _ActivityItem(activity: recent[index]),
                  if (index < recent.length - 1) const Divider(height: 18),
                ],
                if (onViewAll != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onViewAll,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('VIEW ALL'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({required this.activity});

  final DashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    final timestamp = DateTime.tryParse(activity.createdAt)?.toLocal();
    final timeLabel = timestamp == null
        ? 'Recently'
        : '${timestamp.month}/${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_activityIcon(activity.type), color: AppColors.accent, size: 20),
        const SizedBox(width: 12),
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
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 5),
              Text(
                timeLabel,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (activity.xpGained != null)
          Text(
            '+${activity.xpGained} XP',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.trailing,
    required this.child,
  });

  final String title;
  final String trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _AnimatedSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(.88),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.surfaceElevated, AppColors.surface],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryGlow.withOpacity(.52)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGlow.withOpacity(.11),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 24),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardLabel extends StatelessWidget {
  const _RewardLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.accent, size: 15),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AuthPanel(
      child: Column(
        children: [
          const Icon(Icons.wifi_off, color: AppColors.textSecondary, size: 32),
          const SizedBox(height: 12),
          const Text(
            'STATUS UNAVAILABLE',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

IconData _skillIcon(String id) {
  return switch (id) {
    'programming' => Icons.code,
    'problem-solving' => Icons.psychology_outlined,
    'communication' => Icons.forum_outlined,
    'strength' => Icons.fitness_center,
    'fitness' => Icons.directions_run,
    'focus' => Icons.center_focus_strong,
    'financial-management' => Icons.account_balance_wallet_outlined,
    _ => Icons.auto_awesome,
  };
}

IconData _activityIcon(String type) {
  return switch (type) {
    'QUEST_COMPLETED' => Icons.task_alt,
    'CHARACTER_LEVEL_UP' => Icons.trending_up,
    'RANK_PROMOTED' => Icons.military_tech,
    'MILESTONE_COMPLETED' => Icons.emoji_events_outlined,
    _ => Icons.bolt,
  };
}
