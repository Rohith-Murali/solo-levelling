import 'package:material_ui/material_ui.dart';

import '../features/home/presentation/home_page.dart';
import 'theme/app_theme.dart';

class SoloLevelingApp extends StatelessWidget {
  const SoloLevelingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solo Leveling',
      theme: AppTheme.dark,
      home: const HomePage(),
    );
  }
}
