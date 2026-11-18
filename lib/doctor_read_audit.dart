import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'appointment_page.dart';
import 'appointment_booking_service.dart';
import 'auth_service.dart';
import 'clinical_directory.dart';
import 'doctor_dashboard_service.dart';

/// Opt-in debug audit: existing production parsers, GET requests only, no payload
/// logging. Tokens and medical records remain in the app process.
class DoctorReadAudit {
  DoctorReadAudit({http.Client? client})
    : _client = _ReadOnlyClient(client ?? http.Client());
  final _ReadOnlyClient _client;

  Future<void> run(
    AuthSession session, {
    String patientId = '',
    String appointmentId = '',
    bool recordsOnly = false,
    required void Function(String) report,
  }) async {
    final service = DoctorDashboardService(client: _client);
    final booking = AppointmentBookingService(client: _client);
    var passed = 0, failed = 0, restricted = 0;
    Future<bool> check(String label, Future<void> Function() action) async {
      if (_client.stopped) {
        report('$label|skipped|0');
        return false;
      }
      _client.statuses.clear();
      var parsed = true;
      try {
        await action();
      } catch (_) {
        parsed = false;
      }
      final codes = _client.statuses;
      final int code =
          codes.where((code) => code != 200).firstOrNull ??
          codes.lastOrNull ??
          0;
      final result = switch (code) {
        401 => 'expired',
        403 => 'restricted',
        404 => 'not_found',
        429 => 'rate_limited',
        200 when parsed => 'pass',
        200 => 'contract_error',
        0 => 'client_error',
        _ => 'http_error',
      };
      if (result == 'pass') {
        passed++;
      } else if (result == 'restricted') {
        restricted++;
      } else {
        failed++;
      }
      report('$label|$result|$code');
      return result == 'pass';
    }

    Future<void> raw(String path) async {
      final response = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}$path'),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) throw const FormatException();
      final body = jsonDecode(response.body);
      if (body is! Map || body['success'] != true || body['data'] == null) {
        throw const FormatException();
      }
    }

    try {
      DoctorProfile? profile;
      final authenticated = await check('identity', () async {
        profile = await service.fetchProfile(session);
      });
      if (!authenticated || profile?.role.trim().toLowerCase() != 'doctor') {
        report('doctor_scope|not_verified|0');
        return;
      }
      report('doctor_scope|pass|200');
      if (!recordsOnly) {
        await check('dashboard', () async {
          await service.fetchHome(session, profile!, DateTime.now());
        });
        await check('today_queue', () async {
          await service.fetchDoctorTodayAppointments(session);
        });
        await check('appointments', () async {
          AppointmentPage.fromJson(await service.fetchAppointments(session));
        });
        String? doctorId;
        await check('doctor_profile', () async {
          doctorId = await booking.ownDoctorId(session);
        });
        await check('booking_doctors', () async {
          await booking.doctors(session);
        });
        if (doctorId != null) {
          final date = DateTime.now().toIso8601String().split('T').first;
          await check('booking_slots', () async {
            await booking.slots(session, doctorId!, date);
          });
        }
        await check(
          'schedule_strip',
          () => raw('/dashboard/doctor/schedule?days=7'),
        );
        await check(
          'recent_patients',
          () => raw('/dashboard/doctor/recent-patients?limit=5'),
        );
        await check('patients', () async {
          await service.fetchPatients(session, perPage: 5);
        });
        await check('patient_lookups', () async {
          await service.fetchPatientLookups(session);
        });
        await check('prescriptions', () async {
          await service.fetchDirectory(
            session,
            ClinicalDirectory.prescriptions,
          );
        });
        await check('lab_orders', () async {
          await service.fetchLaboratoryOrders(session, perPage: 5);
        });
        await check('lab_stages', () async {
          await service.fetchLaboratoryCounts(session);
        });
        await check('lab_catalog', () async {
          await service.fetchLaboratoryCatalog(session);
        });
        await check('lab_categories', () async {
          await service.fetchLaboratoryCategories(session);
        });
        await check('stock', () async {
          await service.fetchPharmacyStock(session);
        });
        await check('account_sessions', () async {
          await service.fetchAccountSessions(session);
        });
        await check('security_activity', () async {
          await service.fetchSecurityActivity(session);
        });
        await check('notification_preferences', () async {
          await service.fetchNotificationPreferences(session);
        });
        await check('notifications', () async {
          await service.fetchNotifications(session);
        });
        await check('unread_count', () async {
          await service.fetchUnreadNotifications(session);
        });
      }
      var patientVerified = false;
      if (patientId.trim().isNotEmpty) {
        patientVerified = await check('dummy_patient', () async {
          await service.fetchPatient(session, patientId);
        });
        if (patientVerified) {
          await check('dummy_patient_visits', () async {
            await service.fetchPatientRecords(session, patientId, labs: false);
          });
          await check('dummy_patient_labs', () async {
            await service.fetchPatientRecords(session, patientId, labs: true);
          });
        }
      }
      if (appointmentId.trim().isNotEmpty) {
        await check('dummy_appointment', () async {
          final appointment = await service.fetchAppointmentDetail(
            session,
            appointmentId,
          );
          if (patientVerified && appointment.patientId != patientId) {
            throw const FormatException();
          }
        });
      }
    } finally {
      report('summary|pass=$passed,restricted=$restricted,failed=$failed|0');
      service.close();
    }
  }
}

class _ReadOnlyClient extends http.BaseClient {
  _ReadOnlyClient(this.inner);
  final http.Client inner;
  final statuses = <int>[];
  bool stopped = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET' || stopped) {
      throw http.ClientException('Read audit stopped');
    }
    final response = await inner.send(request);
    statuses.add(response.statusCode);
    if (response.statusCode == 401 || response.statusCode == 429) {
      stopped = true;
    }
    return response;
  }

  @override
  void close() => inner.close();
}
