import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../domain/dashboard_data.dart';
import '../domain/dashboard_repository.dart';

class CharacterTitlesScreen extends StatefulWidget {
  const CharacterTitlesScreen({
    required this.repository,
    required this.accessToken,
    super.key,
  });

  final DashboardRepository repository;
  final String? accessToken;

  @override
  State<CharacterTitlesScreen> createState() => _CharacterTitlesScreenState();
}

class _CharacterTitlesScreenState extends State<CharacterTitlesScreen> {
  DashboardData? _data;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
      AppLogger.unexpected('character-titles-load', error, stackTrace);
      if (!mounted) return;
      setState(() => _errorMessage = 'Character titles could not be loaded.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('CHARACTER TITLES')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              data == null
                  ? 'Titles are assigned as your character levels up.'
                  : 'CURRENT TITLE  ·  ${data.character.title}',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.accent, letterSpacing: 0.6),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            if (_isLoading && data == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (data != null && data.titleTiers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Title progression is unavailable.'),
              )
            else if (data != null)
              for (final tier in data.titleTiers) ...[
                const SizedBox(height: 12),
                _TitleTierCard(
                  tier: tier,
                  currentLevel: data.character.level,
                  currentTitle: data.character.title,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _TitleTierCard extends StatelessWidget {
  const _TitleTierCard({
    required this.tier,
    required this.currentLevel,
    required this.currentTitle,
  });

  final DashboardTitleTier tier;
  final int currentLevel;
  final String currentTitle;

  @override
  Widget build(BuildContext context) {
    final unlocked = currentLevel >= tier.minimumLevel;
    final active = currentTitle == tier.name;
    final range = tier.maximumLevel == null
        ? 'LV ${tier.minimumLevel}+'
        : 'LV ${tier.minimumLevel}–${tier.maximumLevel}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? AppColors.accent : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.workspace_premium : Icons.lock_outline,
            color: unlocked ? AppColors.accent : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: unlocked
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  range,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (active)
            const Text(
              'CURRENT',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (unlocked)
            const Icon(Icons.check_circle, color: AppColors.accent, size: 18),
        ],
      ),
    );
  }
}
