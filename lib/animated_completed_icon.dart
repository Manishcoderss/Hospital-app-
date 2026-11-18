import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative looping checkmark; the count remains the source of visit status.
class AnimatedCompletedIcon extends StatefulWidget {
  const AnimatedCompletedIcon({super.key, this.size = 34});
  final double size;

  @override
  State<AnimatedCompletedIcon> createState() => _AnimatedCompletedIconState();
}

class _AnimatedCompletedIconState extends State<AnimatedCompletedIcon>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
    value: .4,
  );
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion || !TickerMode.valuesOf(context).enabled) {
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
        child: CustomPaint(painter: _CompletedPainter(_motion, _reducedMotion)),
      ),
    ),
  );
}

class _CompletedPainter extends CustomPainter {
  _CompletedPainter(this.motion, this.reducedMotion) : super(repaint: motion);
  final Animation<double> motion;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final phase = motion.value;
    final progress = reducedMotion
        ? 1.0
        : phase < .30
        ? Curves.easeInOut.transform(phase / .30)
        : phase < .65
        ? 1.0
        : phase < .82
        ? 1 - Curves.easeInOut.transform((phase - .65) / .17)
        : 0.0;
    final ring = Path()
      ..addArc(const Rect.fromLTWH(12, 12, 76, 76), .05, math.pi * 1.68);
    final check = Path()
      ..moveTo(27, 49)
      ..lineTo(44, 66)
      ..lineTo(88, 23);
    final metric = check.computeMetrics().first;
    final visibleCheck = metric.extractPath(0, metric.length * progress);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Layered blue strokes echo the reference's luminous outlined mark.
    paint
      ..color = const Color(0xFF087DDE).withValues(alpha: .14)
      ..strokeWidth = 10;
    canvas.drawPath(ring, paint);
    canvas.drawPath(visibleCheck, paint);
    paint
      ..color = const Color(0xFF087DDE)
      ..strokeWidth = 6;
    canvas.drawPath(ring, paint);
    canvas.drawPath(visibleCheck, paint);
    paint
      ..color = const Color(0xFF61CCFF)
      ..strokeWidth = 1.3;
    canvas.drawPath(ring, paint);
    canvas.drawPath(visibleCheck, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CompletedPainter oldDelegate) =>
      oldDelegate.motion != motion ||
      oldDelegate.reducedMotion != reducedMotion;
}
