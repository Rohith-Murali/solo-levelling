import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/navigation/navigation_config.dart';
import '../../../features/dashboard/domain/dashboard_data.dart';
import '../../../features/dashboard/domain/dashboard_repository.dart';
import '../../../features/dashboard/presentation/dashboard_screen.dart';
import 'system_bottom_nav.dart';
import 'system_drawer.dart';
import 'system_top_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({
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
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  DashboardCharacter? _character;

  void _select(int index) {
    if (index != _selectedIndex) setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SystemTopBar(
      character: _character,
      onCharacterTap: () => _select(3),
    ),
    drawer: SystemDrawer(
      character: _character,
      selectedIndex: _selectedIndex,
      onPrimarySelected: _select,
      onSecondarySelected: _showSecondary,
      onLogout: widget.onLogout,
    ),
    body: IndexedStack(
      index: _selectedIndex,
      children: [
        DashboardScreen(
          repository: widget.repository,
          accessToken: widget.accessToken,
          onCharacterRequired: widget.onCharacterRequired,
          onCharacterLoaded: (character) =>
              setState(() => _character = character),
        ),
        for (final destination in primaryDestinations.skip(1))
          _PlaceholderPage(title: destination.label, icon: destination.icon),
      ],
    ),
    bottomNavigationBar: SystemBottomNav(
      selectedIndex: _selectedIndex,
      onSelected: _select,
    ),
  );

  void _showSecondary(String label) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          _PlaceholderPage(title: label, icon: Icons.settings_outlined),
    ),
  );
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accent, size: 48),
          const SizedBox(height: 18),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.accent,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'This system module is ready for its feature implementation.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}
