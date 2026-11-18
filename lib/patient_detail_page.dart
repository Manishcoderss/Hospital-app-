import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_record_check_button.dart';
import 'doctor_dashboard_service.dart';
import 'patient.dart';
import 'patient_records_page.dart';

class PatientDetailPage extends StatefulWidget {
  const PatientDetailPage({
    super.key,
    required this.session,
    required this.patientId,
    required this.service,
  });
  final AuthSession session;
  final String patientId;
  final DoctorDashboardService service;
  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  Patient? patient;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      patient = null;
      error = null;
    });
    try {
      final result = await widget.service.fetchPatient(
        widget.session,
        widget.patientId,
      );
      if (!mounted) return;
      setState(() {
        patient = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e is AppointmentDetailException
            ? e.message
            : 'Unable to connect. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = patient;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F3EA),
        foregroundColor: const Color(0xFF207361),
        surfaceTintColor: Colors.transparent,
        title: const Text('Patient Detail'),
        actions: [
          if (doctorQaEnabled && item != null)
            DoctorRecordCheckButton(
              session: widget.session,
              patientId: item.id,
            ),
          IconButton(
            onPressed: loading ? null : load,
            tooltip: 'Refresh patient',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: load, child: const Text('Retry')),
                  ],
                ),
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const Divider(height: 28),
                          field('Patient number', item.number),
                          field('Age', item.age),
                          field('Gender', item.gender),
                          field('Blood group', item.bloodGroup),
                          field('Phone', item.phone),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clinical history',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          field('Allergies', item.allergies),
                          field('Medical history', item.medicalHistory),
                          field('Past surgical history', item.surgicalHistory),
                          field(
                            'Past chemotherapy history',
                            item.chemotherapyHistory,
                          ),
                          field(
                            'Past radiation history',
                            item.radiationHistory,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.history),
                            title: const Text('Visit History'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => openRecords(labs: false),
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.science_outlined),
                            title: const Text('Lab Reports'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => openRecords(labs: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void openRecords({required bool labs}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientRecordsPage(
          session: widget.session,
          patientId: widget.patientId,
          service: widget.service,
          labs: labs,
        ),
      ),
    );
  }

  Widget field(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF718594), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value ?? 'Not recorded',
          style: const TextStyle(color: Color(0xFF203D50), fontSize: 16),
        ),
      ],
    ),
  );
}
