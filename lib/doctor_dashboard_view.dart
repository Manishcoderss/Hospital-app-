import 'package:flutter/material.dart';

import 'appointment.dart';
import 'clinical_directory.dart';
import 'home_snapshot.dart';
import 'animated_appointment_icon.dart';
import 'animated_waiting_icon.dart';
import 'animated_doctor_icon.dart';
import 'animated_completed_icon.dart';
import 'animated_patients_icon.dart';
import 'animated_prescription_icon.dart';
import 'animated_lab_icon.dart';
import 'animated_ipd_icon.dart';

const _ink = Color(0xFF20312D);
const _green = Color(0xFF207361);
const _muted = Color(0xFF566963);

class DoctorDashboardView extends StatelessWidget {
  const DoctorDashboardView({
    super.key,
    required this.name,
    required this.hospital,
    required this.isDoctor,
    required this.date,
    required this.data,
    required this.loading,
    required this.error,
    required this.unread,
    required this.filter,
    required this.onFilter,
    required this.onRefresh,
    required this.onPickDate,
    required this.onDate,
    required this.onNotifications,
    required this.onVisits,
    required this.onDirectory,
    required this.onAppointment,
    required this.onPatient,
  });
  final String name, hospital, filter;
  final bool isDoctor, loading;
  final DateTime date;
  final HomeSnapshot? data;
  final String? error;
  final int? unread;
  final ValueChanged<String> onFilter, onPatient;
  final Future<void> Function() onRefresh;
  final VoidCallback onPickDate, onNotifications, onVisits;
  final ValueChanged<DateTime> onDate;
  final ValueChanged<ClinicalDirectory> onDirectory;
  final ValueChanged<Appointment> onAppointment;

  @override
  Widget build(BuildContext context) {
    final rows = [...?data?.appointments]
      ..sort((a, b) => a.time.compareTo(b.time));
    final filtered = rows
        .where(
          (a) => switch (filter) {
            'Waiting' => ['scheduled', 'confirmed'].contains(a.status),
            'With doctor' => a.status == 'in_progress',
            'Completed' => a.status == 'completed',
            _ => true,
          },
        )
        .toList();
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: _green,
          secondary: Color(0xFF57A88E),
          surface: Color(0xFFFFFFFF),
          onSurface: _ink,
        ),
      ),
      child: ColoredBox(
        color: const Color(0xFFF7F3EA),
        child: RefreshIndicator(
          onRefresh: onRefresh,
          color: _green,
          child: ListView(
            key: const PageStorageKey('home-dashboard'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 18),
            children: [
              _header(context),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    _surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _title(
                            isDoctor
                                ? "Today's queue (${data?.total ?? '—'})"
                                : 'Hospital queue',
                            onVisits,
                          ),
                          const SizedBox(height: 8),
                          _queueFilters(),
                          if (loading)
                            _empty('Loading schedule…')
                          else if (error != null)
                            _empty('Schedule unavailable')
                          else if (filtered.isEmpty)
                            _queueEmpty()
                          else
                            for (final item in filtered) _queueRow(item),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _dateBar(context),
                    const SizedBox(height: 16),
                    if (loading)
                      const LinearProgressIndicator(
                        color: _green,
                        minHeight: 2,
                      ),
                    if (error != null)
                      _surface(
                        child: Column(
                          children: [
                            const Text(
                              'Dashboard unavailable',
                              style: TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: _muted),
                            ),
                            TextButton(
                              onPressed: onRefresh,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    Column(
                      children: [
                        Row(
                          children: [
                            _metric(
                              'Appointments',
                              data?.total,
                              'All bookings',
                              Icons.calendar_month_outlined,
                              _green,
                            ),
                            const SizedBox(width: 10),
                            _metric(
                              'Waiting',
                              data?.waiting,
                              'Scheduled + confirmed',
                              Icons.schedule,
                              const Color(0xFFBE7E16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _metric(
                              'With doctor',
                              data?.inProgress,
                              'In consultation',
                              Icons.medical_services_outlined,
                              const Color(0xFF7048CE),
                            ),
                            const SizedBox(width: 10),
                            _metric(
                              'Completed',
                              data?.completed,
                              'Visits finished',
                              Icons.task_alt,
                              const Color(0xFF168846),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _surface(
                      child: Column(
                        children: [
                          _title(
                            'Quick access',
                            () => onDirectory(ClinicalDirectory.patients),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _quick(
                                'Patients',
                                Icons.people_outline,
                                _green,
                                ClinicalDirectory.patients,
                              ),
                              _quick(
                                'Prescriptions',
                                Icons.description_outlined,
                                const Color(0xFF57A88E),
                                ClinicalDirectory.prescriptions,
                              ),
                              _quick(
                                'Lab Reports',
                                Icons.science_outlined,
                                const Color(0xFFFFB300),
                                ClinicalDirectory.labs,
                              ),
                              _quick(
                                'Pharmacy',
                                Icons.local_pharmacy_outlined,
                                const Color(0xFF207361),
                                ClinicalDirectory.pharmacy,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _surface(
                      child: Column(
                        children: [
                          _title(
                            'Follow-ups due (${data?.followUpCount ?? '—'})',
                            () => onDirectory(ClinicalDirectory.patients),
                          ),
                          if (data?.weeklyFollowUps == true)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Next 7 days',
                                style: TextStyle(color: _muted, fontSize: 11),
                              ),
                            ),
                          if (loading)
                            _empty('Loading follow-ups…')
                          else if (error != null)
                            _empty('Follow-ups unavailable')
                          else if (data?.followUps.isNotEmpty == true)
                            for (final item in data!.followUps)
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                    color: Color(0xFFE5DDCD),
                                  ),
                                ),
                                tileColor: const Color(0xFFFAF8F2),
                                leading: _avatar(item.name, 19),
                                title: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: _ink,
                                  ),
                                ),
                                subtitle: Text(
                                  item.doctor ?? 'Follow-up due',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: _ink,
                                  size: 19,
                                ),
                                onTap: item.patientId == null
                                    ? null
                                    : () => onPatient(item.patientId!),
                              )
                          else
                            _followUpEmpty(
                              data?.followUpCount == 0
                                  ? 'No follow-ups due'
                                  : 'Open Patients to review follow-up care.',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Open navigation menu',
          onPressed: () => Scaffold.maybeOf(context)?.openDrawer(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _ink,
            side: const BorderSide(color: Color(0xFFE4DBCB)),
            minimumSize: const Size(44, 44),
          ),
          icon: const Icon(Icons.menu),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hospital.isEmpty ? 'Samagati City Hospital' : hospital,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if (!isDoctor)
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Text(
                    'Hospital overview · Admin',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: unread == null
              ? 'Notifications'
              : '$unread unread notifications',
          onPressed: onNotifications,
          icon: Badge(
            isLabelVisible: (unread ?? 0) > 0,
            child: const Icon(
              Icons.notifications_none,
              color: _muted,
              size: 22,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _dateBar(BuildContext context) => _surface(
    padding: 6,
    child: Row(
      children: [
        const SizedBox(width: 7),
        const Icon(Icons.calendar_today_outlined, color: _green, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: loading || isDoctor ? null : onPickDate,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    MaterialLocalizations.of(context).formatMediumDate(date),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more, color: _muted, size: 18),
              ],
            ),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(64, 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: loading
              ? null
              : () => onDate(DateUtils.dateOnly(DateTime.now())),
          child: const Text(
            'Today',
            style: TextStyle(color: _green, fontSize: 12),
          ),
        ),
        SizedBox(
          width: 29,
          child: IconButton(
            tooltip: 'Previous day',
            style: IconButton.styleFrom(backgroundColor: Colors.white),
            padding: EdgeInsets.zero,
            onPressed: loading || isDoctor
                ? null
                : () => onDate(date.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left, size: 22),
          ),
        ),
        SizedBox(
          width: 29,
          child: IconButton(
            tooltip: 'Next day',
            style: IconButton.styleFrom(backgroundColor: Colors.white),
            padding: EdgeInsets.zero,
            onPressed: loading || isDoctor
                ? null
                : () => onDate(date.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right, size: 22),
          ),
        ),
      ],
    ),
  );

  Widget _metric(
    String label,
    int? value,
    String hint,
    IconData icon,
    Color color,
  ) => Expanded(
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: color.withValues(alpha: .12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onVisits,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: label == 'Appointments'
                        ? const ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              _green,
                              BlendMode.srcIn,
                            ),
                            child: AnimatedAppointmentIcon(size: 28),
                          )
                        : label == 'Waiting'
                        ? const AnimatedWaitingIcon()
                        : label == 'With doctor'
                        ? const AnimatedDoctorIcon()
                        : label == 'Completed'
                        ? const ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              _green,
                              BlendMode.srcIn,
                            ),
                            child: AnimatedCompletedIcon(),
                          )
                        : Icon(icon, color: color, size: 21),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value?.toString() ?? '',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                style: const TextStyle(color: _muted, fontSize: 11),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _queueFilters() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
    ),
    child: LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in [
              ('All', 'All', data?.total, _green),
              ('Waiting', 'Waiting', data?.waiting, const Color(0xFFF3A000)),
              ('With doctor', 'In room', data?.inProgress, _green),
              ('Completed', 'Done', data?.completed, const Color(0xFF14A44D)),
            ])
              InkWell(
                key: ValueKey('queue-filter-${entry.$1}'),
                onTap: () => onFilter(entry.$1),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  constraints: BoxConstraints(minWidth: bounds.maxWidth / 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: filter == entry.$1
                        ? const LinearGradient(
                            colors: [Color(0xFF2D8B71), Color(0xFF1C6958)],
                          )
                        : null,
                    boxShadow: filter == entry.$1
                        ? const [
                            BoxShadow(
                              color: Color(0x55207361),
                              blurRadius: 9,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (entry.$1 != 'All') ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: entry.$4,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '${entry.$2} ',
                        style: TextStyle(
                          color: filter == entry.$1 ? Colors.white : _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: filter == entry.$1
                              ? Colors.white24
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entry.$3 ?? '—'}',
                          style: TextStyle(
                            color: filter == entry.$1 ? Colors.white : _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _queueEmpty() => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Color(0xFFC8DAD2),
            shape: BoxShape.circle,
          ),
          child: const CircleAvatar(
            backgroundColor: Color(0xFF207361),
            radius: 27,
            child: Icon(Icons.check_rounded, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                filter == 'All'
                    ? 'All clear for today'
                    : 'No matching appointments',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                filter == 'All'
                    ? 'No appointments for this day'
                    : 'No appointments in this status',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: onVisits,
          style: FilledButton.styleFrom(
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            minimumSize: const Size(0, 38),
          ),
          child: const Text(
            '+ Book',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
  Widget _queueRow(Appointment item) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Material(
      color: const Color(0xFFFFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: _queueColor(item), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onAppointment(item),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 3, color: _queueColor(item)),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.tokenNumber == null ? '' : '#${item.tokenNumber} '}${item.patientName}',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.reason ?? item.department,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.doctorName,
                        style: const TextStyle(color: _muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.time,
                      style: TextStyle(color: _queueColor(item), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.status.replaceAll('_', ' '),
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Color _queueColor(Appointment item) => switch (item.status) {
    'completed' => _green,
    'in_progress' => const Color(0xFF57A88E),
    'cancelled' || 'no_show' => const Color(0xFFFF5078),
    _ => const Color(0xFFFFB300),
  };
  Widget _quick(
    String label,
    IconData icon,
    Color color,
    ClinicalDirectory directory,
  ) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: color.withValues(alpha: .10)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onDirectory(directory),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: .08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: directory == ClinicalDirectory.patients
                      ? const ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            _green,
                            BlendMode.srcIn,
                          ),
                          child: AnimatedPatientsIcon(),
                        )
                      : directory == ClinicalDirectory.prescriptions
                      ? const ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            _green,
                            BlendMode.srcIn,
                          ),
                          child: AnimatedPrescriptionIcon(),
                        )
                      : directory == ClinicalDirectory.labs
                      ? const ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            _green,
                            BlendMode.srcIn,
                          ),
                          child: AnimatedLabIcon(),
                        )
                      : directory == ClinicalDirectory.ipd
                      ? const ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            _green,
                            BlendMode.srcIn,
                          ),
                          child: AnimatedIpdIcon(),
                        )
                      : Icon(icon, color: color, size: 23),
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _followUpEmpty(String text) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 14),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7DFCF)),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          child: const Icon(
            Icons.event_available_outlined,
            color: _green,
            size: 24,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _surface({required Widget child, double padding = 12}) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE3DCCB)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x06207361),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
  Widget _title(String text, VoidCallback action) => Row(
    children: [
      if (text == 'Hospital queue' || text.startsWith("Today's queue")) ...[
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: Color(0xFF16A34A),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
      ],
      Expanded(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      InkWell(
        onTap: action,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 5),
          child: Text(
            'View all ›',
            style: TextStyle(
              fontSize: 11,
              color: _green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );
  Widget _empty(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(text, style: const TextStyle(color: _muted, fontSize: 12)),
  );
  Widget _avatar(String name, double radius) => CircleAvatar(
    radius: radius,
    backgroundColor: const Color(0xFFEDF2E9),
    child: Text(
      name
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .take(2)
          .map((s) => s[0])
          .join()
          .toUpperCase(),
      style: TextStyle(
        fontSize: radius * .55,
        color: _green,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
