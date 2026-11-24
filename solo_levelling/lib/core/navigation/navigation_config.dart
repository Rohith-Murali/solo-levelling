import 'package:material_ui/material_ui.dart';

enum PrimaryDestination { dashboard, quests, goals, skills, character, history }

class NavigationDestinationConfig {
  const NavigationDestinationConfig({
    required this.destination,
    required this.label,
    required this.icon,
    required this.drawerLabel,
  });

  final PrimaryDestination destination;
  final String label;
  final IconData icon;
  final String drawerLabel;
}

const primaryDestinations = <NavigationDestinationConfig>[
  NavigationDestinationConfig(
    destination: PrimaryDestination.dashboard,
    label: 'Dashboard',
    drawerLabel: 'Dashboard',
    icon: Icons.home_outlined,
  ),
  NavigationDestinationConfig(
    destination: PrimaryDestination.quests,
    label: 'Quests',
    drawerLabel: 'Quest Center',
    icon: Icons.track_changes,
  ),
  NavigationDestinationConfig(
    destination: PrimaryDestination.goals,
    label: 'Goals',
    drawerLabel: 'Goals',
    icon: Icons.flag_outlined,
  ),
  NavigationDestinationConfig(
    destination: PrimaryDestination.skills,
    label: 'Skills',
    drawerLabel: 'Skill Library',
    icon: Icons.bolt_outlined,
  ),
  NavigationDestinationConfig(
    destination: PrimaryDestination.character,
    label: 'Character',
    drawerLabel: 'Character Status',
    icon: Icons.person_outline,
  ),
  NavigationDestinationConfig(
    destination: PrimaryDestination.history,
    label: 'History',
    drawerLabel: 'Activity Log',
    icon: Icons.bar_chart,
  ),
];
