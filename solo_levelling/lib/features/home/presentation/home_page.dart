import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.bolt,
                color: AppColors.accent,
                size: 36,
                semanticLabel: 'System status',
              ),
              const SizedBox(height: 16),
              Text(
                'SOLO LEVELING',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(letterSpacing: 3, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'SYSTEM INITIALIZED',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
