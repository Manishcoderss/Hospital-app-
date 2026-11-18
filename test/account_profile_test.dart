import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/profile_page.dart';

const session = AuthSession(
  'token',
  'refresh',
  'Test Doctor',
  'test@example.test',
  role: 'doctor',
);
http.Response ok(Object data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
void main() {
  testWidgets(
    'profile edits own details, Undo restores and email/mobile stay read-only',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      final account = <String, dynamic>{
        'id': 'user',
        'first_name': 'Test',
        'last_name': 'Doctor',
        'full_name': 'Test Doctor',
        'address': 'Example address',
        'email': 'test@example.test',
        'phone': '9000000000',
        'role': 'doctor',
        'hospital': {'name': 'Example Hospital'},
        'created_at': '2026-10-22T10:00:00',
        'is_email_verified': false,
      };
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            writes++;
            expect(request.url.path, '/api/v1/users/user');
            expect(request.headers['Authorization'], 'Bearer token');
            final body = jsonDecode(request.body) as Map;
            expect(body.keys.toSet(), {'first_name', 'last_name', 'address'});
            expect(body['first_name'], 'Updated');
            account['first_name'] = body['first_name'];
            account['full_name'] = 'Updated Doctor';
            return ok({});
          }
          expect(request.url.path, '/api/v1/auth/me');
          return ok(account);
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfilePage(
              session: session,
              service: service,
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('My account'), findsNothing);
      expect(find.text('Your details'), findsOneWidget);
      expect(find.text('22 Oct 2026'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(3));
      expect(writes, 0);
      await tester.enterText(find.byType(TextField).first, 'Temporary');
      await tester.pump();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Test',
      );
      await tester.enterText(find.byType(TextField).first, 'Updated');
      await tester.pump();
      await tester.tap(find.text('Save details'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Updated Doctor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('notification preferences whitelist fields and retain mandatory security alerts', () async {
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/notification-preferences/');
        final body = jsonDecode(request.body) as Map;
        expect(body['email_notifications'], true);
        expect(body['security_alerts'], true);
        expect(body.containsKey('user_id'), false);
        expect(body['quiet_hours_start'], '22:00');
        expect(body['quiet_hours_end'], '07:00');
        return ok({});
      }),
    );
    addTearDown(service.close);
    await service.saveNotificationPreferences(session, {
      'email_notifications': true,
      'security_alerts': false,
      'quiet_hours_start': '22:00',
      'quiet_hours_end': '07:00',
      'user_id': 'different-user',
    });
  });
  test('partial quiet hours do not send a save request', () async {
    var calls = 0;
    final service = DoctorDashboardService(
      client: MockClient((_) async {
        calls++;
        return ok({});
      }),
    );
    addTearDown(service.close);
    await expectLater(
      service.saveNotificationPreferences(session, {
        'quiet_hours_start': '22:00',
      }),
      throwsA(isA<AppointmentDetailException>()),
    );
    expect(calls, 0);
  });
  test('verification uses authenticated account email rather than arbitrary recipient', () async {
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return ok({'id': 'user', 'email': 'test@example.test'});
        }
        expect(request.url.path, '/api/v1/otp/verify');
        expect(jsonDecode(request.body), {
          'target': 'test@example.test',
          'otp': '123456',
          'purpose': 'verify_email',
        });
        return ok({});
      }),
    );
    addTearDown(service.close);
    await service.verifyAccountEmail(session, '123456');
  });
}
