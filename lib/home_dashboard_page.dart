import 'package:flutter/material.dart';

import 'doctor_dashboard_view.dart';
import 'appointment.dart';
import 'appointment_detail_page.dart';
import 'auth_service.dart';
import 'clinical_directory.dart';
import 'doctor_dashboard_service.dart';
import 'home_snapshot.dart';
import 'patient_detail_page.dart';
import 'patient_records.dart';

const _brand = Color(0xFF087F83);

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({
    super.key,
    required this.session,
    required this.service,
    required this.onVisits,
    required this.onDirectory,
  });
  final AuthSession session;
  final DoctorDashboardService service;
  final void Function(DateTime date) onVisits;
  final void Function(ClinicalDirectory directory) onDirectory;
  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage>
    with WidgetsBindingObserver {
  DoctorProfile? profile;
  HomeSnapshot? snapshot;
  DateTime date = DateUtils.dateOnly(DateTime.now());
  DateTime? refreshed;
  bool loading = true;
  bool _requestInFlight = false;
  String? error;
  int? unread;
  String filter = 'All';
  bool get isDoctor => profile?.role.toLowerCase() == 'doctor';
  String get dateLabel =>
      MaterialLocalizations.of(context).formatFullDate(date);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loading) {
      load();
    }
  }

  Future<void> load() async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    setState(() {
      loading = true;
      error = null;
      snapshot = null;
    });
    try {
      final identity = await widget.service.fetchProfile(widget.session);
      if (!mounted) return;
      setState(() {
        profile = identity;
        if (isDoctor) date = DateUtils.dateOnly(DateTime.now());
      });
      final result = await widget.service.fetchHome(
        widget.session,
        identity,
        date,
      );
      if (!mounted) return;
      setState(() {
        snapshot = result;
        loading = false;
        refreshed = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e is AppointmentDetailException ? e.message : 'Unable to load your dashboard. Check your connection and try again.';
      });
    }
    try {
      final count = await widget.service.fetchUnreadNotifications(
        widget.session,
      );
      if (mounted) {
        setState(() {
          unread = count;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          unread = null;
        });
      }
    }
    _requestInFlight = false;
  }

  Future<void> pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || selected == null || selected == date) return;
    setState(() {
      date = selected;
      filter = 'All';
    });
    await load();
  }

  void openAppointment(Appointment item) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AppointmentDetailPage(
        session: widget.session,
        appointmentId: item.id,
        service: widget.service,
      ),
    ),
  );
  Future<void> openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _NotificationsPage(
          session: widget.session,
          service: widget.service,
        ),
      ),
    );
    if (mounted) {
      try {
        final count = await widget.service.fetchUnreadNotifications(
          widget.session,
        );
        if (mounted) {
          setState(() {
            unread = count;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            unread = null;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => DoctorDashboardView(
    name: profile?.name ?? widget.session.name,
    hospital: profile?.hospitalName ?? 'Samagati City Hospital',
    isDoctor: isDoctor,
    date: date,
    data: snapshot,
    loading: loading,
    error: error,
    unread: unread,
    filter: filter,
    onFilter: (value) => setState(() => filter = value),
    onRefresh: load,
    onPickDate: pickDate,
    onDate: (value) {
      if (loading || (isDoctor && !DateUtils.isSameDay(value, DateTime.now()))) {
        return;
      }
      setState(() {
        date = value;
        filter = 'All';
      });
      load();
    },
    onNotifications: openNotifications,
    onVisits: () => widget.onVisits(date),
    onDirectory: widget.onDirectory,
    onAppointment: openAppointment,
    onPatient: (id) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientDetailPage(
          session: widget.session,
          patientId: id,
          service: widget.service,
        ),
      ),
    ),
  );
}

class _NotificationsPage extends StatefulWidget {
  const _NotificationsPage({required this.session, required this.service});
  final AuthSession session;
  final DoctorDashboardService service;
  @override
  State<_NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<_NotificationsPage> {
  PatientRecordPage? data;
  String? error;
  bool loading = true;
  int page = 1;
  Future<void> markRead({String? id}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.service.markNotificationsRead(widget.session, id: id);
      if (mounted) await load(page);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Unable to mark notifications as read. Please try again.';
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    load(1);
  }

  Future<void> load(int target) async {
    setState(() {
      loading = true;
      error = null;
      data = null;
      page = target;
    });
    try {
      final result = await widget.service.fetchNotifications(
        widget.session,
        page: target,
      );
      if (mounted) {
        setState(() {
          data = result;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e is AppointmentDetailException
              ? e.message
              : 'Unable to load notifications. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notifications'),
      actions: [
        TextButton(
          onPressed: loading ? null : () => markRead(),
          child: const Text('Mark all read'),
        ),
      ],
    ),
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
                FilledButton(
                  onPressed: () => load(page),
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: () => load(page),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18),
              children: [
                if (data?.items.isEmpty == true)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text('No notifications on this page.'),
                  ),
                for (final item in data?.items ?? <Map<String, dynamic>>[])
                  Card(
                    child: ListTile(
                      leading: Icon(
                        item['is_read'] == true
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color: _brand,
                      ),
                      title: Text(recordText(item, 'title') ?? 'Notification'),
                      trailing: item['is_read'] == true
                          ? null
                          : IconButton(
                              tooltip: 'Mark as read',
                              onPressed: () =>
                                  markRead(id: item['id'] as String),
                              icon: const Icon(Icons.done),
                            ),
                      subtitle: Text(
                        '${recordText(item, 'message') ?? ''}\n${recordText(item, 'created_at') ?? ''}',
                      ),
                    ),
                  ),
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
