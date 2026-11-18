import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/doctor_home.dart';
import 'package:mayo_delivery_partner/soft_bottom_bar.dart';

const session = AuthSession('access', 'refresh', 'Admin', 'example@test.com');
http.Response response(Object data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
Map<String, dynamic> appointmentPage(String page, {bool empty = false}) => {
  'items': empty
      ? []
      : [
          {
            'id': 'appointment-$page',
            'appointment_date': '2026-10-16',
            'appointment_time': '11:30',
            'doctor_id': 'doctor',
            'status': 'confirmed',
            'patient': {'full_name': 'Patient page $page'},
          },
        ],
  'meta': {'total_items': empty ? 0 : 2, 'has_next': !empty && page == '1'},
};

void main() {
  setUp(() {
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
    'appointments sends date, status, page and chronological order',
    () async {
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.url.queryParameters, {
            'date': '2026-10-16',
            'status': 'confirmed',
            'page': '2',
            'per_page': '10',
            'sort': 'time',
            'order': 'asc',
          });
          expect(request.headers['Authorization'], 'Bearer access');
          return response(appointmentPage('2'));
        }),
      );
      addTearDown(service.close);
      await service.fetchAppointments(
        session,
        selectedDate: DateTime(2026, 10, 16),
        status: 'confirmed',
        page: 2,
      );
    },
  );

  testWidgets('Appointments pagination and status filter reset to page one', (
    tester,
  ) async {
    final requests = <Map<String, String>>[];
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return response({'full_name': 'Admin', 'role': 'hospital_admin'});
        }
        if (request.url.path.endsWith('/calendar/day')) {
          return response({
            'appointments': 0,
            'by_status': {},
            'events': [],
            'follow_ups_due': 0,
          });
        }
        if (request.url.path.endsWith('/unread-count')) {
          return response({'unread_count': 0});
        }
        requests.add(request.url.queryParameters);
        return response(
          appointmentPage(
            request.url.queryParameters['page']!,
            empty: request.url.queryParameters['status'] == 'completed',
          ),
        );
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: DoctorHome(session: session, dashboardService: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SoftBottomBar),
        matching: find.text('Appointments'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, 'Next'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Next'));
    await tester.drag(find.byType(ListView).last, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Patient page 2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(ChoiceChip).first,
      -200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, 'Completed'),
      160,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.right,
          )
          .last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await tester.pumpAndSettle();
    expect(requests.last['status'], 'completed');
    expect(requests.last['page'], '1');
    expect(find.textContaining('No completed appointments'), findsOneWidget);
    expect(find.text('Patient page 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
