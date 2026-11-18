import 'package:flutter/material.dart';

import 'patient_mock_data.dart';

class PatientRegistrationDemo extends StatefulWidget {
  const PatientRegistrationDemo({super.key});

  @override
  State<PatientRegistrationDemo> createState() =>
      _PatientRegistrationDemoState();
}

class _PatientRegistrationDemoState extends State<PatientRegistrationDemo> {
  final _form = GlobalKey<FormState>();
  String _name = '', _phone = '', _email = '';

  void _save() {
    if (!_form.currentState!.validate()) return;
    final patient = MockPatient(
      name: _name.trim(),
      phone: _phone.trim(),
      email: _email.trim(),
      patientId: 'PAT-${1001 + mockPatients.length}',
    );
    mockPatients.add(patient);
    Navigator.pop(context, patient);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create patient account')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Create a demo account',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stored only while the demo app is running. Use OTP 123456 or password Patient@123 to sign in.',
            style: TextStyle(color: Color(0xFF657D88), height: 1.5),
          ),
          const SizedBox(height: 24),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Full name'),
            textCapitalization: TextCapitalization.words,
            onChanged: (value) => _name = value,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter your name'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Mobile number'),
            keyboardType: TextInputType.phone,
            onChanged: (value) => _phone = value,
            validator: (value) {
              if (!RegExp(r'^\d{10}$').hasMatch(value?.trim() ?? '')) {
                return 'Enter a 10-digit mobile';
              }
              if (mockPatients.any((patient) => patient.phone == value!.trim())) {
                return 'Mobile already registered';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) => _email = value,
            validator: (value) {
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                  .hasMatch(value?.trim() ?? '')) {
                return 'Enter a valid email';
              }
              if (mockPatients.any(
                (patient) =>
                    patient.email.toLowerCase() == value!.trim().toLowerCase(),
              )) {
                return 'Email already registered';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Create demo account'),
          ),
        ],
      ),
    ),
  );
}
