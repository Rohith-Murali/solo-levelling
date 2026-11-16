import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../domain/dashboard_data.dart';
import '../domain/dashboard_repository.dart';

part 'dashboard_header_widgets.dart';
part 'dashboard_quest_skill_widgets.dart';
part 'dashboard_progression_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.repository,
    required this.accessToken,
    required this.onLogout,
    required this.onCharacterRequired,
    super.key,
  });

  final DashboardRepository repository;
  final String? accessToken;
  final VoidCallback onLogout;
  final VoidCallback onCharacterRequired;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isRefreshing = false;

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
      if (!mounted) return;
      setState(() {
        _data = data;
        _errorMessage = null;
      });
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
              _SystemHeader(onLogout: widget.onLogout),
              const SizedBox(height: 22),
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
                    onTokensTap: () => _showTokenDetails(context),
                  ),
                ),
                const SizedBox(height: 22),
                _ActiveQuestsSection(quests: data.activeQuests),
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

  void _showTokenDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Skill Unlock Tokens'),
        content: const Text(
          'Tokens are system rewards used to unlock additional skills. '
          'Skill acquisition will be available here when that feature is added.',
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
}
