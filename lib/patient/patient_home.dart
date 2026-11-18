import 'package:flutter/material.dart';

import '../stethoscope_icon.dart';
import '../soft_bottom_bar.dart';

import 'patient_login.dart' show PatientLoginPage;
import 'patient_mock_data.dart';

const _teal = Color(0xFF207361);
const _ink = Color(0xFF1C2D28);
const _muted = Color(0xFF62766D);
const _background = Color(0xFFFAF7F0);

String _date(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

class _Visit {
  _Visit(
    this.id,
    this.doctor,
    this.specialty,
    this.date,
    this.time,
    this.reason, {
    this.status = 'Upcoming',
  });
  final String id, doctor, specialty, time, reason;
  final DateTime date;
  String status;
}

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key, required this.patient});
  final MockPatient patient;

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _tab = 0;
  String _visitFilter = 'Upcoming';
  String _recordFilter = 'Prescriptions';
  late String _name = widget.patient.name;
  late String _phone = widget.patient.phone;
  late String _email = widget.patient.email;
  bool _readNotifications = false;
  bool _billPaid = false;
  late final List<_Visit> _visits = [
    _Visit(
      'APT-1001',
      'Dr. Lakshmi Iyer',
      'General Medicine',
      DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 2)),
      '10:00 AM',
      'General consultation',
    ),
    _Visit(
      'APT-1000',
      'Dr. Rohan Shah',
      'Cardiology',
      DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 7)),
      '11:30 AM',
      'Routine follow-up',
      status: 'Completed',
    ),
  ];
  static const _doctors = [
    ('Dr. Lakshmi Iyer', 'General Medicine'),
    ('Dr. Rohan Shah', 'Cardiology'),
    ('Dr. Neha Patel', 'Dermatology'),
  ];
  List<_Visit> get _upcoming =>
      _visits.where((v) => v.status == 'Upcoming').toList()..sort((a, b) {
        final day = a.date.compareTo(b.date);
        return day != 0 ? day : _minutes(a.time).compareTo(_minutes(b.time));
      });

  void _open(String title, Widget content) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: _background,
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.all(20), children: [content]),
      ),
    ),
  );

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _logout() async {
    if (!await _confirm('Sign out?', 'Return to patient login?', 'Sign out') ||
        !mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const PatientLoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: _teal),
      scaffoldBackgroundColor: _background,
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? _teal : _muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? _teal : _muted,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
      ),
    ),
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        titleSpacing: 20,
        title: const Text(
          'SAMAGATI CITY HOSPITAL',
          style: TextStyle(
            color: _teal,
            fontSize: 17,
            letterSpacing: .6,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _notifications,
            icon: Badge(
              isLabelVisible: !_readNotifications,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: _background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.patient.patientId,
                      style: const TextStyle(color: _muted),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Patient portal · Demo',
                      style: TextStyle(color: _teal),
                    ),
                  ],
                ),
              ),
              for (final entry in [
                (0, 'Home', Icons.home_outlined),
                (1, 'Appointments', Icons.calendar_month_outlined),
                (2, 'Health records', Icons.folder_outlined),
                (3, 'Profile', Icons.person_outline),
              ])
                ListTile(
                  leading: Icon(entry.$3),
                  title: Text(entry.$2),
                  selected: _tab == entry.$1,
                  selectedColor: _teal,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _tab = entry.$1);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Bills & payments'),
                onTap: () {
                  Navigator.pop(context);
                  _bills();
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        key: ValueKey(_tab),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (_tab == 0) ..._home(),
          if (_tab == 1) ..._appointments(),
          if (_tab == 2) ..._records(),
          if (_tab == 3) ..._profile(),
        ],
      ),
      bottomNavigationBar: SoftBottomBar(
        patientStyle: true,
        onCenterTap: _book,
        currentIndex: _tab,
        onTap: (value) => setState(() => _tab = value),
      ),
    ),
  );

  List<Widget> _home() => [
    const SizedBox(height: 16),
    Text(
      _name,
      style: const TextStyle(
        color: _ink,
        fontSize: 36,
        height: 1.15,
        letterSpacing: -.9,
        fontWeight: FontWeight.w800,
      ),
    ),
    const SizedBox(height: 10),
    Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEFE9D9),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          'Patient ID: ${widget.patient.patientId}',
          style: const TextStyle(
            color: _muted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
    const Padding(
      padding: EdgeInsets.only(top: 20, bottom: 12),
      child: Divider(color: Color(0xFFE5DECD)),
    ),
    _heading(
      'Your next visit',
      action: 'View all ›',
      onTap: () => setState(() => _tab = 1),
    ),
    if (_upcoming.isNotEmpty)
      _homeTimeline(_upcoming.first)
    else
      _card(
        const Text(
          'No upcoming visits. Book a consultation when you need one.',
        ),
      ),
    const SizedBox(height: 12),
    SizedBox(
      height: 58,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          foregroundColor: _background,
          shape: const StadiumBorder(),
        ),
        onPressed: _book,
        icon: const Icon(Icons.add, size: 23),
        label: const Text(
          'Book appointment',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    ),
    const SizedBox(height: 76),
    const Text(
      'Demo records · Changes reset when you sign out.',
      textAlign: TextAlign.center,
      style: TextStyle(color: _muted, fontSize: 12),
    ),
  ];

  Widget _homeTimeline(_Visit visit) {
    final days = DateUtils.dateOnly(visit.date)
        .difference(DateUtils.dateOnly(DateTime.now()))
        .inDays;
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Stack(
      children: [
        Positioned(
          left: 12,
          top: 17,
          bottom: 34,
          child: Container(width: 2, color: const Color(0xFFDAD5C3)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: const BoxDecoration(
                    color: _teal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Appointment booked',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${visit.id} · ${visit.status}',
                        style: const TextStyle(color: _muted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: const BoxDecoration(
                    color: Color(0xFF30977D),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(color: const Color(0xFFE4DAC6)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0C3F4833),
                          blurRadius: 22,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${weekdays[visit.date.weekday - 1]}, ${_date(visit.date).toUpperCase()}',
                                    style: const TextStyle(
                                      color: _teal,
                                      fontSize: 13,
                                      letterSpacing: .5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      visit.time,
                                      style: const TextStyle(
                                        color: _ink,
                                        fontSize: 29,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 61,
                              height: 61,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: 1,
                                      strokeWidth: 6,
                                      color: Color(0xFFE8E1CE),
                                    ),
                                  ),
                                  SizedBox.expand(
                                    child: CircularProgressIndicator(
                                      value: (1 - days.clamp(0, 7) / 7).clamp(
                                        .08,
                                        1,
                                      ),
                                      strokeWidth: 6,
                                      color: _teal,
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        days <= 0 ? 'Today' : '$days',
                                        style: TextStyle(
                                          color: _ink,
                                          fontSize: days <= 0 ? 12 : 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (days > 0)
                                        Text(
                                          days == 1 ? 'day' : 'days',
                                          style: const TextStyle(
                                            color: _muted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2F9E85), _teal],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: StethoscopeIcon(size: 28),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    visit.doctor,
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    visit.specialty,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          visit.reason,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final buttons = [
                              OutlinedButton(
                                onPressed: () => _book(replace: visit),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _teal,
                                  side: const BorderSide(
                                    color: _teal,
                                    width: 1.3,
                                  ),
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                child: const Text(
                                  'Reschedule',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              FilledButton(
                                onPressed: () => _cancelVisit(visit),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFF6E7E3),
                                  foregroundColor: const Color(0xFFB9422D),
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                child: const Text(
                                  'Cancel visit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ];
                            if (constraints.maxWidth < 230) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buttons.first,
                                  const SizedBox(height: 8),
                                  buttons.last,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: buttons.first),
                                const SizedBox(width: 8),
                                Expanded(child: buttons.last),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0ECDC),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC6BEA4)),
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 18,
                    color: Color(0xFF90A39A),
                  ),
                ),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'After your visit',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Prescriptions and reports will appear here.',
                        style: TextStyle(
                          color: Color(0xFF7C8E85),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _cancelVisit(_Visit visit) async {
    if (!await _confirm(
          'Cancel appointment?',
          '${visit.doctor}\n${_date(visit.date)} · ${visit.time}',
          'Cancel visit',
        ) ||
        !mounted) {
      return;
    }
    setState(() => visit.status = 'Cancelled');
  }

  List<Widget> _appointments() => [
    _heading('My appointments'),
    FilledButton.icon(
      onPressed: _book,
      icon: const Icon(Icons.add),
      label: const Text('Book appointment'),
    ),
    const SizedBox(height: 14),
    Wrap(
      spacing: 8,
      children: [
        for (final filter in ['Upcoming', 'Completed', 'Cancelled'])
          ChoiceChip(
            label: Text(filter),
            selected: _visitFilter == filter,
            onSelected: (_) => setState(() => _visitFilter = filter),
          ),
      ],
    ),
    const SizedBox(height: 14),
    if (_visits.every((v) => v.status != _visitFilter))
      _card(Text('No ${_visitFilter.toLowerCase()} appointments.')),
    for (final visit
        in (_visitFilter == 'Upcoming'
            ? _upcoming
            : _visits.where((v) => v.status == _visitFilter)))
      _visitCard(visit),
  ];

  Widget _visitCard(_Visit visit) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month_outlined, color: _teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_date(visit.date)} · ${visit.time}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          visit.doctor,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(visit.specialty, style: const TextStyle(color: _muted)),
        const SizedBox(height: 12),
        Text(visit.reason),
        const SizedBox(height: 8),
        Text(
          '${visit.id} · ${visit.status}',
          style: const TextStyle(color: _teal, fontSize: 12),
        ),
        if (visit.status == 'Upcoming') ...[
          const Divider(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              OutlinedButton(
                onPressed: () => _book(replace: visit),
                child: const Text('Reschedule'),
              ),
              TextButton(
                onPressed: () async {
                  if (!await _confirm(
                        'Cancel appointment?',
                        '${visit.doctor}\n${_date(visit.date)} · ${visit.time}',
                        'Cancel visit',
                      ) ||
                      !mounted) {
                    return;
                  }
                  setState(() => visit.status = 'Cancelled');
                },
                child: const Text('Cancel visit'),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  Future<void> _book({_Visit? replace}) async {
    final result = await Navigator.of(context).push<_Visit>(
      MaterialPageRoute(
        builder: (_) => _BookingPage(
          doctors: _doctors,
          visits: _visits,
          previous: replace,
          nextId: 'APT-${1001 + _visits.length}',
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (replace != null) _visits.remove(replace);
      _visits.insert(0, result);
      _visitFilter = 'Upcoming';
      _tab = 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          replace == null
              ? 'Demo appointment booked.'
              : 'Demo appointment rescheduled.',
        ),
      ),
    );
  }

  List<Widget> _records() => [
    _heading('Health records'),
    const Text(
      'Your prescriptions and reports in one place.',
      style: TextStyle(color: _muted),
    ),
    const SizedBox(height: 16),
    Wrap(
      spacing: 8,
      children: [
        for (final label in ['Prescriptions', 'Reports'])
          ChoiceChip(
            label: Text(label),
            selected: _recordFilter == label,
            onSelected: (_) => setState(() => _recordFilter = label),
          ),
      ],
    ),
    const SizedBox(height: 16),
    if (_recordFilter == 'Prescriptions')
      _recordTile(
        'Consultation prescription',
        'Dr. Rohan Shah · Issued',
        Icons.description_outlined,
        _prescription,
      )
    else
      _recordTile(
        'Laboratory report',
        'Complete blood count · Available',
        Icons.science_outlined,
        _report,
      ),
  ];

  void _prescription() => _open(
    'Prescription',
    _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Consultation summary'),
          _detail('Patient', _name),
          _detail('Patient ID', widget.patient.patientId),
          _detail('Doctor', 'Dr. Rohan Shah'),
          _detail('Status', 'Issued'),
          const Divider(height: 28),
          const Text(
            'Sample prescription',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 10),
          const Text(
            'This fictional record demonstrates the prescription screen. Medicine names, doses and clinical advice will come from your doctor when connected to the backend.',
            style: TextStyle(height: 1.6, color: _muted),
          ),
          const SizedBox(height: 16),
          _detail('Medicines', 'No medicines in this demo record'),
          _detail('Follow-up', 'Discuss at your next consultation'),
        ],
      ),
    ),
  );

  void _report() => _open(
    'Laboratory report',
    _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Complete blood count'),
          _detail('Patient', _name),
          _detail('Patient ID', widget.patient.patientId),
          _detail('Order', 'LAB-1001'),
          _detail('Status', 'Reported'),
          const Divider(height: 28),
          const Text(
            'Illustrative results',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          _detail('Haemoglobin', '13.5 g/dL'),
          _detail('White blood cells', '7,200 /µL'),
          _detail('Platelets', '250,000 /µL'),
          const SizedBox(height: 12),
          const Text(
            'Fictional sample data. This is not a clinical report or a diagnosis.',
            style: TextStyle(color: _muted, height: 1.5),
          ),
        ],
      ),
    ),
  );

  Future<void> _bills() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StatefulBuilder(
          builder: (context, update) => Scaffold(
            backgroundColor: _background,
            appBar: AppBar(title: const Text('Bills & payments')),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _heading('Consultation bill'),
                      _detail('Invoice', 'INV-1001'),
                      _detail('Patient', _name),
                      _detail('Consultation', '₹500'),
                      _detail('Total', '₹500'),
                      _detail('Status', _billPaid ? 'Paid · Demo' : 'Unpaid'),
                      const SizedBox(height: 16),
                      if (!_billPaid)
                        FilledButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Simulate payment?'),
                                content: const Text(
                                  'This demo marks the bill as paid. No money will be charged.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Back'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Simulate payment'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && context.mounted) {
                              update(() => _billPaid = true);
                            }
                          },
                          child: const Text('Simulate payment'),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Demo invoice · No real payment processing.',
                        style: TextStyle(color: _muted, fontSize: 12),
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
    if (mounted) setState(() {});
  }

  List<Widget> _profile() => [
    _heading('My profile'),
    _card(
      Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFE2F5F4),
            child: Text(
              _name.isEmpty ? 'P' : _name[0],
              style: const TextStyle(fontSize: 28, color: _teal),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(widget.patient.patientId, style: const TextStyle(color: _muted)),
          const Divider(height: 32),
          _detail('Mobile', _phone),
          _detail('Email', _email),
          _detail('Hospital', 'Samagati City Hospital'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit demo profile'),
          ),
        ],
      ),
    ),
    _recordTile(
      'Bills & payments',
      'View your demo consultation bill',
      Icons.receipt_long_outlined,
      _bills,
    ),
    _recordTile(
      'Help & support',
      'Patient portal information',
      Icons.help_outline,
      () => _open(
        'Help & support',
        _card(
          const Text(
            'This patient portal uses mock data. Booking, payments and account changes are simulated. For hospital support, use the contact information provided by your hospital.',
            style: TextStyle(height: 1.6),
          ),
        ),
      ),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: _logout,
      icon: const Icon(Icons.logout),
      label: const Text('Sign out'),
    ),
  ];

  Future<void> _editProfile() async {
    final form = GlobalKey<FormState>();
    var name = _name, phone = _phone, email = _email;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit demo profile'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  onChanged: (v) => name = v,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile'),
                  onChanged: (v) => phone = v,
                  validator: (v) =>
                      !RegExp(r'^\d{10}$').hasMatch(v?.trim() ?? '')
                      ? 'Enter a 10-digit mobile'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  onChanged: (v) => email = v,
                  validator: (v) =>
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(v?.trim() ?? '')
                      ? 'Enter a valid email'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _name = name.trim();
        _phone = phone.trim();
        _email = email.trim();
      });
    }
  }

  void _notifications() {
    setState(() => _readNotifications = true);
    _open(
      'Notifications',
      Column(
        children: [
          _card(
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.science_outlined, color: _teal),
              title: const Text('Your demo report is ready'),
              subtitle: const Text('Open laboratory report'),
              onTap: _report,
            ),
          ),
          if (_upcoming.isNotEmpty)
            _card(
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.calendar_month_outlined,
                  color: _teal,
                ),
                title: const Text('Upcoming appointment'),
                subtitle: Text(
                  '${_upcoming.first.doctor}\n${_date(_upcoming.first.date)} · ${_upcoming.first.time}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _heading(String text, {String? action, VoidCallback? onTap}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            if (action != null)
              TextButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      );

  Widget _recordTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback tap,
  ) => _card(
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _teal),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: tap,
    ),
  );

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(color: _muted)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Text(value, style: const TextStyle(color: _ink)),
        ),
      ],
    ),
  );
}

int _minutes(String time) {
  final parts = time.split(RegExp(r'[: ]'));
  return (int.parse(parts[0]) % 12 + (parts[2] == 'PM' ? 12 : 0)) * 60 +
      int.parse(parts[1]);
}

Widget _card(Widget child, {bool margin = true}) => Padding(
  padding: EdgeInsets.only(bottom: margin ? 12 : 0),
  child: Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFE0E8EC)),
    ),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: double.infinity,
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    ),
  ),
);

class _BookingPage extends StatefulWidget {
  const _BookingPage({
    required this.doctors,
    required this.visits,
    required this.nextId,
    this.previous,
  });
  final List<(String, String)> doctors;
  final List<_Visit> visits;
  final String nextId;
  final _Visit? previous;
  @override
  State<_BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<_BookingPage> {
  final _form = GlobalKey<FormState>();
  late String _doctor = widget.previous?.doctor ?? widget.doctors.first.$1;
  late DateTime _day =
      widget.previous?.date ??
      DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
  late String? _time = widget.previous?.time;
  late String _reason = widget.previous?.reason ?? '';
  static const _slots = [
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '02:00 PM',
    '02:30 PM',
  ];
  bool _taken(String time) => widget.visits.any(
    (v) =>
        v != widget.previous &&
        v.status == 'Upcoming' &&
        v.doctor == _doctor &&
        DateUtils.isSameDay(v.date, _day) &&
        v.time == time,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: AppBar(
      title: Text(
        widget.previous == null ? 'Book appointment' : 'Reschedule appointment',
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose your doctor and an available time.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 20),
          _card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _doctor,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Doctor'),
                  items: [
                    for (final doctor in widget.doctors)
                      DropdownMenuItem(
                        value: doctor.$1,
                        child: Text(
                          '${doctor.$1} · ${doctor.$2}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _doctor = v;
                        _time = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateUtils.dateOnly(DateTime.now());
                    final day = await showDatePicker(
                      context: context,
                      initialDate: _day.isBefore(now) ? now : _day,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 90)),
                    );
                    if (day != null && mounted) {
                      setState(() {
                        _day = day;
                        _time = null;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(_date(_day)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Available times',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (final time in _slots)
                ChoiceChip(
                  label: Text(time),
                  selected: _time == time,
                  onSelected: _taken(time)
                      ? null
                      : (_) => setState(() => _time = time),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason for visit'),
            maxLines: 3,
            onChanged: (v) => _reason = v,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Enter a reason for your visit'
                : null,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _time == null
                ? null
                : () {
                    if (!_form.currentState!.validate()) return;
                    if (_taken(_time!)) {
                      setState(() => _time = null);
                      return;
                    }
                    final specialty = widget.doctors
                        .firstWhere((d) => d.$1 == _doctor)
                        .$2;
                    Navigator.pop(
                      context,
                      _Visit(
                        widget.previous?.id ?? widget.nextId,
                        _doctor,
                        specialty,
                        _day,
                        _time!,
                        _reason.trim(),
                      ),
                    );
                  },
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              widget.previous == null
                  ? 'Confirm demo booking'
                  : 'Confirm reschedule',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mock availability. No real appointment will be created.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
