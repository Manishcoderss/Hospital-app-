import 'appointment.dart';

class HomeFollowUp {
  const HomeFollowUp(this.patientId, this.name, this.doctor);
  final String? patientId;
  final String name;
  final String? doctor;
}

class HomeSnapshot {
  const HomeSnapshot({
    required this.total,
    required this.waiting,
    required this.inProgress,
    required this.completed,
    required this.appointments,
    required this.followUps,
    required this.followUpCount,
    this.weeklyFollowUps = false,
  });
  final int total, waiting, inProgress, completed, followUpCount;
  final List<Appointment> appointments;
  final List<HomeFollowUp> followUps;
  final bool weeklyFollowUps;

  List<Appointment> get active =>
      appointments
          .where(
            (item) =>
                ['scheduled', 'confirmed', 'in_progress'].contains(item.status),
          )
          .toList()
        ..sort((a, b) {
          final rank = (a.status == 'in_progress' ? 0 : 1).compareTo(
            b.status == 'in_progress' ? 0 : 1,
          );
          return rank != 0 ? rank : a.time.compareTo(b.time);
        });

  static int count(Object? value) {
    if (value is! int || value < 0) {
      throw const FormatException('Invalid dashboard count');
    }
    return value;
  }

  factory HomeSnapshot.calendar(Map<String, dynamic> data) {
    final events = data['events'];
    final statuses = data['by_status'];
    if (events is! List || statuses is! Map) {
      throw const FormatException('Invalid calendar day');
    }
    final appointments = <Appointment>[];
    final followUps = <HomeFollowUp>[];
    for (final event in events) {
      if (event is! Map<String, dynamic>) throw const FormatException();
      final patient = event['patient'];
      final doctor = event['doctor'];
      if (event['type'] == 'appointment') {
        appointments.add(
          Appointment.fromJson({
            ...event,
            'appointment_date': event['date'],
            'appointment_time': event['start_time'],
            'doctor_id': doctor is Map ? doctor['id'] : null,
            'patient_id': patient is Map ? patient['id'] : null,
          }),
        );
      } else if (event['type'] == 'follow_up_due') {
        followUps.add(
          HomeFollowUp(
            patient is Map && patient['id'] is String
                ? patient['id'] as String
                : null,
            patient is Map && patient['full_name'] is String
                ? patient['full_name'] as String
                : event['title'] is String
                ? event['title'] as String
                : 'Follow-up',
            doctor is Map && doctor['name'] is String
                ? doctor['name'] as String
                : null,
          ),
        );
      }
    }
    int status(String key) => count(statuses[key] ?? 0);
    return HomeSnapshot(
      total: count(data['appointments']),
      waiting: status('scheduled') + status('confirmed'),
      inProgress: status('in_progress'),
      completed: status('completed'),
      appointments: appointments,
      followUps: followUps,
      followUpCount: count(data['follow_ups_due'] ?? 0),
    );
  }

  factory HomeSnapshot.doctor(
    Map<String, dynamic> summary,
    Map<String, dynamic> day,
  ) {
    final rows = day['items'];
    final today = summary['today'];
    final pending = summary['pending'];
    if (rows is! List || today is! Map || pending is! Map) {
      throw const FormatException();
    }
    final appointments = rows.map((row) {
      if (row is! Map<String, dynamic>) throw const FormatException();
      return Appointment.fromJson(row);
    }).toList();
    int status(String status) =>
        appointments.where((item) => item.status == status).length;
    return HomeSnapshot(
      total: count(today['total']),
      waiting: status('scheduled') + status('confirmed'),
      inProgress: status('in_progress'),
      completed: status('completed'),
      appointments: appointments,
      followUps: const [],
      followUpCount: count(pending['follow_ups_due_7d'] ?? 0),
      weeklyFollowUps: true,
    );
  }
}
