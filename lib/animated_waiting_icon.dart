import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative time-lapse clock, not elapsed patient waiting time.
class AnimatedWaitingIcon extends StatefulWidget {
  const AnimatedWaitingIcon({super.key, this.size = 34});
  final double size;

  @override
  State<AnimatedWaitingIcon> createState() => _AnimatedWaitingIconState();
}

class _AnimatedWaitingIconState extends State<AnimatedWaitingIcon>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(painter: _ClockPainter(_motion)),
      ),
    ),
  );
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    const center = Offset(50, 50);
    const blue = Color(0xFF207361);
    final rim = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF79C8AD), blue, Color(0xFF104B3C)],
      ).createShader(const Rect.fromLTWH(3, 3, 94, 94));
    canvas.drawCircle(center, 47, rim);
    canvas.drawCircle(center, 40, Paint()..color = const Color(0xFFF5F7EC));
    final tick = Paint()..strokeCap = StrokeCap.round;
    Offset point(double angle, double radius) =>
        center + Offset(math.sin(angle), -math.cos(angle)) * radius;
    for (var i = 0; i < 60; i++) {
      final major = i % 5 == 0;
      tick
        ..color = major ? const Color(0xFF207361) : const Color(0xFF7BA58E)
        ..strokeWidth = major ? 1.5 : .7;
      final angle = i * math.pi / 30;
      canvas.drawLine(point(angle, major ? 32 : 35), point(angle, 37), tick);
    }
    for (var number = 1; number <= 12; number++) {
      final label = TextPainter(
        text: TextSpan(
          text: '$number',
          style: const TextStyle(
            color: Color(0xFF305E4D),
            fontSize: 8,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        point(number * math.pi / 6, 26) -
            Offset(label.width / 2, label.height / 2),
      );
    }
    void hand(
      double angle,
      double length,
      Color color,
      double width, {
      double tail = 0,
    }) {
      canvas.drawLine(
        point(angle + math.pi, tail),
        point(angle, length),
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    // Twelve accelerated revolutions per loop; all hands meet seamlessly.
    hand(
      -math.pi / 3 + motion.value * math.pi * 2,
      19,
      const Color(0xFF174C3D),
      2.6,
    );
    hand(
      math.pi / 3 + motion.value * math.pi * 4,
      28,
      const Color(0xFF207361),
      1.8,
    );
    hand(
      motion.value * math.pi * 24,
      34,
      const Color(0xFFFF5364),
      1.1,
      tail: 7,
    );
    canvas.drawCircle(center, 2.4, Paint()..color = const Color(0xFFFF6874));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
