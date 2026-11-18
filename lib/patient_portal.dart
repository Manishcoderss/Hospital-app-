import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'hospital_api.dart';
import 'hospital_theme.dart';
import 'hospital_modules.dart';
import 'api_catalog.dart';
import 'appointment_booking_page.dart';

class PatientPortal extends StatefulWidget {
  const PatientPortal({
    super.key,
    required this.session,
    required this.onSignOut,
    this.api,
  });
  final AuthSession session;
  final VoidCallback onSignOut;
  final HospitalApi? api;
  @override
  State<PatientPortal> createState() => _PatientPortalState();
}

class _PatientPortalState extends State<PatientPortal> {
  late final api = widget.api ?? HospitalApi(widget.session);
  Map<String, dynamic>? patient;
  String? patientId, error;
  bool loading = true;
  bool cancelling = false, cancelUncertain = false;
  int tab = 0;
  List<Map<String, dynamic>> visits = [];
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    if (widget.api == null) api.close();
    super.dispose();
  }

  Future<void> load() async {
    cancelling = false;
    cancelUncertain = false;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final me = await api.get('/auth/me');
      if (me is! Map<String, dynamic>) {
        throw const HospitalApiException(
          'Your patient profile could not be read.',
        );
      }
      final own = me['patient'];
      final id = me['patient_id'] ?? (own is Map ? own['id'] : null);
      if (id is! String || id.isEmpty) {
        throw const HospitalApiException(
          'Your login is not linked to a patient profile. Ask the hospital to link your account.',
        );
      }
      final profile = own is Map<String, dynamic>
          ? own
          : await api.get('/patients/${Uri.encodeComponent(id)}');
      if (profile is! Map<String, dynamic>) {
        throw const HospitalApiException(
          'Your patient profile could not be read.',
        );
      }
      final rows = HospitalApi.rows(
        await api.get('/patients/${Uri.encodeComponent(id)}/appointments'),
      );
      if (mounted) {
        setState(() {
          patientId = id;
          patient = profile;
          visits = [...rows]
            ..sort(
              (
                a,
                b,
              ) => ('${a['appointment_date'] ?? a['date'] ?? ''} ${a['appointment_time'] ?? a['time'] ?? ''}')
                  .compareTo(
                    '${b['appointment_date'] ?? b['date'] ?? ''} ${b['appointment_time'] ?? b['time'] ?? ''}',
                  ),
            );
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> book() async {
    if (patientId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AppointmentBookingPage(
          session: widget.session,
          patientId: patientId,
        ),
      ),
    );
    if (mounted) load();
  }

  void resource(String title, String suffix) {
    if (patientId == null) return;
    final op = hospitalOperations.firstWhere(
      (o) =>
          o['method'] == 'GET' &&
          o['path'] == '/patients/{{patient_id}}/$suffix',
    );
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HospitalOperationPage(
          api: api,
          operation: op,
          initialParameters: {'patient_id': patientId!},
        ),
      ),
    );
  }

  Widget card(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: child),
  );
  Widget heading(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 24, 0, 14),
    child: Text(
      t,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final name = patient?['full_name']?.toString() ?? widget.session.name;
    return Theme(
      data: HospitalTheme.data,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'samagati',
            style: TextStyle(
              color: HospitalTheme.blue,
              fontWeight: FontWeight.w800,
              letterSpacing: -.7,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      HospitalModulePage(api: api, group: 'Notifications'),
                ),
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
            children: [
              if (loading) const LinearProgressIndicator(),
              if (error != null) ...[
                card(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unable to load your care space',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(error!),
                      TextButton(
                        onPressed: load,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ],
              if (tab == 0) ...[
                Text(
                  'Hi, ${name.split(' ').first}',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'How can we help you today?',
                  style: TextStyle(color: HospitalTheme.muted),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(23),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFDDEAFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 17,
                            color: HospitalTheme.blue,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Here for your health',
                            style: TextStyle(color: HospitalTheme.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'Good care, made simple.',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF183D73),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 11),
                      const Text(
                        'Book a visit and keep your health records together.',
                        style: TextStyle(color: Color(0xFF617B9B)),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: patientId == null ? null : book,
                        icon: const Icon(Icons.add),
                        label: const Text('Book appointment'),
                      ),
                    ],
                  ),
                ),
                heading('What do you need?'),
                LayoutBuilder(
                  builder: (c, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in [
                        (
                          Icons.medical_services_outlined,
                          'Find a doctor',
                          'doctors',
                        ),
                        (
                          Icons.calendar_month_outlined,
                          'My visits',
                          'appointments',
                        ),
                        (
                          Icons.description_outlined,
                          'Health records',
                          'records',
                        ),
                        (
                          Icons.account_balance_wallet_outlined,
                          'Bills & payments',
                          'bills',
                        ),
                      ])
                        SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (item.$3 == 'doctors') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => HospitalModulePage(
                                        api: api,
                                        group: 'Doctors',
                                      ),
                                    ),
                                  );
                                } else if (item.$3 == 'bills') {
                                  resource('Bills', 'bills');
                                } else {
                                  setState(
                                    () =>
                                        tab = item.$3 == 'appointments' ? 1 : 2,
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 20,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      item.$1,
                                      color: HospitalTheme.blue,
                                      size: 21,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.$2,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
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
                heading('Upcoming appointment'),
                if (!loading && error == null)
                  visitCards(
                    visits
                        .where(
                          (v) => [
                            'scheduled',
                            'confirmed',
                            'in_progress',
                          ].contains(v['status']),
                        )
                        .take(1)
                        .toList(),
                  ),
                heading('Your health profile'),
                if (patient != null)
                  card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 25,
                          runSpacing: 12,
                          children: [
                            for (final key in ['age', 'blood_group', 'phone'])
                              if (patient![key] != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patient![key].toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      label(key),
                                      style: const TextStyle(
                                        color: HospitalTheme.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
              if (tab == 1) ...[
                const Text(
                  'Your appointments',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: patientId == null ? null : book,
                  icon: const Icon(Icons.add),
                  label: const Text('Book a visit'),
                ),
                const SizedBox(height: 18),
                if (!loading && error == null) visitCards(visits),
                TextButton(
                  onPressed: patientId == null
                      ? null
                      : () => resource('Appointments', 'appointments'),
                  child: const Text('View full appointment history'),
                ),
              ],
              if (tab == 2) ...[
                const Text(
                  'Health records',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text('Your prescriptions, laboratory reports and bills.'),
                const SizedBox(height: 20),
                for (final item in [
                  (
                    'Prescriptions',
                    'prescriptions',
                    Icons.description_outlined,
                  ),
                  ('Lab reports', 'lab-orders', Icons.science_outlined),
                  ('Bills & payments', 'bills', Icons.receipt_long_outlined),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card(
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(item.$3, color: HospitalTheme.blue),
                        title: Text(item.$1),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => resource(item.$1, item.$2),
                      ),
                    ),
                  ),
              ],
              if (tab == 3) ...[
                const Text(
                  'Your profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 18),
                if (patient != null) RecordView(value: patient),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: widget.onSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Visits',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              label: 'Records',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget visitCards(List<Map<String, dynamic>> rows) => Column(
    children: [
      if (rows.isEmpty) card(const Text('No visits to show.')),
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFEAF2FF),
                      child: Icon(
                        Icons.medical_services_outlined,
                        color: HospitalTheme.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doctorName(row),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            (row['status'] ?? '').toString().replaceAll(
                              '_',
                              ' ',
                            ),
                            style: const TextStyle(
                              color: HospitalTheme.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    Text(
                      (row['appointment_date'] ??
                              row['date'] ??
                              'Date unavailable')
                          .toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      (row['appointment_time'] ?? row['time'] ?? '').toString(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: () => detail(row),
                    child: const Text('View details'),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
  String doctorName(Map<String, dynamic> row) {
    final d = row['doctor'];
    return d is Map
        ? (d['full_name'] ?? d['name'] ?? 'Your doctor').toString()
        : (row['doctor_name'] ?? row['name'] ?? 'Hospital consultation')
              .toString();
  }

  Future<void> cancelVisit(Map<String, dynamic> record) async {
    if (cancelling || cancelUncertain) return;
    final id = record['id'];
    if (id is! String) return;
    cancelling = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this appointment?'),
        content: const Text('You can book another available time later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep visit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      cancelling = false;
      return;
    }
    try {
      await api.execute(
        {'method': 'PATCH', 'path': '/appointments/{{appointment_id}}/status'},
        parameters: {'appointment_id': id},
        body: {'status': 'cancelled'},
      );
      if (!mounted) return;
      Navigator.pop(context);
      await load();
    } catch (e) {
      cancelling = false;
      cancelUncertain = e is HospitalApiException && e.uncertain;
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void reschedule(Map<String, dynamic> record) {
    final id = record['id'];
    if (id is! String) return;
    final op = hospitalOperations.firstWhere(
      (o) =>
          o['path'] == '/appointments/{{appointment_id}}' &&
          o['method'] == 'PUT',
    );
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => HospitalOperationPage(
          api: api,
          operation: op,
          initialParameters: {'appointment_id': id},
          initialBody: {
            if ((record['appointment_date'] ?? record['date']) != null)
              'date': record['appointment_date'] ?? record['date'],
            if ((record['appointment_time'] ?? record['time']) != null)
              'time': record['appointment_time'] ?? record['time'],
          },
        ),
      ),
    ).then((_) {
      if (mounted) load();
    });
  }

  void detail(Map<String, dynamic> record) {
    final id = record['id'];
    if (id is! String) return;
    final op = hospitalOperations.firstWhere(
      (o) =>
          o['path'] == '/appointments/{{appointment_id}}' &&
          o['method'] == 'GET',
    );
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (c) => Scaffold(
          appBar: AppBar(title: const Text('Your appointment')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              RecordView(value: record),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  c,
                  MaterialPageRoute<void>(
                    builder: (_) => HospitalOperationPage(
                      api: api,
                      operation: op,
                      initialParameters: {'appointment_id': id},
                    ),
                  ),
                ),
                child: const Text('Refresh full details'),
              ),
              if (['scheduled', 'confirmed'].contains(record['status'])) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => reschedule(record),
                  child: const Text('Reschedule appointment'),
                ),
                TextButton(
                  onPressed: () => cancelVisit(record),
                  child: const Text('Cancel appointment'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
