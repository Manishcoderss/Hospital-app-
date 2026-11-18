import 'package:flutter/material.dart';

import 'stethoscope_icon.dart';
import 'animated_appointment_icon.dart';

class SoftBottomBar extends StatelessWidget {
  const SoftBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.dark = false,
    this.referenceStyle = false,
    this.appointmentStyle = false,
    this.patientStyle = false,
    this.onCenterTap,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool dark;
  final bool referenceStyle;
  final bool appointmentStyle;
  final bool patientStyle;
  final VoidCallback? onCenterTap;
  static const items = [
    (Icons.home_rounded, 'Home'),
    (Icons.calendar_month_outlined, 'Appointments'),
    (Icons.people_outline, 'Patients'),
    (Icons.medical_services_outlined, 'Clinical'),
    (Icons.person_outline, 'Profile'),
  ];
  @override
  Widget build(BuildContext context) => patientStyle
      ? _patientBar(context)
      : appointmentStyle
      ? Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE4DBCB))),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 76,
              child: Row(
                children: [
                  _tab(0),
                  _tab(1),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -14),
                      child: Tooltip(
                        message: 'Clinical',
                        child: Semantics(
                          button: true,
                          label: 'Clinical',
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFC8DAD2),
                            ),
                            child: Material(
                              color: const Color(0xFF207361),
                              shape: const CircleBorder(
                                side: BorderSide(
                                  color: Color(0xFFF7F3EA),
                                  width: 4,
                                ),
                              ),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => onTap(3),
                                child: const SizedBox(
                                  width: 58,
                                  height: 58,
                                  child: Center(child: StethoscopeIcon()),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _tab(2),
                  _tab(4),
                ],
              ),
            ),
          ),
        )
      : referenceStyle
      ? Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE7EEF6))),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height:
                  66 +
                  (MediaQuery.textScalerOf(context).scale(10) - 10).clamp(
                    0.0,
                    double.infinity,
                  ),
              child: Row(
                children: [
                  for (final i in [0, 1, 3, 2, 4]) _tab(i),
                ],
              ),
            ),
          ),
        )
      : dark
      ? _darkBar()
      : CustomPaint(
          painter: _NavigationShape(),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 82,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tab(0),
                  _tab(1),
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(0, -8),
                      child: Center(
                        child: Semantics(
                          button: true,
                          selected: currentIndex == 3,
                          label: 'Clinical',
                          child: Tooltip(
                            message: 'Clinical',
                            child: Material(
                              shape: const CircleBorder(),
                              color: const Color(0xFF2563EB),
                              elevation: 7,
                              shadowColor: const Color(0x552563EB),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => onTap(3),
                                child: const SizedBox(
                                  width: 59,
                                  height: 59,
                                  child: Center(child: StethoscopeIcon()),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _tab(2),
                  _tab(4),
                ],
              ),
            ),
          ),
        );
  Widget _patientBar(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFE4DBCB))),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height:
            76 +
            (MediaQuery.textScalerOf(context).scale(10) - 10).clamp(
              0.0,
              double.infinity,
            ),
        child: Row(
          children: [
            for (final entry in const [
              (Icons.home_rounded, 'Home'),
              (Icons.calendar_month_outlined, 'Visits'),
              (Icons.folder_outlined, 'Records'),
              (Icons.person_outline, 'Profile'),
            ].asMap().entries) ...[
              if (entry.key == 2)
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(0, -14),
                    child: Tooltip(
                      message: 'Book appointment',
                      child: Semantics(
                        button: true,
                        label: 'Book appointment',
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFC8DAD2),
                          ),
                          child: Material(
                            color: const Color(0xFF207361),
                            shape: const CircleBorder(
                              side: BorderSide(
                                color: Color(0xFFF7F3EA),
                                width: 4,
                              ),
                            ),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onCenterTap,
                              child: const SizedBox(
                                width: 58,
                                height: 58,
                                child: Center(child: StethoscopeIcon()),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: currentIndex == entry.key,
                  child: InkWell(
                    onTap: () => onTap(entry.key),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 19, bottom: 7),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (entry.key == 1)
                            AnimatedAppointmentIcon(
                              size: 27,
                              color: currentIndex == entry.key
                                  ? const Color(0xFF207361)
                                  : const Color(0xFF566963),
                            )
                          else
                            Icon(
                              entry.value.$1,
                              size: 27,
                              color: currentIndex == entry.key
                                  ? const Color(0xFF207361)
                                  : const Color(0xFF566963),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            entry.value.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: currentIndex == entry.key
                                  ? const Color(0xFF207361)
                                  : const Color(0xFF566963),
                              fontWeight: currentIndex == entry.key
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _darkBar() => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF0C131D),
      border: Border(top: BorderSide(color: Color(0xFF1B2939))),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            for (final i in [0, 1, 3, 2, 4])
              Expanded(
                child: Semantics(
                  button: true,
                  selected: currentIndex == i,
                  child: Tooltip(
                    message: items[i].$2,
                    child: InkWell(
                      onTap: () => onTap(i),
                      child: Center(
                        child: Text(
                          items[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: currentIndex == i
                                ? const Color(0xFF2BFF9C)
                                : const Color(0xFF70839D),
                            fontSize: 10,
                            fontWeight: currentIndex == i
                                ? FontWeight.w800
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  Widget _tab(int i) {
    final selected = i == currentIndex;
    final color = appointmentStyle || (referenceStyle && currentIndex == 0)
        ? selected
              ? const Color(0xFF207361)
              : const Color(0xFF566963)
        : selected
        ? const Color(0xFF008DFF)
        : const Color(0xFF687D9F);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => onTap(i),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.only(top: referenceStyle ? 8 : 19, bottom: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (i == 1)
                  AnimatedAppointmentIcon(size: 27, color: color)
                else
                  Icon(items[i].$1, color: color, size: 27),
                const SizedBox(height: 4),
                Text(
                  items[i].$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (!referenceStyle && !appointmentStyle)
                  const SizedBox(height: 5),
                if (!referenceStyle && !appointmentStyle)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 25,
                    height: 2,
                    decoration: BoxDecoration(
                      color: selected ? color : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationShape extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(0, 22)
      ..cubicTo(w * .07, -2, w * .16, 0, w * .29, 0)
      ..cubicTo(w * .38, 0, w * .39, 19, w * .5, 19)
      ..cubicTo(w * .61, 19, w * .62, 0, w * .71, 0)
      ..cubicTo(w * .84, 0, w * .93, -2, w, 22)
      ..lineTo(w, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawShadow(path, const Color(0x182563EB), 15, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _NavigationShape oldDelegate) => false;
}
