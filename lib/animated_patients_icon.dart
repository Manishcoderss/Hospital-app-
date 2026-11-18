import 'package:flutter/material.dart';

/// Decorative care symbol; the ECG is not patient monitoring data.
class AnimatedPatientsIcon extends StatefulWidget {
  const AnimatedPatientsIcon({super.key, this.size = 34});
  final double size;

  @override
  State<AnimatedPatientsIcon> createState() => _AnimatedPatientsIconState();
}

class _AnimatedPatientsIconState extends State<AnimatedPatientsIcon>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
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
        child: CustomPaint(painter: _CarePainter(_motion, _reducedMotion)),
      ),
    ),
  );
}

class _CarePainter extends CustomPainter {
  _CarePainter(this.motion, this.reducedMotion) : super(repaint: motion);
  final Animation<double> motion;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final outline = Paint()
      ..color = const Color(0xFF102044)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final heart = Path()
      ..moveTo(50, 17)
      ..cubicTo(26, -2, 9, 21, 23, 39)
      ..lineTo(50, 65)
      ..lineTo(77, 39)
      ..cubicTo(91, 21, 74, -2, 50, 17)
      ..close();
    canvas.drawPath(heart, outline);
    final hand = Path()
      ..moveTo(42, 94)
      ..lineTo(27, 94)
      ..lineTo(26, 87)
      ..lineTo(12, 75)
      ..quadraticBezierTo(8, 72, 7, 66)
      ..lineTo(4, 53)
      ..quadraticBezierTo(13, 50, 16, 61)
      ..lineTo(18, 66)
      ..quadraticBezierTo(21, 60, 27, 65)
      ..lineTo(36, 72)
      ..quadraticBezierTo(42, 76, 42, 84)
      ..close()
      ..moveTo(18, 66)
      ..lineTo(29, 76);
    canvas.drawPath(hand, outline);
    canvas.save();
    canvas.translate(100, 0);
    canvas.scale(-1, 1);
    canvas.drawPath(hand, outline);
    canvas.restore();
    final ecg = Path()
      ..moveTo(17, 36)
      ..lineTo(40, 36)
      ..lineTo(45, 25)
      ..lineTo(52, 48)
      ..lineTo(58, 36)
      ..lineTo(83, 36);
    final metric = ecg.computeMetrics().first;
    final phase = motion.value;
    final end = reducedMotion ? 1.0 : (phase / .55).clamp(0.0, 1.0);
    final start = reducedMotion ? 0.0 : ((phase - .58) / .32).clamp(0.0, 1.0);
    canvas.save();
    canvas.clipPath(heart);
    canvas.drawPath(
      metric.extractPath(start * metric.length, end * metric.length),
      Paint()
        ..color = const Color(0xFF35BCAE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CarePainter oldDelegate) =>
      oldDelegate.motion != motion ||
      oldDelegate.reducedMotion != reducedMotion;
}
