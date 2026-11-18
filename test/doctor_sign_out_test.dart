import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/doctor_home.dart';
import 'package:mayo_delivery_partner/main.dart';
import 'package:mayo_delivery_partner/profile_page.dart';
import 'package:mayo_delivery_partner/remembered_session_store.dart';
import 'package:mayo_delivery_partner/soft_bottom_bar.dart';

const session = AuthSession(
  'access',
  'refresh',
  'Doctor',
  'doctor@example.test',
  role: 'doctor',
);

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
  tearDown(
    () => TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAccessibilityFeaturesTestValue(),
  );

  for (final serverSuccess in [true, false]) {
    testWidgets(
      'logout clears saved account, avoids duplicate POST and handles server success=$serverSuccess',
      (tester) async {
        tester.view.physicalSize = const Size(390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pending = Completer<http.Response>();
        var logoutCalls = 0;
        final store = RememberedSessionStore();
        await store.save(session);
        final service = DoctorDashboardService(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/auth/logout')) {
              logoutCalls++;
              return pending.future;
            }
            return http.Response(
              jsonEncode({
                'success': true,
                'data': switch (request.url.path) {
                  '/api/v1/auth/me' => {
                    'role': 'doctor',
                    'full_name': 'Doctor',
                  },
                  '/api/v1/dashboard/doctor' => {
                    'today': {'total': 0},
                    'pending': {},
                  },
                  '/api/v1/dashboard/doctor/today' => {'items': []},
                  _ => {'unread_count': 0},
                },
              }),
              200,
            );
          }),
        );
        addTearDown(service.close);
        await tester.pumpWidget(
          MaterialApp(
            home: DoctorHome(
              session: session,
              dashboardService: service,
              sessionStore: store,
            ),
          ),
        );
        await tester.pumpAndSettle();
        tester.widget<SoftBottomBar>(find.byType(SoftBottomBar)).onTap(4);
        await tester.pumpAndSettle();
        final profile = tester.widget<ProfilePage>(find.byType(ProfilePage));
        profile.onSignOut();
        profile.onSignOut();
        await tester.pump();
        expect(await store.read(), isNull);
        expect(logoutCalls, 1);
        pending.complete(
          http.Response(
            serverSuccess ? '{"success":true}' : '',
            serverSuccess ? 200 : 503,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(DoctorHome), findsNothing);
        if (!serverSuccess) {
          expect(
            find.text(
              'Signed out on this device. Server sign-out could not be confirmed.',
            ),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
