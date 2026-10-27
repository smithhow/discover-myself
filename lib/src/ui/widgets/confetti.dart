import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight falling-confetti animation drawn with a [CustomPainter].
class Confetti extends StatefulWidget {
  const Confetti({
    super.key,
    this.particles = 20,
    this.duration = const Duration(seconds: 2),
  });

  final int particles;
  final Duration duration;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    if (MediaQuery.of(context).disableAnimations) return;
    _started = true;
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          key: const Key('confetti'),
          painter: _ConfettiPainter(_controller.value, widget.particles),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.progress, this.count);

  final double progress;
  final int count;

  static const _colors = [
    Colors.amber,
    Colors.pinkAccent,
    Colors.lightBlueAccent,
    Colors.greenAccent,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final lane = (i + 0.5) / count;
      final x = size.width * lane + math.sin(progress * math.pi * 4 + i) * 12;
      final y = -20 + (size.height + 40) * ((progress + i * 0.05) % 1.0);
      paint.color = _colors[i % _colors.length].withValues(alpha: 1 - progress);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 2 + i);
      canvas.drawRect(const Rect.fromLTWH(-4, -3, 8, 6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.count != count;
}
