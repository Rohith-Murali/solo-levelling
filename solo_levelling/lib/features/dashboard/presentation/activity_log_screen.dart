import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../domain/dashboard_data.dart';
import '../domain/dashboard_repository.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({
    required this.repository,
    required this.accessToken,
    required this.isActive,
    super.key,
  });

  final DashboardRepository repository;
  final String? accessToken;
  final bool isActive;

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  List<DashboardActivity> _activities = const [];
  String _filter = 'ALL';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ActivityLogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _load();
  }

  Future<void> _load() async {
    final token = widget.accessToken;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Your session expired. Please sign in again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.repository.load(token);
      if (!mounted) return;
      setState(() => _activities = data.recentActivity);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error, stackTrace) {
      AppLogger.unexpected('activity-log-load', error, stackTrace);
      if (mounted) setState(() => _error = 'Activity log could not be loaded.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = <String>{
      'ALL',
      ..._activities.map((activity) => activity.type),
    }.toList(growable: false);
    final filtered = _filter == 'ALL'
        ? _activities
        : _activities.where((activity) => activity.type == _filter).toList();
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Text('ACTIVITY LOG', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'Complete system history. Filter events to inspect your progression.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in types)
                ChoiceChip(
                  label: Text(type == 'ALL' ? 'ALL EVENTS' : _label(type)),
                  selected: type == _filter,
                  onSelected: (_) => setState(() => _filter = type),
                  selectedColor: AppColors.primaryGlow,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: type == _filter
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: const TextStyle(color: AppColors.accent)),
          ],
          if (_loading && _activities.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('No matching activity records.')),
            )
          else ...[
            const SizedBox(height: 16),
            for (final activity in filtered) ...[
              _LogEntry(activity: activity),
              if (activity != filtered.last) const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  String _label(String type) => type
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _LogEntry extends StatelessWidget {
  const _LogEntry({required this.activity});

  final DashboardActivity activity;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(activity.createdAt)?.toLocal();
    final time = date == null
        ? 'RECENT'
        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(.86),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGlow.withOpacity(.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow.withOpacity(.12),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon(activity.type), color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.description,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 7),
                Text(
                  time,
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
      ),
    );
  }

  IconData _icon(String type) {
    if (type.contains('QUEST')) return Icons.assignment_turned_in_outlined;
    if (type.contains('SKILL')) return Icons.auto_awesome;
    if (type.contains('LEVEL')) return Icons.trending_up;
    if (type.contains('RANK')) return Icons.military_tech_outlined;
    return Icons.bolt;
  }
}
