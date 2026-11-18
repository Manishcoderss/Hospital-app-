import 'package:flutter/material.dart';

import 'appointment.dart';
import 'appointment_page.dart';
import 'doctor_opd_view.dart';

const appointmentCream = Color(0xFFF7F3EA);
const _green = Color(0xFF207361);
const _ink = Color(0xFF20312D);
const _muted = Color(0xFF566963);

class AppointmentsScheduleView extends StatelessWidget {
  const AppointmentsScheduleView({
    super.key,
    required this.isAdmin,
    required this.isDoctor,
    required this.date,
    required this.dateLabel,
    required this.page,
    required this.pageNumber,
    required this.status,
    required this.busy,
    required this.ready,
    required this.onRefresh,
    required this.onDate,
    required this.onPickDate,
    required this.onStatus,
    required this.onPage,
    required this.appointmentBuilder,
    required this.onAppointment,
    required this.onBook,
    required this.state,
    this.doctorRows,
    this.sort = 'time',
    this.ascending = true,
    this.onSort,
  });

  final bool isAdmin, isDoctor, busy, ready;
  final DateTime date;
  final String dateLabel;
  final AppointmentPage? page;
  final int pageNumber;
  final String? status;
  final Future<void> Function() onRefresh;
  final ValueChanged<DateTime> onDate;
  final VoidCallback onPickDate;
  final ValueChanged<String?> onStatus;
  final ValueChanged<int> onPage;
  final Widget Function(Appointment) appointmentBuilder;
  final ValueChanged<Appointment> onAppointment;
  final VoidCallback onBook;
  final Widget state;
  final List<Appointment>? doctorRows;
  final String sort;
  final bool ascending;
  final ValueChanged<String>? onSort;

  @override
  Widget build(BuildContext context) {
    final rows = [...?page?.items];
    if (!isDoctor) rows.sort((a, b) => a.time.compareTo(b.time));
    if (isDoctor) {
      return DoctorOpdView(
        dateLabel: dateLabel,
        rows: rows,
        allRows: doctorRows,
        status: status,
        ready: ready,
        busy: busy,
        state: state,
        onRefresh: onRefresh,
        onStatus: onStatus,
        onAppointment: onAppointment,
        onBook: onBook,
        date: date,
        onDate: onDate,
        onPickDate: onPickDate,
        pageNumber: pageNumber,
        totalItems: page?.totalItems ?? 0,
        hasNext: page?.hasNext ?? false,
        onPage: onPage,
        sort: sort,
        ascending: ascending,
        onSort: onSort,
      );
    }
    return ColoredBox(
      color: appointmentCream,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: _green,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Text(
              isAdmin ? 'ADMIN · HOSPITAL-WIDE' : 'DOCTOR · PERSONAL SCHEDULE',
              style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDoctor ? 'My Appointments' : 'Appointments',
                        style: TextStyle(
                          color: _ink,
                          fontSize: isDoctor ? 26 : 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.8,
                        ),
                      ),
                      InkWell(
                        onTap: isAdmin && !busy ? onPickDate : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            '$dateLabel · ${ready ? '${page!.totalItems} booked' : '— booked'}',
                            style: const TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  _dateButton(
                    Icons.chevron_left,
                    'Previous day',
                    false,
                    () => onDate(date.subtract(const Duration(days: 1))),
                  ),
                  const SizedBox(width: 6),
                  _dateButton(
                    Icons.chevron_right,
                    'Next day',
                    true,
                    () => onDate(date.add(const Duration(days: 1))),
                  ),
                ],
              ],
            ),
            if (isAdmin)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: busy ? null : onPickDate,
                  style: TextButton.styleFrom(
                    foregroundColor: _green,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Change date'),
                ),
              ),
            const SizedBox(height: 8),
            if (isAdmin || isDoctor)
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final entry in const [
                      ('all', 'All statuses', Colors.white),
                      ('scheduled', 'Scheduled', Color(0xFF9258FF)),
                      ('confirmed', 'Confirmed', Color(0xFF349BFF)),
                      ('in_progress', 'With doctor', Color(0xFFE5A03C)),
                      ('completed', 'Completed', _green),
                      ('cancelled', 'Cancelled', Color(0xFFED4751)),
                      ('no_show', 'No-show', _muted),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: (status ?? 'all') == entry.$1,
                          showCheckmark: false,
                          avatar: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (status ?? 'all') == entry.$1
                                  ? Colors.white
                                  : entry.$1 == 'all'
                                  ? _green
                                  : entry.$3,
                            ),
                          ),
                          label: Text(entry.$2),
                          labelStyle: TextStyle(
                            color: (status ?? 'all') == entry.$1
                                ? Colors.white
                                : _ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          selectedColor: _green,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: (status ?? 'all') == entry.$1
                                ? _green
                                : const Color(0xFFE4DBCB),
                          ),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          onSelected: busy
                              ? null
                              : (_) => onStatus(
                                  entry.$1 == 'all' ? null : entry.$1,
                                ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (!ready)
              state
            else ...[
              if (rows.isEmpty && status != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No ${status!.replaceAll('_', ' ')} appointments for $dateLabel.',
                    style: const TextStyle(color: _muted),
                  ),
                ),
              if (page!.isEmpty && status == null)
                for (final hour in [9, 10, 11, 12, 13]) _emptyHour(hour),
              for (final item in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 54,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: Text(
                            item.time,
                            style: const TextStyle(
                              color: _muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      Expanded(child: appointmentBuilder(item)),
                    ],
                  ),
                ),
              if (isAdmin) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE4DBCB)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: pageNumber > 1
                            ? () => onPage(pageNumber - 1)
                            : null,
                        style: TextButton.styleFrom(
                          foregroundColor: _green,
                          backgroundColor: appointmentCream,
                        ),
                        child: const Text('Previous'),
                      ),
                      Text(
                        'Page $pageNumber of ${(page!.totalItems / 10).ceil().clamp(1, 999999)}',
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: page!.hasNext
                            ? () => onPage(pageNumber + 1)
                            : null,
                        style: TextButton.styleFrom(
                          foregroundColor: _green,
                          backgroundColor: appointmentCream,
                        ),
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _dateButton(
    IconData icon,
    String label,
    bool filled,
    VoidCallback action,
  ) => IconButton(
    tooltip: label,
    onPressed: busy ? null : action,
    style: IconButton.styleFrom(
      backgroundColor: filled ? _green : Colors.white,
      foregroundColor: filled ? Colors.white : _ink,
      side: BorderSide(color: filled ? _green : const Color(0xFFE4DBCB)),
    ),
    icon: Icon(icon),
  );

  // Empty hours are a visual guide, not backend-confirmed booking availability.
  Widget _emptyHour(int hour) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          child: Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              '${hour > 12 ? hour - 12 : hour}:00',
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
        Expanded(
          child: CustomPaint(
            painter: _DashedOutline(),
            child: SizedBox(
              height: 62,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Free slot',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      width: 31,
                      height: 31,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE3EFE8),
                      ),
                      child: const Icon(Icons.add, color: _green, size: 21),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DashedOutline extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(17)),
      );
    final paint = Paint()
      ..color = const Color(0xFFCCC5B3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += 7) {
        canvas.drawPath(metric.extractPath(offset, offset + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
