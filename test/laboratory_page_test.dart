import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/laboratory_page.dart';
import 'package:mayo_delivery_partner/new_lab_order_page.dart';

const session = AuthSession(
  'access',
  'refresh',
  'Doctor',
  'doctor@test',
  role: 'doctor',
);
http.Response ok(Object data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
Map<String, dynamic> envelope(List<Map<String, dynamic>> items, {int? total}) =>
    {
      'items': items,
      'meta': {'total_items': total ?? items.length, 'has_next': false},
    };
void main() {
  testWidgets(
    'Laboratory loads stage counts, catalogue search/category and new order',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queries = <Map<String, String>>[];
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          if (request.url.path.endsWith('/auth/me')) {
            return ok({'full_name': 'Doctor', 'role': 'doctor'});
          }
          if (request.url.path.endsWith('/lookups/all')) {
            return ok({
              'lab_test_categories': [
                {'value': 'Hematology', 'label': 'Hematology'},
              ],
            });
          }
          if (request.url.path.endsWith('/lab-tests/catalog')) {
            queries.add(request.url.queryParameters);
            return ok(
              envelope([
                {
                  'id': 'test',
                  'name': 'CBC',
                  'code': 'CBC',
                  'category': 'Hematology',
                  'sample_type': 'Blood',
                  'normal_range': 'See parameters',
                  'turnaround_hours': 4,
                  'price': 100,
                },
              ]),
            );
          }
          return ok(
            envelope(
              [],
              total: request.url.queryParameters['status'] == 'ordered' ? 2 : 0,
            ),
          );
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: LaboratoryPage(session: session, service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Awaiting sample 2'), findsOneWidget);
      expect(find.text('Nothing in this stage'), findsOneWidget);
      await tester.tap(find.text('Test catalogue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('CBC'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'CBC');
      await tester.tap(find.byTooltip('Search catalogue'));
      await tester.pumpAndSettle();
      expect(queries.last['search'], 'CBC');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hematology').last);
      await tester.pumpAndSettle();
      expect(queries.last['category'], 'Hematology');
      await tester.tap(find.text('PRICE'));
      await tester.pumpAndSettle();
      expect(queries.last['sort'], 'price');
      await tester.tap(find.text('New lab order'));
      await tester.pumpAndSettle();
      expect(find.byType(NewLabOrderPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('new lab order uses exact payload and bearer token', () async {
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/lab-tests/');
        expect(request.headers['Authorization'], 'Bearer access');
        expect(jsonDecode(request.body), {
          'patient_id': 'patient',
          'tests': [
            {'catalog_id': 'test', 'priority': 'routine'},
          ],
          'notes': 'Review',
        });
        return ok({'id': 'order'});
      }),
    );
    addTearDown(service.close);
    expect(
      await service.createLaboratoryOrder(
        session,
        patientId: 'patient',
        tests: [
          {'catalog_id': 'test', 'priority': 'routine'},
        ],
        notes: ' Review ',
      ),
      'order',
    );
  });
  test('laboratory patient search uses laboratory scope', () async {
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        expect(request.url.queryParameters['module'], 'laboratory');
        return ok({'items': []});
      }),
    );
    addTearDown(service.close);
    expect(await service.searchLaboratoryPatients(session, 'Example'), isEmpty);
  });
}
