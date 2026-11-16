import 'package:material_ui/material_ui.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/character/domain/character_repository.dart';
import '../features/character/presentation/character_creation_screen.dart';
import 'theme/app_theme.dart';

class SoloLevelingApp extends StatefulWidget {
  const SoloLevelingApp({
    required this.authController,
    required this.characterRepository,
    super.key,
  });

  final AuthController authController;
  final CharacterRepository characterRepository;

  @override
  State<SoloLevelingApp> createState() => _SoloLevelingAppState();
}

class _SoloLevelingAppState extends State<SoloLevelingApp> {
  bool _showRegistration = false;

  @override
  void initState() {
    super.initState();
    widget.authController.restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solo Leveling',
      theme: AppTheme.dark,
      home: AnimatedBuilder(
        animation: widget.authController,
        builder: (context, _) {
          final state = widget.authController.state;
          if (state.status == AuthStatus.initializing) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = state.user;
          if (state.status == AuthStatus.signedIn && user != null) {
            if (!user.hasCharacter) {
              return CharacterCreationScreen(
                repository: widget.characterRepository,
                accessToken: widget.authController.accessToken,
                onCreated: widget.authController.markCharacterCreated,
              );
            }
            return WelcomeScreen(user: user, controller: widget.authController);
          }

          if (_showRegistration) {
            return RegisterScreen(
              controller: widget.authController,
              errorMessage: state.errorMessage,
              onShowLogin: () => setState(() => _showRegistration = false),
            );
          }

          return LoginScreen(
            controller: widget.authController,
            errorMessage: state.errorMessage,
            onShowRegister: () => setState(() => _showRegistration = true),
          );
        },
      ),
    );
  }
}
