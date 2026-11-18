import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedDoctorIcon extends StatefulWidget {
  const AnimatedDoctorIcon({super.key, this.size = 34});
  final double size;

  @override
  State<AnimatedDoctorIcon> createState() => _AnimatedDoctorIconState();
}

class _AnimatedDoctorIconState extends State<AnimatedDoctorIcon>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
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
        child: CustomPaint(painter: _DoctorPainter(_motion)),
      ),
    ),
  );
}

class _DoctorPainter extends CustomPainter {
  _DoctorPainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    const blue = Color(0xFF207361);
    final wave = math.sin(motion.value * math.pi * 2);
    // A gentle breathing pulse keeps the silhouette legible at small sizes.
    canvas.translate(50, 50);
    canvas.scale(1 + .025 * wave);
    canvas.translate(-50, -50);
    canvas.drawCircle(const Offset(50, 50), 47, Paint()..color = blue);
    final white = Paint()..color = Colors.white;
    final outline = Paint()
      ..color = blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Hair and masked face.
    final hair = Path()
      ..moveTo(32, 43)
      ..lineTo(31, 31)
      ..cubicTo(30, 20, 38, 18, 44, 18)
      ..lineTo(48, 18)
      ..quadraticBezierTo(54, 18, 55, 24)
      ..quadraticBezierTo(61, 25, 60, 34)
      ..lineTo(59, 43)
      ..close();
    canvas.drawPath(hair, white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 30, 23, 23),
        const Radius.circular(8),
      ),
      white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 30, 23, 23),
        const Radius.circular(8),
      ),
      outline,
    );
    canvas.drawPath(
      Path()
        ..moveTo(34, 43)
        ..quadraticBezierTo(45, 39, 57, 43),
      outline,
    );
    // Coat with V neckline.
    final coat = Path()
      ..moveTo(25, 80)
      ..lineTo(25, 69)
      ..quadraticBezierTo(25, 60, 38, 57)
      ..lineTo(45.5, 67)
      ..lineTo(53, 57)
      ..quadraticBezierTo(65, 60, 65, 69)
      ..lineTo(65, 80)
      ..quadraticBezierTo(65, 82, 63, 82)
      ..lineTo(27, 82)
      ..quadraticBezierTo(25, 82, 25, 80)
      ..close();
    canvas.drawPath(coat, white);
    canvas.drawPath(
      Path()
        ..moveTo(38, 57)
        ..lineTo(45.5, 68)
        ..lineTo(53, 57),
      outline,
    );
    // Stethoscope.
    canvas.drawLine(const Offset(35, 59), const Offset(35, 72), outline);
    canvas.drawCircle(const Offset(35, 74), 2.5, outline);
    canvas.drawPath(
      Path()
        ..moveTo(56, 59)
        ..lineTo(56, 69)
        ..moveTo(53, 76)
        ..lineTo(53, 72)
        ..cubicTo(53, 67, 60, 67, 60, 72)
        ..lineTo(60, 76),
      outline,
    );
    // Medical cross gently floats and grows independently of the doctor.
    canvas.save();
    canvas.translate(70, 48 - 1.8 * wave);
    canvas.scale(1 + .10 * wave);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3, -8, 6, 16),
        const Radius.circular(2),
      ),
      white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-8, -3, 16, 6),
        const Radius.circular(2),
      ),
      white,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DoctorPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
