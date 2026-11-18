import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Decorative medical calendar animation.
class AnimatedAppointmentIcon extends StatefulWidget {
  const AnimatedAppointmentIcon({
    super.key,
    this.size = 28,
    this.color = const Color(0xFF0745FF),
  });
  final double size;
  final Color color;

  @override
  State<AnimatedAppointmentIcon> createState() =>
      _AnimatedAppointmentIconState();
}

class _AnimatedAppointmentIconState extends State<AnimatedAppointmentIcon>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
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
        child: CustomPaint(
          painter: _MedicalCalendarPainter(_motion, widget.color),
        ),
      ),
    ),
  );
}

class _MedicalCalendarPainter extends CustomPainter {
  _MedicalCalendarPainter(this.motion, this.color) : super(repaint: motion);
  final Animation<double> motion;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final phase = motion.value;
    // Lift the chestpiece, settle it, then briefly contract the centre date.
    final lift = phase < .55
        ? math.pow(math.sin(phase / .55 * math.pi), 2).toDouble()
        : 0.0;
    final shrink = phase > .5 && phase < .9
        ? math.pow(math.sin((phase - .5) / .4 * math.pi), 2).toDouble()
        : 0.0;
    final chestY = 78 - 20 * lift;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final calendar = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 9, 69, 56),
          const Radius.circular(8),
        ),
      )
      ..moveTo(5, 23)
      ..lineTo(74, 23);
    for (var row = 0; row < 2; row++) {
      for (var column = 0; column < 3; column++) {
        final cellSize = row == 1 && column == 1 ? 9 - 7 * shrink : 9.0;
        calendar.addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(18.5 + column * 20, 35.5 + row * 16),
              width: cellSize,
              height: cellSize,
            ),
            const Radius.circular(.8),
          ),
        );
      }
    }
    canvas.drawPath(calendar, paint);
    final tube = Path()
      ..moveTo(38, chestY + 10)
      ..cubicTo(38, 94 - 3 * lift, 48, 91, 59, 91)
      ..cubicTo(85, 91, 87, 78 - 3 * lift, 87, 65)
      ..lineTo(87, 53);
    canvas.drawPath(tube, paint);
    // An opaque centre lets the moving chestpiece pass over calendar dates.
    canvas.drawCircle(Offset(38, chestY), 10, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(38, chestY), 10, paint);
    canvas.drawCircle(const Offset(87, 45), 8, paint);
    canvas.save();
    canvas.translate(38, chestY);
    canvas.drawLine(const Offset(-4, 0), const Offset(4, 0), paint);
    canvas.drawLine(const Offset(0, -4), const Offset(0, 4), paint);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MedicalCalendarPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.motion != motion;
}
