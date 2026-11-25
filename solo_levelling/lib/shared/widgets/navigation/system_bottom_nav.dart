import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/navigation/navigation_config.dart';

class SystemBottomNav extends StatelessWidget {
  const SystemBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          for (var index = 0; index < primaryDestinations.length; index++)
            Expanded(
              child: _NavItem(
                config: primaryDestinations[index],
                selected: primaryDestinations[index].tabIndex == selectedIndex,
                onTap: () => onSelected(primaryDestinations[index].tabIndex),
              ),
            ),
        ],
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.config,
    required this.selected,
    required this.onTap,
  });
  final NavigationDestinationConfig config;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: config.label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceElevated : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              config.icon,
              color: selected ? AppColors.accent : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              config.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.textMuted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
