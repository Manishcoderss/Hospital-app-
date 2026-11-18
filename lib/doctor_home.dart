import 'hospital_workspace.dart' show HospitalServicesHost;
import 'soft_bottom_bar.dart';
import 'appointments_schedule_view.dart';
import 'appointment_booking_page.dart';
import 'appointment_summary_card.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'appointment_response_diagnostics.dart';
import 'appointment_page.dart';
import 'appointment.dart';
import 'appointment_detail_page.dart';
import 'auth_service.dart';
import 'doctor_read_audit.dart';
import 'remembered_session_store.dart';
import 'doctor_dashboard_service.dart';
import 'clinical_directory.dart';
import 'clinical_home_page.dart';
import 'clinical_directory_page.dart';
import 'home_dashboard_page.dart';
import 'profile_page.dart';
import 'main.dart' show LoginPage;

const teal = Color(0xFF087F83);
const navy = Color(0xFF203D50);
const muted = Color(0xFF718594);

class DoctorHome extends StatefulWidget {
  const DoctorHome({
    super.key,
    required this.session,
    this.dashboardService,
    this.sessionStore,
  });

  final AuthSession session;
  final DoctorDashboardService? dashboardService;
  final RememberedSessionStore? sessionStore;

  @override
  State<DoctorHome> createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  late final _dashboardService =
      widget.dashboardService ??
      DoctorDashboardService(
        sessionAudit: kDebugMode && const bool.fromEnvironment('DOCTOR_LIVE_QA')
            ? (check, status) => debugPrint('DOCTOR_AUTH_QA|$check|$status')
            : null,
      );
  late final _sessionStore = widget.sessionStore ?? RememberedSessionStore();
  int selectedTab = 0;
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());

  String get selectedDateLabel =>
      MaterialLocalizations.of(context).formatMediumDate(selectedDate);

  DoctorProfile? doctorProfile;
  bool isProfileLoading = false;
  String? profileError;

  DashboardSummary? dashboardSummary;
  bool isDashboardLoading = false;
  String? dashboardError;
  bool isAppointmentsLoading = false;
  String? appointmentsError;
  AppointmentPage? appointmentPage;
  List<Appointment> doctorSchedule = const [];
  int appointmentsPageNumber = 1;
  String? appointmentStatus;
  String appointmentSort = 'time';
  bool appointmentAscending = true;
  int _profileRequest = 0;
  int _appointmentsRequest = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode && const bool.fromEnvironment('DOCTOR_LIVE_QA')) {
      // Opt-in test builds only. Reports contain no medical values or tokens.
      DoctorReadAudit().run(
        widget.session,
        patientId: const String.fromEnvironment('QA_PATIENT_ID'),
        appointmentId: const String.fromEnvironment('QA_APPOINTMENT_ID'),
        report: (line) => debugPrint('DOCTOR_QA|$line'),
      );
    }
  }

  @override
  void dispose() {
    if (widget.dashboardService == null) _dashboardService.close();
    super.dispose();
  }

  Future<void> loadDoctorProfile() async {
    final request = ++_profileRequest;
    _appointmentsRequest++;
    setState(() {
      isProfileLoading = true;
      profileError = null;
      appointmentPage = null;
      appointmentsError = null;
      isAppointmentsLoading = false;
    });

    try {
      final profile = await _dashboardService.fetchProfile(widget.session);

      if (!mounted || request != _profileRequest) return;

      setState(() {
        doctorProfile = profile;
        isProfileLoading = false;
      });

      if (['hospital_admin', 'doctor'].contains(profile.role.toLowerCase())) {
        await loadAppointments(pageNumber: 1);
      }
    } catch (e) {
      if (!mounted || request != _profileRequest) return;

      setState(() {
        profileError = e.toString().replaceFirst('Exception: ', '');
        isProfileLoading = false;
      });
    }
  }

  Future<void> loadDashboardSummary() async {
    if (doctorProfile?.role.toLowerCase() != 'hospital_admin') {
      return;
    }

    setState(() {
      isDashboardLoading = true;
      dashboardError = null;
      dashboardSummary = null;
    });

    try {
      final result = await _dashboardService.fetchDashboardSummary(
        widget.session,
        selectedDate: selectedDate,
      );
      debugPrint(
        'DASHBOARD API SUCCESS: '
        'appointments=${result.appointments}, '
        'scheduled=${result.scheduled}, '
        'inProgress=${result.inProgress}, '
        'completed=${result.completed}',
      );
      if (!mounted) return;

      setState(() {
        dashboardSummary = result;
        isDashboardLoading = false;
      });
    } catch (e) {
      debugPrint('DASHBOARD API ERROR: $e');

      if (!mounted) return;
      setState(() {
        dashboardError = e.toString().replaceFirst('Exception: ', '');
        isDashboardLoading = false;
      });
    }
  }

  Future<void> loadAppointments({int? pageNumber}) async {
    final request = ++_appointmentsRequest;
    final role = doctorProfile?.role.toLowerCase();
    if (!['hospital_admin', 'doctor'].contains(role)) {
      return;
    }

    setState(() {
      isAppointmentsLoading = true;
      appointmentsError = null;
      appointmentPage = null;
      appointmentsPageNumber = pageNumber ?? appointmentsPageNumber;
    });

    try {
      final result = await _dashboardService.fetchAppointments(
        widget.session,
        selectedDate: selectedDate,
        status: appointmentStatus == 'waiting'
            ? 'scheduled'
            : appointmentStatus == 'checked_in'
            ? 'confirmed'
            : appointmentStatus,
        page: appointmentsPageNumber,
        sort: role == 'doctor' ? appointmentSort : 'time',
        order: role == 'doctor' && !appointmentAscending ? 'desc' : 'asc',
      );

      if (!mounted || request != _appointmentsRequest) return;

      if (kDebugMode) {
        debugPrint('APPOINTMENTS API SUCCESS - structure only');
        for (final line in describeAppointmentResponse(result)) {
          debugPrint('APPOINTMENTS STRUCTURE: $line');
        }
      }

      final page = AppointmentPage.fromJson(result);
      setState(() {
        appointmentPage = page;
        doctorSchedule = page.items;
        isAppointmentsLoading = false;
      });
    } catch (e) {
      // Network exceptions may contain URLs or response details.
      if (kDebugMode) debugPrint('APPOINTMENTS API ERROR (${e.runtimeType})');

      if (!mounted || request != _appointmentsRequest) return;

      setState(() {
        appointmentsError = 'Unable to load appointments. Please try again.';
        isAppointmentsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TickerMode(enabled: selectedTab == 0, child: homePage()),
      visitsPage(),
      selectedTab == 2
          ? ClinicalDirectoryPage(
              session: widget.session,
              service: _dashboardService,
              directory: ClinicalDirectory.patients,
              embedded: true,
            )
          : const SizedBox.shrink(),
      clinicalPage(),
      selectedTab == 4
          ? ProfilePage(
              session: widget.session,
              service: _dashboardService,
              onSignOut: signOut,
            )
          : const SizedBox.shrink(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: selectedTab == 0
          ? null
          : AppBar(
              backgroundColor: [1, 2, 3, 4].contains(selectedTab)
                  ? appointmentCream
                  : const Color(0xFFF5F9F9),
              foregroundColor: [1, 2, 3, 4].contains(selectedTab)
                  ? const Color(0xFF207361)
                  : navy,
              leading: [1, 2, 3, 4].contains(selectedTab)
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: IconButton.filledTonal(
                        tooltip: 'Open navigation menu',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                        ),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        icon: const Icon(Icons.menu, color: Color(0xFF20312D)),
                      ),
                    )
                  : null,
              surfaceTintColor: Colors.transparent,
              actions:
                  selectedTab == 1 &&
                      doctorProfile?.role.toLowerCase() == 'doctor'
                  ? [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: FilledButton.icon(
                          onPressed: isProfileLoading || isAppointmentsLoading
                              ? null
                              : bookAppointment,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF207361),
                          ),
                          icon: const Icon(Icons.add_box_outlined, size: 19),
                          label: const Text('Book'),
                        ),
                      ),
                    ]
                  : null,
              title: Text(
                selectedTab == 1 &&
                        doctorProfile?.role.toLowerCase() == 'doctor'
                    ? 'My OPD'
                    : selectedTab == 2
                    ? 'Patients'
                    : selectedTab == 3
                    ? 'Clinical'
                    : selectedTab == 4
                    ? 'Profile'
                    : 'SAMAGATI HMS',
                style: TextStyle(
                  fontSize: selectedTab == 3 ? 24 : 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
      drawer: navigationMenu(),
      backgroundColor: selectedTab == 0
          ? appointmentCream
          : const Color(0xFFF5F9F9),
      body: SafeArea(
        child: IndexedStack(index: selectedTab, children: pages),
      ),

      bottomNavigationBar: SoftBottomBar(
        appointmentStyle: [1, 2, 3, 4].contains(selectedTab),
        referenceStyle: selectedTab == 0,
        currentIndex: selectedTab,
        onTap: changeTab,
      ),
    );
  }

  Future<void> signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    try {
      await _sessionStore.clear();
      final revoked = await _dashboardService.revokeSession(widget.session);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => LoginPage(sessionStore: _sessionStore),
        ),
        (_) => false,
      );
      if (!revoked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Signed out on this device. Server sign-out could not be confirmed.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to clear saved sign-in. Please try signing out again.',
            ),
          ),
        );
      }
    } finally {
      _signingOut = false;
    }
  }

  Widget navigationMenu() => Drawer(
    backgroundColor: const Color(0xFFF7F3EA),
    child: SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF207361),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SAMAGATI HMS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.session.name,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(switch (widget.session.role.toLowerCase()) {
                  'doctor' => 'Doctor',
                  'hospital_admin' => 'Hospital administrator',
                  'patient' => 'Patient',
                  _ => 'Hospital account',
                }, style: const TextStyle(color: Color(0xFFE2F3EC))),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                menuTab('Home', Icons.home_outlined, 0),
                menuTab('Appointments', Icons.calendar_month_outlined, 1),
                menuTab('Patients', Icons.people_outline, 2),
                const Divider(
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFFD9E2D5),
                ),
                for (final entry in [
                  (ClinicalDirectory.prescriptions, Icons.description_outlined),
                  (ClinicalDirectory.labs, Icons.science_outlined),
                  (ClinicalDirectory.pharmacy, Icons.local_pharmacy_outlined),
                ])
                  ListTile(
                    leading: Icon(entry.$2, color: const Color(0xFF207361)),
                    title: Text(
                      entry.$1.title,
                      style: const TextStyle(color: Color(0xFF20312D)),
                    ),
                    onTap: () {
                      _scaffoldKey.currentState?.closeDrawer();
                      openDirectory(entry.$1);
                    },
                  ),
                const Divider(
                  indent: 20,
                  endIndent: 20,
                  color: Color(0xFFD9E2D5),
                ),
                ListTile(
                  leading: const Icon(Icons.grid_view_outlined),
                  title: const Text('All hospital services'),
                  onTap: () {
                    _scaffoldKey.currentState?.closeDrawer();
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            HospitalServicesHost(session: widget.session),
                      ),
                    );
                  },
                ),
                menuTab('Profile & account', Icons.person_outline, 4),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget menuTab(String label, IconData icon, int tab) => ListTile(
    leading: Icon(icon, color: const Color(0xFF207361)),
    title: Text(label),
    textColor: const Color(0xFF20312D),
    selected: selectedTab == tab,
    selectedColor: const Color(0xFF207361),
    selectedTileColor: const Color(0xFFE2F0E7),
    onTap: () {
      _scaffoldKey.currentState?.closeDrawer();
      changeTab(tab);
    },
  );

  Widget homePage() => HomeDashboardPage(
    session: widget.session,
    service: _dashboardService,
    onVisits: (date) {
      selectedDate = date;
      appointmentPage = null;
      appointmentStatus = null;
      appointmentsPageNumber = 1;
      changeTab(1);
    },
    onDirectory: openDirectory,
  );
  void openDirectory(ClinicalDirectory directory) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClinicalDirectoryPage(
          session: widget.session,
          service: _dashboardService,
          directory: directory,
        ),
      ),
    );
  }

  Widget clinicalPage() => ClinicalHomePage(onDirectory: openDirectory);

  Future<void> chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted || date == null || date == selectedDate) return;
    setState(() {
      selectedDate = date;
      dashboardSummary = null;
      dashboardError = null;
      appointmentPage = null;
      appointmentsError = null;
    });
    await loadAppointments(pageNumber: 1);
  }

  Widget visitsPage() => AppointmentsScheduleView(
    isAdmin: doctorProfile?.role.toLowerCase() == 'hospital_admin',
    isDoctor: doctorProfile?.role.toLowerCase() == 'doctor',
    date: selectedDate,
    dateLabel: selectedDateLabel,
    page: appointmentPage,
    pageNumber: appointmentsPageNumber,
    status: appointmentStatus,
    busy: isProfileLoading || isAppointmentsLoading,
    ready:
        !isProfileLoading &&
        !isAppointmentsLoading &&
        profileError == null &&
        appointmentsError == null &&
        appointmentPage != null,
    onRefresh: loadDoctorProfile,
    onPickDate: chooseDate,
    onDate: (date) {
      setState(() {
        selectedDate = date;
      });
      loadAppointments(pageNumber: 1);
    },
    onStatus: (value) {
      setState(() {
        appointmentStatus = value;
      });
      loadAppointments(pageNumber: 1);
    },
    onPage: (page) => loadAppointments(pageNumber: page),
    appointmentBuilder: appointmentCard,
    onAppointment: openAppointment,
    doctorRows: doctorSchedule,
    sort: appointmentSort,
    ascending: appointmentAscending,
    onSort: (key) {
      setState(() {
        appointmentAscending = appointmentSort == key
            ? !appointmentAscending
            : true;
        appointmentSort = key;
      });
      loadAppointments(pageNumber: 1);
    },
    onBook: bookAppointment,
    state: appointmentState(),
  );
  Widget appointmentCard(Appointment appointment) => AppointmentSummaryCard(
    appointment: appointment,
    onTap: () => openAppointment(appointment),
  );

  Future<void> bookAppointment() async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppointmentBookingPage(session: widget.session),
      ),
    );
    if (!mounted || booked != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Appointment booked successfully.')),
    );
    await loadAppointments(pageNumber: 1);
  }

  Future<void> openAppointment(Appointment appointment) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentDetailPage(
          session: widget.session,
          appointmentId: appointment.id,
          service: _dashboardService,
        ),
      ),
    );
    if (mounted) await loadAppointments();
  }

  Widget appointmentState({bool isNextPatient = false}) {
    if (isProfileLoading || isAppointmentsLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: LinearProgressIndicator(color: teal),
      );
    }
    if (profileError != null) {
      return emptyCard(
        'Pull down to retry loading your profile and appointments.',
      );
    }
    if (appointmentsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          emptyCard(appointmentsError!),
          TextButton.icon(
            onPressed: loadAppointments,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }
    if (appointmentPage?.isEmpty == true) {
      return emptyCard('No appointments returned for $selectedDateLabel.');
    }
    // Admin results must not be presented as a personal doctor queue.
    if (doctorProfile?.role.toLowerCase() == 'hospital_admin') {
      return emptyCard(
        'Sign in with a verified doctor account to view a personal patient queue.',
      );
    }
    return emptyCard(
      isNextPatient
          ? 'Next patient will appear once doctor access is connected.'
          : 'Your queue will appear once doctor access is connected.',
    );
  }

  Widget sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: navy,
      ),
    );
  }

  Widget overviewCard(String title, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minHeight: 105),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3ECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 21, color: teal),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5ECEC)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
      ),
    );
  }

  Widget quickAction(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 25, color: teal),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: navy,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void changeTab(int index) {
    setState(() => selectedTab = index);
    if (index == 1) loadDoctorProfile();
  }

  Widget placeholder(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42, color: teal),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              color: navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This module will be connected next.',
            style: TextStyle(color: muted),
          ),
        ],
      ),
    );
  }
}
