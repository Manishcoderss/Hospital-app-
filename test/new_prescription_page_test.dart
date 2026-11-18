import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/appointment_booking_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/new_prescription_page.dart';
import 'package:mayo_delivery_partner/prescription_detail_page.dart';

http.Response ok(Object data, [int status = 200]) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status);
const session = AuthSession(
  'token',
  'refresh',
  'Doctor',
  'doctor@test',
  role: 'doctor',
);
void main() {
  testWidgets('selected patient must match the returned patient identity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        if (request.url.path.endsWith('/auth/me')) {
          return ok({'id': 'user', 'full_name': 'Doctor', 'role': 'doctor'});
        }
        if (request.url.path.endsWith('/patients/dropdown')) {
          return ok({
            'items': [
              {'id': 'qa', 'full_name': 'QA Doctor Test'},
            ],
          });
        }
        if (request.url.path.endsWith('/patients/qa')) {
          return ok({
            'id': 'different',
            'full_name': 'Different test patient',
            'allergies': 'Must not copy into the editor',
          });
        }
        throw StateError('Unexpected read');
      }),
    );
    final booking = AppointmentBookingService(
      client: MockClient(
        (request) async => request.url.path.endsWith('/doctors/me')
            ? ok({'id': 'doctor'})
            : ok([
                {'id': 'doctor', 'name': 'Test doctor'},
              ]),
      ),
    );
    addTearDown(service.close);
    addTearDown(booking.close);
    await tester.pumpWidget(
      MaterialApp(
        home: NewPrescriptionPage(
          session: session,
          service: service,
          bookingService: booking,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'QA');
    await tester.tap(find.byTooltip('Search patients'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('QA Doctor Test'));
    await tester.pumpAndSettle();
    expect(
      find.text('Patient response could not be read. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('Different test patient'), findsNothing);
    expect(find.textContaining('Must not copy into the editor'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'expired patient search explains sign-in and clears old results',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var searches = 0;
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          if (request.url.path.endsWith('/auth/me')) {
            return ok({'id': 'user', 'full_name': 'Doctor', 'role': 'doctor'});
          }
          if (request.url.path.endsWith('/patients/dropdown')) {
            searches++;
            return searches == 1
                ? ok({
                    'items': [
                      {'id': 'qa', 'full_name': 'QA Doctor Test'},
                    ],
                  })
                : http.Response('{"message":"private server detail"}', 401);
          }
          throw StateError('Unexpected read');
        }),
      );
      final booking = AppointmentBookingService(
        client: MockClient(
          (request) async => request.url.path.endsWith('/doctors/me')
              ? ok({'id': 'doctor'})
              : ok([
                  {'id': 'doctor', 'name': 'Test doctor'},
                ]),
        ),
      );
      addTearDown(service.close);
      addTearDown(booking.close);
      await tester.pumpWidget(
        MaterialApp(
          home: NewPrescriptionPage(
            session: session,
            service: service,
            bookingService: booking,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'QA');
      await tester.tap(find.byTooltip('Search patients'));
      await tester.pumpAndSettle();
      expect(find.text('QA Doctor Test'), findsOneWidget);
      await tester.tap(find.byTooltip('Search patients'));
      await tester.pumpAndSettle();
      expect(
        find.text('Session expired. Please sign in again.'),
        findsOneWidget,
      );
      expect(find.text('QA Doctor Test'), findsNothing);
      expect(find.textContaining('private server detail'), findsNothing);
      expect(searches, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'full editor selects patient and saves draft without an appointment',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saves = 0, issues = 0;
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/me')) {
            return ok({'id': 'user', 'full_name': 'Doctor', 'role': 'doctor'});
          }
          if (request.url.path.endsWith('/patients/dropdown')) {
            return ok({
              'items': [
                {'id': 'patient', 'full_name': 'Example Patient'},
              ],
            });
          }
          if (request.url.path.endsWith('/patients/patient')) {
            return ok({
              'id': 'patient',
              'full_name': 'Example Patient',
              'allergies': 'Recorded allergy',
            });
          }
          if (request.url.path.endsWith('/prescriptions/allergy-check')) {
            return ok({
              'items': [
                {'index': 0, 'conflicts': []},
              ],
            });
          }
          if (request.url.path.endsWith('/prescriptions/') &&
              request.method == 'POST') {
            saves++;
            final payload = jsonDecode(request.body) as Map;
            expect(payload.containsKey('appointment_id'), false);
            expect(payload.containsKey('doctor_id'), false);
            expect(payload['patient_id'], 'patient');
            expect(
              payload['medications'][0]['medicine_name'],
              'Example medicine',
            );
            expect(payload['medications'][0]['dosage'], 'Example dose');
            return ok({'id': 'rx', 'status': 'draft'}, 201);
          }
          if (request.method == 'PATCH') issues++;
          if (request.url.path.endsWith('/prescriptions/rx')) {
            return ok({
              'id': 'rx',
              'status': 'draft',
              'patient_id': 'patient',
              'patient': {'full_name': 'Example Patient'},
              'medications': [],
              'lab_tests': [],
            });
          }
          throw StateError('Unexpected request ${request.url.path}');
        }),
      );
      final booking = AppointmentBookingService(
        client: MockClient(
          (request) async => request.url.path.endsWith('/doctors/me')
              ? ok({'id': 'doctor'})
              : ok([
                  {'id': 'doctor', 'name': 'Example Doctor'},
                ]),
        ),
      );
      addTearDown(service.close);
      addTearDown(booking.close);
      await tester.pumpWidget(
        MaterialApp(
          home: NewPrescriptionPage(
            session: session,
            service: service,
            bookingService: booking,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(saves, 0);
      await tester.enterText(find.byType(TextField).first, 'Example');
      await tester.tap(find.byTooltip('Search patients'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Example Patient'));
      await tester.pumpAndSettle();
      final medicine = find.widgetWithText(TextFormField, 'Medicine name');
      await tester.scrollUntilVisible(
        medicine,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(medicine, 'Example medicine');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dose'),
        'Example dose',
      );
      final saveButton = find.widgetWithText(OutlinedButton, 'Save draft');
      await tester.scrollUntilVisible(
        saveButton,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(find.text('Review prescription'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save draft'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(issues, 0);
      expect(find.byType(PrescriptionDetailPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
