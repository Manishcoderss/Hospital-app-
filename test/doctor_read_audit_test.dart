import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_read_audit.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';

const session = AuthSession(
  'PRIVATE_ACCESS',
  'PRIVATE_REFRESH',
  'PRIVATE_NAME',
  'PRIVATE_EMAIL',
  role: 'doctor',
);
http.Response ok(Object data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);

void main() {
  for (final matchesPatient in [true, false]) {
    test(
      'selected-record checks use opaque IDs and validate patient linkage: $matchesPatient',
      () async {
        final paths = <String>[];
        final lines = <String>[];
        await DoctorReadAudit(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            paths.add(request.url.path);
            return ok(switch (request.url.path) {
              '/api/v1/auth/me' => {'role': 'doctor'},
              '/api/v1/patients/opaque-patient' => {
                'id': 'opaque-patient',
                'full_name': 'PRIVATE_TEST_PATIENT',
              },
              '/api/v1/appointments/opaque-appointment' => {
                'id': 'opaque-appointment',
                'doctor_id': 'doctor',
                'patient_id': matchesPatient
                    ? 'opaque-patient'
                    : 'other-patient',
                'appointment_date': '2026-11-17',
                'appointment_time': '10:00',
                'status': 'scheduled',
              },
              _ => {
                'items': [],
                'meta': {'total_items': 0, 'has_next': false},
              },
            });
          }),
        ).run(
          session,
          patientId: 'opaque-patient',
          appointmentId: 'opaque-appointment',
          recordsOnly: true,
          report: lines.add,
        );
        expect(paths, [
          '/api/v1/auth/me',
          '/api/v1/patients/opaque-patient',
          '/api/v1/patients/opaque-patient/appointments',
          '/api/v1/patients/opaque-patient/lab-orders',
          '/api/v1/appointments/opaque-appointment',
        ]);
        expect(
          lines,
          contains(
            'dummy_appointment|${matchesPatient ? 'pass' : 'contract_error'}|200',
          ),
        );
        expect(lines.join(), isNot(contains('opaque-')));
        expect(lines.join(), isNot(contains('PRIVATE')));
      },
    );
  }
  for (final oldTokenStatus in [401, 200]) {
    test(
      'opt-in logout probe detects old access status $oldTokenStatus without exporting it',
      () async {
        final lines = <String>[];
        final methods = <String>[];
        final service = DoctorDashboardService(
          sessionAudit: (check, code) => lines.add('$check:$code'),
          client: MockClient((request) async {
            methods.add(request.method);
            expect(request.headers['Authorization'], 'Bearer PRIVATE_ACCESS');
            if (request.method == 'POST') return http.Response('', 204);
            expect(request.url.path, '/api/v1/auth/me');
            return http.Response('PRIVATE_USER_BODY', oldTokenStatus);
          }),
        );
        addTearDown(service.close);
        expect(await service.revokeSession(session), oldTokenStatus == 401);
        expect(methods, ['POST', 'GET']);
        expect(lines, ['logout:204', 'revoked_access:$oldTokenStatus']);
        expect(lines.join(), isNot(contains('PRIVATE')));
      },
    );
  }
  test(
    'read audit stops before medical reads for a non-doctor account',
    () async {
      var calls = 0;
      final lines = <String>[];
      await DoctorReadAudit(
        client: MockClient((request) async {
          calls++;
          return ok({'role': 'patient'});
        }),
      ).run(session, report: lines.add);
      expect(calls, 1);
      expect(lines, contains('doctor_scope|not_verified|0'));
    },
  );

  for (final code in [401, 429]) {
    test('read audit stops further requests after HTTP $code', () async {
      final paths = <String>[];
      final lines = <String>[];
      await DoctorReadAudit(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          paths.add(request.url.path);
          if (request.url.path.endsWith('/auth/me')) {
            return ok({'role': 'doctor'});
          }
          return http.Response('PRIVATE_SERVER_BODY', code);
        }),
      ).run(session, report: lines.add);
      expect(paths.any((path) => path.contains('/appointments')), isFalse);
      expect(lines, contains('appointments|skipped|0'));
      expect(lines.join(), isNot(contains('PRIVATE')));
    });
  }

  test(
    'read audit records permissions without tokens, IDs or medical values',
    () async {
      final lines = <String>[];
      final methods = <String>[];
      await DoctorReadAudit(
        client: MockClient((request) async {
          methods.add(request.method);
          expect(request.headers['Authorization'], 'Bearer PRIVATE_ACCESS');
          if (request.url.path.endsWith('/auth/me')) {
            return ok({'role': 'doctor', 'full_name': 'PRIVATE_NAME'});
          }
          return http.Response('{"message":"PRIVATE_MEDICAL_BODY"}', 403);
        }),
      ).run(
        session,
        patientId: 'PRIVATE_PATIENT',
        appointmentId: 'PRIVATE_APPOINTMENT',
        report: lines.add,
      );
      expect(methods.every((method) => method == 'GET'), isTrue);
      expect(lines, contains('dummy_patient|restricted|403'));
      expect(lines, isNot(contains('dummy_patient_visits|pass|200')));
      expect(lines.join(), isNot(contains('PRIVATE')));
      expect(lines, contains('stock|restricted|403'));
    },
  );

  test(
    'HTTP 200 with malformed data is not a passed integration check',
    () async {
      final lines = <String>[];
      await DoctorReadAudit(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/me')) {
            return ok({'role': 'doctor'});
          }
          return ok({'private': 'PRIVATE_MEDICAL_BODY'});
        }),
      ).run(session, report: lines.add);
      expect(lines, contains('dashboard|contract_error|200'));
      expect(lines, contains('appointments|contract_error|200'));
      expect(lines.join(), isNot(contains('PRIVATE')));
    },
  );

  for (final code in [200, 204, 401, 403, 500]) {
    test(
      'current-session logout uses backend contract for HTTP $code',
      () async {
        var requests = 0;
        final service = DoctorDashboardService(
          client: MockClient((request) async {
            requests++;
            expect(request.method, 'POST');
            expect(request.url.path, '/api/v1/auth/logout');
            expect(request.headers['Authorization'], 'Bearer PRIVATE_ACCESS');
            expect(request.body, isEmpty);
            return http.Response(code == 200 ? '{"success":true}' : '', code);
          }),
        );
        addTearDown(service.close);
        expect(
          await service.revokeSession(session),
          [200, 204, 401].contains(code),
        );
        expect(requests, 1);
      },
    );
  }

  test(
    'offline logout and malformed success are not falsely confirmed',
    () async {
      for (final offline in [true, false]) {
        final service = DoctorDashboardService(
          client: MockClient((_) async {
            if (offline) {
              throw http.ClientException('PRIVATE_CONNECTION_DETAILS');
            }
            return http.Response('<html>PRIVATE</html>', 200);
          }),
        );
        addTearDown(service.close);
        expect(await service.revokeSession(session), isFalse);
      }
    },
  );
}
