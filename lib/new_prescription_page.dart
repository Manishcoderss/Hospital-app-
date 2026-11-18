import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'appointment_booking_service.dart';
import 'doctor_dashboard_service.dart';
import 'patient.dart';
import 'prescription_draft.dart';
import 'prescription_detail_page.dart';
import 'lab_catalog_picker.dart';
import 'lab_catalog_test.dart';

const _cream = Color(0xFFF7F3EA);
const _green = Color(0xFF207361);
const _ink = Color(0xFF20312D);
const _muted = Color(0xFF566963);

class NewPrescriptionPage extends StatefulWidget {
  const NewPrescriptionPage({
    super.key,
    required this.session,
    required this.service,
    this.bookingService,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  final AppointmentBookingService? bookingService;
  @override
  State<NewPrescriptionPage> createState() => _NewPrescriptionPageState();
}

class _NewPrescriptionPageState extends State<NewPrescriptionPage> {
  final form = GlobalKey<FormState>();
  final patientSearch = TextEditingController();
  static const labels = {
    'chief_complaint': 'Chief complaint',
    'history_of_presenting_illness': 'History of presenting illness',
    'clinical_examination': 'Examination',
    'diagnosis': 'Diagnosis',
    'allergies': 'Allergies',
    'past_surgical_history': 'Past surgical history',
    'past_radiation_history': 'Past radiation history',
    'past_chemotherapy_history': 'Past chemotherapy history',
    'chemotherapy_protocol': 'Chemotherapy protocol',
    'investigation_notes': 'Investigation notes',
    'advice': 'Advice',
    'follow_up_advice': 'Follow-up advice',
    'notes': 'Private note',
  };
  final fields = {for (final key in labels.keys) key: TextEditingController()};
  final medicines = <_MedicineRow>[_MedicineRow()];
  final tests = <LabCatalogTest>[];
  List<Map<String, dynamic>> patients = [], doctors = [];
  Patient? patient;
  DoctorProfile? profile;
  String? doctorId, disposition, error, patientError, doctorError;
  DateTime? followUp;
  bool searching = false,
      loadingPatient = false,
      loadingDoctors = true,
      busy = false,
      dirty = false,
      uncertain = false;
  int patientRequest = 0;
  late final booking = widget.bookingService ?? AppointmentBookingService();

  @override
  void initState() {
    super.initState();
    loadDoctors();
  }

  @override
  void dispose() {
    patientSearch.dispose();
    for (final c in fields.values) {
      c.dispose();
    }
    for (final m in medicines) {
      m.dispose();
    }
    if (widget.bookingService == null) booking.close();
    super.dispose();
  }

  bool get locked => busy || uncertain;
  void markDirty() {
    setState(() {
      dirty = true;
    });
  }

  Future<void> loadDoctors() async {
    setState(() {
      loadingDoctors = true;
      doctorError = null;
    });
    try {
      final identity = await widget.service.fetchProfile(widget.session);
      if (!['doctor', 'hospital_admin'].contains(identity.role)) {
        throw const AppointmentDetailException(
          'This account cannot create prescriptions.',
        );
      }
      final options = await booking.doctors(widget.session);
      String? own;
      if (identity.role == 'doctor') {
        try {
          own = await booking.ownDoctorId(widget.session);
        } on BookingException catch (e) {
          if (![403, 404].contains(e.statusCode)) rethrow;
        }
      }
      if (!mounted) return;
      setState(() {
        profile = identity;
        doctors = options;
        doctorId = options.any((d) => d['id'] == own) ? own : null;
        loadingDoctors = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loadingDoctors = false;
          doctorError = e is BookingException
              ? e.message
              : e is AppointmentDetailException
              ? e.message
              : 'Unable to load prescribing doctors.';
        });
      }
    }
  }

  Future<void> searchPatients() async {
    if (patientSearch.text.trim().isEmpty || locked) return;
    final request = ++patientRequest;
    setState(() {
      searching = true;
      patientError = null;
      patients = [];
    });
    try {
      final result = await widget.service.searchPrescriptionPatients(
        widget.session,
        patientSearch.text,
      );
      if (mounted && request == patientRequest) {
        setState(() {
          patients = result;
          searching = false;
        });
      }
    } catch (e) {
      if (mounted && request == patientRequest) {
        setState(() {
          searching = false;
          patientError = e is AppointmentDetailException
              ? e.message
              : 'Patient search failed. Please retry.';
        });
      }
    }
  }

  Future<void> selectPatient(Map<String, dynamic> row) async {
    if (locked) return;
    if (patient != null && patient!.id != row['id'] && dirty) {
      final change = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change patient?'),
          content: const Text(
            'Consultation, medicines and tests will be cleared to keep each patient record separate.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep patient'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Change patient'),
            ),
          ],
        ),
      );
      if (change != true || !mounted) return;
    }
    final request = ++patientRequest;
    setState(() {
      loadingPatient = true;
      patientError = null;
      patient = null;
    });
    try {
      final record = await widget.service.fetchPatient(
        widget.session,
        row['id'] as String,
      );
      if (record.id != row['id']) {
        throw const AppointmentDetailException(
          'Patient identity did not match the selection. Search again before continuing.',
        );
      }
      if ([
        record.allergies,
        record.surgicalHistory,
        record.radiationHistory,
        record.chemotherapyHistory,
      ].contains(
        'Recorded information is not available in a supported format.',
      )) {
        throw const AppointmentDetailException(
          'Patient history format is unsupported. Review this record in the hospital portal.',
        );
      }
      if (!mounted || request != patientRequest) return;
      final removed = [...medicines];
      setState(() {
        for (final c in fields.values) {
          c.clear();
        }
        fields['allergies']!.text = record.allergies ?? '';
        fields['past_surgical_history']!.text = record.surgicalHistory ?? '';
        fields['past_radiation_history']!.text = record.radiationHistory ?? '';
        fields['past_chemotherapy_history']!.text =
            record.chemotherapyHistory ?? '';
        medicines
          ..clear()
          ..add(_MedicineRow());
        tests.clear();
        followUp = null;
        disposition = null;
        patient = record;
        patients = [];
        patientSearch.clear();
        loadingPatient = false;
        dirty = true;
      });
      if (kDebugMode && const bool.fromEnvironment('DOCTOR_LIVE_QA')) {
        debugPrint('DOCTOR_SELECTION_QA|patient_history|pass');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final m in removed) {
          m.dispose();
        }
      });
    } catch (e) {
      if (mounted && request == patientRequest) {
        setState(() {
          loadingPatient = false;
          patientError = e is AppointmentDetailException
              ? e.message
              : 'Unable to load patient history.';
        });
      }
    }
  }

  Future<void> pickFollowUp() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final result = await showDatePicker(
      context: context,
      initialDate: followUp ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: DateTime(today.year + 5),
    );
    if (mounted && result != null) {
      setState(() {
        followUp = result;
        dirty = true;
      });
    }
  }

  PrescriptionDraft snapshot() => PrescriptionDraft(
    patientId: patient!.id,
    doctorId: doctorId!,
    fields: {
      for (final entry in fields.entries) entry.key: entry.value.text,
      'disposition': disposition ?? '',
      'follow_up_date': followUp == null
          ? ''
          : '${followUp!.year}-${followUp!.month.toString().padLeft(2, '0')}-${followUp!.day.toString().padLeft(2, '0')}',
    },
    medications: medicines
        .where((m) => m.fields['medicine_name']!.text.trim().isNotEmpty)
        .map((m) => m.toJson())
        .toList(),
    labTests: tests
        .map(
          (t) => <String, dynamic>{
            'catalog_id': t.id,
            'test_name': t.name,
            'priority': 'routine',
          },
        )
        .toList(),
  );

  Future<void> save(bool issue) async {
    if (locked ||
        patient == null ||
        doctorId == null ||
        profile == null ||
        !(form.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      for (final medicine in medicines) {
        final name = medicine.fields['medicine_name']!.text.trim();
        if (name.isEmpty &&
            medicine.fields.values.any((c) => c.text.trim().isNotEmpty)) {
          throw const AppointmentDetailException(
            'Enter a medicine name or remove the incomplete row.',
          );
        }
        final quantity = medicine.fields['quantity']!.text.trim();
        if (quantity.isNotEmpty &&
            (int.tryParse(quantity) == null || int.parse(quantity) <= 0)) {
          throw const AppointmentDetailException(
            'Medicine quantity must be a positive whole number.',
          );
        }
      }
      final draft = snapshot();
      if (issue && draft.medications.isEmpty && tests.isEmpty) {
        throw const AppointmentDetailException(
          'Add at least one medicine or lab test before issuing.',
        );
      }
      final conflicts = await widget.service.checkDraftAllergies(
        widget.session,
        draft,
      );
      if (conflicts.any((c) => c.isNotEmpty)) {
        throw const AppointmentDetailException(
          'A medicine conflicts with recorded allergies. Review the medicine selection before saving.',
        );
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Review prescription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient!.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('Diagnosis: ${fields['diagnosis']!.text}'),
                const SizedBox(height: 10),
                for (final m in draft.medications)
                  Text(
                    '${m['medicine_name']} · ${m['dosage'] ?? ''} · ${m['frequency'] ?? ''} · ${m['duration'] ?? ''}',
                  ),
                for (final t in tests) Text('Lab: ${t.name}'),
                const SizedBox(height: 10),
                Text(
                  issue
                      ? 'The draft will be saved, then you can review and confirm issuing.'
                      : 'Save this prescription as a draft.',
                ),
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
              child: const Text('Save draft'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final id = await widget.service.savePrescriptionDraft(
        widget.session,
        draft,
        role: profile!.role,
      );
      if (!mounted) return;
      setState(() {
        dirty = false;
      });
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PrescriptionDetailPage(
            session: widget.session,
            id: id,
            service: widget.service,
            reviewIssueOnLoad: issue,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          uncertain = e is DraftSaveException && e.uncertain;
          error = e is DraftSaveException
              ? e.message
              : e is AppointmentDetailException
              ? e.message
              : 'Unable to prepare the prescription. Please try again.';
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

  Future<void> leave() async {
    if (busy) return;
    final discard =
        !dirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Discard prescription changes?'),
                content: const Text('Unsaved changes will be lost.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ) ==
            true;
    if (mounted && discard) {
      setState(() {
        dirty = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !busy) Navigator.pop(context);
      });
    }
  }

  Widget input(String key, {String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: fields[key],
      enabled: !locked,
      maxLines: 2,
      onChanged: (_) => markDirty(),
      decoration: InputDecoration(
        labelText: labels[key],
        hintText: hint,
        alignLabelWithHint: true,
      ),
    ),
  );
  Widget section(String title, List<Widget> children, {String? description}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE1E6DC)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        description,
                        style: const TextStyle(color: _muted, height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE6EADF)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      );
  Widget responsiveFields(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 650
        ? Column(children: children)
        : Wrap(
            spacing: 18,
            children: [
              for (final child in children)
                SizedBox(width: (constraints.maxWidth - 18) / 2, child: child),
            ],
          ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme
          .copyWith(primary: _green, surface: Colors.white),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE5D9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDCE5D9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
      ),
    ),
    child: PopScope(
      canPop: !dirty && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        backgroundColor: _cream,
        appBar: AppBar(
          backgroundColor: _cream,
          foregroundColor: _green,
          surfaceTintColor: Colors.transparent,
          title: const Text('New prescription'),
          leading: IconButton(
            onPressed: busy ? null : leave,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: Form(
          key: form,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              section('Patient *', [
                if (patient != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${patient!.name} · ${patient!.number ?? ''}',
                      style: const TextStyle(
                        color: _green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                TextField(
                  controller: patientSearch,
                  enabled: !locked && !loadingPatient,
                  onSubmitted: (_) => searchPatients(),
                  decoration: InputDecoration(
                    hintText: 'Search by name, number or mobile',
                    suffixIcon: IconButton(
                      tooltip: 'Search patients',
                      onPressed: locked || searching ? null : searchPatients,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                ),
                if (searching || loadingPatient)
                  const LinearProgressIndicator(),
                if (patientError != null)
                  Text(
                    patientError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                for (final row in patients)
                  ListTile(
                    title: Text(
                      (row['full_name'] ??
                              row['name'] ??
                              row['label'] ??
                              'Patient')
                          .toString(),
                    ),
                    onTap: locked ? null : () => selectPatient(row),
                  ),
                if (!searching &&
                    patients.isEmpty &&
                    patientSearch.text.trim().isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Search for a patient to select their record.',
                      style: TextStyle(color: _muted),
                    ),
                  ),
              ]),
              section('Consultation', [
                responsiveFields([
                  input('chief_complaint'),
                  input('history_of_presenting_illness'),
                  input('clinical_examination', hint: 'Vitals and findings'),
                  input('diagnosis'),
                ]),
              ], description: 'Each section prints under its own heading.'),
              Card(
                margin: const EdgeInsets.only(bottom: 18),
                color: Colors.white,
                child: ExpansionTile(
                  title: const Text(
                    'Patient history & oncology sections',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    responsiveFields([
                      for (final key in [
                        'allergies',
                        'past_surgical_history',
                        'past_radiation_history',
                        'past_chemotherapy_history',
                        'chemotherapy_protocol',
                      ])
                        input(key),
                    ]),
                  ],
                ),
              ),
              section(
                'Medicines',
                [
                  for (final medicine in medicines)
                    Container(
                      key: ObjectKey(medicine),
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: medicine.fields['medicine_name'],
                                  enabled: !locked,
                                  onChanged: (_) => markDirty(),
                                  decoration: const InputDecoration(
                                    labelText: 'Medicine name',
                                    prefixIcon: Icon(Icons.medication_outlined),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove medicine',
                                onPressed: locked
                                    ? null
                                    : () {
                                        setState(() {
                                          medicines.remove(medicine);
                                          dirty = true;
                                        });
                                        WidgetsBinding.instance
                                            .addPostFrameCallback(
                                              (_) => medicine.dispose(),
                                            );
                                      },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) => Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final entry in const [
                                  ('dosage', 'Dose', '500 mg'),
                                  ('frequency', 'Frequency', '1-0-1'),
                                  ('duration', 'Duration', '5 days'),
                                  ('quantity', 'Qty', ''),
                                  (
                                    'instructions',
                                    'Instructions',
                                    'After food',
                                  ),
                                ])
                                  SizedBox(
                                    width: constraints.maxWidth < 550
                                        ? (constraints.maxWidth - 10) / 2
                                        : (constraints.maxWidth - 40) / 5,
                                    child: TextFormField(
                                      controller: medicine.fields[entry.$1],
                                      enabled: !locked,
                                      onChanged: (_) => markDirty(),
                                      keyboardType: entry.$1 == 'quantity'
                                          ? TextInputType.number
                                          : TextInputType.text,
                                      validator: (value) =>
                                          entry.$1 == 'quantity' &&
                                              value?.trim().isNotEmpty ==
                                                  true &&
                                              (int.tryParse(value!.trim()) ==
                                                      null ||
                                                  int.parse(value.trim()) <= 0)
                                          ? 'Positive whole number required'
                                          : null,
                                      decoration: InputDecoration(
                                        labelText: entry.$2,
                                        hintText: entry.$3,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextButton.icon(
                    onPressed: locked
                        ? null
                        : () => setState(() {
                            medicines.add(_MedicineRow());
                            dirty = true;
                          }),
                    icon: const Icon(Icons.add),
                    label: const Text('Add medicine'),
                  ),
                ],
                description: 'Enter the medicine name, dose and instructions.',
              ),
              section(
                'Lab tests',
                [
                  for (final test in tests)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(test.name),
                      trailing: IconButton(
                        tooltip: 'Remove test',
                        onPressed: locked
                            ? null
                            : () => setState(() {
                                tests.remove(test);
                                dirty = true;
                              }),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: locked
                        ? null
                        : () async {
                            final chosen = await Navigator.of(context)
                                .push<LabCatalogTest>(
                                  MaterialPageRoute(
                                    builder: (_) => LabCatalogPicker(
                                      session: widget.session,
                                      service: widget.service,
                                    ),
                                  ),
                                );
                            if (!mounted || chosen == null) return;
                            if (!tests.any(
                              (t) =>
                                  t.id == chosen.id ||
                                  t.name.toLowerCase() ==
                                      chosen.name.toLowerCase(),
                            )) {
                              setState(() {
                                tests.add(chosen);
                                dirty = true;
                              });
                            }
                          },
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Add a test — CBC, LFT, HbA1c…'),
                  ),
                  const SizedBox(height: 16),
                  input('investigation_notes'),
                  const Text(
                    'Outside reports reviewed, imaging not in the catalogue, etc.',
                    style: TextStyle(color: _muted),
                  ),
                ],
                description:
                    'Sent to the laboratory as one order when you issue.',
              ),
              section('Advice & follow-up', [
                input('advice', hint: 'Diet, rest, warning signs…'),
                input('follow_up_advice'),
                OutlinedButton.icon(
                  onPressed: locked ? null : pickFollowUp,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    followUp == null
                        ? 'Follow-up date'
                        : MaterialLocalizations.of(context)
                              .formatMediumDate(followUp!),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final days in [7, 14, 30])
                      ActionChip(
                        label: Text(days == 30 ? '1 month' : '$days days'),
                        onPressed: locked
                            ? null
                            : () => setState(() {
                                followUp = DateUtils.dateOnly(DateTime.now())
                                    .add(Duration(days: days));
                                dirty = true;
                              }),
                      ),
                    if (followUp != null)
                      ActionChip(
                        label: const Text('Clear date'),
                        onPressed: locked
                            ? null
                            : () => setState(() {
                                followUp = null;
                                dirty = true;
                              }),
                      ),
                  ],
                ),
                const Text(
                  'Shows on the calendar until it is booked.',
                  style: TextStyle(color: _muted),
                ),
              ]),
              section('Summary', [
                if (loadingDoctors) const LinearProgressIndicator(),
                if (doctorError != null) ...[
                  Text(doctorError!, style: const TextStyle(color: Colors.red)),
                  TextButton(
                    onPressed: locked ? null : loadDoctors,
                    child: const Text('Retry doctors'),
                  ),
                ],
                DropdownButtonFormField<String>(
                  key: ValueKey(doctorId),
                  initialValue: doctorId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Prescribing doctor *',
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
                          dirty = true;
                        }),
                ),
                const SizedBox(height: 16),
                const Text('After this visit', style: TextStyle(color: _ink)),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final item in const [
                      ('home', 'Home'),
                      ('follow_up', 'Follow-up'),
                      ('admit', 'Admit'),
                      ('refer', 'Refer'),
                    ])
                      ChoiceChip(
                        label: Text(item.$2),
                        selected: disposition == item.$1,
                        onSelected: locked
                            ? null
                            : (_) => setState(() {
                                disposition = item.$1;
                                dirty = true;
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                input('notes'),
                const Text('Not printed.', style: TextStyle(color: _muted)),
                const Divider(height: 28),
                Text(
                  '${medicines.where((m) => m.fields['medicine_name']!.text.trim().isNotEmpty).length} medicines · ${tests.length} tests',
                  style: const TextStyle(color: _muted),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: locked || patient == null || doctorId == null
                      ? null
                      : () => save(false),
                  child: const Text('Save draft'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed:
                      locked ||
                          patient == null ||
                          doctorId == null ||
                          (medicines.every(
                                (m) => m.fields['medicine_name']!.text
                                    .trim()
                                    .isEmpty,
                              ) &&
                              tests.isEmpty)
                      ? null
                      : () => save(true),
                  icon: busy
                      ? const Icon(Icons.hourglass_top)
                      : const Icon(Icons.send_outlined),
                  label: Text(busy ? 'Saving…' : 'Save & issue'),
                ),
              ]),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MedicineRow {
  final fields = {
    for (final key in [
      'medicine_name',
      'dosage',
      'frequency',
      'duration',
      'quantity',
      'instructions',
    ])
      key: TextEditingController(),
  };
  Map<String, dynamic> toJson() => {
    for (final entry in fields.entries)
      if (entry.value.text.trim().isNotEmpty)
        entry.key: entry.key == 'quantity'
            ? int.parse(entry.value.text.trim())
            : entry.value.text.trim(),
  };
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
  }
}
