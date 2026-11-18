import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/doctor_home.dart';
import 'package:mayo_delivery_partner/soft_bottom_bar.dart';

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
  testWidgets(
    'doctor appointments use web list, selected date and status filters',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final paths = <String>[];
      final listQueries = <Map<String, String>>[];
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          paths.add(request.url.path);
          final Object data;
          if (request.url.path.endsWith('/auth/me')) {
            data = <String, dynamic>{
              'full_name': 'Example Doctor',
              'role': 'doctor',
              'id': 'doctor',
            };
          } else if (request.url.path.endsWith('/dashboard/doctor')) {
            data = <String, dynamic>{
              'today': {'total': 2},
              'pending': {'follow_ups_due_7d': 0},
            };
          } else if (request.url.path.endsWith('/appointments/')) {
            listQueries.add(request.url.queryParameters);
            data = <String, dynamic>{
              'items': [
                for (final entry in [
                  ('waiting', 'scheduled', '11:30'),
                  ('finished', 'completed', '09:00'),
                ])
                  {
                    'id': entry.$1,
                    'appointment_date': '2026-10-19',
                    'doctor_id': 'doctor',
                    'appointment_time': entry.$3,
                    'status': entry.$2,
                    'patient': {'full_name': 'Patient ${entry.$1}'},
                    'doctor': {
                      'name': 'Example Doctor',
                      'department_name': 'Medicine',
                    },
                  },
              ],
            };
          } else {
            data = <String, dynamic>{'unread_count': 0};
          }
          if (request.url.path.endsWith('/appointments/')) {
            final map = data as Map<String, dynamic>;
            final filter = request.url.queryParameters['status'];
            final items = (map['items'] as List)
                .where(
                  (row) =>
                      filter == null ||
                      filter.split(',').contains(row['status']),
                )
                .toList();
            map['items'] = items;
            map['meta'] = {'total_items': items.length, 'has_next': false};
          }
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
          );
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorHome(
            session: const AuthSession(
              'access',
              'refresh',
              'Doctor',
              'doctor@test.com',
            ),
            dashboardService: service,
          ),
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
      expect(find.text('My OPD'), findsOneWidget);
      expect(find.text('Patient waiting'), findsOneWidget);
      expect(find.text('Patient finished'), findsOneWidget);
      expect(find.text('Change date'), findsNothing);
      expect(find.byTooltip('Next day'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.textContaining('2 appointments'), findsOneWidget);
      for (final heading in ['TOKEN', 'TIME', 'PATIENT', 'REASON', 'STATUS']) {
        expect(find.text(heading), findsOneWidget);
      }

      for (final column in [
        ('TOKEN', 'token'),
        ('TIME', 'time'),
        ('PATIENT', 'patient'),
        ('REASON', 'reason'),
        ('STATUS', 'status'),
      ]) {
        await tester.tap(find.text(column.$1));
        await tester.pumpAndSettle();
        expect(listQueries.last['sort'], column.$2);
        expect(listQueries.last['order'], 'asc');
        expect(listQueries.last['page'], '1');
        await tester.tap(find.text(column.$1));
        await tester.pumpAndSettle();
        expect(listQueries.last['order'], 'desc');
      }

      await tester.tap(find.widgetWithText(ChoiceChip, 'Waiting 1'));
      await tester.pumpAndSettle();
      expect(find.text('Patient waiting'), findsOneWidget);
      expect(find.text('Patient finished'), findsNothing);
      await tester.scrollUntilVisible(
        find.widgetWithText(ChoiceChip, 'Done 0'),
        160,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.right,
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Done 0'));
      await tester.pumpAndSettle();
      expect(find.text('Patient finished'), findsOneWidget);
      expect(find.text('Patient waiting'), findsNothing);
      expect(listQueries.last['status'], 'completed');
      final previousDate = listQueries.last['date'];
      await tester.tap(find.byTooltip('Next day'));
      await tester.pumpAndSettle();
      expect(listQueries.last['date'], isNot(previousDate));
      expect(listQueries.last['page'], '1');
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'malformed personal schedule is rejected instead of showing an empty day',
    () async {
      final service = DoctorDashboardService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {'items': 'invalid'},
            }),
            200,
          ),
        ),
      );
      addTearDown(service.close);
      await expectLater(
        service.fetchDoctorTodayAppointments(
          const AuthSession('access', 'refresh', 'Doctor', 'doctor@test.com'),
        ),
        throwsFormatException,
      );
    },
  );

  testWidgets('admin Visits shows hospital list without a personal queue', (
    tester,
  ) async {
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        final Object data;
        if (request.url.path.endsWith('/auth/me')) {
          data = <String, dynamic>{
            'full_name': 'Example Admin',
            'role': 'hospital_admin',
            'id': 'admin',
          };
        } else if (request.url.path.endsWith('/calendar/day')) {
          data = <String, dynamic>{
            'appointments': 1,
            'by_status': {'confirmed': 1},
          };
        } else {
          data = <String, dynamic>{
            'items': [
              {
                'id': 'appointment-example',
                'appointment_date': '2026-10-16',
                'appointment_time': '11:30',
                'doctor_id': 'doctor-example',
                'status': 'confirmed',
                'patient': {'full_name': 'Example Patient'},
                'doctor': {
                  'name': 'Example Doctor',
                  'department_name': 'General Medicine',
                },
                'token_number': 1,
              },
            ],
            'meta': {'total_items': 1, 'has_next': false},
          };
        }
        return http.Response(jsonEncode({'success': true, 'data': data}), 200);
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: DoctorHome(
          session: const AuthSession(
            'test',
            'refresh',
            'Example Admin',
            'example@test.com',
          ),
          dashboardService: service,
        ),
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
    expect(find.text('ADMIN · HOSPITAL-WIDE'), findsOneWidget);
    expect(find.text('Example Patient'), findsOneWidget);
    expect(find.textContaining('1 booked'), findsOneWidget);
    expect(find.text('Token 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Example Patient'), findsNothing);
  });
}
