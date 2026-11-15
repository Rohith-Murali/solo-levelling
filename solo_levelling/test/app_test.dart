import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:solo_levelling/app/app.dart';
import 'package:solo_levelling/app/theme/app_colors.dart';

void main() {
  testWidgets('renders the themed application shell', (tester) async {
    await tester.pumpWidget(const SoloLevelingApp());

    expect(find.text('SOLO LEVELING'), findsOneWidget);
    expect(find.text('SYSTEM INITIALIZED'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      AppColors.background,
    );
  });
}
