import 'package:flutter/material.dart';

/// Decorative reference animation; this is not a patient monitor signal.
class PulseEcg extends StatefulWidget {
  const PulseEcg({super.key});
  @override
  State<PulseEcg> createState() => _PulseEcgState();
}

class _PulseEcgState extends State<PulseEcg>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
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
  Widget build(BuildContext context) => Semantics(
    label: 'Decorative ECG animation, not live patient data',
    child: SizedBox(
      height: 70,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(painter: _PulsePainter(_motion)),
      ),
    ),
  );
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final cycle = size.width / 3;
    final shift = motion.value * cycle;
    final path = Path();
    for (var i = -1; i < 5; i++) {
      final x = i * cycle - shift;
      final y = size.height * .57;
      if (i == -1) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      path.lineTo(x + cycle * .64, y);
      path.lineTo(x + cycle * .72, size.height * .18);
      path.lineTo(x + cycle * .83, size.height * .88);
      path.lineTo(x + cycle * .93, y);
      path.lineTo(x + cycle, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF00B8EF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.miter,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) =>
      motion != oldDelegate.motion;
}
