import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mayo_delivery_partner/appointment.dart';
import 'package:mayo_delivery_partner/auth_service.dart';
import 'package:mayo_delivery_partner/doctor_dashboard_service.dart';
import 'package:mayo_delivery_partner/prescription_draft_page.dart';

void main() {
  testWidgets(
    'lab catalog selection prevents duplicate tests and review does not save',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      final service = DoctorDashboardService(
        client: MockClient((request) async {
          if (request.method != 'GET') {
            writes++;
            fail('Selecting and reviewing lab tests must not save');
          }
          final Object data;
          if (request.url.path.endsWith('/auth/me')) {
            data = {
              'id': 'admin',
              'full_name': 'Admin',
              'role': 'hospital_admin',
            };
          } else if (request.url.path.endsWith('/dropdown')) {
            data = [
              {'id': 'cbc', 'name': 'Example CBC', 'sample_type': 'blood'},
            ];
          } else {
            data = {'id': 'patient', 'full_name': 'Example Patient'};
          }
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
          );
        }),
      );
      addTearDown(service.close);
      const appointment = Appointment(
        id: 'appointment',
        date: '2026-10-16',
        time: '11:30',
        status: 'confirmed',
        patientName: 'Example Patient',
        doctorId: 'doctor',
        doctorName: 'Example Doctor',
        department: 'Medicine',
        patientId: 'patient',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PrescriptionDraftPage(
            session: const AuthSession(
              'access',
              'refresh',
              'Admin',
              'example@test.com',
              role: 'hospital_admin',
            ),
            appointment: appointment,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var index = 0; index < 2; index++) {
        await tester.scrollUntilVisible(
          find.text('Add lab test'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Add lab test'));
        await tester.pumpAndSettle();
        expect(find.text('Choose lab test'), findsOneWidget);
        await tester.tap(find.text('Example CBC'));
        await tester.pumpAndSettle();
      }
      expect(find.text('This test is already on the draft.'), findsOneWidget);
      expect(find.text('Remove test'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Review draft'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Review draft'));
      await tester.pumpAndSettle();
      expect(find.text('1 lab tests'), findsOneWidget);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
