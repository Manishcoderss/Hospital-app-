// Mock patient records.
// Never use these credentials in production.
class MockPatient {
  final String name;
  final String patientId;
  final String phone;
  final String email;

  const MockPatient({
    required this.name,
    required this.patientId,
    required this.phone,
    required this.email,
  });
}

final mockPatients = <MockPatient>[
  const MockPatient(
    name: 'Aarav Sharma',
    patientId: 'PAT-1001',
    phone: '9876543210',
    email: 'aarav@example.com',
  ),
  const MockPatient(
    name: 'Priya Patel',
    patientId: 'PAT-1002',
    phone: '9123456780',
    email: 'priya@example.com',
  ),
];
