import 'package:flutter/material.dart';

import 'appointment_booking_service.dart';
import 'auth_service.dart';

class AppointmentBookingPage extends StatefulWidget {
  const AppointmentBookingPage({
    super.key,
    required this.session,
    this.service,
    this.patientId,
  });
  final AuthSession session;
  final AppointmentBookingService? service;
  final String? patientId;
  @override
  State<AppointmentBookingPage> createState() => _AppointmentBookingPageState();
}

class _AppointmentBookingPageState extends State<AppointmentBookingPage> {
  late final service = widget.service ?? AppointmentBookingService();
  final search = TextEditingController(),
      reason = TextEditingController(),
      symptoms = TextEditingController();
  List<Map<String, dynamic>> doctors = [], patients = [];
  List<String> slots = [];
  String? doctorId, patientId, time, error, searchError, slotError;
  DateTime date = DateUtils.dateOnly(DateTime.now());
  bool loading = true,
      searching = false,
      loadingSlots = false,
      saving = false,
      uncertain = false,
      followUp = false,
      searched = false;
  int slotRequest = 0, searchRequest = 0;
  String get dateValue =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    reason.dispose();
    symptoms.dispose();
    if (widget.service == null) service.close();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final options = await service.doctors(widget.session);
      patientId = widget.patientId;
      String? ownId;
      try {
        if (widget.session.role.toLowerCase() == 'doctor')
          ownId = await service.ownDoctorId(widget.session);
      } on BookingException catch (e) {
        // The web form treats /doctors/me as a suggested selection only.
        // Dropdown and booking endpoints enforce the user's permissions.
        if (![403, 404].contains(e.statusCode)) rethrow;
      }
      if (!mounted) return;
      setState(() {
        doctors = options;
        doctorId = options.any((item) => item['id'] == ownId) ? ownId : null;
        loading = false;
      });
      await loadSlots();
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e is BookingException
              ? e.message
              : 'Unable to load booking options.';
        });
      }
    }
  }

  Future<void> findPatients() async {
    if (search.text.trim().isEmpty) return;
    final request = ++searchRequest;
    setState(() {
      searching = true;
      searchError = null;
      patientId = null;
      patients = [];
    });
    try {
      final result = await service.patients(widget.session, search.text);
      if (!mounted || request != searchRequest) return;
      setState(() {
        patients = result;
        searched = true;
        searching = false;
      });
    } catch (e) {
      if (mounted && request == searchRequest) {
        setState(() {
          searching = false;
          searchError = e is BookingException
              ? e.message
              : 'Patient search failed.';
        });
      }
    }
  }

  Future<void> loadSlots() async {
    final id = doctorId;
    if (id == null) return;
    final request = ++slotRequest;
    setState(() {
      loadingSlots = true;
      slotError = null;
      time = null;
      slots = [];
    });
    try {
      final result = await service.slots(widget.session, id, dateValue);
      if (!mounted || request != slotRequest) return;
      final now = DateTime.now();
      setState(() {
        slots = result
            .where(
              (value) => DateTime(
                date.year,
                date.month,
                date.day,
                int.parse(value.split(':')[0]),
                int.parse(value.split(':')[1]),
              ).isAfter(now),
            )
            .toList();
        loadingSlots = false;
      });
    } catch (e) {
      if (mounted && request == slotRequest) {
        setState(() {
          loadingSlots = false;
          slotError = e is BookingException
              ? e.message
              : 'Unable to load available times.';
        });
      }
    }
  }

  Future<void> save() async {
    if (saving ||
        uncertain ||
        patientId == null ||
        doctorId == null ||
        time == null) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await service.book(
        widget.session,
        patientId: patientId!,
        doctorId: doctorId!,
        date: dateValue,
        time: time!,
        reason: reason.text,
        symptoms: symptoms.text,
        followUp: followUp,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        uncertain = e is BookingException && e.uncertain;
        error = e is BookingException
            ? e.message
            : 'Unable to book appointment.';
      });
      if (!uncertain) await loadSlots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = saving || uncertain;
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F3EA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F3EA),
          surfaceTintColor: Colors.transparent,
          title: const Text('Book appointment'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Pick the patient, doctor and an available time.',
                    style: TextStyle(color: Color(0xFF6B7E98)),
                  ),
                  const SizedBox(height: 18),
                  if (error != null) ...[
                    Text(
                      error!,
                      style: const TextStyle(color: Color(0xFFB42318)),
                    ),
                    if (doctors.isEmpty)
                      TextButton(onPressed: load, child: const Text('Retry')),
                    const SizedBox(height: 12),
                  ],
                  if (doctors.isNotEmpty) ...[
                    if (widget.patientId == null) ...[
                      TextField(
                        controller: search,
                        enabled: !locked,
                        decoration: InputDecoration(
                          labelText: 'Search patient by name, number or mobile',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: 'Search patients',
                            onPressed: locked || searching
                                ? null
                                : findPatients,
                            icon: const Icon(Icons.search),
                          ),
                        ),
                        onSubmitted: (_) => findPatients(),
                        onChanged: (_) {
                          searchRequest++;
                          setState(() {
                            patientId = null;
                            patients = [];
                            searched = false;
                            searching = false;
                          });
                        },
                      ),
                      if (searching) const LinearProgressIndicator(),
                      if (searchError != null)
                        Text(
                          searchError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      if (searched && patients.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('No patients found. Try another search.'),
                        ),
                      for (final patient in patients)
                        ListTile(
                          selected: patientId == patient['id'],
                          leading: Icon(
                            patientId == patient['id']
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          onTap: locked
                              ? null
                              : () => setState(() {
                                  patientId = patient['id'] as String;
                                }),
                          title: Text(
                            (patient['full_name'] ??
                                    patient['name'] ??
                                    patient['label'] ??
                                    'Patient')
                                .toString(),
                          ),
                          subtitle: Text(
                            (patient['patient_number'] ?? '').toString(),
                          ),
                        ),
                      const SizedBox(height: 18),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: doctorId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Doctor',
                        border: OutlineInputBorder(),
                      ),
                      items: doctors
                          .map(
                            (item) => DropdownMenuItem(
                              value: item['id'] as String,
                              child: Text(
                                (item['name'] ?? 'Doctor').toString(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: locked
                          ? null
                          : (id) {
                              setState(() {
                                doctorId = id;
                              });
                              loadSlots();
                            },
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: locked
                          ? null
                          : () async {
                              final now = DateUtils.dateOnly(DateTime.now());
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: date.isBefore(now) ? now : date,
                                firstDate: now,
                                lastDate: DateTime(now.year + 2),
                              );
                              if (picked == null || !mounted) return;
                              setState(() {
                                date = picked;
                              });
                              loadSlots();
                            },
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(date),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Available times',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (doctorId == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Choose a doctor to see available times.'),
                      )
                    else if (loadingSlots)
                      const LinearProgressIndicator()
                    else if (slotError != null) ...[
                      Text(slotError!),
                      TextButton(
                        onPressed: locked ? null : loadSlots,
                        child: const Text('Retry availability'),
                      ),
                    ] else if (slots.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No available times. Choose another date or doctor.',
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final slot in slots)
                            ChoiceChip(
                              label: Text(slot),
                              selected: time == slot,
                              onSelected: locked
                                  ? null
                                  : (_) => setState(() {
                                      time = slot;
                                    }),
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: reason,
                      enabled: !locked,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason for visit',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: symptoms,
                      enabled: !locked,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Symptoms',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('This is a follow-up visit'),
                      value: followUp,
                      onChanged: locked
                          ? null
                          : (value) => setState(() {
                              followUp = value ?? false;
                            }),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed:
                          locked ||
                              loadingSlots ||
                              patientId == null ||
                              time == null
                          ? null
                          : save,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF127467),
                        padding: const EdgeInsets.all(16),
                      ),
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.event_available),
                      label: Text(saving ? 'Booking…' : 'Book appointment'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
