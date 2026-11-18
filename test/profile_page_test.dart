import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/profile_page.dart';

void main() {
  testWidgets(
    'Profile retries failed load and sign out requires confirmation',
    (tester) async {
      var requests = 0;
      var signedOut = 0;
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/me');
          expect(request.headers['Authorization'], 'Bearer token');
          requests++;
          if (requests == 1) return http.Response('{}', 503);
          return http.Response(
            '{"success":true,"data":{"id":"user","full_name":"Test Admin","role":"hospital_admin","hospital":{"name":"Test Hospital"}}}',
            200,
          );
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfilePage(
              session: const AuthSession(
                'token',
                'refresh',
                'Fallback',
                'test@example.com',
              ),
              service: service,
              onSignOut: () => signedOut++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Unable to load'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Test Admin'), findsOneWidget);
      expect(find.text('Hospital administrator'), findsOneWidget);
      expect(find.text('Test Hospital'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sign out'),
        200,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(signedOut, 0);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(signedOut, 1);
    },
  );
}
