import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';

void main() {
  test(
    'doctor login trims email but preserves password and account role',
    () async {
      final auth = AuthService(
        client: MockClient((request) async {
          expect(jsonDecode(request.body), {
            'email': 'doctor@example.test',
            'password': ' secret ',
          });
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'access_token': 'access',
                'refresh_token': 'refresh',
                'user': {
                  'full_name': 'Doctor',
                  'role': ' DOCTOR ',
                  'is_active': true,
                },
              },
            }),
            200,
          );
        }),
      );
      addTearDown(auth.close);
      final session = await auth.login(' doctor@example.test ', ' secret ');
      expect(session.role, 'doctor');
      expect(session.email, 'doctor@example.test');
    },
  );

  test('inactive account cannot create a usable sign-in', () async {
    final auth = AuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'access_token': 'access',
              'refresh_token': 'refresh',
              'user': {'role': 'doctor', 'is_active': false},
            },
          }),
          200,
        ),
      ),
    );
    addTearDown(auth.close);
    await expectLater(
      auth.login('doctor@example.test', 'secret'),
      throwsA(
        isA<LoginException>().having(
          (error) => error.message,
          'message',
          contains('inactive'),
        ),
      ),
    );
  });

  test('Rejected credentials preserve API error', () async {
    final auth = AuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'success': false, 'message': 'Invalid credentials'}),
          401,
        ),
      ),
    );
    addTearDown(auth.close);
    await expectLater(
      auth.login('test@example.com', 'wrong'),
      throwsA(
        isA<LoginException>().having(
          (e) => e.message,
          'message',
          'Invalid credentials',
        ),
      ),
    );
  });
  test('HTML and incomplete successful responses fail safely', () async {
    for (final body in ['<html>Error</html>', '{"success":true,"data":{}}']) {
      final auth = AuthService(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(auth.close);
      await expectLater(
        auth.login('test@example.com', 'secret'),
        throwsA(isA<LoginException>()),
      );
    }
  });
  test('Network and timeout failures are readable', () async {
    for (final error in [
      http.ClientException('offline'),
      TimeoutException('timeout'),
    ]) {
      final auth = AuthService(client: MockClient((_) async => throw error));
      addTearDown(auth.close);
      await expectLater(
        auth.login('test@example.com', 'secret'),
        throwsA(isA<LoginException>()),
      );
    }
  });
  test(
    'Password-reset-required account does not enter signed-in screen',
    () async {
      final auth = AuthService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'access_token': 'test',
                'refresh_token': 'test',
                'user': {'force_password_reset': true},
              },
            }),
            200,
          ),
        ),
      );
      addTearDown(auth.close);
      await expectLater(
        auth.login('test@example.com', 'secret'),
        throwsA(isA<LoginException>()),
      );
    },
  );
}
