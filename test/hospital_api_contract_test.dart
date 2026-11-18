import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/api_catalog.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/hospital_api.dart';

void main() {
  const session = AuthSession(
    'access-test',
    'refresh-test',
    'Test user',
    'test@example.com',
    role: 'hospital_admin',
  );
  test(
    'all 375 collection operations resolve and dispatch without fixture values',
    () async {
      expect(hospitalOperations, hasLength(375));
      final seen = <String>{};
      final client = MockClient((request) async {
        expect(request.url.host, 'test.hospital.invalid');
        expect(request.url.toString(), isNot(contains('{{')));
        expect(request.headers['Authorization'], startsWith('Bearer '));
        expect([
          'GET',
          'POST',
          'PUT',
          'PATCH',
          'DELETE',
        ], contains(request.method));
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'items': []},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = HospitalApi(
        session,
        client: client,
        baseUrl: 'https://test.hospital.invalid/api/v1',
      );
      addTearDown(api.close);
      for (final op in hospitalOperations) {
        expect(seen.add(op['id'] as String), isTrue);
        final parameters = {
          for (final key in op['parameters'] as List)
            key as String: 'test /?id',
        };
        await api.execute(
          op,
          parameters: parameters,
          query: {
            for (final key in op['query'] as List) key as String: 'test filter',
          },
          body: const {'test': true},
        );
      }
    },
  );
  test('missing identity never dispatches a patient request', () async {
    var calls = 0;
    final api = HospitalApi(
      session,
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.execute({
        'method': 'GET',
        'path': '/patients/{{patient_id}}',
      }, parameters: {}),
      throwsA(isA<HospitalApiException>()),
    );
    expect(calls, 0);
  });
  test(
    'permissions, expired sessions and rate limits have clear errors',
    () async {
      for (final status in [401, 403, 404, 429]) {
        final api = HospitalApi(
          session,
          client: MockClient(
            (_) async => http.Response('<html>error</html>', status),
          ),
        );
        addTearDown(api.close);
        await expectLater(
          api.get('/patients'),
          throwsA(
            isA<HospitalApiException>().having(
              (e) => e.status,
              'status',
              status,
            ),
          ),
        );
      }
    },
  );
  test('server mutation errors cannot be silently submitted again', () async {
    final api = HospitalApi(
      session,
      client: MockClient(
        (_) async =>
            http.Response('{"success":false,"message":"Unavailable"}', 503),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.execute(
        {'method': 'PATCH', 'path': '/appointments/id/status'},
        body: {'status': 'cancelled'},
      ),
      throwsA(
        isA<HospitalApiException>().having(
          (e) => e.uncertain,
          'uncertain',
          true,
        ),
      ),
    );
  });
  test('binary documents keep exact server bytes', () async {
    final bytes = [37, 80, 68, 70, 45];
    final api = HospitalApi(
      session,
      client: MockClient(
        (_) async => http.Response.bytes(
          bytes,
          200,
          headers: {'content-type': 'application/pdf'},
        ),
      ),
    );
    addTearDown(api.close);
    final result = await api.execute({
      'method': 'GET',
      'path': '/consents/test/form',
    });
    expect(result.bytes, bytes);
    expect(result.data, isNull);
  });
  test('refresh endpoint uses the refresh credential only', () async {
    final api = HospitalApi(
      session,
      client: MockClient((r) async {
        expect(r.headers['Authorization'], 'Bearer refresh-test');
        return http.Response('{"success":true,"data":{}}', 200);
      }),
    );
    addTearDown(api.close);
    await api.execute({'method': 'POST', 'path': '/auth/refresh'});
  });
}
