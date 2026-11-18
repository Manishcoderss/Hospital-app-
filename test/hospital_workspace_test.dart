import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/hospital_api.dart';
import 'package:mayo_delivery_partner/hospital_theme.dart';
import 'package:mayo_delivery_partner/hospital_modules.dart';
import 'package:mayo_delivery_partner/patient_portal.dart';

void main() {
  const session = AuthSession(
    'access',
    'refresh',
    'Alice Patient',
    'alice@example.com',
    role: 'patient',
  );

  test(
    'patient prescriptions open prescription records, not patient records',
    () {
      final actions = recordActions(
        {'path': '/patients/{{patient_id}}/prescriptions'},
        {'patient_id': 'patient-own'},
        'rx-own',
        readonly: true,
      );
      expect(actions, isNotEmpty);
      expect(
        actions.every(
          (a) => (a['operation'] as Map)['path'].toString().startsWith(
            '/prescriptions/{{prescription_id}}',
          ),
        ),
        isTrue,
      );
      expect((actions.first['parameters'] as Map)['prescription_id'], 'rx-own');
      expect((actions.first['parameters'] as Map)['patient_id'], 'patient-own');
      expect(
        actions.every((a) => (a['operation'] as Map)['method'] == 'GET'),
        isTrue,
      );
    },
  );
  test('admission timelines do not treat event IDs as admission IDs', () {
    expect(
      recordActions(
        {'path': '/admissions/{{admission_id}}/timeline'},
        {'admission_id': 'admission-own'},
        'event-id',
      ),
      isEmpty,
    );
  });
  testWidgets(
    'patient cancellation needs confirmation and uses the selected own visit',
    (tester) async {
      var writes = 0;
      var cancelled = false;
      final api = HospitalApi(
        session,
        client: MockClient((r) async {
          Object data;
          if (r.method == 'PATCH') {
            expect(r.url.path, '/api/v1/appointments/visit-own/status');
            expect(jsonDecode(r.body), {'status': 'cancelled'});
            writes++;
            cancelled = true;
            data = {'id': 'visit-own'};
          } else if (r.url.path.endsWith('/auth/me')) {
            data = {'patient_id': 'patient-own'};
          } else if (r.url.path.endsWith('/appointments')) {
            data = {
              'items': [
                {
                  'id': 'visit-own',
                  'status': cancelled ? 'cancelled' : 'confirmed',
                  'appointment_date': '2026-12-20',
                  'appointment_time': '10:00',
                  'doctor': {'full_name': 'Dr. Example'},
                },
              ],
            };
          } else {
            data = {'id': 'patient-own', 'full_name': 'Alice Patient'};
          }
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PatientPortal(session: session, api: api, onSignOut: () {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('View details'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel appointment'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel appointment'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Your appointment'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('patient only loads the profile linked by auth/me', (
    tester,
  ) async {
    final paths = <String>[];
    final api = HospitalApi(
      session,
      client: MockClient((r) async {
        paths.add(r.url.path);
        final data = switch (r.url.path) {
          '/api/v1/auth/me' => {
            'patient_id': 'patient-own',
            'id': 'user-other',
          },
          '/api/v1/patients/patient-own' => {
            'id': 'patient-own',
            'full_name': 'Alice Patient',
            'age': 30,
          },
          '/api/v1/patients/patient-own/appointments' => {'items': []},
          _ => throw StateError('Unexpected patient access'),
        };
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PatientPortal(session: session, api: api, onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hi, Alice'), findsOneWidget);
    expect(paths, contains('/api/v1/patients/patient-own/appointments'));
    expect(paths.any((p) => p.contains('user-other')), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unlinked patient cannot browse another patient', (tester) async {
    var calls = 0;
    final api = HospitalApi(
      session,
      client: MockClient((r) async {
        calls++;
        return http.Response('{"success":true,"data":{"id":"user-1"}}', 200);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PatientPortal(session: session, api: api, onSignOut: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('not linked'), findsOneWidget);
    expect(calls, 1);
  });
  testWidgets('module navigation fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = HospitalApi(
      session,
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: HospitalTheme.data,
        home: HospitalModulesPage(api: api),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hospital workspace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
