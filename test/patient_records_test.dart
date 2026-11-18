import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/patient_records_page.dart';
import 'package:mayo_delivery_partner/lab_report_page.dart';

const session = AuthSession('access', 'refresh', 'Admin', 'test@example.com');
http.Response response(Object data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, dynamic> page(int current) => {
  'items': [
    {
      'id': 'visit-$current',
      'patient_id': 'patient',
      'appointment_number': 'VISIT-$current',
      'appointment_date': '2026-10-16',
      'status': 'completed',
    },
  ],
  'meta': {'total_items': 2, 'has_next': current == 1},
};
Map<String, dynamic> report({String patient = 'patient'}) => {
  'id': 'order',
  'patient_id': patient,
  'order_number': 'LAB-EXAMPLE',
  'status': 'pending',
  'tests': [
    {
      'test_name': 'Example Panel',
      'status': 'pending',
      'results': [
        {
          'name': 'Example marker',
          'value': 0,
          'unit': 'mg/L',
          'normal_range': '0–1',
          'flag': 'H',
        },
      ],
    },
  ],
};

void main() {
  test(
    'patient scoped history and labs use verified endpoints and pagination',
    () async {
      final paths = <String>[];
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers['Authorization'], 'Bearer access');
          expect(request.url.queryParameters, {
            'page': '2',
            'per_page': '10',
            'sort': 'date',
            'order': 'desc',
          });
          return response(page(2));
        }),
      );
      addTearDown(service.close);
      await service.fetchPatientRecords(
        session,
        'patient',
        labs: false,
        page: 2,
      );
      await service.fetchPatientRecords(
        session,
        'patient',
        labs: true,
        page: 2,
      );
      expect(paths, [
        '/api/v1/patients/patient/appointments',
        '/api/v1/patients/patient/lab-orders',
      ]);
    },
  );

  test(
    'report rejects mismatched patient and malformed test results',
    () async {
      for (final data in [
        report(patient: 'other'),
        {
          ...report(),
          'tests': [
            {'results': 'bad'},
          ],
        },
      ]) {
        final service = DoctorDashboardService(
          client: MockClient((_) async => response(data)),
        );
        await expectLater(
          service.fetchLabReport(session, 'order', 'patient'),
          throwsFormatException,
        );
        service.close();
      }
    },
  );

  test(
    'records reject malformed envelope instead of claiming empty history',
    () async {
      final service = DoctorDashboardService(
        client: MockClient((_) async => response({'items': []})),
      );
      addTearDown(service.close);
      await expectLater(
        service.fetchPatientRecords(session, 'patient', labs: false),
        throwsFormatException,
      );
    },
  );

  testWidgets('history can navigate forward and backward through pages', (
    tester,
  ) async {
    final service = DoctorDashboardService(
      client: MockClient(
        (request) async =>
            response(page(int.parse(request.url.queryParameters['page']!))),
      ),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PatientRecordsPage(
          session: session,
          patientId: 'patient',
          service: service,
          labs: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('VISIT-1'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('VISIT-2'), findsOneWidget);
    expect(find.text('VISIT-1'), findsNothing);
    await tester.tap(find.text('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('VISIT-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'report shows panel results, numeric zero and lab flag without interpretation',
    (tester) async {
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/lab-tests/order');
          return response(report());
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: LabReportPage(
            session: session,
            patientId: 'patient',
            orderId: 'order',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Example marker'), findsOneWidget);
      expect(find.text('Result: 0'), findsOneWidget);
      expect(find.text('Lab flag: H'), findsOneWidget);
      expect(find.textContaining('Provisional report'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('permission error offers retry and does not show empty history', (
    tester,
  ) async {
    var attempts = 0;
    final service = DoctorDashboardService(
      client: MockClient((_) async {
        attempts++;
        return attempts == 1
            ? http.Response('PRIVATE', 403)
            : response({
                'items': [],
                'meta': {'total_items': 0, 'has_next': false},
              });
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PatientRecordsPage(
          session: session,
          patientId: 'patient',
          service: service,
          labs: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('permission'), findsOneWidget);
    expect(find.textContaining('No lab orders'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No lab orders on this page.'), findsOneWidget);
  });
}
