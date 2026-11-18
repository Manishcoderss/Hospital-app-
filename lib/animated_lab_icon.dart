import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedLabIcon extends StatefulWidget {
  const AnimatedLabIcon({super.key, this.size = 34});
  final double size;

  @override
  State<AnimatedLabIcon> createState() => _AnimatedLabIconState();
}

class _AnimatedLabIconState extends State<AnimatedLabIcon>
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
        child: CustomPaint(painter: _LabPainter(_motion)),
      ),
    ),
  );
}

class _LabPainter extends CustomPainter {
  _LabPainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final wave = math.sin(motion.value * math.pi * 2);
    final outline = Paint()
      ..color = const Color(0xFF102044)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accent = Paint()
      ..color = const Color(0xFF45B8A9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.translate(40, 47);
    canvas.rotate(.055 * wave);
    canvas.translate(-40, -47);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 12, 57, 71),
        const Radius.circular(7),
      ),
      outline,
    );
    canvas.drawRect(const Rect.fromLTWH(16, 19, 45, 57), outline);
    final clip = Path()
      ..moveTo(27, 19)
      ..lineTo(27, 12)
      ..lineTo(33, 12)
      ..cubicTo(33, 3, 44, 3, 44, 12)
      ..lineTo(50, 12)
      ..lineTo(50, 19);
    canvas.drawPath(clip, outline);
    canvas.drawLine(const Offset(27, 40), const Offset(51, 40), accent);
    canvas.drawLine(const Offset(33, 48), const Offset(47, 29), accent);
    void hexagon(double x, double y) {
      final path = Path();
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        final dx = x + 6.5 * math.cos(angle);
        final dy = y + 6.5 * math.sin(angle);
        if (i == 0) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = Colors.white);
      canvas.drawPath(path, outline);
    }

    hexagon(35, 42);
    hexagon(45, 35);
    canvas.drawRect(const Rect.fromLTWH(24, 57, 28, 14), accent);
    canvas.drawLine(const Offset(33, 57), const Offset(33, 71), accent);
    canvas.drawLine(const Offset(24, 64), const Offset(52, 64), accent);
    canvas.restore();
    // The tube passes in front of the clipboard while rocking independently.
    canvas.save();
    canvas.translate(77 - 4 * wave, 73 - 2 * wave);
    canvas.rotate(-.12 * wave);
    final tube = Path()
      ..moveTo(-7, -13)
      ..lineTo(-7, 16)
      ..cubicTo(-7, 27, 7, 27, 7, 16)
      ..lineTo(7, -13)
      ..close();
    canvas.drawPath(tube, Paint()..color = Colors.white);
    canvas.drawPath(tube, outline);
    canvas.drawLine(const Offset(-5, -4), const Offset(5, -4), accent);
    canvas.drawRect(const Rect.fromLTWH(-5, 3, 5, 13), outline);
    final cap = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-10, -20, 20, 8),
      const Radius.circular(1),
    );
    canvas.drawRRect(cap, Paint()..color = Colors.white);
    canvas.drawRRect(cap, outline);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LabPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
