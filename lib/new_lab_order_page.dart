import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'appointment_booking_service.dart';
import 'doctor_dashboard_service.dart';
import 'lab_catalog_picker.dart';
import 'lab_catalog_test.dart';
import 'prescription_draft.dart';

class NewLabOrderPage extends StatefulWidget {
  const NewLabOrderPage({
    super.key,
    required this.session,
    required this.service,
    this.bookingService,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  final AppointmentBookingService? bookingService;
  @override
  State<NewLabOrderPage> createState() => _NewLabOrderPageState();
}

class _NewLabOrderPageState extends State<NewLabOrderPage> {
  final search = TextEditingController(), notes = TextEditingController();
  final tests = <LabCatalogTest>[];
  final priorities = <String, String>{};
  List<Map<String, dynamic>> patients = [], doctors = [];
  Map<String, dynamic>? patient;
  DoctorProfile? profile;
  String? doctorId, error, searchError;
  bool loading = true, searching = false, busy = false, uncertain = false;
  int searchRequest = 0;
  late final booking = widget.bookingService ?? AppointmentBookingService();
  bool get locked => busy || uncertain;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    notes.dispose();
    if (widget.bookingService == null) booking.close();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final identity = await widget.service.fetchProfile(widget.session);
      final options = identity.role == 'doctor'
          ? <Map<String, dynamic>>[]
          : await booking.doctors(widget.session);
      if (mounted) {
        setState(() {
          profile = identity;
          doctors = options;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Unable to load order options. Please retry.';
        });
      }
    }
  }

  Future<void> findPatients() async {
    if (search.text.trim().isEmpty || locked) return;
    final current = ++searchRequest;
    setState(() {
      searching = true;
      searchError = null;
      patients = [];
      patient = null;
    });
    try {
      final result = await widget.service.searchLaboratoryPatients(
        widget.session,
        search.text,
      );
      if (mounted && current == searchRequest) {
        setState(() {
          patients = result;
          searching = false;
        });
      }
    } catch (_) {
      if (mounted && current == searchRequest) {
        setState(() {
          searching = false;
          searchError = 'Patient search failed. Please retry.';
        });
      }
    }
  }

  Future<void> addTest() async {
    final selected = await Navigator.of(context).push<LabCatalogTest>(
      MaterialPageRoute(
        builder: (_) =>
            LabCatalogPicker(session: widget.session, service: widget.service),
      ),
    );
    if (!mounted || selected == null) return;
    if (!tests.any(
      (t) =>
          t.id == selected.id ||
          t.name.toLowerCase() == selected.name.toLowerCase(),
    )) {
      setState(() {
        tests.add(selected);
        priorities[selected.id] = 'routine';
      });
    }
  }

  Future<void> save() async {
    if (locked ||
        patient == null ||
        tests.isEmpty ||
        profile == null ||
        (profile!.role != 'doctor' && doctorId == null)) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send lab order?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (patient!['full_name'] ??
                          patient!['name'] ??
                          patient!['label'] ??
                          'Patient')
                      .toString(),
                ),
                const SizedBox(height: 10),
                for (final test in tests)
                  Text('${test.name} · ${priorities[test.id]}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continue editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send order'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await widget.service.createLaboratoryOrder(
        widget.session,
        patientId: patient!['id'] as String,
        doctorId: profile!.role == 'doctor' ? null : doctorId,
        tests: tests
            .map(
              (t) => <String, dynamic>{
                'catalog_id': t.id,
                'priority': priorities[t.id],
              },
            )
            .toList(),
        notes: notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          uncertain = e is DraftSaveException && e.uncertain;
          error = e is DraftSaveException
              ? e.message
              : 'Unable to create lab order. Please retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme
          .copyWith(primary: const Color(0xFF207361), surface: Colors.white),
    ),
    child: PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3EA),
        appBar: AppBar(
          title: const Text('New lab order'),
          backgroundColor: const Color(0xFFF7F3EA),
          foregroundColor: const Color(0xFF207361),
          surfaceTintColor: Colors.transparent,
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const Text(
                    'Choose the patient and the tests to send to the laboratory.',
                    style: TextStyle(color: Color(0xFF566963), height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: Colors.red)),
                    if (profile == null)
                      TextButton(onPressed: load, child: const Text('Retry')),
                    const SizedBox(height: 12),
                  ],
                  if (profile != null) ...[
                    TextField(
                      controller: search,
                      enabled: !locked,
                      onSubmitted: (_) => findPatients(),
                      onChanged: (_) {
                        searchRequest++;
                        setState(() {
                          patient = null;
                          patients = [];
                          searching = false;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Patient *',
                        hintText: 'Search by name, phone or patient ID',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: 'Search patients',
                          onPressed: locked || searching ? null : findPatients,
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    if (searching) const LinearProgressIndicator(),
                    if (searchError != null) Text(searchError!),
                    for (final row in patients)
                      Card(
                        color: Colors.white,
                        child: ListTile(
                          selected: patient?['id'] == row['id'],
                          leading: Icon(
                            patient?['id'] == row['id']
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          title: Text(
                            (row['full_name'] ??
                                    row['name'] ??
                                    row['label'] ??
                                    'Patient')
                                .toString(),
                          ),
                          onTap: locked
                              ? null
                              : () => setState(() {
                                  patient = row;
                                }),
                        ),
                      ),
                    const SizedBox(height: 18),
                    if (profile!.role != 'doctor')
                      DropdownButtonFormField<String>(
                        initialValue: doctorId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Referring doctor *',
                          border: OutlineInputBorder(),
                        ),
                        items: doctors
                            .map(
                              (d) => DropdownMenuItem(
                                value: d['id'] as String,
                                child: Text(
                                  (d['name'] ?? 'Doctor').toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: locked
                            ? null
                            : (id) => setState(() {
                                doctorId = id;
                              }),
                      ),
                    const SizedBox(height: 18),
                    const Text(
                      'Tests *',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF20312D),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final test in tests)
                      Card(
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      test.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove test',
                                    onPressed: locked
                                        ? null
                                        : () => setState(() {
                                            tests.remove(test);
                                            priorities.remove(test.id);
                                          }),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              DropdownButtonFormField<String>(
                                initialValue: priorities[test.id],
                                decoration: const InputDecoration(
                                  labelText: 'Priority',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'routine',
                                    child: Text('Routine'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'urgent',
                                    child: Text('Urgent'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'stat',
                                    child: Text('STAT'),
                                  ),
                                ],
                                onChanged: locked
                                    ? null
                                    : (value) => setState(() {
                                        priorities[test.id] =
                                            value ?? 'routine';
                                      }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: locked ? null : addTest,
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Add test from catalogue'),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: notes,
                      enabled: !locked,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF207361),
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed:
                          locked ||
                              patient == null ||
                              tests.isEmpty ||
                              (profile!.role != 'doctor' && doctorId == null)
                          ? null
                          : save,
                      icon: Icon(
                        busy ? Icons.hourglass_top : Icons.send_outlined,
                      ),
                      label: Text(busy ? 'Sending…' : 'Create lab order'),
                    ),
                  ],
                ],
              ),
      ),
    ),
  );
}
