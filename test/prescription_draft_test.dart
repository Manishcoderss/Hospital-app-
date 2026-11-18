import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/appointment.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/prescription_draft.dart';
import 'package:mayo_delivery_partner/prescription_draft_page.dart';

const session = AuthSession(
  'access',
  'refresh',
  'Admin',
  'example@test.com',
  role: 'hospital_admin',
);
const appointment = Appointment(
  id: 'appointment',
  date: '2026-10-16',
  time: '11:30',
  status: 'confirmed',
  patientName: 'Example Patient',
  doctorId: 'doctor',
  doctorName: 'Example Doctor',
  department: 'Medicine',
  patientId: 'patient',
);
const draft = PrescriptionDraft(
  patientId: 'patient',
  doctorId: 'doctor',
  appointmentId: 'appointment',
  fields: {'chief_complaint': ' Example complaint ', 'allergies': ''},
  medications: [
    {'medicine_name': 'Example medicine', 'dosage': 'Recorded dosage'},
  ],
);
http.Response response(Object data, {int status = 200}) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status);

void main() {
  testWidgets(
    'leaving edited consultation requires confirmation and can discard',
    (tester) async {
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/me')) {
            return response({
              'id': 'admin',
              'full_name': 'Admin',
              'role': 'hospital_admin',
            });
          }
          return response({'id': 'patient', 'full_name': 'Example Patient'});
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PrescriptionDraftPage(
                      session: session,
                      appointment: appointment,
                      service: service,
                    ),
                  ),
                ),
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Chief complaint'),
        'Unsaved note',
      );
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Unsaved note'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Start'), findsOneWidget);
      expect(find.byType(PrescriptionDraftPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final role in ['hospital_admin', 'doctor']) {
    test(
      'draft save for $role uses verified payload and never issues',
      () async {
        final service = DoctorDashboardService(
          client: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/v1/prescriptions/');
            expect(request.headers['Authorization'], 'Bearer access');
            final body = jsonDecode(request.body) as Map;
            expect(body['patient_id'], 'patient');
            expect(body['appointment_id'], 'appointment');
            expect(body['chief_complaint'], 'Example complaint');
            expect(body['allergies'], isNull);
            expect(body.containsKey('doctor_id'), role != 'doctor');
            expect(body['lab_tests'], isEmpty);
            return response({
              'id': 'saved-draft',
              'status': 'draft',
            }, status: 201);
          }),
        );
        addTearDown(service.close);
        expect(
          await service.savePrescriptionDraft(session, draft, role: role),
          'saved-draft',
        );
      },
    );
  }

  test(
    'allergy check validates each medicine and preserves server conflicts',
    () async {
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/prescriptions/allergy-check');
          expect(jsonDecode(request.body)['medications'], [
            {'medicine_name': 'Example medicine'},
          ]);
          return response({
            'items': [
              {
                'index': 0,
                'conflicts': ['Recorded conflict'],
              },
            ],
          });
        }),
      );
      addTearDown(service.close);
      expect(await service.checkDraftAllergies(session, draft), [
        ['Recorded conflict'],
      ]);
    },
  );

  test(
    'incomplete allergy response cannot be treated as no conflicts',
    () async {
      final service = DoctorDashboardService(
        client: MockClient((_) async => response({'items': []})),
      );
      addTearDown(service.close);
      await expectLater(
        service.checkDraftAllergies(session, draft),
        throwsFormatException,
      );
    },
  );

  test(
    'uncertain write result is marked so the UI can prevent blind retry',
    () async {
      for (final result in [
        http.Response('PRIVATE', 500),
        response({'id': 'missing-status'}),
        response({'id': 'issued', 'status': 'issued'}),
      ]) {
        final service = DoctorDashboardService(
          client: MockClient((_) async => result),
        );
        await expectLater(
          service.savePrescriptionDraft(session, draft, role: 'doctor'),
          throwsA(
            isA<DraftSaveException>()
                .having((e) => e.uncertain, 'uncertain', true)
                .having(
                  (e) => e.message,
                  'safe message',
                  isNot(contains('PRIVATE')),
                ),
          ),
        );
        service.close();
      }
    },
  );

  test('unauthorized role does not send a save request', () async {
    final service = DoctorDashboardService(
      client: MockClient((_) async {
        fail('Must not send a write');
      }),
    );
    addTearDown(service.close);
    await expectLater(
      service.savePrescriptionDraft(session, draft, role: 'patient'),
      throwsA(isA<DraftSaveException>()),
    );
  });

  testWidgets('review and continue editing do not write to the backend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var writes = 0;
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        if (request.method != 'GET') {
          writes++;
          fail('Opening or reviewing notes must not save');
        }
        if (request.url.path.endsWith('/auth/me')) {
          return response({
            'id': 'admin',
            'full_name': 'Admin',
            'role': 'hospital_admin',
          });
        }
        return response({
          'id': 'patient',
          'full_name': 'Example Patient',
          'allergies': null,
        });
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PrescriptionDraftPage(
          session: session,
          appointment: appointment,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Chief complaint'),
      'Example complaint',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Review draft'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Review draft'));
    await tester.pumpAndSettle();
    expect(find.text('Save draft'), findsOneWidget);
    expect(writes, 0);
    await tester.scrollUntilVisible(
      find.text('Continue editing'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Continue editing'));
    await tester.pumpAndSettle();
    expect(find.text('Save draft'), findsNothing);
    expect(writes, 0);
    expect(tester.takeException(), isNull);
  });
}
