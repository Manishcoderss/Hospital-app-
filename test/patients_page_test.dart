import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/patients_page.dart';
import 'package:mayo_delivery_partner/patient_registration_page.dart';
import 'package:mayo_delivery_partner/prescription_draft.dart';

const session = AuthSession(
  'token',
  'refresh',
  'Doctor',
  'doctor@test',
  role: 'doctor',
);
http.Response ok(Object data, [int code = 200]) =>
    http.Response(jsonEncode({'success': true, 'data': data}), code);
void main() {
  test('prescription patient lookup uses documented singular module', () async {
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/patients/dropdown');
        expect(request.url.queryParameters['module'], 'prescription');
        expect(request.url.queryParameters['q'], 'QA');
        return ok({
          'items': [
            {'id': 'qa', 'full_name': 'QA Doctor Test'},
          ],
        });
      }),
    );
    addTearDown(service.close);
    expect(
      (await service.searchPrescriptionPatients(session, ' QA ')).single['id'],
      'qa',
    );
  });
  testWidgets(
    'mobile patient details use separate cards without sideways scroll',
    (tester) async {
      tester.view.physicalSize = const Size(390, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/lookups/all')) return ok({});
          return ok({
            'items': [
              for (final name in ['Twinkle Shah', 'Bhoomi'])
                {
                  'id': name,
                  'full_name': name,
                  'patient_number': name,
                  'age': 20,
                  'gender': 'female',
                  'phone': '9000000000',
                  'blood_group': 'B+',
                  'city': 'Vadodara',
                  'insurance_provider_name': 'A long insurance provider name that wraps within the card',
                  'created_at': '2026-10-23T10:00:00',
                },
            ],
            'meta': {'total_items': 2, 'has_next': false},
          });
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PatientsPage(session: session, service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        findsNothing,
      );
      final verticalScroll = find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      );
      await tester.scrollUntilVisible(
        find.text('Blood group').first,
        200,
        scrollable: verticalScroll,
      );
      expect(find.text('9000000000'), findsNWidgets(2));
      expect(find.text('B+'), findsNWidgets(2));
      await tester.scrollUntilVisible(
        find.text('Registered').last,
        200,
        scrollable: verticalScroll,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Patients maps API fields, applies filters/sort/page size and opens registration',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final queries = <Map<String, String>>[];
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          if (request.url.path.endsWith('/auth/me')) {
            return ok({
              'full_name': 'Doctor',
              'role': 'doctor',
              'hospital': {'name': 'Example Hospital'},
            });
          }
          if (request.url.path.endsWith('/lookups/all')) {
            return ok({
              'genders': [
                {'value': 'female', 'label': 'Female'},
              ],
              'blood_groups': [
                {'value': 'B+', 'label': 'B+'},
              ],
              'insurance_categories': [
                {'value': 'insured', 'label': 'Insured'},
              ],
            });
          }
          if (request.url.path.contains('/form-defaults/')) {
            return ok({});
          }
          queries.add(request.url.queryParameters);
          return ok({
            'items': [
              {
                'id': 'patient',
                'full_name': 'Example Patient',
                'patient_number': 'PAT-EXAMPLE',
                'age': 20,
                'gender': 'female',
                'phone': '9000000000',
                'blood_group': 'B+',
                'insurance_provider_name': 'Example Cover',
                'city': 'Vadodara',
                'created_at': '2026-10-23T10:00:00',
              },
            ],
            'meta': {'total_items': 1, 'has_next': false},
          });
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PatientsPage(session: session, service: service),
        ),
      );
      await tester.pumpAndSettle();
      for (final value in [
        'Example Patient',
        'PAT-EXAMPLE',
        '20 y · Female',
        '9000000000',
        'Example Cover',
        'Vadodara',
        '23 Oct 2026',
        'Showing 1–1 of 1 patients',
      ]) {
        expect(find.text(value), findsOneWidget);
      }
      expect(queries.last['per_page'], '100');
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female').last);
      await tester.pumpAndSettle();
      expect(queries.last['gender'], 'female');
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B+').last);
      await tester.pumpAndSettle();
      expect(queries.last['blood_group'], 'B+');
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insured').last);
      await tester.pumpAndSettle();
      expect(queries.last['insurance_category'], 'insured');
      await tester.tap(find.text('CITY'));
      await tester.pumpAndSettle();
      expect(queries.last['sort'], 'city');
      expect(queries.last['order'], 'asc');
      await tester.tap(find.text('CITY'));
      await tester.pumpAndSettle();
      expect(queries.last['order'], 'desc');
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25').last);
      await tester.pumpAndSettle();
      expect(queries.last['per_page'], '25');
      expect(queries.last['page'], '1');
      await tester.tap(find.text('Register patient'));
      await tester.pumpAndSettle();
      expect(find.byType(PatientRegistrationPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'registration sends explicit entered values and validates created patient',
    () async {
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/patients/');
          expect(request.headers['Authorization'], 'Bearer token');
          expect(jsonDecode(request.body), {
            'first_name': 'Example',
            'age': 20,
          });
          return ok({'id': 'created', 'full_name': 'Example', 'age': 20}, 201);
        }),
      );
      addTearDown(service.close);
      expect(
        (await service.registerPatient(session, {
          'first_name': 'Example',
          'age': 20,
        })).id,
        'created',
      );
    },
  );
  test(
    'registration unknown outcome is uncertain and never automatically retried',
    () async {
      var writes = 0;
      final service = DoctorDashboardService(
        client: MockClient((_) async {
          writes++;
          return http.Response('{}', 500);
        }),
      );
      addTearDown(service.close);
      await expectLater(
        service.registerPatient(session, {'first_name': 'Example'}),
        throwsA(
          isA<DraftSaveException>().having(
            (e) => e.uncertain,
            'uncertain',
            true,
          ),
        ),
      );
      expect(writes, 1);
    },
  );
  test('registration exposes validation field labels without echoed data', () async {
    final service = DoctorDashboardService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': [
              {
                'loc': ['body', 'gender'],
                'msg': 'private message',
                'input': 'private input',
              },
              {
                'loc': ['body', 'id_proof_number'],
                'msg': 'private message',
              },
            ],
          }),
          422,
        ),
      ),
    );
    addTearDown(service.close);
    await expectLater(
      service.registerPatient(session, {'first_name': 'QA'}),
      throwsA(
        isA<DraftSaveException>()
            .having(
              (e) => e.message,
              'safe message',
              'Registration rejected (HTTP 422). Check: Sex, ID proof number.',
            )
            .having((e) => e.uncertain, 'confirmed rejection', false),
      ),
    );
  });
}
