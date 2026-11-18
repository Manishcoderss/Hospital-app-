import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';

const session = AuthSession(
  'test-token',
  'test-refresh',
  'Doctor',
  'test@example.com',
);

void main() {
  test(
    'calendar and appointments use the same explicitly selected date',
    () async {
      final requestedDates = <String?>[];
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          requestedDates.add(request.url.queryParameters['date']);
          return http.Response(
            request.url.path.endsWith('/calendar/day')
                ? '{"success":true,"data":{"appointments":1,"by_status":{"confirmed":1}}}'
                : '{"success":true,"data":{"items":[],"meta":{"total_items":0,"has_next":false}}}',
            200,
          );
        }),
      );
      addTearDown(service.close);
      final date = DateTime(2026, 10, 16);
      final summary = await service.fetchDashboardSummary(
        session,
        selectedDate: date,
      );
      await service.fetchAppointments(session, selectedDate: date);
      expect(requestedDates, ['2026-10-16', '2026-10-16']);
      expect(summary.appointments, 1);
      expect(summary.confirmed, 1);
      expect(summary.scheduled, 0);
    },
  );

  test(
    'appointments uses authenticated existing endpoint and local date',
    () async {
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/appointments/');
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(
            request.url.queryParameters['date'],
            matches(r'^\d{4}-\d{2}-\d{2}$'),
          );
          return http.Response('{"success":true,"data":[]}', 200);
        }),
      );
      addTearDown(service.close);
      expect(await service.fetchAppointments(session), {
        'success': true,
        'data': [],
      });
    },
  );

  for (final status in [401, 403, 500]) {
    test('rejects appointments HTTP $status', () async {
      final service = DoctorDashboardService(
        client: MockClient(
          (_) async => http.Response('private response', status),
        ),
      );
      addTearDown(service.close);
      await expectLater(service.fetchAppointments(session), throwsException);
    });
  }

  for (final body in [
    'not json',
    'null',
    '{"success":false,"message":"PRIVATE"}',
  ]) {
    test(
      'rejects invalid or failed envelope without exposing body: $body',
      () async {
        final service = DoctorDashboardService(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        addTearDown(service.close);
        await expectLater(
          service.fetchAppointments(session),
          throwsA(
            predicate((Object error) => !error.toString().contains('PRIVATE')),
          ),
        );
      },
    );
  }
}
