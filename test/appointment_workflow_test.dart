import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/appointment.dart';
import 'package:mayo_delivery_partner/appointment_workflow.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';

const session = AuthSession(
  'token',
  'refresh',
  'Doctor',
  'doctor@example.test',
  role: 'doctor',
);
Appointment visit(String status) => Appointment(
  id: 'visit',
  date: '2026-10-23',
  time: '12:00',
  status: status,
  patientName: 'Example Patient',
  doctorId: 'doctor',
  doctorName: 'Doctor',
  department: 'Medicine',
);

void main() {
  for (final transition in [
    ('scheduled', 'confirmed'),
    ('confirmed', 'in_progress'),
    ('in_progress', 'completed'),
  ]) {
    test(
      'authenticated transition ${transition.$1} to ${transition.$2}',
      () async {
        final service = DoctorDashboardService(
          client: MockClient((request) async {
            expect(request.method, 'PATCH');
            expect(request.url.path, '/api/v1/appointments/visit/status');
            expect(request.headers['Authorization'], 'Bearer token');
            final body = jsonDecode(request.body);
            expect(body['status'], transition.$2);
            if (transition.$2 == 'completed') {
              expect(body['diagnosis'], 'Review');
              expect(body['doctor_notes'], 'Recorded notes');
              expect(body['follow_up_date'], '2026-11-01');
            } else {
              expect(body.keys, ['status']);
            }
            return http.Response('{"success":true}', 200);
          }),
        );
        addTearDown(service.close);
        await service.updateAppointmentStatus(
          session,
          visit(transition.$1),
          status: transition.$2,
          diagnosis: ' Review ',
          notes: 'Recorded notes',
          followUpDate: '2026-11-01',
        );
      },
    );
  }
  test('invalid transition never sends a request', () async {
    var calls = 0;
    final service = DoctorDashboardService(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(service.close);
    await expectLater(
      service.updateAppointmentStatus(
        session,
        visit('scheduled'),
        status: 'completed',
      ),
      throwsA(isA<AppointmentStatusException>()),
    );
    expect(calls, 0);
  });
  for (final code in [403, 409, 500]) {
    test('HTTP $code is handled without automatic retries', () async {
      var calls = 0;
      final service = DoctorDashboardService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', code);
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.updateAppointmentStatus(
          session,
          visit('confirmed'),
          status: 'in_progress',
        ),
        throwsA(
          isA<AppointmentStatusException>().having(
            (e) => e.uncertain,
            'uncertain',
            code == 500,
          ),
        ),
      );
      expect(calls, 1);
    });
  }
  testWidgets('check-in requires confirmation and refreshes after saving', (
    tester,
  ) async {
    var writes = 0, refreshed = 0;
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'visit',
                'appointment_date': '2026-10-23',
                'appointment_time': '12:00',
                'status': 'scheduled',
                'doctor_id': 'doctor',
              },
            }),
            200,
          );
        }
        writes++;
        return http.Response('{"success":true}', 200);
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppointmentWorkflow(
            appointment: visit('scheduled'),
            session: session,
            service: service,
            onUpdated: () async {
              refreshed++;
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(refreshed, 1);
    expect(tester.takeException(), isNull);
  });
}
