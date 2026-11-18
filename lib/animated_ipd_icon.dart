import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedIpdIcon extends StatefulWidget {
  const AnimatedIpdIcon({super.key, this.size = 34});
  final double size;

  @override
  State<AnimatedIpdIcon> createState() => _AnimatedIpdIconState();
}

class _IpdPainter extends CustomPainter {
  _IpdPainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final phase = motion.value;
    final tilt = .45 * math.pow(math.sin(phase * math.pi), 2);
    final pen = Paint()
      ..color = const Color(0xFF102044)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accent = Paint()
      ..color = const Color(0xFF43B5A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final hair = Path()
      ..moveTo(22, 42)
      ..cubicTo(10, 22, 22, 10, 32, 10)
      ..cubicTo(46, 10, 53, 28, 43, 42);
    canvas.drawPath(hair, pen);
    final face = Path()
      ..moveTo(21, 33)
      ..cubicTo(26, 26, 29, 35, 35, 32)
      ..quadraticBezierTo(44, 27, 44, 35)
      ..lineTo(43, 44)
      ..cubicTo(41, 59, 23, 59, 22, 44)
      ..close();
    canvas.drawPath(face, pen);
    canvas.drawPath(
      Path()
        ..moveTo(29, 45)
        ..quadraticBezierTo(33, 49, 37, 45),
      accent,
    );
    canvas.drawPath(
      Path()
        ..moveTo(27, 56)
        ..lineTo(27, 60)
        ..cubicTo(27, 69, 39, 69, 39, 60)
        ..lineTo(39, 56),
      pen,
    );
    canvas.drawPath(
      Path()
        ..moveTo(27, 59)
        ..cubicTo(8, 60, 7, 67, 7, 76)
        ..lineTo(7, 83)
        ..lineTo(63, 83)
        ..lineTo(63, 74)
        ..quadraticBezierTo(60, 61, 39, 59),
      pen,
    );
    canvas.save();
    canvas.translate(70, 60);
    canvas.rotate(tilt.toDouble());
    // White fill keeps the moving syringe clear of the patient's shoulder.
    final barrel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-9, -15, 18, 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(barrel, Paint()..color = Colors.white);
    canvas.drawRRect(barrel, accent);
    canvas.drawRect(const Rect.fromLTWH(-4, -23, 8, 8), accent);
    canvas.drawLine(const Offset(0, -23), const Offset(0, -37), accent);
    canvas.drawLine(const Offset(-8, 3), const Offset(8, 3), accent);
    canvas.drawLine(const Offset(-13, 19), const Offset(13, 19), accent);
    final extension = 10 + 5 * math.cos(phase * math.pi * 2);
    canvas.drawRect(Rect.fromLTWH(-4, 19, 8, extension), accent);
    canvas.drawLine(
      Offset(-9, 19 + extension),
      Offset(9, 19 + extension),
      accent,
    );
    // A short burst of drops repeats while the syringe is upright.
    if (phase < .28 && phase > .02) {
      final t = (phase - .02) / .26;
      final dropPaint = Paint()
        ..color = const Color(0xFF43B5A6).withValues(alpha: 1 - t);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, -39 - 14 * t), width: 2.5, height: 4),
        dropPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(3 * t, -43 - 19 * t),
          width: 2,
          height: 3.5,
        ),
        dropPaint,
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IpdPainter oldDelegate) =>
      oldDelegate.motion != motion;
}

class _AnimatedIpdIconState extends State<AnimatedIpdIcon>
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
        child: CustomPaint(painter: _IpdPainter(_motion)),
      ),
    ),
  );
}
