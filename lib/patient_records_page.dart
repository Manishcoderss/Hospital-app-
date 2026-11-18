import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_dashboard_service.dart';
import 'patient_records.dart';
import 'appointment_detail_page.dart';
import 'lab_report_page.dart';

class PatientRecordsPage extends StatefulWidget {
  const PatientRecordsPage({
    super.key,
    required this.session,
    required this.patientId,
    required this.service,
    required this.labs,
  });
  final AuthSession session;
  final String patientId;
  final DoctorDashboardService service;
  final bool labs;
  @override
  State<PatientRecordsPage> createState() => _PatientRecordsPageState();
}

class _PatientRecordsPageState extends State<PatientRecordsPage> {
  PatientRecordPage? records;
  int page = 1;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load(1);
  }

  Future<void> load(int target) async {
    setState(() {
      loading = true;
      error = null;
      records = null;
    });
    try {
      final result = await widget.service.fetchPatientRecords(
        widget.session,
        widget.patientId,
        labs: widget.labs,
        page: target,
      );
      if (!mounted) return;
      setState(() {
        records = result;
        page = target;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        page = target;
        loading = false;
        error = e is AppointmentDetailException
            ? e.message
            : 'Unable to load records. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = records;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        title: Text(widget.labs ? 'Lab Reports' : 'Visit History'),
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
                    FilledButton(
                      onPressed: () => load(page),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => load(page),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    '${data?.total ?? 0} ${widget.labs ? 'lab orders' : 'visits'}',
                  ),
                  const SizedBox(height: 12),
                  if (data != null && data.items.isEmpty)
                    Text(
                      widget.labs
                          ? 'No lab orders on this page.'
                          : 'No visits on this page.',
                    ),
                  for (final item in data?.items ?? <Map<String, dynamic>>[])
                    recordCard(item),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: page > 1 ? () => load(page - 1) : null,
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
    );
  }

  Widget recordCard(Map<String, dynamic> item) {
    final doctor = item['doctor'];
    final tests = item['tests'];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          recordText(
                item,
                widget.labs ? 'order_number' : 'appointment_number',
              ) ??
              'Record',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              widget.labs
                  ? (recordText(item, 'ordered_at') ??
                        recordText(item, 'created_at') ??
                        'Date unavailable')
                  : '${recordText(item, 'appointment_date') ?? 'Date unavailable'} ${recordText(item, 'appointment_time') ?? ''}',
            ),
            if (doctor is Map)
              Text(recordText(doctor, 'name') ?? 'Doctor unavailable'),
            Text(recordText(item, 'status') ?? 'Status unavailable'),
            if (!widget.labs)
              Text(
                recordText(item, 'diagnosis') ??
                    recordText(item, 'reason') ??
                    'Diagnosis / reason not recorded',
              ),
            if (widget.labs && tests is List)
              for (final test in tests.whereType<Map>())
                Text(recordText(test, 'test_name') ?? 'Lab test'),
            const SizedBox(height: 8),
            Text(
              widget.labs ? 'View report' : 'View visit',
              style: const TextStyle(color: Color(0xFF087F83)),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => widget.labs
                ? LabReportPage(
                    session: widget.session,
                    patientId: widget.patientId,
                    orderId: item['id'] as String,
                    service: widget.service,
                  )
                : AppointmentDetailPage(
                    session: widget.session,
                    appointmentId: item['id'] as String,
                    service: widget.service,
                  ),
          ),
        ),
      ),
    );
  }
}
