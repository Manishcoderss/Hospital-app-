import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'doctor_read_audit.dart';

const doctorQaEnabled = kDebugMode && bool.fromEnvironment('DOCTOR_LIVE_QA');

/// Debug-only check of a record explicitly selected by the tester in the app.
class DoctorRecordCheckButton extends StatefulWidget {
  const DoctorRecordCheckButton({
    super.key,
    required this.session,
    this.patientId = '',
    this.appointmentId = '',
  });
  final AuthSession session;
  final String patientId, appointmentId;
  @override
  State<DoctorRecordCheckButton> createState() =>
      _DoctorRecordCheckButtonState();
}

class _DoctorRecordCheckButtonState extends State<DoctorRecordCheckButton> {
  bool busy = false;

  Future<void> check() async {
    if (busy || !doctorQaEnabled) return;
    setState(() => busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check this dummy record?'),
          content: const Text(
            'Confirm this is your dummy test record. This check only reads data and records pass/fail status. It does not save or change any record.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Run read check'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      var failed = false;
      await DoctorReadAudit().run(
        widget.session,
        patientId: widget.patientId,
        appointmentId: widget.appointmentId,
        recordsOnly: true,
        report: (line) {
          debugPrint('DOCTOR_RECORD_QA|$line');
          if (line.contains('|not_verified|') ||
              line.contains('|contract_error|') ||
              line.contains('|not_found|') ||
              line.contains('|expired|') ||
              line.contains('|http_error|') ||
              line.contains('|client_error|') ||
              line.contains('|restricted|') ||
              line.contains('|rate_limited|')) {
            failed = true;
          }
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failed
                  ? 'Read check found an issue. See the QA status report.'
                  : 'Selected record read checks passed.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Check test record (read-only)',
    onPressed: busy ? null : check,
    icon: busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.fact_check_outlined),
  );
}
