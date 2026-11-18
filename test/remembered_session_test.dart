import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/main.dart';
import 'package:mayo_delivery_partner/doctor_home.dart';
import 'package:mayo_delivery_partner/remembered_session_store.dart';

http.Response ok(Object data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
const session = AuthSession(
  'access',
  'refresh',
  'Doctor',
  'doctor@example.test',
  role: 'doctor',
);

class DeleteFailureStorage extends FlutterSecureStorage {
  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw StateError('Native storage unavailable');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });
  test(
    'secure store persists only refresh token/email and can be cleared',
    () async {
      final store = RememberedSessionStore();
      await store.save(session);
      final raw = await const FlutterSecureStorage().read(
        key: RememberedSessionStore.key,
      );
      expect(jsonDecode(raw!), {
        'refresh_token': 'refresh',
        'email': 'doctor@example.test',
      });
      expect(raw.contains('password'), false);
      expect(raw.contains('access_token'), false);
      expect((await store.read())!.email, session.email);
      await store.clear();
      expect(await store.read(), isNull);
    },
  );
  test(
    'corrupt saved sign-in is removed without trusting cached data',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        RememberedSessionStore.key: 'not-json',
      });
      expect(await RememberedSessionStore().read(), isNull);
      expect(
        await const FlutterSecureStorage().read(
          key: RememberedSessionStore.key,
        ),
        isNull,
      );
    },
  );
  test(
    'restore uses refresh bearer and validates user with fresh access token',
    () async {
      final requests = <String>[];
      final auth = AuthService(
        client: MockClient((request) async {
          requests.add(request.url.path);
          if (request.url.path.endsWith('/auth/refresh')) {
            expect(request.method, 'POST');
            expect(request.headers['Authorization'], 'Bearer refresh');
            expect(request.body, isEmpty);
            return ok({
              'access_token': 'fresh-access',
              'refresh_token': 'rotated-refresh',
            });
          }
          expect(request.headers['Authorization'], 'Bearer fresh-access');
          return ok({
            'full_name': 'Doctor',
            'email': session.email,
            'role': 'doctor',
            'is_active': true,
          });
        }),
      );
      addTearDown(auth.close);
      final restored = await auth.restoreSession('refresh');
      expect(restored.accessToken, 'fresh-access');
      expect(restored.refreshToken, 'rotated-refresh');
      expect(restored.role, 'doctor');
      expect(requests, ['/api/v1/auth/refresh', '/api/v1/auth/me']);
    },
  );
  test('refresh endpoint returning only access token preserves original refresh token', () async {
    final auth = AuthService(
      client: MockClient(
        (request) async => request.method == 'POST'
            ? ok({'access_token': 'fresh'})
            : ok({'role': 'doctor'}),
      ),
    );
    addTearDown(auth.close);
    expect((await auth.restoreSession('refresh')).refreshToken, 'refresh');
  });
  testWidgets(
    'Remember me checkbox persists successful sign-in without a password',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = AuthService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/login');
          return ok({
            'access_token': 'access',
            'refresh_token': 'refresh',
            'user': {
              'full_name': 'Doctor',
              'email': session.email,
              'role': 'doctor',
            },
          });
        }),
      );
      addTearDown(auth.close);
      await tester.pumpWidget(MyApp(authService: auth));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, session.email);
      await tester.enterText(
        find.byType(TextFormField).last,
        'example-password',
      );
      await tester.ensureVisible(find.text('Remember me'));
      await tester.tap(find.text('Remember me'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Login'));
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.byType(DoctorHome), findsOneWidget);
      expect((await RememberedSessionStore().read())!.refreshToken, 'refresh');
      final raw = await const FlutterSecureStorage().read(
        key: RememberedSessionStore.key,
      );
      expect(raw!.contains('example-password'), false);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('saved session restores on app start without password login', (
    tester,
  ) async {
    await RememberedSessionStore().save(session);
    var refreshes = 0;
    final auth = AuthService(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/api/v1/auth/refresh');
          refreshes++;
          return ok({'access_token': 'fresh-access'});
        }
        return ok({
          'full_name': 'Doctor',
          'email': session.email,
          'role': 'doctor',
          'is_active': true,
        });
      }),
    );
    addTearDown(auth.close);
    await tester.pumpWidget(MyApp(authService: auth));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorHome), findsOneWidget);
    expect(refreshes, 1);
    expect(tester.takeException(), isNull);
  });
  test('failed native deletion cannot restore the old saved account', () async {
    await RememberedSessionStore().save(session);
    await RememberedSessionStore(storage: DeleteFailureStorage()).clear();
    expect(await RememberedSessionStore().read(), isNull);
    expect(
      await const FlutterSecureStorage().read(key: RememberedSessionStore.key),
      isNotNull,
    );
  });
  testWidgets('expired saved token is cleared and sign-in is shown', (
    tester,
  ) async {
    await RememberedSessionStore().save(session);
    final auth = AuthService(
      client: MockClient((_) async => http.Response('{"success":false}', 401)),
    );
    addTearDown(auth.close);
    await tester.pumpWidget(MyApp(authService: auth));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(await RememberedSessionStore().read(), isNull);
    expect(find.byType(DoctorHome), findsNothing);
  });
  testWidgets('saved patient sign-in cannot restore into staff dashboard', (
    tester,
  ) async {
    await RememberedSessionStore().save(session);
    final auth = AuthService(
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return ok({'access_token': 'fresh-access'});
        }
        return ok({
          'full_name': 'Patient',
          'role': 'patient',
          'is_active': true,
        });
      }),
    );
    addTearDown(auth.close);
    await tester.pumpWidget(MyApp(authService: auth));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorHome), findsNothing);
    expect(await RememberedSessionStore().read(), isNull);
    expect(
      find.text(
        'Please use patient sign-in. This login is for hospital staff.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry saved sign-in'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'temporary refresh failure retains saved sign-in and unchecking clears it',
    (tester) async {
      await RememberedSessionStore().save(session);
      final auth = AuthService(
        client: MockClient((_) async => http.Response('{}', 503)),
      );
      addTearDown(auth.close);
      await tester.pumpWidget(MyApp(authService: auth));
      await tester.pumpAndSettle();
      expect(await RememberedSessionStore().read(), isNotNull);
      expect(find.text('Retry saved sign-in'), findsOneWidget);
      await tester.ensureVisible(find.text('Remember me'));
      await tester.tap(find.text('Remember me'));
      await tester.pumpAndSettle();
      expect(await RememberedSessionStore().read(), isNull);
    },
  );
}
