import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'clinical_directory.dart';
import 'doctor_dashboard_service.dart';
import 'patient_records.dart';
import 'patient_detail_page.dart';
import 'lab_report_page.dart';
import 'prescription_detail_page.dart';
import 'prescriptions_page.dart';
import 'laboratory_page.dart';
import 'pharmacy_page.dart';
import 'patients_page.dart';

class ClinicalDirectoryPage extends StatefulWidget {
  const ClinicalDirectoryPage({
    super.key,
    required this.session,
    required this.service,
    required this.directory,
    this.embedded = false,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  final ClinicalDirectory directory;
  final bool embedded;
  @override
  State<ClinicalDirectoryPage> createState() => _ClinicalDirectoryPageState();
}

class _ClinicalDirectoryPageState extends State<ClinicalDirectoryPage> {
  final searchController = TextEditingController();
  PatientRecordPage? data;
  String query = '';
  String? error;
  int page = 1;
  int request = 0;
  bool loading = true;
  bool get isPatients => widget.directory == ClinicalDirectory.patients;
  bool get canSearch =>
      widget.directory == ClinicalDirectory.patients ||
      widget.directory == ClinicalDirectory.ipd;
  @override
  void initState() {
    super.initState();
    if (![
      ClinicalDirectory.prescriptions,
      ClinicalDirectory.labs,
      ClinicalDirectory.pharmacy,
      ClinicalDirectory.patients,
    ].contains(widget.directory)) {
      load(1);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load(int target) async {
    final current = ++request;
    setState(() {
      loading = true;
      error = null;
      data = null;
      page = target;
    });
    try {
      final result = await widget.service.fetchDirectory(
        widget.session,
        widget.directory,
        page: target,
        search: query,
      );
      if (!mounted || current != request) return;
      setState(() {
        data = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted || current != request) return;
      setState(() {
        loading = false;
        error = e is AppointmentDetailException
            ? e.message
            : 'Unable to load records. Please try again.';
      });
    }
  }

  void search() {
    query = searchController.text.trim();
    load(1);
  }

  @override
  Widget build(BuildContext context) =>
      widget.directory == ClinicalDirectory.prescriptions
      ? PrescriptionsPage(session: widget.session, service: widget.service)
      : widget.directory == ClinicalDirectory.labs
      ? LaboratoryPage(session: widget.session, service: widget.service)
      : widget.directory == ClinicalDirectory.pharmacy
      ? PharmacyPage(session: widget.session, service: widget.service)
      : widget.directory == ClinicalDirectory.patients
      ? PatientsPage(
          session: widget.session,
          service: widget.service,
          embedded: widget.embedded,
        )
      : Scaffold(
          backgroundColor: isPatients
              ? const Color(0xFFF3F7FD)
              : const Color(0xFFF5F9F9),
          appBar: AppBar(
            title: Text(widget.directory.title),
            backgroundColor: isPatients ? const Color(0xFFF3F7FD) : null,
            foregroundColor: isPatients ? const Color(0xFF14345C) : null,
            surfaceTintColor: Colors.transparent,
          ),
          body: Column(
            children: [
              if (isPatients)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE3EDFF), Color(0xFFF0F5FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        color: Color(0xFF2563EB),
                        size: 30,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Patient directory',
                        style: TextStyle(
                          color: Color(0xFF14345C),
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Find a patient and view their care history.',
                        style: TextStyle(
                          color: Color(0xFF657D99),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              if (canSearch)
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => search(),
                    decoration: InputDecoration(
                      labelText: 'Search patients',
                      filled: isPatients,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          isPatients ? 16 : 4,
                        ),
                        borderSide: const BorderSide(color: Color(0xFFE3EBF8)),
                      ),
                      enabledBorder: isPatients
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3EBF8),
                              ),
                            )
                          : null,
                      focusedBorder: isPatients
                          ? OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                                width: 1.5,
                              ),
                            )
                          : null,
                      suffixIcon: IconButton(
                        tooltip: 'Search',
                        onPressed: search,
                        icon: Icon(
                          Icons.search,
                          color: isPatients ? const Color(0xFF2563EB) : null,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: isPatients ? const Color(0xFF2563EB) : null,
                        ),
                      )
                    : error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () => load(page),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: isPatients ? const Color(0xFF2563EB) : null,
                        onRefresh: () => load(page),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(18),
                          children: [
                            if (widget.directory == ClinicalDirectory.ipd)
                              const Text('Active admissions'),
                            Text(
                              '${data?.total ?? 0} records${query.isEmpty ? '' : ' matching "$query"'}',
                              style: isPatients
                                  ? const TextStyle(
                                      color: Color(0xFF657D99),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            if (data?.items.isEmpty == true)
                              const Text('No matching records found.'),
                            for (final item
                                in data?.items ?? <Map<String, dynamic>>[])
                              recordCard(item),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: page > 1
                                      ? () => load(page - 1)
                                      : null,
                                  child: const Text('Previous'),
                                ),
                                Text('Page $page'),
                                TextButton(
                                  onPressed: data?.hasNext == true
                                      ? () => load(page + 1)
                                      : null,
                                  child: const Text('Next'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
  Widget recordCard(Map<String, dynamic> item) {
    final patient = item['patient'];
    final isPatient = widget.directory == ClinicalDirectory.patients;
    final patientName = isPatient
        ? recordText(item, 'full_name')
        : patient is Map
        ? recordText(patient, 'full_name')
        : null;
    final number = recordText(item, switch (widget.directory) {
      ClinicalDirectory.patients => 'patient_number',
      ClinicalDirectory.prescriptions => 'prescription_number',
      ClinicalDirectory.labs => 'order_number',
      ClinicalDirectory.ipd => 'admission_number',
      ClinicalDirectory.pharmacy => 'prescription_number',
    });
    final linkedPatient = isPatient
        ? item['id']
        : item['patient_id'] ?? (patient is Map ? patient['id'] : null);
    final canOpen =
        widget.directory == ClinicalDirectory.prescriptions ||
        linkedPatient is String && linkedPatient.isNotEmpty;
    return Card(
      elevation: isPatient ? 0 : null,
      color: isPatient ? Colors.white : null,
      shape: isPatient
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE3EBF8)),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: isPatient
            ? Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF3FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF2563EB),
                  size: 25,
                ),
              )
            : null,
        title: Text(
          patientName ?? number ?? 'Record',
          style: isPatient
              ? const TextStyle(
                  color: Color(0xFF14345C),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )
              : null,
        ),
        subtitleTextStyle: isPatient
            ? const TextStyle(
                color: Color(0xFF657D99),
                fontSize: 12,
                height: 1.6,
              )
            : null,
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (number != null) Text(number),
            if (isPatient)
              Text(
                [
                  recordText(item, 'age'),
                  recordText(item, 'gender'),
                ].whereType<String>().join(' · '),
              ),
            if (!isPatient)
              Text(recordText(item, 'status') ?? 'Status unavailable'),
            if (widget.directory == ClinicalDirectory.prescriptions)
              Text(
                recordText(item, 'diagnosis') ??
                    recordText(item, 'chief_complaint') ??
                    'Diagnosis not recorded',
              ),
            if (widget.directory == ClinicalDirectory.ipd) ...[
              Text(
                recordText(item, 'provisional_diagnosis') ??
                    'Diagnosis not recorded',
              ),
              if (item['current_bed'] is Map)
                Text(
                  [
                    recordText(item['current_bed'] as Map, 'ward'),
                    recordText(item['current_bed'] as Map, 'bed_number'),
                  ].whereType<String>().join(' · '),
                ),
            ],
            if (canOpen)
              Text(
                switch (widget.directory) {
                  ClinicalDirectory.prescriptions => 'View prescription',
                  ClinicalDirectory.labs => 'View report',
                  _ => 'View patient',
                },
                style: TextStyle(
                  color: isPatient
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF087F83),
                ),
              ),
            if (!canOpen) const Text('Patient link unavailable'),
          ],
        ),
        trailing: canOpen
            ? Icon(
                Icons.chevron_right,
                color: isPatient ? const Color(0xFF2563EB) : null,
              )
            : null,
        onTap: !canOpen
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => switch (widget.directory) {
                    ClinicalDirectory.prescriptions => PrescriptionDetailPage(
                      session: widget.session,
                      id: item['id'] as String,
                      service: widget.service,
                    ),
                    ClinicalDirectory.labs => LabReportPage(
                      session: widget.session,
                      patientId: linkedPatient as String,
                      orderId: item['id'] as String,
                      service: widget.service,
                    ),
                    _ => PatientDetailPage(
                      session: widget.session,
                      patientId: linkedPatient as String,
                      service: widget.service,
                    ),
                  },
                ),
              ),
      ),
    );
  }
}
