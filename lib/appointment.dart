/// Fields verified from the existing appointments API structure.
class Appointment {
  const Appointment({
    required this.id,
    required this.date,
    required this.time,
    required this.status,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.department,
    this.number,
    this.tokenNumber,
    this.reason,
    this.symptoms,
    this.diagnosis,
    this.doctorNotes,
    this.followUpDate,
    this.patientId,
  });

  final String id;
  final String date;
  final String time;
  final String status;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String department;
  final String? number;
  final int? tokenNumber;
  final String? reason;
  final String? symptoms;
  final String? diagnosis;
  final String? doctorNotes;
  final String? followUpDate;
  final String? patientId;

  factory Appointment.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Invalid appointment fields');
      }
      return value.trim();
    }

    String nestedString(Object? value, String key, String fallback) {
      final field = value is Map ? value[key] : null;
      return field is String && field.trim().isNotEmpty
          ? field.trim()
          : fallback;
    }

    final token = json['token_number'];
    String? optionalString(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    return Appointment(
      id: requiredString('id'),
      date: requiredString('appointment_date'),
      time: requiredString('appointment_time'),
      status: requiredString('status'),
      doctorId: requiredString('doctor_id'),
      patientName: nestedString(
        json['patient'],
        'full_name',
        'Patient name unavailable',
      ),
      doctorName: nestedString(
        json['doctor'],
        'name',
        'Doctor name unavailable',
      ),
      department: nestedString(
        json['doctor'],
        'department_name',
        'Department unavailable',
      ),
      number: json['appointment_number'] is String
          ? json['appointment_number'] as String
          : null,
      tokenNumber: token is int ? token : null,
      reason: optionalString('reason'),
      symptoms: optionalString('symptoms'),
      diagnosis: optionalString('diagnosis'),
      doctorNotes: optionalString('doctor_notes'),
      followUpDate: optionalString('follow_up_date'),
      patientId: optionalString('patient_id'),
    );
  }
}
