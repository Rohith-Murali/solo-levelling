import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../../shared/widgets/system_notification.dart';
import '../domain/character_options.dart';
import '../domain/character_repository.dart';

class CharacterCreationScreen extends StatefulWidget {
  const CharacterCreationScreen({
    required this.repository,
    required this.accessToken,
    required this.onCreated,
    super.key,
  });

  final CharacterRepository repository;
  final String? accessToken;
  final VoidCallback onCreated;

  @override
  State<CharacterCreationScreen> createState() =>
      _CharacterCreationScreenState();
}

class _CharacterCreationScreenState extends State<CharacterCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  CharacterOptions? _options;
  String? _selectedAvatarId;
  String? _selectedSkillId;
  String? _errorMessage;
  int _step = 0;
  bool _isLoadingOptions = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoadingOptions = true;
      _errorMessage = null;
    });

    try {
      final token = widget.accessToken;
      if (token == null) {
        throw const ApiException('Your session expired. Please sign in again.');
      }
      final options = await widget.repository.getOptions(token);
      if (!mounted) return;
      setState(() {
        _options = options;
        _selectedAvatarId ??= options.avatars.firstOrNull?.id;
        _selectedSkillId ??= options.startingSkills.firstOrNull?.id;
        _isLoadingOptions = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoadingOptions = false;
      });
    } catch (error, stackTrace) {
      AppLogger.unexpected('character-options', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load character options. Please try again.';
        _isLoadingOptions = false;
      });
    }
  }

  void _continue() {
    if (_step == 1) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (_selectedAvatarId == null) {
        setState(() => _errorMessage = 'Choose an avatar to continue.');
        return;
      }
    } else if (_step == 2 && _selectedSkillId == null) {
      setState(() => _errorMessage = 'Choose a starting skill to continue.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _step++;
    });
  }

  Future<void> _createCharacter() async {
    if (_isSubmitting) return;
    final token = widget.accessToken;
    final avatarId = _selectedAvatarId;
    final skillId = _selectedSkillId;
    if (token == null || avatarId == null || skillId == null) {
      setState(
        () => _errorMessage = 'Your session or character selection is unavailable. Please try again.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.createCharacter(
        accessToken: token,
        name: _nameController.text.trim(),
        avatarId: avatarId,
        startingSkillId: skillId,
      );
      if (!mounted) return;
      await SystemNotification.show(
        context,
        icon: Icons.auto_awesome,
        message: 'Character initialized!\n\nLevel 1 unlocked\nStarting skill acquired',
      );
      if (!mounted) return;
      widget.onCreated();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error, stackTrace) {
      AppLogger.unexpected('character-creation', error, stackTrace);
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Character creation failed. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthBrandHeader(
                    title: 'CHARACTER INITIALIZATION',
                    subtitle:
                        'Create the identity that will track your growth.',
                  ),
                  const SizedBox(height: 24),
                  AuthPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_step > 0) ...[
                          Text(
                            'STEP $_step OF 3',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: AppColors.accent,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (_step == 0) _buildIntroduction(context),
                        if (_step == 1 && options != null)
                          _buildIdentity(context, options),
                        if (_step == 2 && options != null)
                          _buildSkillSelection(context, options),
                        if (_step == 3 && options != null)
                          _buildReview(context, options),
                        if (_isLoadingOptions) ...[
                          const SizedBox(height: 20),
                          const Center(child: CircularProgressIndicator()),
                        ],
                        if (_errorMessage != null)
                          AuthErrorMessage(message: _errorMessage),
                        if (!_isLoadingOptions && options == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: OutlinedButton(
                              onPressed: _loadOptions,
                              child: const Text('Retry loading options'),
                            ),
                          ),
                        const SizedBox(height: 24),
                        if (options != null) _buildActions(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroduction(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.bolt,
          color: AppColors.accent,
          size: 42,
          semanticLabel: 'Character initialization',
        ),
        const SizedBox(height: 16),
        Text(
          'INITIALIZE YOUR HUNTER',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const Text(
          'Choose your identity and one ability to begin tracking. '
          'Your real-world quest completion is what drives progression.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildIdentity(BuildContext context, CharacterOptions options) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your identity',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('character-name'),
            controller: _nameController,
            maxLength: 24,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Character name',
              hintText: 'Enter a name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty) return 'Enter a character name.';
              if (name.length > 24) {
                return 'Use 24 characters or fewer.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Select an avatar',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: options.avatars.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final avatar = options.avatars[index];
              final selected = avatar.id == _selectedAvatarId;
              return _AvatarTile(
                key: ValueKey('avatar-${avatar.id}'),
                avatar: avatar,
                selected: selected,
                onTap: () => setState(() {
                  _selectedAvatarId = avatar.id;
                  _errorMessage = null;
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSkillSelection(BuildContext context, CharacterOptions options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose one starting skill',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'This starts a progress tracker; it does not certify expertise.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        for (final skill in options.startingSkills) ...[
          _SkillTile(
            skill: skill,
            selected: skill.id == _selectedSkillId,
            onTap: () => setState(() {
              _selectedSkillId = skill.id;
              _errorMessage = null;
            }),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildReview(BuildContext context, CharacterOptions options) {
    final avatar = options.avatars.firstWhere(
      (item) => item.id == _selectedAvatarId,
    );
    final skill = options.startingSkills.firstWhere(
      (item) => item.id == _selectedSkillId,
    );
    final progression = options.initialProgression;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review your character',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        _ReviewRow(label: 'Name', value: _nameController.text.trim()),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  avatar.imagePath,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  avatar.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        _ReviewRow(label: 'Starting skill', value: skill.name),
        const Divider(height: 24),
        Text(
          'INITIAL STATUS',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: AppColors.accent, letterSpacing: 1),
        ),
        const SizedBox(height: 10),
        _ReviewRow(label: 'Character level', value: '${progression.level}'),
        _ReviewRow(label: 'Character XP', value: '${progression.xp}'),
        _ReviewRow(label: 'Skill level', value: '${progression.skillLevel}'),
        _ReviewRow(label: 'Skill XP', value: '${progression.skillXp}'),
      ],
    );
  }

  Widget _buildActions() {
    if (_step == 0) {
      return AuthSubmitButton(
        label: 'Initialize Character',
        isBusy: _isLoadingOptions,
        onPressed: _continue,
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting
                ? null
                : () => setState(() {
                    _step--;
                    _errorMessage = null;
                  }),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _step < 3
              ? AuthSubmitButton(
                  label: 'Continue',
                  isBusy: _isLoadingOptions,
                  onPressed: _continue,
                )
              : AuthSubmitButton(
                  label: 'Create Character',
                  isBusy: _isSubmitting,
                  onPressed: _createCharacter,
                ),
        ),
      ],
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.avatar,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final CharacterAvatar avatar;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${avatar.name} avatar',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceElevated : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  avatar.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00050B18), Color(0xE6050B18)],
                      ),
                    ),
                    child: Text(
                      avatar.name,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.check_circle,
                      color: AppColors.accent,
                      semanticLabel: 'Selected',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.skill,
    required this.selected,
    required this.onTap,
  });

  final StartingSkill skill;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${skill.name}. ${skill.description}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceElevated : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      skill.description,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
