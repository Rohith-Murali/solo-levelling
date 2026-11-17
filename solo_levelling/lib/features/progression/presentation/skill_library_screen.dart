import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../dashboard/domain/dashboard_data.dart';
import '../../dashboard/domain/dashboard_repository.dart';
import '../domain/progression_data.dart';
import '../domain/progression_repository.dart';
import '../../../shared/widgets/system_notification.dart';

class SkillLibraryScreen extends StatefulWidget {
  const SkillLibraryScreen({
    required this.dashboardRepository,
    required this.progressionRepository,
    required this.accessToken,
    required this.isActive,
    required this.onDataChanged,
    super.key,
  });

  final DashboardRepository dashboardRepository;
  final ProgressionRepository? progressionRepository;
  final String? accessToken;
  final bool isActive;
  final VoidCallback onDataChanged;

  @override
  State<SkillLibraryScreen> createState() => _SkillLibraryScreenState();
}

class _SkillLibraryScreenState extends State<SkillLibraryScreen> {
  DashboardData? _dashboard;
  List<LibrarySkill> _library = const [];
  String? _errorMessage;
  bool _isLoading = true;
  bool _isAcquiring = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SkillLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _load();
  }

  Future<void> _load() async {
    final token = widget.accessToken;
    final repository = widget.progressionRepository;
    if (token == null || repository == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Skill services are unavailable. Sign in again.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dashboard = await widget.dashboardRepository.load(token);
      final library = await repository.loadSkillLibrary(token);
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _library = library;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error, stackTrace) {
      AppLogger.unexpected('skill-library-load', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Skill data could not be loaded. Try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acquireSkill(String skillId) async {
    await _performAcquisition(
      (repository, token) => repository.acquireSkill(token, skillId: skillId),
    );
  }

  Future<void> _createCustomSkill() async {
    final input = await showDialog<_CustomSkillInput>(
      context: context,
      builder: (context) => const _CreateCustomSkillDialog(),
    );
    if (input == null) return;
    await _performAcquisition(
      (repository, token) => repository.acquireSkill(
        token,
        name: input.name,
        description: input.description,
        category: input.category,
      ),
    );
  }

  Future<void> _performAcquisition(
    Future<void> Function(ProgressionRepository repository, String token)
    action,
  ) async {
    final token = widget.accessToken;
    final repository = widget.progressionRepository;
    if (token == null || repository == null || _isAcquiring) return;
    final previous = _dashboard;

    setState(() {
      _isAcquiring = true;
      _errorMessage = null;
    });
    try {
      await action(repository, token);
      await _load();
      if (mounted) {
        final oldIds = {
          for (final skill in previous?.skills ?? const []) skill.id,
        };
        final added = _dashboard?.skills.where(
          (skill) => !oldIds.contains(skill.id),
        );
        if (added != null && added.isNotEmpty) {
          await SystemNotification.show(
            context,
            icon: Icons.auto_awesome,
            message: 'NEW SKILL UNLOCKED\n\n${added.first.name}',
          );
        }
      }
      widget.onDataChanged();
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.code == 'CONCURRENT_UPDATE') await _load();
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (error, stackTrace) {
      AppLogger.unexpected('skill-library-acquire', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'The skill could not be acquired. Try again.';
      });
    } finally {
      if (mounted) setState(() => _isAcquiring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = _dashboard;
    final acquired = {
      for (final skill in dashboard?.skills ?? const <DashboardSkill>[])
        skill.id: skill,
    };
    final acquiredSkills = dashboard?.skills ?? const <DashboardSkill>[];
    final availableLibrary = _library
        .where((skill) => !acquired.containsKey(skill.id))
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Text('SKILL LIBRARY', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            dashboard == null
                ? 'Your skills and progression will appear here.'
                : '${dashboard.character.skillUnlockTokens} skill unlock token${dashboard.character.skillUnlockTokens == 1 ? '' : 's'} available.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _SkillNotice(message: _errorMessage!, onRetry: _load),
          ],
          if (_isLoading && dashboard == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 20),
          Text(
            'ACQUIRED SKILLS',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.accent, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          if (acquiredSkills.isEmpty)
            const Text(
              'No skills have been acquired yet.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            for (final skill in acquiredSkills) ...[
              _AcquiredSkillEntry(skill: skill),
              if (skill != acquiredSkills.last) const SizedBox(height: 10),
            ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'AVAILABLE SKILLS',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppColors.accent, letterSpacing: 1),
                ),
              ),
              OutlinedButton(
                onPressed:
                    _isAcquiring ||
                        (dashboard?.character.skillUnlockTokens ?? 0) < 1
                    ? null
                    : _createCustomSkill,
                child: const Text('Create custom'),
              ),
            ],
          ),
          if (!_isLoading && _library.isEmpty)
            const Text(
              'No library skills are currently available.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          if (availableLibrary.isEmpty && _library.isNotEmpty)
            const Text(
              'All library skills are acquired.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          for (final skill in availableLibrary) ...[
            _SkillEntry(
              skill: skill,
              hasTokens: (dashboard?.character.skillUnlockTokens ?? 0) > 0,
              isAcquiring: _isAcquiring,
              onAcquire: _acquireSkill,
            ),
            if (skill != availableLibrary.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SkillEntry extends StatelessWidget {
  const _SkillEntry({
    required this.skill,
    required this.hasTokens,
    required this.isAcquiring,
    required this.onAcquire,
  });
  final LibrarySkill skill;
  final bool hasTokens;
  final bool isAcquiring;
  final Future<void> Function(String) onAcquire;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(.88),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xAA12345A), Color(0x66050B18)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGlow),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow.withOpacity(.14),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  skill.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: !hasTokens || isAcquiring
                ? null
                : () => onAcquire(skill.id),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }
}

class _AcquiredSkillEntry extends StatelessWidget {
  const _AcquiredSkillEntry({required this.skill});
  final DashboardSkill skill;

  @override
  Widget build(BuildContext context) {
    final progress = skill.xpToNextLevel <= 0
        ? 0.0
        : (skill.currentLevelXp / skill.xpToNextLevel)
              .clamp(0.0, 1.0)
              .toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(.88),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xAA12345A), Color(0x66050B18)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGlow),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow.withOpacity(.14),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  skill.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'LV ${skill.level}',
                style: const TextStyle(color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.background,
            color: AppColors.primaryGlow,
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

class _CustomSkillInput {
  const _CustomSkillInput({
    required this.name,
    required this.description,
    required this.category,
  });
  final String name;
  final String description;
  final String category;
}

class _CreateCustomSkillDialog extends StatefulWidget {
  const _CreateCustomSkillDialog();

  @override
  State<_CreateCustomSkillDialog> createState() =>
      _CreateCustomSkillDialogState();
}

class _CreateCustomSkillDialogState extends State<_CreateCustomSkillDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'PERSONAL';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    Navigator.pop(
      context,
      _CustomSkillInput(
        name: name,
        description: description,
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    title: const Text('Create custom skill'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              maxLength: 80,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a skill name.'
                  : null,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextFormField(
              controller: _descriptionController,
              maxLength: 500,
              maxLines: 3,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a description.'
                  : null,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const [
                DropdownMenuItem(value: 'PHYSICAL', child: Text('Physical')),
                DropdownMenuItem(value: 'COGNITIVE', child: Text('Cognitive')),
                DropdownMenuItem(value: 'TECHNICAL', child: Text('Technical')),
                DropdownMenuItem(value: 'PERSONAL', child: Text('Personal')),
                DropdownMenuItem(value: 'CREATIVE', child: Text('Creative')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Acquire')),
    ],
  );
}

class _SkillNotice extends StatelessWidget {
  const _SkillNotice({required this.message, required this.onRetry});
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
