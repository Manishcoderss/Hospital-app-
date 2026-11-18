import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_dashboard_service.dart';
import 'patient_records.dart';

class LabReportPage extends StatefulWidget {
  const LabReportPage({
    super.key,
    required this.session,
    required this.patientId,
    required this.orderId,
    required this.service,
  });
  final AuthSession session;
  final String patientId;
  final String orderId;
  final DoctorDashboardService service;
  @override
  State<LabReportPage> createState() => _LabReportPageState();
}

class _LabReportPageState extends State<LabReportPage> {
  Map<String, dynamic>? report;
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
      report = null;
    });
    try {
      final data = await widget.service.fetchLabReport(
        widget.session,
        widget.orderId,
        widget.patientId,
      );
      if (!mounted) return;
      setState(() {
        report = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e is AppointmentDetailException
            ? e.message
            : 'Unable to read this report. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = report;
    final tests = data == null
        ? <Map<String, dynamic>>[]
        : recordList(data['tests']);
    final pending = tests.any(
      (test) => test['status'] != 'completed' && test['status'] != 'cancelled',
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F3EA),
        foregroundColor: const Color(0xFF207361),
        surfaceTintColor: Colors.transparent,
        title: const Text('Lab Report'),
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
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  Text(
                    recordText(data!, 'order_number') ?? 'Laboratory report',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (data['patient'] is Map)
                    Text(
                      recordText(data['patient'] as Map, 'full_name') ??
                          'Patient',
                    ),
                  Text(
                    'Order status: ${recordText(data, 'status') ?? 'Unavailable'}',
                  ),
                  if (pending)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Provisional report — some tests are still awaiting results.',
                      ),
                    ),
                  if (tests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No test results returned.'),
                    ),
                  for (final test in tests) testCard(test),
                  if (recordText(data, 'notes') != null)
                    Text('Notes: ${recordText(data, 'notes')}'),
                ],
              ),
            ),
    );
  }

  Widget testCard(Map<String, dynamic> test) {
    final results = recordList(test['results']);
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recordText(test, 'test_name') ?? 'Test',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Status: ${recordText(test, 'status') ?? 'Unavailable'}'),
            const Divider(height: 24),
            if (results.isEmpty) ...resultFields(test, nameKey: 'test_name'),
            for (final result in results) ...[
              if (recordText(result, 'section') != null)
                Text(recordText(result, 'section')!),
              ...resultFields(result, nameKey: 'name'),
              const Divider(height: 24),
            ],
            if (recordText(test, 'result_notes') != null)
              Text('Notes: ${recordText(test, 'result_notes')}'),
          ],
        ),
      ),
    );
  }

  List<Widget> resultFields(
    Map<String, dynamic> result, {
    required String nameKey,
  }) {
    final flag = recordText(result, 'flag');
    final abnormal =
        result['is_abnormal'] == true || ['H', 'L', 'A'].contains(flag);
    return [
      if (recordText(result, nameKey) != null)
        Text(recordText(result, nameKey)!),
      Text(
        'Result: ${recordText(result, 'result_value') ?? recordText(result, 'value') ?? 'Pending / not recorded'}',
        style: TextStyle(
          color: abnormal ? Colors.red.shade800 : const Color(0xFF203D50),
          fontWeight: abnormal ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      Text('Unit: ${recordText(result, 'unit') ?? 'Not recorded'}'),
      Text(
        'Reference range: ${recordText(result, 'normal_range') ?? 'Not recorded'}',
      ),
      if (abnormal)
        Text(
          'Lab flag: ${flag ?? 'Abnormal'}',
          style: TextStyle(color: Colors.red.shade800),
        ),
    ];
  }
}
