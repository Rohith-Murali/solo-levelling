import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/app_colors.dart';
import '../application/auth_controller.dart';
import '../domain/auth_user.dart';
import 'widgets/auth_widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.user,
    required this.controller,
    super.key,
  });

  final AuthUser user;
  final AuthController controller;

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      children: [
        AuthPanel(
          child: Column(
            children: [
              const Icon(
                Icons.bolt,
                color: AppColors.accent,
                size: 40,
                semanticLabel: 'System status',
              ),
              const SizedBox(height: 20),
              Text(
                'WELCOME, HUNTER',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                user.email,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              const Text(
                'Your system is ready. Your journey starts now.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AuthSubmitButton(
                label: 'Sign out',
                isBusy: controller.state.isBusy,
                onPressed: controller.logout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
