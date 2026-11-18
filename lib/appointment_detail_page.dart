import 'package:flutter/material.dart';

import 'appointment.dart';
import 'appointment_workflow.dart';
import 'auth_service.dart';
import 'doctor_record_check_button.dart';
import 'doctor_dashboard_service.dart';
import 'patient_detail_page.dart';
import 'prescription_draft_page.dart';

class AppointmentDetailPage extends StatefulWidget {
  const AppointmentDetailPage({
    super.key,
    required this.session,
    required this.appointmentId,
    required this.service,
  });

  final AuthSession session;
  final String appointmentId;
  final DoctorDashboardService service;

  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  Appointment? appointment;
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
      error = null;
      appointment = null;
    });
    try {
      final result = await widget.service.fetchAppointmentDetail(
        widget.session,
        widget.appointmentId,
      );
      if (!mounted) return;
      setState(() {
        appointment = result;
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
    final item = appointment;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        title: const Text('Appointment Detail'),
        actions: [
          if (doctorQaEnabled && item != null)
            DoctorRecordCheckButton(
              session: widget.session,
              patientId: item.patientId ?? '',
              appointmentId: item.id,
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
                    FilledButton.icon(
                      onPressed: load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
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
                            item.patientName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          if (item.number != null) Text(item.number!),
                          if (item.patientId != null) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PatientDetailPage(
                                    session: widget.session,
                                    patientId: item.patientId!,
                                    service: widget.service,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.person_outline),
                              label: const Text('View Patient'),
                            ),
                          ],
                          const Divider(height: 28),
                          field('Date', item.date),
                          field('Time', item.time),
                          field('Status', item.status.replaceAll('_', ' ')),
                          field('Token', item.tokenNumber?.toString()),
                          field('Doctor', item.doctorName),
                          field('Department', item.department),
                          AppointmentWorkflow(
                            key: ValueKey(item),
                            appointment: item,
                            session: widget.session,
                            service: widget.service,
                            onUpdated: load,
                          ),
                          if (item.patientId != null &&
                              !['cancelled', 'no_show'].contains(item.status) &&
                              [
                                'doctor',
                                'hospital_admin',
                              ].contains(widget.session.role.toLowerCase()))
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PrescriptionDraftPage(
                                    session: widget.session,
                                    appointment: item,
                                    service: widget.service,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.edit_note),
                              label: const Text('Write prescription draft'),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Visit information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          field('Reason', item.reason),
                          field('Symptoms', item.symptoms),
                          field('Diagnosis', item.diagnosis),
                          field('Doctor notes', item.doctorNotes),
                          field('Follow-up date', item.followUpDate),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget field(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
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
          style: const TextStyle(color: Color(0xFF203D50), fontSize: 15),
        ),
      ],
    ),
  );
}
