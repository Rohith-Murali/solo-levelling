import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_colors.dart';
import '../../../features/dashboard/domain/dashboard_data.dart';

class SystemTopBar extends StatelessWidget implements PreferredSizeWidget {
  const SystemTopBar({
    required this.character,
    required this.onCharacterTap,
    super.key,
  });

  final DashboardCharacter? character;
  final VoidCallback onCharacterTap;

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final data = character;
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.surface,
      elevation: 0,
      titleSpacing: 14,
      shape: const Border(bottom: BorderSide(color: AppColors.border)),
      title: InkWell(
        onTap: onCharacterTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(path: data?.avatarImagePath),
            const SizedBox(width: 10),
            if (data == null)
              const SizedBox(width: 110, child: _LoadingIdentity())
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'LV.${data.level} - ${data.title}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
        ),
        Builder(
          builder: (context) => IconButton(
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _LoadingIdentity extends StatelessWidget {
  const _LoadingIdentity();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(width: 82, height: 13, color: AppColors.surfaceElevated),
      const SizedBox(height: 6),
      Container(width: 108, height: 10, color: AppColors.surfaceElevated),
    ],
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.path});
  final String? path;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(9),
    child: SizedBox(
      width: 40,
      height: 40,
      child: path == null
          ? const ColoredBox(
              color: AppColors.surfaceElevated,
              child: Icon(Icons.person, color: AppColors.accent),
            )
          : Image.asset(
              path!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: AppColors.surfaceElevated,
                child: Icon(Icons.person, color: AppColors.accent),
              ),
            ),
    ),
  );
}
