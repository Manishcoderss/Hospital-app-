import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/clinical_directory.dart';
import 'package:mayo_delivery_partner/clinical_home_page.dart';
import 'package:mayo_delivery_partner/clinical_directory_page.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/doctor_home.dart';
import 'package:mayo_delivery_partner/patient_detail_page.dart';

const session = AuthSession('access', 'refresh', 'Admin', 'example@test.com');
http.Response response(Object data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Map<String, dynamic> page(List<Map<String, dynamic>> rows) => {
  'items': rows,
  'meta': {'total_items': rows.length, 'has_next': false},
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
    'directories use existing authenticated endpoints and appropriate filters',
    () async {
      final requests = <http.Request>[];
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          requests.add(request);
          return response(page([]));
        }),
      );
      addTearDown(service.close);
      for (final kind in ClinicalDirectory.values) {
        await service.fetchDirectory(
          session,
          kind,
          page: 2,
          search: ' Example ',
        );
      }
      expect(requests.map((r) => r.url.path), [
        '/api/v1/patients/',
        '/api/v1/prescriptions/',
        '/api/v1/lab-tests/',
        '/api/v1/admissions/',
        '/api/v1/prescriptions/',
      ]);
      expect(requests.first.url.queryParameters['search'], 'Example');
      expect(requests.first.url.queryParameters['sort'], 'registered');
      expect(requests[1].url.queryParameters.containsKey('search'), isFalse);
      expect(requests[3].url.queryParameters['status'], 'active');
      expect(requests[3].url.queryParameters['sort'], 'admitted');
      expect(requests.last.url.queryParameters['status'], 'issued');
      for (final request in requests) {
        expect(request.headers['Authorization'], 'Bearer access');
        expect(request.url.queryParameters['page'], '2');
      }
    },
  );

  testWidgets('patient search opens the reused Patient Detail screen', (
    tester,
  ) async {
    final searches = <String?>[];
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/patients/')) {
          searches.add(request.url.queryParameters['search']);
          return response(
            page([
              {
                'id': 'patient',
                'full_name': 'Example Patient',
                'patient_number': 'PAT-EXAMPLE',
              },
            ]),
          );
        }
        return response({'id': 'patient', 'full_name': 'Example Patient'});
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ClinicalDirectoryPage(
          session: session,
          service: service,
          directory: ClinicalDirectory.patients,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Example');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(searches, ['', 'Example']);
    await tester.tap(find.text('Example Patient'));
    await tester.pumpAndSettle();
    expect(find.byType(PatientDetailPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Clinical tab provides working report shortcut', (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/me')) {
          return response({'full_name': 'Admin', 'role': 'hospital_admin'});
        }
        if (request.url.path.endsWith('/calendar/day')) {
          return response({'appointments': 0});
        }
        return response(page([]));
      }),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: DoctorHome(session: session, dashboardService: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clinical'));
    await tester.pumpAndSettle();
    final clinicalScroll = find.descendant(
      of: find.byType(ClinicalHomePage),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('View issued prescriptions and dispensing'),
      150,
      scrollable: clinicalScroll,
    );
    expect(
      find.text('View issued prescriptions and dispensing'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Lab Reports').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lab Reports').last);
    await tester.pumpAndSettle();
    expect(find.byType(ClinicalDirectoryPage), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Nothing in this stage'),
      250,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    expect(find.text('Nothing in this stage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
