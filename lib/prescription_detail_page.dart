import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_dashboard_service.dart';
import 'patient_records.dart';
import 'prescription_draft.dart';

class PrescriptionDetailPage extends StatefulWidget {
  const PrescriptionDetailPage({
    super.key,
    required this.session,
    required this.id,
    required this.service,
    this.reviewIssueOnLoad = false,
    this.pharmacyContext = false,
  });
  final AuthSession session;
  final String id;
  final DoctorDashboardService service;
  final bool reviewIssueOnLoad;
  final bool pharmacyContext;
  @override
  State<PrescriptionDetailPage> createState() => _PrescriptionDetailPageState();
}

class _PrescriptionDetailPageState extends State<PrescriptionDetailPage> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;
  bool issuing = false;
  bool issueUncertain = false;
  String? issueError;
  bool initialIssueReviewed = false;
  bool dispenseUncertain = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (issuing) return;
    setState(() {
      loading = true;
      data = null;
      error = null;
    });
    try {
      final result = await widget.service.fetchPrescription(
        widget.session,
        widget.id,
      );
      if (!mounted) return;
      setState(() {
        data = result;
        loading = false;
        if (result['status'] != 'issued') dispenseUncertain = false;
        if (result['status'] != 'draft') {
          issueError = null;
          issueUncertain = false;
        }
      });
      if (widget.reviewIssueOnLoad &&
          !initialIssueReviewed &&
          result['status'] == 'draft') {
        initialIssueReviewed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) issue();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e is AppointmentDetailException
            ? e.message
            : 'Unable to load prescription. Please try again.';
      });
    }
  }

  Future<void> dispense() async {
    if (issuing || dispenseUncertain || data?['status'] != 'issued') return;
    setState(() {
      issuing = true;
      issueError = null;
    });
    try {
      final profile = await widget.service.fetchProfile(widget.session);
      if (!['pharmacist', 'hospital_admin'].contains(profile.role)) {
        throw const AppointmentDetailException(
          'Your account cannot dispense prescriptions.',
        );
      }
      final fresh = await widget.service.fetchPrescription(
        widget.session,
        widget.id,
      );
      if (fresh['status'] != 'issued') {
        throw const AppointmentDetailException(
          'This prescription is no longer waiting for dispensing. Refresh before continuing.',
        );
      }
      final medicines = recordList(fresh['medications']);
      if (medicines.isEmpty) {
        throw const AppointmentDetailException(
          'This prescription has no medicines to dispense.',
        );
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Dispense prescription?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recordText(fresh, 'prescription_number') ?? widget.id),
                const SizedBox(height: 10),
                for (final medicine in medicines)
                  Text(
                    '${recordText(medicine, 'medicine_name') ?? 'Medicine'} · Quantity ${recordText(medicine, 'quantity') ?? 'not recorded'}',
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Dispensing deducts available stock, earliest expiry first.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Dispense'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await widget.service.dispensePrescription(widget.session, widget.id);
      if (!mounted) return;
      setState(() {
        issuing = false;
      });
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          dispenseUncertain = e is DraftSaveException && e.uncertain;
          issueError = e is DraftSaveException
              ? e.message
              : e is AppointmentDetailException
              ? e.message
              : 'Unable to confirm dispensing. Refresh before continuing.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          issuing = false;
        });
      }
    }
  }

  Future<void> issue() async {
    if (issuing || issueUncertain || data?['status'] != 'draft') return;
    setState(() {
      issuing = true;
      issueError = null;
    });
    try {
      final profile = await widget.service.fetchProfile(widget.session);
      if (!['doctor', 'hospital_admin'].contains(profile.role.toLowerCase())) {
        throw const AppointmentDetailException(
          'Your account cannot issue prescriptions.',
        );
      }
      final fresh = await widget.service.fetchPrescription(
        widget.session,
        widget.id,
      );
      if (!mounted) return;
      setState(() {
        data = fresh;
      });
      if (fresh['status'] != 'draft') {
        throw const AppointmentDetailException(
          'This prescription is no longer a draft. Its current status is shown above.',
        );
      }
      final medicines = recordList(fresh['medications']);
      final tests = recordList(fresh['lab_tests']);
      if (medicines.isEmpty && tests.isEmpty) {
        throw const AppointmentDetailException(
          'Add at least one medicine or lab test before issuing. Edit this draft in the hospital portal.',
        );
      }
      final linkedPatient = fresh['patient'];
      final patientId =
          fresh['patient_id'] ??
          (linkedPatient is Map ? linkedPatient['id'] : null);
      if (patientId is! String || patientId.isEmpty) {
        throw const FormatException('Patient link missing');
      }
      final conflicts = await widget.service.checkMedicationAllergies(
        widget.session,
        patientId: patientId,
        allergies: recordText(fresh, 'allergies'),
        medications: medicines,
      );
      for (var index = 0; index < conflicts.length; index++) {
        if (conflicts[index].isNotEmpty &&
            recordText(medicines[index], 'allergy_override_reason') == null) {
          throw const AppointmentDetailException(
            'A medicine conflicts with a recorded allergy. Review the draft in the hospital portal before issuing.',
          );
        }
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Issue this prescription?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recordText(fresh, 'prescription_number') ?? widget.id),
                Text(
                  linkedPatient is Map
                      ? recordText(linkedPatient, 'full_name') ?? patientId
                      : patientId,
                ),
                const SizedBox(height: 12),
                Text(
                  '${medicines.length} medicines · ${tests.length} lab tests',
                ),
                const SizedBox(height: 12),
                const Text(
                  'This finalizes the draft, makes the issued prescription available to the patient, and sends ordered tests to the laboratory.',
                ),
                if (conflicts.any((values) => values.isNotEmpty))
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Recorded allergy overrides are present. Review the recorded reasons before confirming.',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm issue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await widget.service.issuePrescription(widget.session, widget.id);
      if (!mounted) return;
      setState(() {
        issuing = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Prescription issued')));
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          issueUncertain = e is DraftSaveException && e.uncertain;
          issueError = e is DraftSaveException
              ? e.message
              : e is AppointmentDetailException
              ? e.message
              : 'Issue checks could not be completed. Please refresh and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          issuing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = data;
    return PopScope(
      canPop: !issuing,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F3EA),
          foregroundColor: const Color(0xFF207361),
          surfaceTintColor: Colors.transparent,
          title: const Text('Prescription'),
          actions: [
            IconButton(
              tooltip: 'Refresh prescription',
              onPressed: issuing || loading ? null : load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFF7F3EA),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(error!, textAlign: TextAlign.center),
                    ),
                    FilledButton(onPressed: load, child: const Text('Retry')),
                  ],
                ),
              )
            : item == null
            ? const SizedBox.shrink()
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  children: [
                    Text(
                      recordText(item, 'prescription_number') ?? 'Prescription',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    field('Status', recordText(item, 'status')),
                    if (item['patient'] is Map)
                      field(
                        'Patient',
                        recordText(item['patient'] as Map, 'full_name'),
                      ),
                    field(
                      'Chief complaint',
                      recordText(item, 'chief_complaint'),
                    ),
                    field('Diagnosis', recordText(item, 'diagnosis')),
                    for (final entry in {
                      'history_of_presenting_illness':
                          'History of presenting illness',
                      'clinical_examination': 'Examination',
                      'chemotherapy_protocol': 'Chemotherapy protocol',
                    }.entries)
                      if (recordText(item, entry.key) != null)
                        field(entry.value, recordText(item, entry.key)),
                    const Divider(),
                    Text(
                      'Medicines',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (recordList(item['medications']).isEmpty)
                      const Text('No medicines recorded.'),
                    for (final medicine in recordList(item['medications']))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              field(
                                'Medicine',
                                recordText(medicine, 'medicine_name'),
                              ),
                              field('Dosage', recordText(medicine, 'dosage')),
                              field(
                                'Frequency',
                                recordText(medicine, 'frequency'),
                              ),
                              field(
                                'Duration',
                                recordText(medicine, 'duration'),
                              ),
                              field(
                                'Quantity',
                                recordText(medicine, 'quantity'),
                              ),
                              field(
                                'Instructions',
                                recordText(medicine, 'instructions'),
                              ),
                              if (recordText(
                                    medicine,
                                    'allergy_override_reason',
                                  ) !=
                                  null)
                                field(
                                  'Recorded allergy override reason',
                                  recordText(
                                    medicine,
                                    'allergy_override_reason',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    if (recordList(item['lab_tests']).isNotEmpty) ...[
                      Text(
                        'Investigations',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final test in recordList(item['lab_tests']))
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                field('Test', recordText(test, 'test_name')),
                                field('Priority', recordText(test, 'priority')),
                                field(
                                  'Instructions',
                                  recordText(test, 'instructions'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    if (recordText(item, 'investigation_notes') != null)
                      field(
                        'Investigation notes',
                        recordText(item, 'investigation_notes'),
                      ),
                    field('Advice', recordText(item, 'advice')),
                    field('Follow-up date', recordText(item, 'follow_up_date')),
                    field(
                      'Follow-up advice',
                      recordText(item, 'follow_up_advice'),
                    ),
                    if (issueError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          issueError!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    if (widget.pharmacyContext &&
                        item['status'] == 'issued' &&
                        [
                          'pharmacist',
                          'hospital_admin',
                        ].contains(widget.session.role))
                      FilledButton.icon(
                        onPressed: issuing || dispenseUncertain
                            ? null
                            : dispense,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF207361),
                        ),
                        icon: const Icon(Icons.medication_outlined),
                        label: Text(issuing ? 'Checking…' : 'Dispense'),
                      ),
                    if (item['status'] == 'draft' &&
                        [
                          'doctor',
                          'hospital_admin',
                        ].contains(widget.session.role.toLowerCase())) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Review the complete draft before issuing. Edits to a saved draft can currently be made in the hospital portal.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: issuing || issueUncertain ? null : issue,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          issuing ? 'Checking…' : 'Issue prescription',
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget field(String label, String? text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF718594))),
        Text(text ?? 'Not recorded'),
      ],
    ),
  );
}
