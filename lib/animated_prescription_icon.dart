import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedPrescriptionIcon extends StatefulWidget {
  const AnimatedPrescriptionIcon({super.key, this.size = 34});
  final double size;

  @override
  State<AnimatedPrescriptionIcon> createState() =>
      _AnimatedPrescriptionIconState();
}

class _AnimatedPrescriptionIconState extends State<AnimatedPrescriptionIcon>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
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
        child: CustomPaint(painter: _DocumentsPainter(_motion)),
      ),
    ),
  );
}

class _DocumentsPainter extends CustomPainter {
  _DocumentsPainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final wave = math.sin(motion.value * math.pi * 2);
    final pen = Paint()
      ..color = const Color(0xFF0745FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(11, 8 - wave, 57, 72),
        const Radius.circular(9),
      ),
      pen,
    );
    canvas.save();
    canvas.translate(59 + 2 * wave, 55 + 3 * wave);
    canvas.rotate(.065 * wave);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-29, -36, 57, 72),
        const Radius.circular(9),
      ),
      pen,
    );
    // Keep the overlapping outlines visible, as in the reference.
    canvas.drawLine(const Offset(0, -25), const Offset(0, -11), pen);
    canvas.drawLine(const Offset(-7, -18), const Offset(7, -18), pen);
    canvas.drawLine(const Offset(-16, 3), const Offset(-4, 3), pen);
    canvas.drawLine(const Offset(-16, 13), const Offset(-4, 13), pen);
    final currency = Path()
      ..moveTo(19, 10)
      ..cubicTo(9, 5, 5, 17, 15, 19)
      ..cubicTo(26, 21, 18, 32, 9, 27)
      ..moveTo(15, 6)
      ..lineTo(15, 32);
    canvas.drawPath(currency, pen);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DocumentsPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
