import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_colors.dart';

class SystemNotificationData {
  const SystemNotificationData({required this.message, required this.icon});

  final String message;
  final IconData icon;
}

class SystemNotification {
  const SystemNotification._();

  static Future<void> show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          _HolographicNotification(message: message, icon: icon),
    );
  }

  /// Presents each event as its own system screen, in order.
  static Future<void> showStack(
    BuildContext context,
    List<SystemNotificationData> notifications,
  ) async {
    for (final notification in notifications) {
      if (!context.mounted) return;
      await show(
        context,
        message: notification.message,
        icon: notification.icon,
      );
    }
  }
}

class _HolographicNotification extends StatefulWidget {
  const _HolographicNotification({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  State<_HolographicNotification> createState() =>
      _HolographicNotificationState();
}

class _HolographicNotificationState extends State<_HolographicNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    child: AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final pulse = 0.55 + (_animation.value * 0.45);
        return CustomPaint(
          painter: _HolographicFramePainter(progress: _animation.value),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            decoration: BoxDecoration(
              color: const Color(0xEE061A31),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF123A61).withValues(alpha: .82),
                  AppColors.surface.withValues(alpha: .98),
                  const Color(0xFF041329).withValues(alpha: .98),
                ],
              ),
              border: Border.all(
                color: AppColors.primaryGlow.withValues(alpha: pulse),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGlow.withValues(alpha: .32 * pulse),
                  blurRadius: 28,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: .16),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _PulseIcon(icon: widget.icon, animation: _animation),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'NOTIFICATION',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.accent,
                              letterSpacing: 2.6,
                              fontWeight: FontWeight.w800,
                              shadows: const [
                                Shadow(
                                  color: AppColors.primaryGlow,
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                      ),
                    ),
                    Text(
                      'SYS',
                      style: TextStyle(
                        color: AppColors.primaryGlow.withValues(alpha: .8),
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  color: AppColors.primaryGlow.withValues(alpha: .5),
                ),
                const SizedBox(height: 22),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(color: AppColors.primaryGlow, blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      side: const BorderSide(color: AppColors.primaryGlow),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ACKNOWLEDGE'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _PulseIcon extends StatelessWidget {
  const _PulseIcon({required this.icon, required this.animation});

  final IconData icon;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final glow = 0.45 + (animation.value * .55);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryGlow.withValues(alpha: .12),
        border: Border.all(color: AppColors.accent.withValues(alpha: glow)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow.withValues(alpha: .45 * glow),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.accent, size: 27),
    );
  }
}

class _HolographicFramePainter extends CustomPainter {
  const _HolographicFramePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.primaryGlow.withValues(alpha: .7)
      ..strokeWidth = 2;
    final scanY = size.height * progress;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), line);
    canvas.drawLine(const Offset(0, 8), Offset(36, 8), line);
    canvas.drawLine(
      Offset(size.width - 36, size.height - 8),
      Offset(size.width, size.height - 8),
      line,
    );
  }

  @override
  bool shouldRepaint(_HolographicFramePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
