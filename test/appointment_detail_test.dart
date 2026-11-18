import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/appointment_detail_page.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';

const session = AuthSession('access', 'refresh', 'Admin', 'example@test.com');
Map<String, dynamic> detail({String id = 'example'}) => {
  'success': true,
  'data': {
    'id': id,
    'appointment_date': '2026-10-16',
    'appointment_time': '11:30',
    'doctor_id': 'doctor',
    'status': 'confirmed',
    'patient': {'full_name': 'Example Patient'},
    'doctor': {'name': 'Example Doctor', 'department_name': 'Medicine'},
    'reason': null,
    'symptoms': 'Example symptom',
  },
};

void main() {
  test('detail request uses selected ID and bearer token', () async {
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/appointments/example');
        expect(request.headers['Authorization'], 'Bearer access');
        return http.Response(jsonEncode(detail()), 200);
      }),
    );
    addTearDown(service.close);
    final result = await service.fetchAppointmentDetail(session, 'example');
    expect(result.id, 'example');
    expect(result.reason, isNull);
    expect(result.symptoms, 'Example symptom');
  });

  for (final status in [401, 403, 404, 500]) {
    test('detail handles HTTP $status without exposing response', () async {
      final service = DoctorDashboardService(
        client: MockClient((_) async => http.Response('PRIVATE', status)),
      );
      addTearDown(service.close);
      await expectLater(
        service.fetchAppointmentDetail(session, 'example'),
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

  test('rejects invalid JSON and mismatched appointment ID', () async {
    for (final body in [
      'invalid',
      jsonEncode(detail(id: 'different')),
      '{"success":true,"data":null}',
    ]) {
      final service = DoctorDashboardService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        service.fetchAppointmentDetail(session, 'example'),
        throwsA(isA<AppointmentDetailException>()),
      );
      service.close();
    }
  });

  testWidgets('detail retries failed request and shows recorded fields', (
    tester,
  ) async {
    var attempts = 0;
    final service = DoctorDashboardService(
      client: MockClient((_) async {
        attempts++;
        return attempts == 1
            ? http.Response('', 500)
            : http.Response(jsonEncode(detail()), 200);
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentDetailPage(
          session: session,
          appointmentId: 'example',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Example Patient'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Example Patient'), findsOneWidget);
    expect(find.text('2026-10-16'), findsOneWidget);
    expect(find.text('Reason'), findsOneWidget);
    expect(find.text('Not recorded'), findsWidgets);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });
}
