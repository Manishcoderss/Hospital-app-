import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/prescription_detail_page.dart';
import 'package:mayo_delivery_partner/prescription_draft.dart';

const session = AuthSession(
  'access',
  'refresh',
  'Admin',
  'example@test.com',
  role: 'hospital_admin',
);
http.Response response(Object data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
Map<String, dynamic> prescription({
  String status = 'draft',
  bool medicine = false,
  bool empty = false,
}) => {
  'id': 'rx',
  'patient_id': 'patient',
  'prescription_number': 'RX-EXAMPLE',
  'status': status,
  'patient': {'id': 'patient', 'full_name': 'Example Patient'},
  'medications': medicine
      ? [
          {'medicine_name': 'Example medicine'},
        ]
      : [],
  'lab_tests': medicine || empty
      ? []
      : [
          {
            'catalog_id': 'catalog',
            'test_name': 'Example test',
            'priority': 'routine',
          },
        ],
};

void main() {
  test(
    'catalog search parses existing list envelope and sends exact parameters',
    () async {
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/lab-tests/catalog/dropdown');
          expect(request.url.queryParameters, {'search': 'CBC', 'limit': '30'});
          return response([
            {'id': 'catalog', 'name': 'Example panel', 'sample_type': 'blood'},
          ]);
        }),
      );
      addTearDown(service.close);
      final tests = await service.fetchLabCatalog(session, ' CBC ');
      expect(tests.single.id, 'catalog');
      expect(tests.single.name, 'Example panel');
    },
  );

  test('selected catalog tests are included when saving a draft', () async {
    final service = DoctorDashboardService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/prescriptions/');
        expect(jsonDecode(request.body)['lab_tests'], [
          {
            'catalog_id': 'catalog',
            'test_name': 'Example panel',
            'priority': 'routine',
            'instructions': 'Recorded instruction',
          },
        ]);
        return response({'id': 'draft', 'status': 'draft'});
      }),
    );
    addTearDown(service.close);
    await service.savePrescriptionDraft(
      session,
      const PrescriptionDraft(
        patientId: 'patient',
        doctorId: 'doctor',
        appointmentId: 'appointment',
        fields: {},
        medications: [],
        labTests: [
          {
            'catalog_id': 'catalog',
            'test_name': 'Example panel',
            'priority': 'routine',
            'instructions': 'Recorded instruction',
          },
        ],
      ),
      role: 'hospital_admin',
    );
  });

  test(
    'issue request uses authenticated PATCH and never creates another draft',
    () async {
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/v1/prescriptions/rx/issue');
          expect(request.headers['Authorization'], 'Bearer access');
          return response({});
        }),
      );
      addTearDown(service.close);
      await service.issuePrescription(session, 'rx');
    },
  );

  test(
    'issue permission failure and unknown outcome stay distinguishable',
    () async {
      for (final status in [403, 500]) {
        final service = DoctorDashboardService(
          client: MockClient((_) async => http.Response('PRIVATE', status)),
        );
        await expectLater(
          service.issuePrescription(session, 'rx'),
          throwsA(
            isA<DraftSaveException>()
                .having((e) => e.uncertain, 'uncertain', status == 500)
                .having(
                  (e) => e.message,
                  'safe message',
                  isNot(contains('PRIVATE')),
                ),
          ),
        );
        service.close();
      }
    },
  );

  testWidgets(
    'issue needs fresh review and explicit confirmation; cancel sends no PATCH',
    (tester) async {
      var patches = 0, reads = 0;
      var status = 'draft';
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/me')) {
            return response({
              'id': 'admin',
              'full_name': 'Admin',
              'role': 'hospital_admin',
            });
          }
          if (request.method == 'PATCH') {
            patches++;
            status = 'issued';
            return response({});
          }
          reads++;
          return response(prescription(status: status));
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PrescriptionDetailPage(
            session: session,
            id: 'rx',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Issue prescription'), 250);
      await tester.tap(find.text('Issue prescription'));
      await tester.pumpAndSettle();
      expect(find.text('Issue this prescription?'), findsOneWidget);
      expect(reads, 2);
      expect(patches, 0);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(patches, 0);
      await tester.tap(find.text('Issue prescription'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm issue'));
      await tester.pumpAndSettle();
      expect(patches, 1);
      expect(status, 'issued');
      expect(find.text('Issue prescription'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unresolved allergy conflict blocks issue confirmation and PATCH',
    (tester) async {
      var patches = 0;
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/me')) {
            return response({
              'id': 'admin',
              'full_name': 'Admin',
              'role': 'hospital_admin',
            });
          }
          if (request.url.path.endsWith('/allergy-check')) {
            return response({
              'items': [
                {
                  'index': 0,
                  'conflicts': ['Recorded conflict'],
                },
              ],
            });
          }
          if (request.method == 'PATCH') {
            patches++;
            fail('Conflict must block issue');
          }
          return response(prescription(medicine: true));
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        MaterialApp(
          home: PrescriptionDetailPage(
            session: session,
            id: 'rx',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Issue prescription'), 250);
      await tester.tap(find.text('Issue prescription'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('conflicts with a recorded allergy'),
        findsOneWidget,
      );
      expect(find.text('Confirm issue'), findsNothing);
      expect(patches, 0);
    },
  );
}
