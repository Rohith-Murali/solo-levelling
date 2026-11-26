import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../domain/dashboard_data.dart';
import '../domain/dashboard_repository.dart';

class CharacterStatusScreen extends StatefulWidget {
  const CharacterStatusScreen({
    required this.repository,
    required this.accessToken,
    required this.isActive,
    super.key,
  });

  final DashboardRepository repository;
  final String? accessToken;
  final bool isActive;

  @override
  State<CharacterStatusScreen> createState() => _CharacterStatusScreenState();
}

class _CharacterStatusScreenState extends State<CharacterStatusScreen> {
  DashboardData? _data;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CharacterStatusScreen oldWidget) {
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
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error, stackTrace) {
      AppLogger.unexpected('character-status-load', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Character status could not be loaded. Try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final character = data?.character;
    final progress = character == null || character.xpToNextLevel <= 0
        ? 0.0
        : (character.currentLevelXp / character.xpToNextLevel)
              .clamp(0.0, 1.0)
              .toDouble();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Text(
            'CHARACTER STATUS',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _StatusMessage(message: _errorMessage!, onRetry: _load),
          ],
          if (_isLoading && data == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (character != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: .88),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xAA12345A), Color(0x66050B18)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryGlow),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGlow.withValues(alpha: .16),
                    blurRadius: 18,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.surfaceElevated,
                        child: Icon(Icons.person, color: AppColors.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              character.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              'LV ${character.level}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              character.title,
                              style: const TextStyle(color: AppColors.accent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('CHARACTER XP'),
                      Text(
                        '${character.currentLevelXp} / ${character.xpToNextLevel}',
                        style: const TextStyle(color: AppColors.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    color: AppColors.primaryGlow,
                    backgroundColor: AppColors.background,
                    minHeight: 6,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${character.totalXp} total XP earned',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _StatusStats(
              statistics: data!.statistics,
              skillUnlockTokens: character.skillUnlockTokens,
            ),
            const SizedBox(height: 18),
            Text(
              'CHARACTER STATS',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.accent, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            _CharacterStats(stats: character.stats),
            const SizedBox(height: 18),
            Text(
              'ACQUIRED SKILLS',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.accent, letterSpacing: 1),
            ),
            const SizedBox(height: 10),
            if (data.skills.isEmpty)
              const Text(
                'No acquired skills are available.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              for (final skill in data.skills) ...[
                _StatusSkill(skill: skill),
                if (skill != data.skills.last) const SizedBox(height: 8),
              ],
          ],
        ],
      ),
    );
  }
}

class _CharacterStats extends StatelessWidget {
  const _CharacterStats({required this.stats});
  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final values = <String, int>{
      'STRENGTH': stats.strength,
      'INTELLIGENCE': stats.intelligence,
      'VITALITY': stats.vitality,
      'DISCIPLINE': stats.discipline,
      'PERCEPTION': stats.perception,
    };
    final maxStat = values.values.reduce((a, b) => a > b ? a : b);
    final maxValue = maxStat < 5 ? 5 : maxStat;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 315,
            width: double.infinity,
            child: CustomPaint(
              painter: _StatsRadarPainter(
                labels: values.keys.toList(growable: false),
                values: values.values.toList(growable: false),
                maxValue: maxValue,
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final entry in values.entries)
                _RadarValue(label: entry.key, value: entry.value),
            ],
          ),
        ],
      ),
    );
  }
}

class _RadarValue extends StatelessWidget {
  const _RadarValue({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.primaryGlow,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 5),
      Text(
        '$label  $value',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          letterSpacing: .4,
        ),
      ),
    ],
  );
}

class _StatsRadarPainter extends CustomPainter {
  _StatsRadarPainter({
    required this.labels,
    required this.values,
    required this.maxValue,
  });

  final List<String> labels;
  final List<int> values;
  final int maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    const sides = 5;
    final center = Offset(size.width / 2, size.height / 2 + 3);
    final radius = math
        .min(size.width / 2 - 62, size.height / 2 - 48)
        .toDouble();
    final angles = List<double>.generate(
      sides,
      (index) => -math.pi / 2 + (2 * math.pi * index / sides),
    );

    Offset point(double distance, int index) =>
        center +
        Offset(
          math.cos(angles[index]) * distance,
          math.sin(angles[index]) * distance,
        );

    final gridPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: .48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var level = 1; level <= 5; level++) {
      final path = Path()
        ..moveTo(
          point(radius * level / 5, 0).dx,
          point(radius * level / 5, 0).dy,
        );
      for (var index = 1; index < sides; index++) {
        final vertex = point(radius * level / 5, index);
        path.lineTo(vertex.dx, vertex.dy);
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (var index = 0; index < sides; index++) {
      final vertex = point(radius, index);
      canvas.drawLine(center, vertex, gridPaint);
    }

    final dataPath = Path();
    for (var index = 0; index < sides; index++) {
      final value = (values[index].clamp(0, maxValue) / maxValue).toDouble();
      final vertex = point(radius * value, index);
      if (index == 0) {
        dataPath.moveTo(vertex.dx, vertex.dy);
      } else {
        dataPath.lineTo(vertex.dx, vertex.dy);
      }
    }
    dataPath.close();
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppColors.primary.withValues(alpha: .38)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = AppColors.primaryGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final labelStyle = const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: .5,
    );
    for (var index = 0; index < sides; index++) {
      final labelPosition = point(radius + 28, index);
      final text = TextPainter(
        text: TextSpan(text: labels[index], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 110);
      final x = labelPosition.dx - text.width / 2;
      final y = labelPosition.dy - text.height / 2;
      text.paint(
        canvas,
        Offset(x.clamp(0, size.width - text.width).toDouble(), y),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StatsRadarPainter oldDelegate) =>
      oldDelegate.maxValue != maxValue ||
      oldDelegate.values != values ||
      oldDelegate.labels != labels;
}

class _StatusStats extends StatelessWidget {
  const _StatusStats({
    required this.statistics,
    required this.skillUnlockTokens,
  });
  final DashboardStatistics statistics;
  final int skillUnlockTokens;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _StatusStat(label: 'ACTIVE QUESTS', value: statistics.activeQuestCount),
      _StatusStat(
        label: 'QUESTS CLEARED',
        value: statistics.completedQuestCount,
      ),
      _StatusStat(label: 'SKILLS', value: statistics.acquiredSkillCount),
      _StatusStat(label: 'UNLOCK TOKENS', value: skillUnlockTokens),
    ],
  );
}

class _StatusStat extends StatelessWidget {
  const _StatusStat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: .88),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xAA12345A), Color(0x66050B18)],
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.primaryGlow),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 5),
        Text(
          '$value',
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

class _StatusSkill extends StatelessWidget {
  const _StatusSkill({required this.skill});
  final DashboardSkill skill;

  @override
  Widget build(BuildContext context) {
    final progress = skill.xpToNextLevel <= 0
        ? 0.0
        : (skill.currentLevelXp / skill.xpToNextLevel)
              .clamp(0.0, 1.0)
              .toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: .88),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xAA12345A), Color(0x66050B18)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryGlow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(skill.name)),
              Text(
                'LV ${skill.level}',
                style: const TextStyle(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            color: AppColors.primaryGlow,
            backgroundColor: AppColors.background,
            minHeight: 4,
          ),
          const SizedBox(height: 5),
          Text(
            '${skill.currentLevelXp} / ${skill.xpToNextLevel} Skill XP',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.onRetry});
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
