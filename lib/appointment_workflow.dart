import 'package:flutter/material.dart';

import 'appointment.dart';
import 'auth_service.dart';
import 'doctor_dashboard_service.dart';

class AppointmentWorkflow extends StatefulWidget {
  const AppointmentWorkflow({
    super.key,
    required this.appointment,
    required this.session,
    required this.service,
    required this.onUpdated,
  });
  final Appointment appointment;
  final AuthSession session;
  final DoctorDashboardService service;
  final Future<void> Function() onUpdated;
  @override
  State<AppointmentWorkflow> createState() => _AppointmentWorkflowState();
}

class _AppointmentWorkflowState extends State<AppointmentWorkflow> {
  bool saving = false, uncertain = false, reviewing = false;
  String? error;

  Future<void> update(String next) async {
    if (saving || uncertain || reviewing) return;
    setState(() {
      reviewing = true;
    });
    final diagnosis = TextEditingController(text: widget.appointment.diagnosis);
    final notes = TextEditingController(text: widget.appointment.doctorNotes);
    DateTime? followUp = DateTime.tryParse(
      widget.appointment.followUpDate ?? '',
    );
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              next == 'completed'
                  ? 'Complete consultation'
                  : next == 'confirmed'
                  ? 'Check in patient?'
                  : 'Start consultation?',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.appointment.patientName),
                  if (next == 'completed') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: diagnosis,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Diagnosis'),
                    ),
                    TextField(
                      controller: notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Doctor notes',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final today = DateUtils.dateOnly(DateTime.now());
                        final picked = await showDatePicker(
                          context: context,
                          initialDate:
                              followUp != null && !followUp!.isBefore(today)
                              ? followUp!
                              : today.add(const Duration(days: 7)),
                          firstDate: today,
                          lastDate: DateTime(today.year + 5),
                        );
                        if (picked != null && context.mounted) {
                          setDialogState(() {
                            followUp = picked;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        followUp == null
                            ? 'Follow-up date (optional)'
                            : MaterialLocalizations.of(context)
                                  .formatMediumDate(followUp!),
                      ),
                    ),
                    if (followUp != null)
                      TextButton(
                        onPressed: () => setDialogState(() {
                          followUp = null;
                        }),
                        child: const Text('Clear follow-up date'),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go back'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(next == 'completed' ? 'Complete' : 'Confirm'),
              ),
            ],
          ),
        ),
      );
      if (approved != true || !mounted) return;
      setState(() {
        saving = true;
        error = null;
      });
      final fresh = await widget.service.fetchAppointmentDetail(
        widget.session,
        widget.appointment.id,
      );
      if (fresh.status != widget.appointment.status) {
        throw const AppointmentStatusException(
          'This appointment has changed. Refresh before continuing.',
        );
      }
      await widget.service.updateAppointmentStatus(
        widget.session,
        fresh,
        status: next,
        diagnosis: diagnosis.text,
        notes: notes.text,
        followUpDate: followUp == null
            ? null
            : '${followUp!.year}-${followUp!.month.toString().padLeft(2, '0')}-${followUp!.day.toString().padLeft(2, '0')}',
      );
      if (!mounted) return;
      await widget.onUpdated();
    } catch (e) {
      if (mounted) {
        setState(() {
          uncertain = e is AppointmentStatusException && e.uncertain;
          error = e is AppointmentStatusException
              ? e.message
              : e is AppointmentDetailException
              ? e.message
              : 'Unable to update the appointment. Refresh and try again.';
        });
      }
    } finally {
      diagnosis.dispose();
      notes.dispose();
      if (mounted) {
        setState(() {
          saving = false;
          reviewing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = switch (widget.appointment.status) {
      'scheduled' => 'confirmed',
      'confirmed' => 'in_progress',
      'in_progress' => 'completed',
      _ => null,
    };
    if (next == null ||
        ![
          'doctor',
          'hospital_admin',
          'receptionist',
          'nurse',
        ].contains(widget.session.role)) {
      return const SizedBox.shrink();
    }
    return PopScope(
      canPop: !saving,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  error!,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ),
            FilledButton.icon(
              onPressed: saving || uncertain || reviewing
                  ? null
                  : () => update(next),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF207361),
              ),
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                saving
                    ? 'Updating…'
                    : next == 'confirmed'
                    ? 'Check in'
                    : next == 'in_progress'
                    ? 'Start consult'
                    : 'Complete consultation',
              ),
            ),
            if (uncertain)
              TextButton(
                onPressed: saving ? null : widget.onUpdated,
                child: const Text('Refresh appointment'),
              ),
          ],
        ),
      ),
    );
  }
}
