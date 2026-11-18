import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/clinical_directory.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/home_dashboard_page.dart';
import 'package:mayo_delivery_partner/home_snapshot.dart';

const session = AuthSession(
  'access',
  'refresh',
  'Example Admin',
  'example@test.com',
);
http.Response response(Object data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, dynamic> event(String id, String status, String time) => {
  'id': id,
  'type': 'appointment',
  'date': '2026-10-16',
  'start_time': time,
  'status': status,
  'patient': {'id': 'patient-$id', 'full_name': 'Patient $id'},
  'doctor': {
    'id': 'doctor',
    'name': 'Example Doctor',
    'department_name': 'Medicine',
  },
};
Map<String, dynamic> calendar() => {
  'appointments': 3,
  'by_status': {'scheduled': 1, 'confirmed': 1, 'completed': 1},
  'follow_ups_due': 1,
  'events': [
    event('late', 'scheduled', '14:00'),
    event('early', 'confirmed', '10:00'),
    event('done', 'completed', '09:00'),
    {
      'id': 'follow-up',
      'type': 'follow_up_due',
      'patient': {'id': 'patient', 'full_name': 'Follow-up Patient'},
    },
  ],
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
  test('calendar maps counts, excludes completed next patient and preserves follow-ups', () {
    final data = HomeSnapshot.calendar(calendar());
    expect(data.total, 3);
    expect(data.waiting, 2);
    expect(data.completed, 1);
    expect(data.active.first.id, 'early');
    expect(data.active.map((e) => e.id), isNot(contains('done')));
    expect(data.followUps.single.patientId, 'patient');
    expect(data.followUpCount, 1);
  });

  test('malformed home data cannot appear as a zero-appointment day', () {
    expect(
      () => HomeSnapshot.calendar({'appointments': 0}),
      throwsFormatException,
    );
    expect(
      () => HomeSnapshot.calendar({...calendar(), 'appointments': -1}),
      throwsFormatException,
    );
  });

  test(
    'doctor uses dedicated scoped endpoints instead of hospital calendar',
    () async {
      final paths = <String>[];
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          paths.add(request.url.path);
          return response(
            request.url.path.endsWith('/today')
                ? {'items': []}
                : {
                    'today': {'total': 0},
                    'pending': {'follow_ups_due_7d': 2},
                  },
          );
        }),
      );
      addTearDown(service.close);
      final data = await service.fetchHome(
        session,
        const DoctorProfile(
          name: 'Doctor',
          role: 'doctor',
          hospitalName: 'Hospital',
          userId: 'user',
        ),
        DateTime(2026, 10, 16),
      );
      expect(paths, [
        '/api/v1/dashboard/doctor',
        '/api/v1/dashboard/doctor/today',
      ]);
      expect(data.weeklyFollowUps, isTrue);
      expect(data.followUpCount, 2);
    },
  );

  testWidgets(
    'original Home fits a small phone, shows hospital scope and filters queue',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/me')) {
            return response({
              'full_name': 'Example Admin',
              'role': 'hospital_admin',
            });
          }
          if (request.url.path.endsWith('/unread-count')) {
            return response({'unread_count': 2});
          }
          return response(calendar());
        }),
      );
      addTearDown(service.close);
      ClinicalDirectory? destination;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeDashboardPage(
              session: session,
              service: service,
              onVisits: (_) {},
              onDirectory: (kind) => destination = kind,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hospital overview · Admin'), findsOneWidget);
      expect(find.byTooltip('2 unread notifications'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Hospital queue'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('queue-filter-Completed')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byType(SingleChildScrollView));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-280, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('queue-filter-Completed')));
      await tester.pumpAndSettle();
      expect(find.text('Patient done'), findsOneWidget);
      expect(find.text('Patient late'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Lab Reports'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lab Reports'));
      expect(destination, ClinicalDirectory.labs);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home error has retry and never displays fake zero counts', (
    tester,
  ) async {
    var calls = 0;
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return response({'full_name': 'Admin', 'role': 'hospital_admin'});
        }
        if (request.url.path.endsWith('/unread-count')) {
          return response({'unread_count': 0});
        }
        calls++;
        return calls == 1 ? http.Response('', 500) : response(calendar());
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeDashboardPage(
            session: session,
            service: service,
            onVisits: (_) {},
            onDirectory: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Retry'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Dashboard unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
    'notification reads use the existing authenticated PATCH endpoints',
    () async {
      final paths = <String>[];
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.method, 'PATCH');
          expect(request.headers['Authorization'], 'Bearer access');
          return response({});
        }),
      );
      addTearDown(service.close);
      await service.markNotificationsRead(session, id: 'notification');
      await service.markNotificationsRead(session);
      expect(paths, [
        '/api/v1/notifications/notification/read',
        '/api/v1/notifications/read-all',
      ]);
    },
  );
}
