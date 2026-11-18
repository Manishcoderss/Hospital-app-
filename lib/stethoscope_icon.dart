import 'package:flutter/material.dart';

class StethoscopeIcon extends StatelessWidget {
  const StethoscopeIcon({super.key, this.color = Colors.white, this.size = 30});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _StethoscopePainter(color)),
  );
}

class _StethoscopePainter extends CustomPainter {
  const _StethoscopePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(5, 4)
        ..lineTo(5, 13)
        ..cubicTo(5, 22, 18, 22, 18, 13)
        ..lineTo(18, 4),
      pen,
    );
    canvas.drawLine(const Offset(5, 4), const Offset(8, 4), pen);
    canvas.drawLine(const Offset(15, 4), const Offset(18, 4), pen);
    canvas.drawPath(
      Path()
        ..moveTo(11.5, 20)
        ..lineTo(11.5, 24)
        ..cubicTo(11.5, 31, 26, 31, 26, 21),
      pen,
    );
    canvas.drawCircle(const Offset(26, 17.5), 3.5, pen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StethoscopePainter oldDelegate) =>
      color != oldDelegate.color;
}
