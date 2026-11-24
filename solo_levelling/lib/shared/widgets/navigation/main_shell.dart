import 'package:material_ui/material_ui.dart';

import '../../../features/dashboard/domain/dashboard_data.dart';
import '../../../features/dashboard/domain/dashboard_repository.dart';
import '../../../features/dashboard/presentation/character_status_screen.dart';
import '../../../features/dashboard/presentation/dashboard_screen.dart';
import '../../../features/dashboard/presentation/activity_log_screen.dart';
import '../../../features/progression/presentation/quest_center_screen.dart';
import '../../../features/progression/presentation/goals_screen.dart';
import '../../../features/progression/presentation/skill_library_screen.dart';
import '../../../features/progression/domain/progression_repository.dart';
import 'system_bottom_nav.dart';
import 'system_drawer.dart';
import 'system_top_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    required this.repository,
    required this.accessToken,
    required this.onLogout,
    required this.onCharacterRequired,
    this.progressionRepository,
    super.key,
  });
  final DashboardRepository repository;
  final String? accessToken;
  final VoidCallback onLogout;
  final VoidCallback onCharacterRequired;
  final ProgressionRepository? progressionRepository;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  int _dashboardRevision = 0;
  final Set<int> _visitedTabs = <int>{0};
  DashboardCharacter? _character;

  void _select(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
        _visitedTabs.add(index);
      });
    }
  }

  void _refreshDashboard() {
    setState(() => _dashboardRevision++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SystemTopBar(
      character: _character,
      onCharacterTap: () => _select(4),
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
        if (_visitedTabs.contains(0))
          DashboardScreen(
            key: ValueKey<int>(_dashboardRevision),
            repository: widget.repository,
            accessToken: widget.accessToken,
            onCharacterRequired: widget.onCharacterRequired,
            onViewActivity: () => _select(4),
            progressionRepository: widget.progressionRepository,
            onCharacterLoaded: (character) =>
                setState(() => _character = character),
          )
        else
          const SizedBox.shrink(),
        if (_visitedTabs.contains(1))
          QuestCenterScreen(
            repository: widget.progressionRepository,
            dashboardRepository: widget.repository,
            accessToken: widget.accessToken,
            isActive: _selectedIndex == 1,
            onDataChanged: _refreshDashboard,
          )
        else
          const SizedBox.shrink(),
        if (_visitedTabs.contains(2))
          GoalsScreen(
            repository: widget.progressionRepository,
            accessToken: widget.accessToken,
            isActive: _selectedIndex == 2,
          )
        else
          const SizedBox.shrink(),
        if (_visitedTabs.contains(3))
          SkillLibraryScreen(
            dashboardRepository: widget.repository,
            progressionRepository: widget.progressionRepository,
            accessToken: widget.accessToken,
            isActive: _selectedIndex == 2,
            onDataChanged: _refreshDashboard,
          )
        else
          const SizedBox.shrink(),
        if (_visitedTabs.contains(4))
          CharacterStatusScreen(
            repository: widget.repository,
            accessToken: widget.accessToken,
            isActive: _selectedIndex == 3,
          )
        else
          const SizedBox.shrink(),
        if (_visitedTabs.contains(5))
          ActivityLogScreen(
            repository: widget.repository,
            accessToken: widget.accessToken,
            isActive: _selectedIndex == 4,
          )
        else
          const SizedBox.shrink(),
      ],
    ),
    bottomNavigationBar: SystemBottomNav(
      selectedIndex: _selectedIndex,
      onSelected: _select,
    ),
  );

  void _showSecondary(String label) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => _SystemInfoPage(title: label)),
  );
}

class _SystemInfoPage extends StatelessWidget {
  const _SystemInfoPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          const SizedBox(height: 10),
          const Text(
            'This system module is not connected yet.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
