import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/appointment_booking_page.dart';
import 'package:mayo_delivery_partner/appointment_booking_service.dart';
import 'package:mayo_delivery_partner/auth_service.dart';

const session = AuthSession(
  'access',
  'refresh',
  'Doctor',
  'doctor@example.test',
  role: 'doctor',
);
http.Response ok(Object data, {int status = 200}) =>
    http.Response(jsonEncode({'success': true, 'data': data}), status);

void main() {
  testWidgets(
    'booking form selects patient and available slot, then submits once',
    (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      final service = AppointmentBookingService(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            writes++;
            final body = jsonDecode(request.body) as Map;
            expect(body['patient_id'], 'patient');
            expect(body['doctor_id'], 'doctor');
            expect(body['time'], '23:59');
            return ok({'id': 'created'}, status: 201);
          }
          if (request.url.path.endsWith('/doctors/me')) {
            return ok({'id': 'doctor'});
          }
          if (request.url.path.endsWith('/doctors/dropdown')) {
            return ok([
              {'id': 'doctor', 'name': 'Example Doctor'},
            ]);
          }
          if (request.url.path.endsWith('/patients/dropdown')) {
            return ok({
              'items': [
                {
                  'id': 'patient',
                  'full_name': 'Example Patient',
                  'patient_number': 'PAT-TEST',
                },
              ],
            });
          }
          if (request.url.path.endsWith('/availability')) {
            return ok({
              'is_available': true,
              'slots': [
                {'time': '23:59', 'available': true},
                {'time': '10:00', 'available': false},
              ],
            });
          }
          throw StateError('Unexpected request');
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
                    builder: (_) => AppointmentBookingPage(
                      session: session,
                      service: service,
                    ),
                  ),
                ),
                child: const Text('Open booking'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open booking'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField).first, 'Example');
      await tester.tap(find.byTooltip('Search patients'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Example Patient'));
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(DateTime.now().add(const Duration(days: 1)));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, '10:00'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, '23:59'));
      await tester.pump();
      expect(writes, 0);
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.byType(AppointmentBookingPage), findsNothing);
      expect(find.text('Open booking'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('booking uses the web contract and bearer authentication', () async {
    var writes = 0;
    final service = AppointmentBookingService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/appointments/');
        expect(request.headers['Authorization'], 'Bearer access');
        expect(jsonDecode(request.body), {
          'patient_id': 'patient',
          'doctor_id': 'doctor',
          'date': '2026-11-01',
          'time': '10:30',
          'reason': 'Review',
          'symptoms': 'Headache',
          'is_follow_up': true,
        });
        writes++;
        return ok({'id': 'booked'}, status: 201);
      }),
    );
    addTearDown(service.close);
    expect(
      await service.book(
        session,
        patientId: 'patient',
        doctorId: 'doctor',
        date: '2026-11-01',
        time: '10:30',
        reason: ' Review ',
        symptoms: 'Headache',
        followUp: true,
      ),
      'booked',
    );
    expect(writes, 1);
  });

  test(
    'lookups use scoped patient search and only available doctor slots',
    () async {
      final service = AppointmentBookingService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/patients/dropdown')) {
            expect(request.url.queryParameters, {
              'module': 'appointments',
              'q': 'Example',
              'per_page': '20',
            });
            return ok({
              'items': [
                {'id': 'patient', 'full_name': 'Example Patient'},
              ],
            });
          }
          expect(request.url.path, '/api/v1/doctors/doctor/availability');
          expect(request.url.queryParameters['date'], '2026-11-01');
          return ok({
            'is_available': true,
            'slots': [
              {'time': '10:30', 'available': true},
              {'time': '11:00', 'available': false},
            ],
          });
        }),
      );
      addTearDown(service.close);
      expect(
        (await service.patients(session, ' Example ')).single['id'],
        'patient',
      );
      expect(await service.slots(session, 'doctor', '2026-11-01'), ['10:30']);
    },
  );

  for (final status in [401, 403, 409, 422, 500]) {
    test(
      'booking HTTP $status preserves certainty and does not retry POST',
      () async {
        var writes = 0;
        final service = AppointmentBookingService(
          client: MockClient((_) async {
            writes++;
            return http.Response('{}', status);
          }),
        );
        addTearDown(service.close);
        await expectLater(
          service.book(
            session,
            patientId: 'patient',
            doctorId: 'doctor',
            date: '2026-11-01',
            time: '10:30',
          ),
          throwsA(
            isA<BookingException>().having(
              (e) => e.uncertain,
              'uncertain',
              status == 500,
            ),
          ),
        );
        expect(writes, 1);
      },
    );
  }

  test('lost response is uncertain and never automatically retried', () async {
    var writes = 0;
    final service = AppointmentBookingService(
      client: MockClient((_) async {
        writes++;
        throw http.ClientException('Disconnected');
      }),
    );
    addTearDown(service.close);
    await expectLater(
      service.book(
        session,
        patientId: 'patient',
        doctorId: 'doctor',
        date: '2026-11-01',
        time: '10:30',
      ),
      throwsA(
        isA<BookingException>().having((e) => e.uncertain, 'uncertain', true),
      ),
    );
    expect(writes, 1);
  });

  testWidgets('denied doctor dropdown shows retry and prevents booking', (
    tester,
  ) async {
    var writes = 0;
    final service = AppointmentBookingService(
      client: MockClient((request) async {
        if (request.method == 'POST') writes++;
        return http.Response('{"success":false}', 403);
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AppointmentBookingPage(session: session, service: service),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('doctor profile and permissions'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(writes, 0);
  });

  testWidgets(
    'missing own doctor profile still allows selecting an available doctor',
    (tester) async {
      var slotReads = 0;
      final service = AppointmentBookingService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          if (request.url.path.endsWith('/doctors/dropdown')) {
            return ok([
              {'id': 'doctor', 'name': 'Available Doctor'},
            ]);
          }
          if (request.url.path.endsWith('/doctors/me')) {
            return http.Response(
              '{"success":false,"message":"No doctor profile found for your account"}',
              403,
            );
          }
          if (request.url.path.endsWith('/availability')) {
            slotReads++;
            return ok({'is_available': true, 'slots': []});
          }
          throw StateError('Unexpected endpoint');
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentBookingPage(session: session, service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(TextField), findsWidgets);
      expect(
        find.text('Choose a doctor to see available times.'),
        findsOneWidget,
      );
      expect(slotReads, 0);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Available Doctor').last);
      await tester.pumpAndSettle();
      expect(slotReads, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
