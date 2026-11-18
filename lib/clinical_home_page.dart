import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'clinical_directory.dart';

class ClinicalHomePage extends StatelessWidget {
  const ClinicalHomePage({super.key, required this.onDirectory});
  final ValueChanged<ClinicalDirectory> onDirectory;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF7F3EA),
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 210),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFCFE8DD)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final artWidth = constraints.maxWidth < 290 ? 62.0 : 86.0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'Doctor workspace',
                            style: TextStyle(
                              color: Color(0xFF207361),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 13),
                        const Text(
                          'Clinical',
                          style: TextStyle(
                            color: Color(0xFF172B25),
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.8,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Open prescriptions, laboratory reports and pharmacy records.',
                          style: TextStyle(
                            color: Color(0xFF566F65),
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExcludeSemantics(
                    child: SizedBox(
                      width: artWidth,
                      height: 145,
                      child: const _ClinicalHelix(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Your clinical workspace',
          style: TextStyle(
            color: Color(0xFF20312D),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose a service to view patient records.',
          style: TextStyle(color: Color(0xFF566963), fontSize: 13),
        ),
        const SizedBox(height: 16),
        _card(
          ClinicalDirectory.prescriptions,
          Icons.medication_outlined,
          'View prescriptions and follow-up advice',
          const Color(0xFF207361),
        ),
        _card(
          ClinicalDirectory.labs,
          Icons.science_outlined,
          'View lab orders and available test results',
          const Color(0xFFB87919),
        ),
        _card(
          ClinicalDirectory.pharmacy,
          Icons.local_pharmacy_outlined,
          'View issued prescriptions and dispensing',
          const Color(0xFF207361),
        ),
      ],
    ),
  );

  Widget _card(
    ClinicalDirectory directory,
    IconData icon,
    String description,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE2E7E0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onDirectory(directory),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      directory.title,
                      style: const TextStyle(
                        color: Color(0xFF20312D),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF566963),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: const Color(0xFF207361),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ClinicalHelix extends StatefulWidget {
  const _ClinicalHelix();

  @override
  State<_ClinicalHelix> createState() => _ClinicalHelixState();
}

class _ClinicalHelixState extends State<_ClinicalHelix>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _ClinicalConnectionsPainter(_controller)),
  );
}

class _ClinicalConnectionsPainter extends CustomPainter {
  _ClinicalConnectionsPainter(this.animation) : super(repaint: animation);
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    const left = Color(0xFF207361);
    const right = Color(0xFF7AC8AF);
    final phase = animation.value * 2 * math.pi;
    final center = size.width / 2;
    final amplitude = math.max(0.0, center - 6);
    for (var i = 0; i < 12; i++) {
      final y = 6 + (size.height - 12) * i / 11;
      final angle = phase + i * math.pi / 7;
      final offset = math.sin(angle) * amplitude;
      final depth = math.cos(angle);
      final start = Offset(center - offset, y);
      final end = Offset(center + offset, y);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..strokeWidth = 1.8
          ..color = left.withValues(alpha: .45),
      );
      void dot(Offset point, Color color, double z) {
        canvas.drawCircle(
          point,
          3.5 + (z + 1) * .8,
          Paint()..color = color.withValues(alpha: .65 + (z + 1) * .175),
        );
      }

      if (depth > 0) {
        dot(end, right, -depth);
        dot(start, left, depth);
      } else {
        dot(start, left, depth);
        dot(end, right, -depth);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ClinicalConnectionsPainter oldDelegate) =>
      animation != oldDelegate.animation;
}
