class Patient {
  const Patient({
    required this.id,
    required this.name,
    this.number,
    this.age,
    this.gender,
    this.bloodGroup,
    this.phone,
    this.allergies,
    this.medicalHistory,
    this.surgicalHistory,
    this.chemotherapyHistory,
    this.radiationHistory,
  });
  final String id;
  final String name;
  final String? number;
  final String? age;
  final String? gender;
  final String? bloodGroup;
  final String? phone;
  final String? allergies;
  final String? medicalHistory;
  final String? surgicalHistory;
  final String? chemotherapyHistory;
  final String? radiationHistory;

  factory Patient.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final id = text('id');
    final name = text('full_name');
    if (id == null || name == null) {
      throw const FormatException('Invalid patient response');
    }
    String? clinicalText(String key) {
      final value = json[key];
      if (value == null || value is String && value.trim().isEmpty) return null;
      if (value is String) return value.trim();
      // Never turn an unfamiliar clinical record shape into "Not recorded".
      return 'Recorded information is not available in a supported format.';
    }

    return Patient(
      id: id,
      name: name,
      number: text('patient_number'),
      age: json['age'] is num ? json['age'].toString() : null,
      gender: text('gender'),
      bloodGroup: text('blood_group'),
      phone: text('phone'),
      allergies: clinicalText('allergies'),
      medicalHistory: clinicalText('medical_history'),
      surgicalHistory: clinicalText('past_surgical_history'),
      chemotherapyHistory: clinicalText('past_chemotherapy_history'),
      radiationHistory: clinicalText('past_radiation_history'),
    );
  }
}
