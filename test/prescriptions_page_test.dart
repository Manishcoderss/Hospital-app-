import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/prescriptions_page.dart';
import 'package:mayo_delivery_partner/new_prescription_page.dart';

const session = AuthSession(
  'token',
  'refresh',
  'Doctor',
  'doctor@test',
  role: 'doctor',
);
void main() {
  testWidgets(
    'prescription tabs and sorting send API filters; New opens full editor',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queries = <Map<String, String>>[];
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          if (request.url.path.endsWith('/prescriptions/')) {
            queries.add(request.url.queryParameters);
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'items': [],
                'meta': {'total_items': 0, 'has_next': false},
              },
            }),
            200,
          );
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PrescriptionsPage(session: session, service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No prescriptions here'), findsOneWidget);
      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();
      expect(queries.last['status'], 'draft');
      await tester.tap(find.text('PATIENT'));
      await tester.pumpAndSettle();
      expect(queries.last['sort'], 'patient');
      expect(queries.last['order'], 'asc');
      await tester.tap(find.text('PATIENT'));
      await tester.pumpAndSettle();
      expect(queries.last['order'], 'desc');
      await tester.tap(find.text('New prescription'));
      await tester.pumpAndSettle();
      expect(find.byType(NewPrescriptionPage), findsOneWidget);
      expect(find.text('Patient *'), findsOneWidget);
      expect(find.text('Consultation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('patient lookup uses prescription-specific scope', () async {
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/patients/dropdown');
        expect(request.url.queryParameters['module'], 'prescription');
        expect(request.url.queryParameters['q'], 'Example');
        return http.Response(
          '{"success":true,"data":{"items":[{"id":"patient","full_name":"Example"}]}}',
          200,
        );
      }),
    );
    addTearDown(service.close);
    expect(
      (await service.searchPrescriptionPatients(
        session,
        ' Example ',
      )).single['id'],
      'patient',
    );
  });
}
