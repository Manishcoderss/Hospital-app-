import 'package:flutter/material.dart';

import 'appointment.dart';
import 'appointment_page.dart';
import 'auth_service.dart';
import 'doctor_dashboard_service.dart';
import 'prescription_draft_page.dart';

class PrescriptionVisitPicker extends StatefulWidget {
  const PrescriptionVisitPicker({
    super.key,
    required this.session,
    required this.service,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  @override
  State<PrescriptionVisitPicker> createState() =>
      _PrescriptionVisitPickerState();
}

class _PrescriptionVisitPickerState extends State<PrescriptionVisitPicker> {
  DateTime date = DateUtils.dateOnly(DateTime.now());
  AppointmentPage? data;
  int page = 1, request = 0;
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load(1);
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
      final result = AppointmentPage.fromJson(
        await widget.service.fetchAppointments(
          widget.session,
          selectedDate: date,
          page: target,
        ),
      );
      if (mounted && current == request) {
        setState(() {
          data = result;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted && current == request) {
        setState(() {
          loading = false;
          error = e is AppointmentDetailException
              ? e.message
              : 'Unable to load appointments. Please retry.';
        });
      }
    }
  }

  Future<void> open(Appointment item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrescriptionDraftPage(
          session: widget.session,
          appointment: item,
          service: widget.service,
        ),
      ),
    );
    if (mounted) await load(page);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F3EA),
    appBar: AppBar(
      title: const Text('New prescription'),
      backgroundColor: const Color(0xFFF7F3EA),
      foregroundColor: const Color(0xFF207361),
      surfaceTintColor: Colors.transparent,
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Choose the patient visit',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w700,
            color: Color(0xFF20312D),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select an appointment to load the patient and clinical history into your prescription.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: loading
              ? null
              : () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (!mounted || picked == null) return;
                  setState(() {
                    date = picked;
                  });
                  await load(1);
                },
          icon: const Icon(Icons.calendar_month, color: Color(0xFF207361)),
          label: Text(MaterialLocalizations.of(context).formatMediumDate(date)),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF207361)),
            ),
          ),
        if (error != null) ...[
          Text(error!),
          TextButton(onPressed: () => load(page), child: const Text('Retry')),
        ],
        if (!loading && error == null && data?.items.isEmpty == true)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No appointments on this date. Choose the date of the patient visit.',
            ),
          ),
        for (final item in data?.items ?? <Appointment>[])
          Card(
            color: Colors.white,
            child: ListTile(
              title: Text(item.patientName),
              subtitle: Text(
                '${item.time} · ${item.doctorName}\n${item.reason ?? 'Reason not recorded'}',
              ),
              isThreeLine: true,
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFF207361),
              ),
              enabled:
                  item.patientId != null &&
                  !['cancelled', 'no_show'].contains(item.status),
              onTap: () => open(item),
            ),
          ),
        if (data != null && (page > 1 || data!.hasNext))
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: page > 1 ? () => load(page - 1) : null,
                child: const Text('Previous'),
              ),
              Text('Page $page'),
              TextButton(
                onPressed: data!.hasNext ? () => load(page + 1) : null,
                child: const Text('Next'),
              ),
            ],
          ),
      ],
    ),
  );
}
