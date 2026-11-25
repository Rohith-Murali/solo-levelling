import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/navigation/navigation_config.dart';
import '../../../features/dashboard/domain/dashboard_data.dart';

class SystemDrawer extends StatelessWidget {
  const SystemDrawer({
    required this.character,
    required this.selectedIndex,
    required this.onPrimarySelected,
    required this.onSecondarySelected,
    required this.onLogout,
    super.key,
  });
  final DashboardCharacter? character;
  final int selectedIndex;
  final ValueChanged<int> onPrimarySelected;
  final ValueChanged<String> onSecondarySelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final data = character;
    final progress = data == null || data.xpToNextLevel <= 0
        ? 0.0
        : (data.currentLevelXp / data.xpToNextLevel).clamp(0.0, 1.0);
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            InkWell(
              onTap: () {
                Navigator.pop(context);
                onPrimarySelected(4);
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                color: AppColors.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.bolt, color: AppColors.accent, size: 30),
                    const SizedBox(height: 12),
                    Text(
                      data?.name ?? 'Character loading…',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      data == null
                          ? 'Synchronizing status'
                          : 'LV.${data.level}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      data == null ? 'Synchronizing status' : data.title,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: data == null ? null : progress,
                      color: AppColors.accent,
                      backgroundColor: AppColors.background,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data == null
                          ? 'XP unavailable'
                          : '${data.currentLevelXp} / ${data.xpToNextLevel} XP',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Text(
                'NAVIGATION',
                style: TextStyle(
                  color: AppColors.accent,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ),
            for (var index = 0; index < primaryDestinations.length; index++)
              ListTile(
                leading: Icon(primaryDestinations[index].icon),
                title: Text(primaryDestinations[index].drawerLabel),
                selected: primaryDestinations[index].tabIndex == selectedIndex,
                selectedColor: AppColors.accent,
                onTap: () {
                  Navigator.pop(context);
                  onPrimarySelected(primaryDestinations[index].tabIndex);
                },
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(
                'SYSTEM',
                style: TextStyle(
                  color: AppColors.accent,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ),
            for (final label in [
              'Character Titles',
              'Settings',
              'App Preferences',
              'About',
            ])
              ListTile(
                leading: Icon(
                  label == 'Character Titles'
                      ? Icons.workspace_premium_outlined
                      : label == 'About'
                      ? Icons.info_outline
                      : Icons.settings_outlined,
                ),
                title: Text(label),
                onTap: () {
                  Navigator.pop(context);
                  onSecondarySelected(label);
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}
