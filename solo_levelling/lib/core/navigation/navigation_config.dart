import 'package:material_ui/material_ui.dart';

enum PrimaryDestination { dashboard, goals, skills, character, history }

class NavigationDestinationConfig {
  const NavigationDestinationConfig({
    required this.destination,
    required this.tabIndex,
    required this.label,
    required this.icon,
    required this.drawerLabel,
  });

  final PrimaryDestination destination;
  final int tabIndex;
  final String label;
  final IconData icon;
  final String drawerLabel;
}

const primaryDestinations = <NavigationDestinationConfig>[
  NavigationDestinationConfig(
    destination: PrimaryDestination.dashboard,
    tabIndex: 0,
    label: 'Dashboard',
    drawerLabel: 'Dashboard',
    icon: Icons.home_outlined,
  ),
  NavigationDestinationConfig(
    destination: PrimaryDestination.goals,
    tabIndex: 1,
    label: 'Goals',
    drawerLabel: 'Goals',
    icon: Icons.flag_outlined,
  ),
  NavigationDestinationConfig(
    destination: PrimaryDestination.skills,
    tabIndex: 2,
    label: 'Skills',
    drawerLabel: 'Skill Library',
    icon: Icons.bolt_outlined,
  ),
  NavigationDestinationConfig(
    destination: PrimaryDestination.character,
    tabIndex: 3,
    label: 'Character',
    drawerLabel: 'Character Status',
    icon: Icons.person_outline,
  ),
  NavigationDestinationConfig(
    destination: PrimaryDestination.history,
    tabIndex: 4,
    label: 'History',
    drawerLabel: 'Activity Log',
    icon: Icons.bar_chart,
  ),
];
