import 'package:flutter/material.dart';

import 'appointment.dart';

const _cream = Color(0xFFF7F3EA);
const _green = Color(0xFF207361);
const _ink = Color(0xFF20312D);
const _muted = Color(0xFF566963);

class DoctorOpdView extends StatelessWidget {
  const DoctorOpdView({
    super.key,
    required this.dateLabel,
    required this.rows,
    required this.status,
    required this.ready,
    required this.busy,
    required this.state,
    required this.onRefresh,
    required this.onStatus,
    required this.onAppointment,
    required this.onBook,
    this.allRows,
    required this.date,
    required this.onDate,
    required this.onPickDate,
    required this.pageNumber,
    required this.totalItems,
    required this.hasNext,
    required this.onPage,
    this.sort = 'time',
    this.ascending = true,
    this.onSort,
  });
  final String dateLabel;
  final List<Appointment> rows;
  final List<Appointment>? allRows;
  final String? status;
  final bool ready, busy;
  final Widget state;
  final Future<void> Function() onRefresh;
  final ValueChanged<String?> onStatus;
  final ValueChanged<Appointment> onAppointment;
  final VoidCallback onBook;
  final DateTime date;
  final ValueChanged<DateTime> onDate;
  final VoidCallback onPickDate;
  final int pageNumber, totalItems;
  final bool hasNext;
  final ValueChanged<int> onPage;
  final String sort;
  final bool ascending;
  final ValueChanged<String>? onSort;

  @override
  Widget build(BuildContext context) {
    final source = allRows ?? rows;
    int count(String key) => source
        .where(
          (a) =>
              key == 'all' ||
              (key == 'waiting'
                  ? a.status == 'scheduled'
                  : key == 'checked_in'
                  ? a.status == 'confirmed'
                  : a.status == key),
        )
        .length;
    final active = source
        .where(
          (a) => [
            'scheduled',
            'confirmed',
            'checked_in',
            'in_progress',
          ].contains(a.status),
        )
        .length;
    return ColoredBox(
      color: _cream,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: _green,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
          children: [
            Text(
              DateUtils.isSameDay(date, DateTime.now())
                  ? 'TODAY'
                  : 'SELECTED DATE',
              style: const TextStyle(
                color: _green,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: busy ? null : onPickDate,
                    child: Text(
                      dateLabel,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.8,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Previous day',
                  onPressed: busy
                      ? null
                      : () => onDate(date.subtract(const Duration(days: 1))),
                  icon: const Icon(Icons.chevron_left),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _green,
                  ),
                ),
                IconButton(
                  tooltip: 'Next day',
                  onPressed: busy
                      ? null
                      : () => onDate(date.add(const Duration(days: 1))),
                  icon: const Icon(Icons.chevron_right),
                  style: IconButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              ready
                  ? '$totalItems appointments · $active active · ${count('completed')} done on this page'
                  : busy
                  ? 'Loading your schedule'
                  : 'Schedule unavailable',
              style: const TextStyle(
                color: _muted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: busy ? null : onPickDate,
                style: TextButton.styleFrom(foregroundColor: _green),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Choose date'),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in const [
                    ('all', 'All', Colors.white),
                    ('waiting', 'Waiting', Color(0xFFF4A000)),
                    ('checked_in', 'Checked in', Color(0xFF349BFF)),
                    ('in_progress', 'With doctor', Color(0xFF5CCCB7)),
                    ('completed', 'Done', _green),
                    ('cancelled', 'Cancelled', Color(0xFFED4751)),
                    ('no_show', 'No-show', _muted),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: (status ?? 'all') == f.$1,
                        showCheckmark: false,
                        label: Text('${f.$2}${ready ? ' ${count(f.$1)}' : ''}'),
                        avatar: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (status ?? 'all') == f.$1
                                ? Colors.white
                                : f.$1 == 'all'
                                ? _green
                                : f.$3,
                          ),
                        ),
                        labelStyle: TextStyle(
                          color: (status ?? 'all') == f.$1
                              ? Colors.white
                              : _ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        selectedColor: _green,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: (status ?? 'all') == f.$1
                              ? _green
                              : const Color(0xFFE4DBCB),
                        ),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        onSelected: busy
                            ? null
                            : (_) => onStatus(f.$1 == 'all' ? null : f.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4DBCB)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final column in const [
                    ('token', 'TOKEN'),
                    ('time', 'TIME'),
                    ('patient', 'PATIENT'),
                    ('reason', 'REASON'),
                    ('status', 'STATUS'),
                  ])
                    Semantics(
                      button: true,
                      selected: sort == column.$1,
                      child: TextButton(
                        onPressed: busy || onSort == null
                            ? null
                            : () => onSort!(column.$1),
                        style: TextButton.styleFrom(
                          foregroundColor: sort == column.$1 ? _green : _muted,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 40),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              column.$2,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              sort == column.$1
                                  ? ascending
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward
                                  : Icons.unfold_more,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!ready) state else for (final item in rows) _timeline(item),
          ],
        ),
      ),
    );
  }

  Widget _timeline(Appointment item) {
    final current = item.status == 'in_progress';
    final checked = item.status == 'confirmed';
    final waiting = item.status == 'scheduled';
    final accent = checked
        ? const Color(0xFF096783)
        : waiting
        ? const Color(0xFF946200)
        : _green;
    final tint = checked
        ? const Color(0xFFDEF0F7)
        : waiting
        ? const Color(0xFFFFF0CE)
        : const Color(0xFFE4EFE8);
    final label = switch (item.status) {
      'in_progress' => 'With doctor',
      'confirmed' => 'Checked in',
      'completed' => 'Done',
      'cancelled' => 'Cancelled',
      'no_show' => 'No-show',
      _ => 'Waiting',
    };
    final initials = item.patientName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join()
        .toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 43,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  item.time,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 24,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 22,
                    bottom: -10,
                    child: Container(width: 2, color: const Color(0xFFD8D2BF)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 17),
                    child: Container(
                      width: current ? 15 : 11,
                      height: current ? 15 : 11,
                      decoration: BoxDecoration(
                        color: current ? _green : _cream,
                        borderRadius: BorderRadius.circular(current ? 5 : 20),
                        border: Border.all(
                          color: current ? _green : const Color(0xFFCCC5B3),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Material(
                color: current ? const Color(0xFF104C3F) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(21),
                  side: BorderSide(
                    color: current
                        ? const Color(0xFF104C3F)
                        : const Color(0xFFE4DBCB),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onAppointment(item),
                  child: Container(
                    decoration: current
                        ? const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_green, Color(0xFF0C3D32)],
                            ),
                          )
                        : null,
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (current) ...[
                          const Text(
                            'NOW · WITH DOCTOR',
                            style: TextStyle(
                              color: Color(0xFFA6E4D3),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .7,
                            ),
                          ),
                          const SizedBox(height: 9),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!current) ...[
                              Container(
                                width: 40,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: tint,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.patientName,
                                    style: TextStyle(
                                      color: current ? Colors.white : _ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.reason ??
                                        item.symptoms ??
                                        'Reason not recorded',
                                    style: TextStyle(
                                      color: current
                                          ? const Color(0xFFD5EBE3)
                                          : _muted,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (!current)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: tint,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            Text(
                              '${item.tokenNumber == null ? '' : 'Token ${item.tokenNumber} · '}Time ${item.time}',
                              style: TextStyle(
                                color: current ? Colors.white70 : _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                current
                                    ? 'Next: review consultation'
                                    : checked
                                    ? 'Next: review patient'
                                    : waiting
                                    ? 'Next: review arrival'
                                    : 'View visit record',
                                style: TextStyle(
                                  color: current
                                      ? const Color(0xFFD5EBE3)
                                      : _muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            FilledButton(
                              onPressed: () => onAppointment(item),
                              style: FilledButton.styleFrom(
                                backgroundColor: current
                                    ? _cream
                                    : const Color(0xFF0D4438),
                                foregroundColor: current
                                    ? const Color(0xFF0D4438)
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                minimumSize: const Size(0, 34),
                              ),
                              child: const Text(
                                'View details',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
