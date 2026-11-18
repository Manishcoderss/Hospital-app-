import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/patient_detail_page.dart';
import 'package:mayo_delivery_partner/patient.dart';

const session = AuthSession(
  'test-access',
  'refresh',
  'Admin',
  'example@test.com',
);
String body({String id = 'patient-example'}) => jsonEncode({
  'success': true,
  'data': {
    'id': id,
    'full_name': 'Example Patient',
    'patient_number': 'PAT-EXAMPLE',
    'age': 38,
    'gender': 'female',
    'blood_group': null,
  },
});

void main() {
  test('clinical history preserves text and distinguishes null from unsupported data', () {
    final patient = Patient.fromJson({
      'id': 'example',
      'full_name': 'Example Patient',
      'allergies': null,
      'medical_history': 'Recorded condition',
      'past_surgical_history': {'record': 'example'},
    });
    expect(patient.allergies, isNull);
    expect(patient.medicalHistory, 'Recorded condition');
    expect(patient.surgicalHistory, contains('supported format'));
  });

  test('patient uses selected ID and existing session token', () async {
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/patients/patient-example');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer test-access');
        return http.Response(body(), 200);
      }),
    );
    addTearDown(service.close);
    final patient = await service.fetchPatient(session, 'patient-example');
    expect(patient.age, '38');
    expect(patient.bloodGroup, isNull);
  });

  for (final status in [401, 403, 404, 500]) {
    test('patient HTTP $status does not expose response body', () async {
      final service = DoctorDashboardService(
        client: MockClient((_) async => http.Response('PRIVATE', status)),
      );
      addTearDown(service.close);
      await expectLater(
        service.fetchPatient(session, 'patient-example'),
        throwsA(
          isA<AppointmentDetailException>().having(
            (e) => e.message,
            'safe message',
            isNot(contains('PRIVATE')),
          ),
        ),
      );
    });
  }

  test('patient rejects invalid response and ID mismatch', () async {
    for (final data in [
      'invalid',
      '{"success":true,"data":{}}',
      body(id: 'other'),
    ]) {
      final service = DoctorDashboardService(
        client: MockClient((_) async => http.Response(data, 200)),
      );
      await expectLater(
        service.fetchPatient(session, 'patient-example'),
        throwsA(isA<AppointmentDetailException>()),
      );
      service.close();
    }
  });

  testWidgets(
    'patient retries and distinguishes unloaded records from no allergies',
    (tester) async {
      var requests = 0;
      final service = DoctorDashboardService(
        client: MockClient((_) async {
          requests++;
          return requests == 1
              ? http.Response('', 500)
              : http.Response(body(), 200);
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PatientDetailPage(
            session: session,
            patientId: 'patient-example',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Example Patient'), findsOneWidget);
      expect(find.text('No allergies'), findsNothing);
      expect(find.text('Not recorded'), findsWidgets);
      expect(requests, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
