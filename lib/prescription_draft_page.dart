import 'package:flutter/material.dart';

import 'appointment.dart';
import 'auth_service.dart';
import 'clinical_directory.dart';
import 'clinical_directory_page.dart';
import 'doctor_dashboard_service.dart';
import 'patient.dart';
import 'prescription_detail_page.dart';
import 'prescription_draft.dart';
import 'lab_catalog_picker.dart';
import 'lab_catalog_test.dart';

class PrescriptionDraftPage extends StatefulWidget {
  const PrescriptionDraftPage({
    super.key,
    required this.session,
    required this.appointment,
    required this.service,
  });
  final AuthSession session;
  final Appointment appointment;
  final DoctorDashboardService service;
  @override
  State<PrescriptionDraftPage> createState() => _PrescriptionDraftPageState();
}

class _PrescriptionDraftPageState extends State<PrescriptionDraftPage> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final key in [
      'chief_complaint',
      'history_of_presenting_illness',
      'clinical_examination',
      'diagnosis',
      'allergies',
      'past_surgical_history',
      'past_radiation_history',
      'past_chemotherapy_history',
      'advice',
      'follow_up_advice',
      'notes',
      'investigation_notes',
    ])
      key: TextEditingController(),
  };
  final medicines = <_MedicineFields>[];
  final labTests = <_LabTestFields>[];
  DoctorProfile? profile;
  Patient? patient;
  DateTime? followUp;
  bool loading = true, busy = false, dirty = false, uncertain = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
    for (final medicine in medicines) {
      medicine.dispose();
    }
    for (final test in labTests) {
      test.instructions.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final identity = await widget.service.fetchProfile(widget.session);
      if (!['doctor', 'hospital_admin'].contains(identity.role.toLowerCase())) {
        throw const AppointmentDetailException(
          'This account cannot create prescriptions.',
        );
      }
      final id = widget.appointment.patientId;
      if (id == null) {
        throw const AppointmentDetailException(
          'This appointment does not have a patient link.',
        );
      }
      final record = await widget.service.fetchPatient(widget.session, id);
      if ([
        record.allergies,
        record.surgicalHistory,
        record.radiationHistory,
        record.chemotherapyHistory,
      ].contains(
        'Recorded information is not available in a supported format.',
      )) {
        throw const AppointmentDetailException(
          'The clinical history format could not be loaded for editing. Please review it in the hospital portal.',
        );
      }
      if (!mounted) return;
      fields['chief_complaint']!.text =
          widget.appointment.reason ?? widget.appointment.symptoms ?? '';
      fields['diagnosis']!.text = widget.appointment.diagnosis ?? '';
      fields['allergies']!.text = record.allergies ?? '';
      fields['past_surgical_history']!.text = record.surgicalHistory ?? '';
      fields['past_radiation_history']!.text = record.radiationHistory ?? '';
      fields['past_chemotherapy_history']!.text =
          record.chemotherapyHistory ?? '';
      setState(() {
        profile = identity;
        patient = record;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e is AppointmentDetailException
              ? e.message
              : 'Unable to load patient context. Please try again.';
        });
      }
    }
  }

  PrescriptionDraft snapshot() => PrescriptionDraft(
    patientId: patient!.id,
    doctorId: widget.appointment.doctorId,
    appointmentId: widget.appointment.id,
    fields: {
      for (final entry in fields.entries) entry.key: entry.value.text,
      'follow_up_date': followUp == null
          ? ''
          : '${followUp!.year.toString().padLeft(4, '0')}-${followUp!.month.toString().padLeft(2, '0')}-${followUp!.day.toString().padLeft(2, '0')}',
    },
    medications: medicines.map((medicine) => medicine.toJson()).toList(),
    labTests: labTests.map((test) => test.toJson()).toList(),
  );
  Future<void> review() async {
    if (busy || uncertain || !(form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final draft = snapshot();
    setState(() {
      busy = true;
      error = null;
    });
    List<List<String>> conflicts;
    try {
      conflicts = await widget.service.checkDraftAllergies(
        widget.session,
        draft,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Allergy check could not be completed. Review has not been confirmed; try again.';
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = false;
    });
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Text(
                'Review draft',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                patient!.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Doctor: ${widget.appointment.doctorName}'),
              Text(
                'Appointment: ${widget.appointment.number ?? widget.appointment.date}',
              ),
              const Divider(height: 28),
              for (final entry in draft.fields.entries.where(
                (entry) => entry.value.trim().isNotEmpty,
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${labels[entry.key] ?? entry.key.replaceAll('_', ' ')}: ${entry.value.trim()}',
                  ),
                ),
              Text('${draft.medications.length} medicines'),
              for (var index = 0; index < draft.medications.length; index++)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in draft.medications[index].entries)
                          Text(
                            '${_MedicineFields.labels[entry.key] ?? entry.key}: ${entry.value}',
                          ),
                        if (conflicts[index].isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Recorded allergy conflicts: ${conflicts[index].join(', ')}',
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('${draft.labTests.length} lab tests'),
              for (final test in draft.labTests)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(test['test_name'] as String),
                  subtitle: Text(
                    'Routine${test['instructions'] == null ? '' : '\n${test['instructions']}'}',
                  ),
                ),
              const Text(
                'Save as draft only. Issuing to the patient, pharmacy or laboratory is a separate step.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Save draft'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Continue editing'),
              ),
            ],
          ),
        ),
      ),
    );
    if (save != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final id = await widget.service.savePrescriptionDraft(
        widget.session,
        draft,
        role: profile!.role.toLowerCase(),
      );
      if (!mounted) return;
      setState(() {
        busy = false;
        dirty = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Draft saved')));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PrescriptionDetailPage(
            session: widget.session,
            id: id,
            service: widget.service,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          uncertain = e is DraftSaveException && e.uncertain;
          error = e is DraftSaveException
              ? e.message
              : 'The draft could not be saved.';
        });
      }
    }
  }

  static const labels = {
    'chief_complaint': 'Chief complaint',
    'history_of_presenting_illness': 'History of presenting illness',
    'clinical_examination': 'Examination',
    'diagnosis': 'Diagnosis',
    'allergies': 'Allergies (prescription snapshot)',
    'past_surgical_history': 'Surgical history',
    'past_radiation_history': 'Radiation history',
    'past_chemotherapy_history': 'Chemotherapy history',
    'advice': 'Advice',
    'follow_up_advice': 'Follow-up advice',
    'notes': 'Private note (not printed)',
    'follow_up_date': 'Follow-up date',
    'investigation_notes': 'Investigation notes',
  };
  Future<void> leave() async {
    if (busy) return;
    final discard =
        !dirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Discard unsaved changes?'),
                content: const Text('This draft has not been saved.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep editing'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ) ==
            true;
    if (discard && mounted) {
      setState(() {
        dirty = false;
      });
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) leave();
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F3EA),
        foregroundColor: const Color(0xFF207361),
        surfaceTintColor: Colors.transparent,
        title: const Text('Prescription draft'),
        leading: IconButton(
          onPressed: busy ? null : leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : patient == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error ?? 'Patient unavailable',
                      textAlign: TextAlign.center,
                    ),
                    FilledButton(onPressed: load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    patient!.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    'Dr. ${widget.appointment.doctorName} · ${widget.appointment.date}',
                  ),
                  const SizedBox(height: 16),
                  const Text('Consultation notes'),
                  for (final entry in fields.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: TextFormField(
                        controller: entry.value,
                        enabled: !busy && !uncertain,
                        maxLines: entry.key == 'diagnosis' ? 1 : 2,
                        decoration: InputDecoration(
                          labelText: labels[entry.key],
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          if (!dirty) {
                            setState(() {
                              dirty = true;
                            });
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Medicines',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final medicine in medicines)
                    Card(
                      key: ObjectKey(medicine),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            for (final entry in medicine.fields.entries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TextFormField(
                                  controller: entry.value,
                                  enabled: !busy && !uncertain,
                                  decoration: InputDecoration(
                                    labelText:
                                        _MedicineFields.labels[entry.key],
                                    border: const OutlineInputBorder(),
                                  ),
                                  keyboardType: entry.key == 'quantity'
                                      ? TextInputType.number
                                      : TextInputType.text,
                                  validator: (value) {
                                    if (entry.key == 'medicine_name' &&
                                        (value == null ||
                                            value.trim().isEmpty)) {
                                      return 'Enter a medicine name or remove this row.';
                                    }
                                    if (entry.key == 'quantity' &&
                                        value != null &&
                                        value.trim().isNotEmpty &&
                                        (int.tryParse(value.trim()) == null ||
                                            int.parse(value.trim()) <= 0)) {
                                      return 'Enter a positive whole number.';
                                    }
                                    return null;
                                  },
                                  onChanged: (_) {
                                    if (!dirty) {
                                      setState(() {
                                        dirty = true;
                                      });
                                    }
                                  },
                                ),
                              ),
                            TextButton.icon(
                              onPressed: busy || uncertain
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
                              label: const Text('Remove medicine'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy || uncertain
                        ? null
                        : () => setState(() {
                            medicines.add(_MedicineFields());
                            dirty = true;
                          }),
                    icon: const Icon(Icons.add),
                    label: const Text('Add medicine'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lab tests',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final test in labTests)
                    Card(
                      key: ObjectKey(test),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              test.catalog.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Text('Priority: Routine'),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: test.instructions,
                              enabled: !busy && !uncertain,
                              decoration: const InputDecoration(
                                labelText: 'Test instructions',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {
                                dirty = true;
                              }),
                            ),
                            TextButton.icon(
                              onPressed: busy || uncertain
                                  ? null
                                  : () {
                                      setState(() {
                                        labTests.remove(test);
                                        dirty = true;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback(
                                            (_) => test.instructions.dispose(),
                                          );
                                    },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Remove test'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy || uncertain
                        ? null
                        : () async {
                            final selected = await Navigator.of(context)
                                .push<LabCatalogTest>(
                                  MaterialPageRoute(
                                    builder: (_) => LabCatalogPicker(
                                      session: widget.session,
                                      service: widget.service,
                                    ),
                                  ),
                                );
                            if (!mounted ||
                                !context.mounted ||
                                selected == null) {
                              return;
                            }
                            if (labTests.any(
                              (test) =>
                                  test.catalog.id == selected.id ||
                                  test.catalog.name.toLowerCase() ==
                                      selected.name.toLowerCase(),
                            )) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'This test is already on the draft.',
                                  ),
                                ),
                              );
                            } else {
                              setState(() {
                                labTests.add(_LabTestFields(selected));
                                dirty = true;
                              });
                            }
                          },
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Add lab test'),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Follow-up date'),
                    subtitle: Text(
                      followUp == null
                          ? 'Not set'
                          : MaterialLocalizations.of(context)
                                .formatFullDate(followUp!),
                    ),
                    trailing: followUp == null
                        ? const Icon(Icons.calendar_month)
                        : IconButton(
                            tooltip: 'Clear follow-up date',
                            onPressed: busy || uncertain
                                ? null
                                : () => setState(() {
                                    followUp = null;
                                    dirty = true;
                                  }),
                            icon: const Icon(Icons.close),
                          ),
                    onTap: busy || uncertain
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: followUp ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date != null && mounted) {
                              setState(() {
                                followUp = date;
                                dirty = true;
                              });
                            }
                          },
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        error!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  if (uncertain)
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ClinicalDirectoryPage(
                            session: widget.session,
                            service: widget.service,
                            directory: ClinicalDirectory.prescriptions,
                          ),
                        ),
                      ),
                      child: const Text('Check Prescriptions'),
                    ),
                  FilledButton(
                    onPressed: busy || uncertain ? null : review,
                    child: Text(busy ? 'Please wait…' : 'Review draft'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    ),
  );
}

class _MedicineFields {
  static const labels = {
    'medicine_name': 'Medicine name',
    'dosage': 'Dosage',
    'form': 'Form',
    'frequency': 'Frequency',
    'duration': 'Duration',
    'quantity': 'Quantity',
    'instructions': 'Instructions',
  };
  final fields = {for (final key in labels.keys) key: TextEditingController()};
  Map<String, dynamic> toJson() => {
    for (final entry in fields.entries.where(
      (entry) => entry.value.text.trim().isNotEmpty,
    ))
      entry.key: entry.key == 'quantity'
          ? int.parse(entry.value.text.trim())
          : entry.value.text.trim(),
  };
  void dispose() {
    for (final controller in fields.values) {
      controller.dispose();
    }
  }
}

class _LabTestFields {
  _LabTestFields(this.catalog);
  final LabCatalogTest catalog;
  final instructions = TextEditingController();
  Map<String, dynamic> toJson() => {
    'catalog_id': catalog.id,
    'test_name': catalog.name,
    'priority': 'routine',
    if (instructions.text.trim().isNotEmpty)
      'instructions': instructions.text.trim(),
  };
}
