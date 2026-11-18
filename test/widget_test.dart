import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_home.dart';
import 'package:mayo_delivery_partner/main.dart';
import 'package:mayo_delivery_partner/soft_bottom_bar.dart';
import 'package:mayo_delivery_partner/remembered_session_store.dart';

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
  testWidgets(
    'small phone keyboard and failed login allow retry without duplicate requests',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      var requests = 0;
      final pending = Completer<http.Response>();
      final auth = AuthService(
        client: MockClient((_) {
          requests++;
          return pending.future;
        }),
      );
      addTearDown(auth.close);
      await tester.pumpWidget(MyApp(authService: auth));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'doctor@example.test',
      );
      await tester.enterText(find.byType(TextFormField).last, 'wrong');
      await tester.ensureVisible(find.text('Login'));
      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(requests, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(DoctorHome), findsNothing);
      pending.complete(
        http.Response('{"success":false,"message":"Invalid credentials"}', 401),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invalid credentials'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(await RememberedSessionStore().read(), isNull);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Login'))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('patient account cannot enter or persist in staff login', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'access_token': 'access',
              'refresh_token': 'refresh',
              'user': {'role': 'patient', 'full_name': 'Example Patient'},
            },
          }),
          200,
        ),
      ),
    );
    addTearDown(auth.close);
    await tester.pumpWidget(MyApp(authService: auth));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'patient@example.test',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.ensureVisible(find.text('Remember me'));
    await tester.tap(find.text('Remember me'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Login'));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorHome), findsNothing);
    expect(
      find.text(
        'Please use patient sign-in. This login is for hospital staff.',
      ),
      findsOneWidget,
    );
    expect(await RememberedSessionStore().read(), isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Login validates fields, toggles password and calls login API', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthService(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/login');
        expect(jsonDecode(request.body), {
          'email': 'doctor@example.com',
          'password': 'secret',
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'access_token': 'test-access',
              'refresh_token': 'test-refresh',
              'user': {
                'full_name': 'Test Doctor',
                'email': 'doctor@example.com',
                'role': 'doctor',
              },
            },
          }),
          200,
        );
      }),
    );
    addTearDown(auth.close);
    await tester.pumpWidget(MyApp(authService: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'doctor@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret');
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isFalse,
    );
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.byType(DoctorHome), findsOneWidget);
    expect(await RememberedSessionStore().read(), isNull);
    expect(find.text('Hospital Login'), findsNothing);
    expect(find.byType(SoftBottomBar), findsOneWidget);
    final home = tester.widget<DoctorHome>(find.byType(DoctorHome));
    expect(home.session.name, 'Test Doctor');
    expect(home.session.role, 'doctor');
    expect(tester.takeException(), isNull);
  });
}
