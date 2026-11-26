import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';

class HolographicDialog extends StatelessWidget {
  const HolographicDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.compact = false,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final bool compact;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 620),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xF0163B69), Color(0xF008142B)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: .75),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: .28),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.primaryGlow.withValues(alpha: .24),
            blurRadius: 50,
          ),
        ],
      ),
      // child: Padding(
      //   padding: EdgeInsets.fromLTRB(
      //     compact ? 14 : 20,
      //     compact ? 12 : 18,
      //     compact ? 14 : 20,
      //     compact ? 8 : 14,
      //   ),
      padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.accent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 13 : 14,
                      letterSpacing: compact ? .8 : 1.1,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 10 : 16),
            Flexible(child: SingleChildScrollView(child: child)),
            if (actions != null) ...[
              SizedBox(height: compact ? 8 : 14),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
            ],
          ],
        ),
      ),
    // ),
  );
}
