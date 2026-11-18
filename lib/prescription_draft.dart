class PrescriptionDraft {
  const PrescriptionDraft({
    required this.patientId,
    required this.doctorId,
    this.appointmentId,
    required this.fields,
    required this.medications,
    this.labTests = const [],
  });
  final String patientId, doctorId;
  final String? appointmentId;
  final Map<String, String> fields;
  final List<Map<String, dynamic>> medications;
  final List<Map<String, dynamic>> labTests;

  Map<String, dynamic> toJson({required bool doctorRole}) => {
    'patient_id': patientId,
    if (!doctorRole) 'doctor_id': doctorId,
    if (appointmentId != null) 'appointment_id': appointmentId,
    for (final field in fields.entries)
      field.key: field.value.trim().isEmpty ? null : field.value.trim(),
    'medications': medications,
    'lab_tests': labTests,
  };
}

class DraftSaveException implements Exception {
  const DraftSaveException(this.message, {this.uncertain = false});
  final String message;
  final bool uncertain;
}
