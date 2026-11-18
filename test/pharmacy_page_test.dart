import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/pharmacy_page.dart';
import 'package:mayo_delivery_partner/pharmacy_stock_page.dart';
import 'package:mayo_delivery_partner/prescription_draft.dart';

const session = AuthSession(
  'token',
  'refresh',
  'Doctor',
  'doctor@test',
  role: 'doctor',
);
http.Response ok(Object data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
Map<String, dynamic> page() => {
  'items': [],
  'meta': {'total_items': 0, 'has_next': false},
};
void main() {
  testWidgets(
    'Pharmacy shows summary, tabs, sorting, empty state and Stock destination',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queries = <Map<String, String>>[];
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          if (request.url.path.endsWith('/stock/expiring')) {
            return ok({
              'count': 1,
              'batches': [
                {
                  'id': 'batch',
                  'medicine_name': 'Example',
                  'batch_number': 'TEST',
                  'quantity_remaining': 5,
                  'expiry_date': '2026-11-01',
                },
              ],
            });
          }
          if (request.url.path.endsWith('/prescriptions/') &&
              request.url.queryParameters['per_page'] == '10') {
            queries.add(request.url.queryParameters);
          }
          return ok(page());
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PharmacyPage(session: session, service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('To dispense 0'), findsOneWidget);
      expect(find.text('Below reorder level'), findsOneWidget);
      expect(find.text('Expiring in 30 days'), findsOneWidget);
      expect(find.text('Nothing waiting'), findsOneWidget);
      await tester.tap(find.text('Dispensed'));
      await tester.pumpAndSettle();
      expect(queries.last['status'], 'dispensed');
      expect(find.text('Nothing dispensed yet'), findsOneWidget);
      await tester.tap(find.text('PATIENT'));
      await tester.pumpAndSettle();
      expect(queries.last['sort'], 'patient');
      expect(queries.last['order'], 'asc');
      await tester.tap(find.text('PATIENT'));
      await tester.pumpAndSettle();
      expect(queries.last['order'], 'desc');
      await tester.tap(find.text('Stock'));
      await tester.pumpAndSettle();
      expect(find.byType(PharmacyStockPage), findsOneWidget);
      await tester.tap(find.text('Expiring in 30 days'));
      await tester.pumpAndSettle();
      expect(find.text('Example'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('unavailable stock totals are not falsely reported as zero', () async {
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        if (request.url.path.contains('/stock/')) {
          return http.Response('{}', 403);
        }
        return ok(page());
      }),
    );
    addTearDown(service.close);
    expect(await service.fetchPharmacySummary(session), {
      'issued': 0,
      'low': null,
      'expiring': null,
    });
  });
  test('dispense sends authenticated PATCH only once', () async {
    var calls = 0;
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        calls++;
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/v1/prescriptions/rx/dispense');
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response('{"success":true}', 200);
      }),
    );
    addTearDown(service.close);
    await service.dispensePrescription(session, 'rx');
    expect(calls, 1);
  });
  test('unknown dispensing outcome is marked uncertain', () async {
    final service = DoctorDashboardService(
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(service.close);
    await expectLater(
      service.dispensePrescription(session, 'rx'),
      throwsA(
        isA<DraftSaveException>().having((e) => e.uncertain, 'uncertain', true),
      ),
    );
  });
}
