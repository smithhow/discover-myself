import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen overlay shown when the assessment advances to a new stage.
///
/// Tapping anywhere dismisses it; the parent also dismisses it on a timer.
class StageCelebration extends StatefulWidget {
  const StageCelebration({
    super.key,
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  State<StageCelebration> createState() => _StageCelebrationState();
}

class _StageCelebrationState extends State<StageCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('stage_celebration'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              final scale = 0.7 + 0.3 * Curves.easeOutBack.transform(t);
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _GlowParticlesPainter(t)),
                  Center(
                    child: Opacity(
                      opacity: t.clamp(0.0, 1.0).toDouble(),
                      child: Transform.scale(
                        scale: scale,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.workspace_premium,
                              size: 72,
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '点击继续',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
}

class _GlowParticlesPainter extends CustomPainter {
  _GlowParticlesPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint();
    for (var i = 0; i < 12; i++) {
      final angle = math.pi * 2 * i / 12;
      final distance = 60 + 90 * progress;
      final offset =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      paint.color = Colors.amber.withValues(alpha: (1 - progress) * 0.8);
      canvas.drawCircle(offset, 5 * (1 - progress) + 1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
