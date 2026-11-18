import 'api_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'appointment.dart';
import 'patient.dart';
import 'patient_records.dart';
import 'clinical_directory.dart';
import 'home_snapshot.dart';
import 'prescription_draft.dart';
import 'lab_catalog_test.dart';
import 'appointment_response_diagnostics.dart';

class AppointmentDetailException implements Exception {
  const AppointmentDetailException(this.message);
  final String message;
}

class AppointmentStatusException implements Exception {
  const AppointmentStatusException(this.message, {this.uncertain = false});
  final String message;
  final bool uncertain;
}

class DoctorProfile {
  final String name;
  final String role;
  final String hospitalName;
  final String userId;

  const DoctorProfile({
    required this.name,
    required this.role,
    required this.hospitalName,
    required this.userId,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    final hospital = json['hospital'];
    String hospitalName = 'SAMAGATI HMS';

    if (hospital is Map<String, dynamic>) {
      hospitalName =
          (hospital['name'] ?? hospital['hospital_name'] ?? 'SAMAGATI HMS')
              .toString();
    }

    return DoctorProfile(
      name: (json['full_name'] ?? 'Doctor').toString(),
      role: (json['role'] ?? 'unknown').toString().trim().toLowerCase(),
      hospitalName: hospitalName,
      userId: (json['id'] ?? '').toString(),
    );
  }
}

class DoctorDashboardService {
  DoctorDashboardService({http.Client? client, this.sessionAudit})
    : _client = client ?? http.Client();

  final http.Client _client;
  final void Function(String check, int status)? sessionAudit;

  void close() => _client.close();

  /// Revoke the current token pair. No clinical request is retried here.
  Future<bool> revokeSession(AuthSession session) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/auth/logout'),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));
      sessionAudit?.call('logout', response.statusCode);
      if (response.statusCode == 401) return true;
      if (response.statusCode != 200 && response.statusCode != 204) {
        return false;
      }
      final body = response.statusCode == 204
          ? null
          : jsonDecode(response.body);
      final revoked =
          response.statusCode == 204 ||
          (body is Map && body['success'] == true);
      if (revoked && sessionAudit != null) {
        // Opt-in debug verification. Never exports either token or response.
        final check = await _client
            .get(
              Uri.parse('$baseUrl/auth/me'),
              headers: {
                'Authorization': 'Bearer ${session.accessToken}',
                'Accept': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));
        sessionAudit?.call('revoked_access', check.statusCode);
        return check.statusCode == 401;
      }
      return revoked;
    } catch (_) {
      // Offline sign-out still removes the local remembered session.
      return false;
    }
  }

  Future<void> updateAppointmentStatus(
    AuthSession session,
    Appointment appointment, {
    required String status,
    String? diagnosis,
    String? notes,
    String? followUpDate,
  }) async {
    final expected = switch (appointment.status) {
      'scheduled' => 'confirmed',
      'confirmed' => 'in_progress',
      'in_progress' => 'completed',
      _ => null,
    };
    if (status != expected || expected == null) {
      throw const AppointmentStatusException(
        'Refresh the appointment before changing its status.',
      );
    }
    final http.Response response;
    try {
      response = await _client
          .patch(
            Uri.parse(
              '$baseUrl/appointments/${Uri.encodeComponent(appointment.id)}/status',
            ),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'status': status,
              if (status == 'completed' && diagnosis?.trim().isNotEmpty == true)
                'diagnosis': diagnosis!.trim(),
              if (status == 'completed' && notes?.trim().isNotEmpty == true)
                'doctor_notes': notes!.trim(),
              if (status == 'completed' && followUpDate != null)
                'follow_up_date': followUpDate,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const AppointmentStatusException(
        'The update could not be confirmed. Refresh the appointment before trying again.',
        uncertain: true,
      );
    }
    if ([400, 401, 403, 404, 409, 422].contains(response.statusCode)) {
      throw AppointmentStatusException(switch (response.statusCode) {
        401 => 'Session expired. Please sign in again.',
        403 => 'Your account cannot update this appointment. Contact your administrator.',
        409 => 'Appointment status changed. Refresh before continuing.',
        _ => 'The update was rejected. Refresh and check the appointment.',
      });
    }
    if (response.statusCode == 204) return;
    try {
      final body = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          body is! Map ||
          body['success'] != true) {
        throw const FormatException();
      }
    } catch (_) {
      throw const AppointmentStatusException(
        'The update could not be confirmed. Refresh the appointment before trying again.',
        uncertain: true,
      );
    }
  }

  Future<List<List<String>>> checkDraftAllergies(
    AuthSession session,
    PrescriptionDraft draft,
  ) => checkMedicationAllergies(
    session,
    patientId: draft.patientId,
    allergies: draft.fields['allergies'],
    medications: draft.medications,
  );

  Future<List<List<String>>> checkMedicationAllergies(
    AuthSession session, {
    required String patientId,
    String? allergies,
    required List<Map<String, dynamic>> medications,
  }) async {
    if (medications.isEmpty) return [];
    final response = await _client
        .post(
          Uri.parse('$baseUrl/prescriptions/allergy-check'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
          body: jsonEncode({
            'patient_id': patientId,
            if (allergies?.trim().isNotEmpty == true)
              'allergies': allergies!.trim(),
            'medications': [
              for (final medicine in medications)
                {
                  if (medicine['medicine_id'] != null)
                    'medicine_id': medicine['medicine_id'],
                  'medicine_name': medicine['medicine_name'],
                },
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const AppointmentDetailException(
        'Allergy check could not be completed. Please try again.',
      );
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map && decoded['success'] == true
        ? decoded['data']
        : null;
    final items = data is Map ? data['items'] : null;
    if (items is! List || items.length != medications.length) {
      throw const FormatException('Invalid allergy check');
    }
    final results = List<List<String>>.generate(items.length, (_) => []);
    final seen = <int>{};
    for (final item in items) {
      if (item is! Map || item['index'] is! int || item['conflicts'] is! List) {
        throw const FormatException();
      }
      final index = item['index'] as int;
      final conflicts = item['conflicts'] as List;
      if (index < 0 ||
          index >= results.length ||
          !seen.add(index) ||
          conflicts.any((value) => value is! String)) {
        throw const FormatException();
      }
      results[index] = conflicts.cast<String>();
    }
    return results;
  }

  Future<List<LabCatalogTest>> fetchLabCatalog(
    AuthSession session,
    String search,
  ) async {
    final response = await _client
        .get(
          Uri.parse(
            '$baseUrl/lab-tests/catalog/dropdown',
          ).replace(queryParameters: {'search': search.trim(), 'limit': '30'}),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw const AppointmentDetailException(
        'Lab catalog could not be loaded. Please try again.',
      );
    }
    final decoded = jsonDecode(response.body);
    final data = decoded is Map && decoded['success'] == true
        ? decoded['data']
        : null;
    final items = data is Map ? data['items'] : data;
    if (items is! List) {
      throw const FormatException('Invalid lab catalog response');
    }
    return items.map((item) {
      if (item is! Map<String, dynamic>) throw const FormatException();
      return LabCatalogTest.fromJson(item);
    }).toList();
  }

  Future<void> issuePrescription(AuthSession session, String id) async {
    final http.Response response;
    try {
      response = await _client
          .patch(
            Uri.parse(
              '$baseUrl/prescriptions/${Uri.encodeComponent(id)}/issue',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const DraftSaveException(
        'The issue result could not be confirmed. Check this prescription in the hospital portal before trying again.',
        uncertain: true,
      );
    }
    if ([400, 401, 403, 404, 409, 422].contains(response.statusCode)) {
      throw DraftSaveException(switch (response.statusCode) {
        401 => 'Session expired. Please sign in again.',
        403 =>
          'Your account does not have permission to issue this prescription.',
        409 =>
          'The prescription status has changed. Refresh before continuing.',
        _ => 'The prescription could not be issued. Review the draft in the hospital portal.',
      });
    }
    if (response.statusCode == 204) return;
    try {
      final decoded = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw const FormatException();
      }
    } catch (_) {
      throw const DraftSaveException(
        'The issue result could not be confirmed. Check this prescription in the hospital portal before trying again.',
        uncertain: true,
      );
    }
  }

  Future<String> savePrescriptionDraft(
    AuthSession session,
    PrescriptionDraft draft, {
    required String role,
  }) async {
    if (!['doctor', 'hospital_admin'].contains(role)) {
      throw const DraftSaveException(
        'This account cannot create prescriptions.',
      );
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/prescriptions/'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
            body: jsonEncode(draft.toJson(doctorRole: role == 'doctor')),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const DraftSaveException(
        'The save result could not be confirmed. Check Prescriptions before creating another draft.',
        uncertain: true,
      );
    }
    if ([400, 401, 403, 404, 409, 422].contains(response.statusCode)) {
      throw DraftSaveException(switch (response.statusCode) {
        401 => 'Session expired. Please sign in again.',
        403 =>
          'Your account does not have permission to save this prescription.',
        409 => 'This prescription conflicts with an existing record. Check Prescriptions.',
        _ => 'The draft was rejected. Review the fields and try again.',
      });
    }
    try {
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormatException();
      }
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded['success'] == true
          ? decoded['data']
          : null;
      if (data is! Map ||
          data['id'] is! String ||
          (data['id'] as String).isEmpty ||
          data['status'] != 'draft') {
        throw const FormatException();
      }
      return data['id'] as String;
    } catch (_) {
      throw const DraftSaveException(
        'The save result could not be confirmed. Check Prescriptions before creating another draft.',
        uncertain: true,
      );
    }
  }

  Future<List<Appointment>> fetchDoctorTodayAppointments(
    AuthSession session,
  ) async {
    final data = await _readPatientResource(
      session,
      Uri.parse('$baseUrl/dashboard/doctor/today'),
    );
    final rows = data['items'];
    if (rows is! List) throw const FormatException('Invalid doctor schedule');
    return List.unmodifiable(
      rows.map((row) {
        if (row is! Map<String, dynamic>) {
          throw const FormatException('Invalid doctor appointment');
        }
        return Appointment.fromJson(row);
      }),
    );
  }

  Future<HomeSnapshot> fetchHome(
    AuthSession session,
    DoctorProfile profile,
    DateTime date,
  ) async {
    if (profile.role.toLowerCase() == 'doctor') {
      final results = await Future.wait([
        _readPatientResource(session, Uri.parse('$baseUrl/dashboard/doctor')),
        _readPatientResource(
          session,
          Uri.parse('$baseUrl/dashboard/doctor/today'),
        ),
      ]);
      return HomeSnapshot.doctor(results[0], results[1]);
    }
    if (profile.role.toLowerCase() != 'hospital_admin') {
      throw const AppointmentDetailException(
        'Your account does not have access to this dashboard.',
      );
    }
    final selected =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return HomeSnapshot.calendar(
      await _readPatientResource(
        session,
        Uri.parse('$baseUrl/calendar/day')
            .replace(queryParameters: {'date': selected}),
      ),
    );
  }

  Future<int> fetchUnreadNotifications(AuthSession session) async {
    final data = await _readPatientResource(
      session,
      Uri.parse('$baseUrl/notifications/unread-count'),
    );
    return HomeSnapshot.count(data['unread_count']);
  }

  Future<void> markNotificationsRead(AuthSession session, {String? id}) async {
    final path = id == null ? 'read-all' : '${Uri.encodeComponent(id)}/read';
    final response = await _client
        .patch(
          Uri.parse('$baseUrl/notifications/$path'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 204) return;
    if (response.statusCode != 200) {
      throw const AppointmentDetailException(
        'Unable to mark notifications as read. Please try again.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['success'] != true) {
      throw const FormatException('Invalid notification response');
    }
  }

  Future<PatientRecordPage> fetchNotifications(
    AuthSession session, {
    int page = 1,
  }) async => PatientRecordPage.fromJson(
    await _readPatientResource(
      session,
      Uri.parse('$baseUrl/notifications/')
          .replace(queryParameters: {'page': '$page', 'per_page': '15'}),
    ),
  );

  Future<PatientRecordPage> fetchDirectory(
    AuthSession session,
    ClinicalDirectory directory, {
    int page = 1,
    String search = '',
    String? patientId,
    String? prescriptionStatus,
    String prescriptionSort = 'date',
    String prescriptionOrder = 'desc',
  }) async {
    final path = switch (directory) {
      ClinicalDirectory.patients => 'patients',
      ClinicalDirectory.prescriptions => 'prescriptions',
      ClinicalDirectory.labs => 'lab-tests',
      ClinicalDirectory.ipd => 'admissions',
      ClinicalDirectory.pharmacy => 'prescriptions',
    };
    final params = <String, String>{
      'page': '$page',
      'per_page': '10',
      'order': directory == ClinicalDirectory.prescriptions
          ? prescriptionOrder
          : 'desc',
      'sort': switch (directory) {
        ClinicalDirectory.patients => 'registered',
        ClinicalDirectory.ipd => 'admitted',
        ClinicalDirectory.prescriptions => prescriptionSort,
        _ => 'date',
      },
      if (directory == ClinicalDirectory.patients ||
          directory == ClinicalDirectory.ipd)
        'search': search.trim(),
      if (directory == ClinicalDirectory.ipd) 'status': 'active',
      if (directory == ClinicalDirectory.pharmacy) 'status': 'issued',
      if (directory == ClinicalDirectory.prescriptions && patientId != null)
        'patient_id': patientId,
      if (directory == ClinicalDirectory.prescriptions &&
          prescriptionStatus != null)
        'status': prescriptionStatus,
    };
    return PatientRecordPage.fromJson(
      await _readPatientResource(
        session,
        Uri.parse('$baseUrl/$path/').replace(queryParameters: params),
      ),
    );
  }

  Future<PatientRecordPage> fetchPatients(
    AuthSession session, {
    String search = '',
    String? gender,
    String? bloodGroup,
    String? insuranceCategory,
    int page = 1,
    int perPage = 100,
    String sort = 'registered',
    String order = 'desc',
  }) async => PatientRecordPage.fromJson(
    await _readPatientResource(
      session,
      Uri.parse('$baseUrl/patients/').replace(
        queryParameters: {
          'search': search.trim(),
          'gender': ?gender,
          'blood_group': ?bloodGroup,
          'insurance_category': ?insuranceCategory,
          'page': '$page',
          'per_page': '$perPage',
          'sort': sort,
          'order': order,
        },
      ),
    ),
  );

  Future<Map<String, dynamic>> fetchPatientLookups(AuthSession session) =>
      _readPatientResource(session, Uri.parse('$baseUrl/lookups/all'));
  Future<Map<String, dynamic>> fetchPatientDefaults(AuthSession session) =>
      _readPatientResource(
        session,
        Uri.parse('$baseUrl/lookups/form-defaults/patient'),
      );

  Future<Patient> registerPatient(
    AuthSession session,
    Map<String, dynamic> values,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/patients/'),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(values),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const DraftSaveException(
        'Registration result could not be confirmed. Search the patient directory before registering again.',
        uncertain: true,
      );
    }
    if ([400, 401, 403, 404, 409, 422].contains(response.statusCode)) {
      throw DraftSaveException(switch (response.statusCode) {
        401 => 'Session expired. Please sign in again.',
        403 => 'Your account cannot register patients.',
        409 => 'A patient with these details may already exist. Search the directory before continuing.',
        _ => _registrationValidationMessage(response),
      });
    }
    try {
      final body = jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body is! Map ||
          body['success'] != true ||
          body['data'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return Patient.fromJson(body['data'] as Map<String, dynamic>);
    } catch (_) {
      throw const DraftSaveException(
        'Registration result could not be confirmed. Search the patient directory before registering again.',
        uncertain: true,
      );
    }
  }

  String _registrationValidationMessage(http.Response response) {
    const labels = {
      'first_name': 'First name',
      'last_name': 'Last name',
      'gender': 'Sex',
      'age': 'Age',
      'date_of_birth': 'Date of birth',
      'phone': 'Mobile number',
      'email': 'Email',
      'address': 'Address',
      'city': 'City',
      'state': 'State',
      'country': 'Country',
      'zip_code': 'Postal code',
      'id_proof_type': 'ID proof type',
      'id_proof_number': 'ID proof number',
      'emergency_contact_name': 'Emergency contact name',
      'emergency_contact_phone': 'Emergency contact mobile',
      'emergency_contact_relation': 'Relation',
    };
    final fields = <String>{};
    try {
      final body = jsonDecode(response.body);
      void inspect(dynamic value) {
        if (value is Map) {
          for (final entry in value.entries) {
            if (labels.containsKey(entry.key)) fields.add(entry.key as String);
            // Inspect validation metadata only, never echoed request values.
            if ([
              'errors',
              'error',
              'detail',
              'details',
              'loc',
              'field',
              'path',
            ].contains(entry.key)) {
              inspect(entry.value);
            }
          }
        } else if (value is List) {
          for (final item in value) {
            inspect(item);
          }
        } else if (value is String && labels.containsKey(value)) {
          fields.add(value);
        }
      }

      inspect(body);
    } catch (_) {
      /* Keep malformed or unstructured server text private. */
    }
    final names = fields.map((key) => labels[key]!).join(', ');
    return 'Registration rejected (HTTP ${response.statusCode}). '
        '${names.isEmpty ? 'Check identity, address and emergency contact details.' : 'Check: $names.'}';
  }

  Future<List<Map<String, dynamic>>> searchPrescriptionPatients(
    AuthSession session,
    String search,
  ) async {
    final data = await _readPatientResource(
      session,
      Uri.parse('$baseUrl/patients/dropdown').replace(
        queryParameters: {
          'module': 'prescription',
          'q': search.trim(),
          'per_page': '20',
        },
      ),
    );
    final rows = recordList(data['items']);
    if (kDebugMode && const bool.fromEnvironment('DOCTOR_LIVE_QA')) {
      debugPrint(
        'DOCTOR_LOOKUP_QA|prescription|rows=${rows.length}|items=${data['items'] is List}',
      );
    }
    return rows;
  }

  Future<PatientRecordPage> fetchLaboratoryOrders(
    AuthSession session, {
    String status = 'ordered',
    String? patientId,
    int page = 1,
    int perPage = 10,
    String sort = 'date',
    String order = 'desc',
  }) async => PatientRecordPage.fromJson(
    await _readPatientResource(
      session,
      Uri.parse('$baseUrl/lab-tests/').replace(
        queryParameters: {
          'status': status,
          'patient_id': ?patientId,
          'page': '$page',
          'per_page': '$perPage',
          'sort': sort,
          'order': order,
        },
      ),
    ),
  );

  Future<Map<String, int>> fetchLaboratoryCounts(AuthSession session) async {
    const stages = ['ordered', 'sample_collected', 'processing', 'completed'];
    final counts = await Future.wait(
      stages.map(
        (stage) async => (await fetchLaboratoryOrders(
          session,
          status: stage,
          perPage: 1,
        )).total,
      ),
    );
    return {for (var i = 0; i < stages.length; i++) stages[i]: counts[i]};
  }

  Future<PatientRecordPage> fetchLaboratoryCatalog(
    AuthSession session, {
    String search = '',
    String? category,
    int page = 1,
    String sort = 'name',
    String order = 'asc',
  }) async => PatientRecordPage.fromJson(
    await _readPatientResource(
      session,
      Uri.parse('$baseUrl/lab-tests/catalog').replace(
        queryParameters: {
          'search': search.trim(),
          'category': ?category,
          'page': '$page',
          'per_page': '10',
          'sort': sort,
          'order': order,
        },
      ),
    ),
  );

  Future<List<Map<String, dynamic>>> fetchLaboratoryCategories(
    AuthSession session,
  ) async {
    final data = await _readPatientResource(
      session,
      Uri.parse('$baseUrl/lookups/all'),
    );
    return recordList(data['lab_test_categories']);
  }

  Future<List<Map<String, dynamic>>> searchLaboratoryPatients(
    AuthSession session,
    String search,
  ) async {
    final data = await _readPatientResource(
      session,
      Uri.parse('$baseUrl/patients/dropdown').replace(
        queryParameters: {
          'module': 'laboratory',
          'q': search.trim(),
          'per_page': '20',
        },
      ),
    );
    return recordList(data['items']);
  }

  Future<String> createLaboratoryOrder(
    AuthSession session, {
    required String patientId,
    String? doctorId,
    required List<Map<String, dynamic>> tests,
    String notes = '',
  }) async {
    if (tests.isEmpty) {
      throw const DraftSaveException('Select at least one test.');
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/lab-tests/'),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'patient_id': patientId,
              'doctor_id': ?doctorId,
              'tests': tests,
              if (notes.trim().isNotEmpty) 'notes': notes.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const DraftSaveException(
        'Order result could not be confirmed. Check Laboratory before creating another order.',
        uncertain: true,
      );
    }
    if ([400, 401, 403, 404, 409, 422].contains(response.statusCode)) {
      throw DraftSaveException(switch (response.statusCode) {
        401 => 'Session expired. Please sign in again.',
        403 => 'Your account cannot create this lab order. Contact your administrator.',
        409 =>
          'This order conflicts with an existing order. Refresh Laboratory.',
        _ => 'Order rejected. Review the patient, doctor and selected tests.',
      });
    }
    try {
      final body = jsonDecode(response.body);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body is! Map ||
          body['success'] != true ||
          body['data'] is! Map ||
          body['data']['id'] is! String ||
          (body['data']['id'] as String).isEmpty) {
        throw const FormatException();
      }
      return body['data']['id'] as String;
    } catch (_) {
      throw const DraftSaveException(
        'Order result could not be confirmed. Check Laboratory before creating another order.',
        uncertain: true,
      );
    }
  }

  Future<Map<String, dynamic>> fetchPrescription(
    AuthSession session,
    String id,
  ) async {
    final data = await _readPatientResource(
      session,
      Uri.parse('$baseUrl/prescriptions/${Uri.encodeComponent(id)}'),
    );
    if (data['id'] != id) {
      throw const FormatException('Prescription identity mismatch');
    }
    recordList(data['medications']);
    recordList(data['lab_tests']);
    return data;
  }

  Future<Map<String, int?>> fetchPharmacySummary(AuthSession session) async {
    Future<int?> total(String path, String key) async {
      try {
        final data = await _readPatientResource(
          session,
          Uri.parse('$baseUrl/$path'),
        );
        final value = key == 'count'
            ? data['count']
            : (data['meta'] is Map ? data['meta']['total_items'] : null);
        if (value is! int || value < 0) throw const FormatException();
        return value;
      } catch (_) {
        return null;
      }
    }

    final result = await Future.wait([
      total('prescriptions/?status=issued&per_page=1', 'total'),
      total('stock/low-stock?per_page=1', 'total'),
      total('stock/expiring?days=30', 'count'),
    ]);
    return {'issued': result[0], 'low': result[1], 'expiring': result[2]};
  }

  Future<List<Map<String, dynamic>>> searchPharmacyPatients(
    AuthSession session,
    String search,
  ) async {
    final data = await _readPatientResource(
      session,
      Uri.parse('$baseUrl/patients/dropdown').replace(
        queryParameters: {
          'module': 'pharmacy',
          'q': search.trim(),
          'per_page': '20',
        },
      ),
    );
    return recordList(data['items']);
  }

  Future<Map<String, dynamic>> fetchPharmacyStock(
    AuthSession session, {
    String view = 'all',
    String search = '',
    int page = 1,
  }) => _readPatientResource(
    session,
    Uri.parse('$baseUrl/stock/${view == 'expiring' ? 'expiring' : ''}').replace(
      queryParameters: {
        if (view == 'expiring') 'days': '30',
        if (view == 'low') 'low_stock_only': 'true',
        if (view != 'expiring') 'search': search.trim(),
        'page': '$page',
        'per_page': '10',
        'sort': view == 'expiring' ? 'expiry' : 'name',
        'order': 'asc',
      },
    ),
  );

  Future<void> dispensePrescription(AuthSession session, String id) async {
    final http.Response response;
    try {
      response = await _client
          .patch(
            Uri.parse(
              '$baseUrl/prescriptions/${Uri.encodeComponent(id)}/dispense',
            ),
            headers: {
              'Authorization': 'Bearer ${session.accessToken}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: '{}',
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const DraftSaveException(
        'Dispensing result could not be confirmed. Refresh the prescription and stock before retrying.',
        uncertain: true,
      );
    }
    if ([400, 401, 403, 404, 409, 422].contains(response.statusCode)) {
      throw DraftSaveException(switch (response.statusCode) {
        401 => 'Session expired. Please sign in again.',
        403 => 'Your account cannot dispense prescriptions.',
        409 => 'Prescription or stock changed. Refresh before dispensing.',
        _ => 'Dispensing was rejected. Check medicine quantities and available stock.',
      });
    }
    try {
      final body = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          body is! Map ||
          body['success'] != true) {
        throw const FormatException();
      }
    } catch (_) {
      throw const DraftSaveException(
        'Dispensing result could not be confirmed. Refresh the prescription and stock before retrying.',
        uncertain: true,
      );
    }
  }

  Future<Map<String, dynamic>> _readPatientResource(
    AuthSession session,
    Uri uri,
  ) async {
    final response = await _client
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (kDebugMode &&
        const bool.fromEnvironment('DOCTOR_LIVE_QA') &&
        uri.path.endsWith('/patients/dropdown')) {
      debugPrint('DOCTOR_LOOKUP_QA|http|${response.statusCode}');
    }
    if (response.statusCode != 200) {
      throw AppointmentDetailException(switch (response.statusCode) {
        401 => 'Session expired. Please sign in again.',
        403 => 'You do not have permission to view these records.',
        404 => 'These records are no longer available.',
        _ => 'Unable to load records. Please try again.',
      });
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['data'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid records response');
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  Future<PatientRecordPage> fetchPatientRecords(
    AuthSession session,
    String patientId, {
    required bool labs,
    int page = 1,
  }) async {
    final uri =
        Uri.parse(
          '$baseUrl/patients/${Uri.encodeComponent(patientId)}/${labs ? 'lab-orders' : 'appointments'}',
        ).replace(
          queryParameters: {
            'page': '$page',
            'per_page': '10',
            'sort': 'date',
            'order': 'desc',
          },
        );
    final data = await _readPatientResource(session, uri);
    // A scoped endpoint is required; reject an explicit patient mismatch too.
    final result = PatientRecordPage.fromJson(data);
    for (final item in result.items) {
      if (item['patient_id'] != null && item['patient_id'] != patientId) {
        throw const FormatException('Patient mismatch');
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> fetchLabReport(
    AuthSession session,
    String orderId,
    String patientId,
  ) async {
    final data = await _readPatientResource(
      session,
      Uri.parse('$baseUrl/lab-tests/${Uri.encodeComponent(orderId)}'),
    );
    final patient = data['patient'];
    final linkedPatient =
        data['patient_id'] ?? (patient is Map ? patient['id'] : null);
    if (data['id'] != orderId || linkedPatient != patientId) {
      throw const FormatException('Report identity mismatch');
    }
    for (final test in recordList(data['tests'])) {
      recordList(test['results']);
    }
    return data;
  }

  Future<Patient> fetchPatient(AuthSession session, String id) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/patients/${Uri.encodeComponent(id)}'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw AppointmentDetailException(switch (response.statusCode) {
        401 => 'Session expired. Please sign in again.',
        403 => 'You do not have permission to view this patient.',
        404 => 'This patient is no longer available.',
        _ => 'Unable to load patient. Please try again.',
      });
    }
    try {
      final decoded = jsonDecode(response.body);
      if (kDebugMode) {
        for (final line in describeAppointmentResponse(decoded)) {
          debugPrint('PATIENT STRUCTURE: $line');
        }
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['success'] != true ||
          decoded['data'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final patient = Patient.fromJson(decoded['data'] as Map<String, dynamic>);
      if (patient.id != id) throw const FormatException();
      return patient;
    } on FormatException {
      throw const AppointmentDetailException(
        'Patient response could not be read. Please try again.',
      );
    }
  }

  Future<Appointment> fetchAppointmentDetail(
    AuthSession session,
    String id,
  ) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/appointments/${Uri.encodeComponent(id)}'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
        )
        .timeout(const Duration(seconds: 20));
    switch (response.statusCode) {
      case 401:
        throw const AppointmentDetailException(
          'Session expired. Please sign in again.',
        );
      case 403:
        throw const AppointmentDetailException(
          'You do not have permission to view this appointment.',
        );
      case 404:
        throw const AppointmentDetailException(
          'This appointment is no longer available.',
        );
      case 200:
        break;
      default:
        throw const AppointmentDetailException(
          'Unable to load appointment. Please try again.',
        );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['success'] != true ||
          decoded['data'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final appointment = Appointment.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
      if (appointment.id != id) throw const FormatException();
      return appointment;
    } on FormatException {
      throw const AppointmentDetailException(
        'Appointment response could not be read. Please try again.',
      );
    }
  }

  static const String baseUrl = ApiConfig.baseUrl;

  Future<DoctorProfile> fetchProfile(AuthSession session) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/auth/me'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 403) {
      throw Exception('You do not have permission to view this profile.');
    }

    if (response.statusCode != 200) {
      throw Exception('Unable to load profile (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['data'] is! Map<String, dynamic>) {
      throw Exception('Invalid profile response');
    }

    return DoctorProfile.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> fetchAccount(AuthSession session) =>
      _readPatientResource(session, Uri.parse('$baseUrl/auth/me'));
  Future<Map<String, dynamic>> fetchAccountSessions(AuthSession session) =>
      _readPatientResource(session, Uri.parse('$baseUrl/auth/sessions'));
  Future<Map<String, dynamic>> fetchSecurityActivity(AuthSession session) =>
      _readPatientResource(
        session,
        Uri.parse('$baseUrl/auth/security-log')
            .replace(queryParameters: {'limit': '50'}),
      );
  Future<Map<String, dynamic>> fetchNotificationPreferences(
    AuthSession session,
  ) => _readPatientResource(
    session,
    Uri.parse('$baseUrl/notification-preferences/'),
  );

  Future<void> _updateAccountResource(
    AuthSession session,
    String method,
    String path,
    Map<String, dynamic> values,
  ) async {
    final http.Response response;
    final uri = Uri.parse('$baseUrl/$path');
    final headers = {
      'Authorization': 'Bearer ${session.accessToken}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    try {
      response =
          await (method == 'PUT'
                  ? _client.put(uri, headers: headers, body: jsonEncode(values))
                  : _client.post(
                      uri,
                      headers: headers,
                      body: jsonEncode(values),
                    ))
              .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const AppointmentDetailException(
        'The result could not be confirmed. Refresh your account before retrying.',
      );
    }
    if (response.statusCode == 204) return;
    if (response.statusCode == 401) {
      throw const AppointmentDetailException(
        'Session expired or current credentials were rejected. Please sign in again.',
      );
    }
    if (response.statusCode == 403) {
      throw const AppointmentDetailException(
        'Your account does not have permission for this change.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AppointmentDetailException(
        'The change was rejected. Check your details or verification code.',
      );
    }
    try {
      final body = jsonDecode(response.body);
      if (body is! Map || body['success'] != true) {
        throw const FormatException();
      }
    } catch (_) {
      throw const AppointmentDetailException(
        'The result could not be confirmed. Refresh your account before retrying.',
      );
    }
  }

  Future<void> saveAccountDetails(
    AuthSession session, {
    required String firstName,
    required String lastName,
    required String address,
  }) async {
    if (firstName.trim().isEmpty) {
      throw const AppointmentDetailException('Enter your first name.');
    }
    final current = await fetchAccount(session);
    final id = current['id'];
    if (id is! String || id.isEmpty) {
      throw const AppointmentDetailException(
        'Unable to confirm account identity. Please sign in again.',
      );
    }
    await _updateAccountResource(
      session,
      'PUT',
      'users/${Uri.encodeComponent(id)}',
      {
        'first_name': firstName.trim(),
        'last_name': lastName.trim().isEmpty ? null : lastName.trim(),
        'address': address.trim().isEmpty ? null : address.trim(),
      },
    );
  }

  Future<void> changeAccountPassword(
    AuthSession session,
    String current,
    String next,
  ) => _updateAccountResource(session, 'POST', 'auth/password/change', {
    'current_password': current,
    'new_password': next,
  });
  Future<void> sendAccountEmailCode(AuthSession session) async {
    final account = await fetchAccount(session);
    final email = account['email'];
    if (email is! String || email.isEmpty) {
      throw const AppointmentDetailException(
        'Your account email is unavailable.',
      );
    }
    await _updateAccountResource(session, 'POST', 'otp/send', {
      'target': email,
      'channel': 'email',
      'purpose': 'verify_email',
    });
  }

  Future<void> verifyAccountEmail(AuthSession session, String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const AppointmentDetailException(
        'Enter the six-digit verification code.',
      );
    }
    final account = await fetchAccount(session);
    final email = account['email'];
    if (email is! String || email.isEmpty) {
      throw const AppointmentDetailException(
        'Your account email is unavailable.',
      );
    }
    await _updateAccountResource(session, 'POST', 'otp/verify', {
      'target': email,
      'otp': code,
      'purpose': 'verify_email',
    });
  }

  Future<void> saveNotificationPreferences(
    AuthSession session,
    Map<String, dynamic> values,
  ) async {
    const keys = [
      'email_notifications',
      'sms_notifications',
      'push_notifications',
      'appointment_alerts',
      'prescription_alerts',
      'lab_alerts',
      'billing_alerts',
    ];
    final payload = <String, dynamic>{'security_alerts': true};
    for (final key in keys) {
      if (values[key] is bool) payload[key] = values[key];
    }
    for (final key in ['quiet_hours_start', 'quiet_hours_end']) {
      final value = values[key];
      if (value != null &&
          value != '' &&
          (value is! String ||
              !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?$')
                  .hasMatch(value))) {
        throw const AppointmentDetailException('Choose valid quiet hours.');
      }
      payload[key] = value == '' ? null : value;
    }
    if ((payload['quiet_hours_start'] == null) !=
        (payload['quiet_hours_end'] == null)) {
      throw const AppointmentDetailException(
        'Choose both quiet-hours times or clear both.',
      );
    }
    await _updateAccountResource(
      session,
      'PUT',
      'notification-preferences/',
      payload,
    );
  }

  Future<DashboardSummary> fetchDashboardSummary(
    AuthSession session, {
    DateTime? selectedDate,
  }) async {
    final now = selectedDate ?? DateTime.now();

    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse('$baseUrl/calendar/day')
        .replace(queryParameters: {'date': date});

    if (kDebugMode) debugPrint('DASHBOARD REQUEST DATE: $date');

    final response = await _client
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 401) {
      throw Exception('Session expired. Login again.');
    }

    if (response.statusCode == 403) {
      throw Exception('Calendar access denied.');
    }

    if (response.statusCode != 200) {
      throw Exception('Calendar API failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['data'] is! Map<String, dynamic>) {
      throw Exception('Invalid calendar response');
    }

    return DashboardSummary.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  Future<dynamic> fetchAppointments(
    AuthSession session, {
    DateTime? selectedDate,
    String? status,
    int page = 1,
    String sort = 'time',
    String order = 'asc',
  }) async {
    final now = selectedDate ?? DateTime.now();

    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final uri = Uri.parse('$baseUrl/appointments/').replace(
      queryParameters: {
        'date': date,
        'page': '$page',
        'per_page': '10',
        'sort': sort,
        'order': order,
        'status': ?status,
      },
    );

    if (kDebugMode) debugPrint('APPOINTMENTS REQUEST DATE: $date');

    final response = await _client
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${session.accessToken}',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 401) {
      throw Exception('Session expired. Login again.');
    }

    if (response.statusCode == 403) {
      throw Exception('Appointments access denied.');
    }

    if (response.statusCode != 200) {
      throw Exception('Appointments API failed: ${response.statusCode}');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw Exception('Appointments server returned invalid JSON.');
    }

    if (decoded is! Map && decoded is! List) {
      throw Exception('Unexpected appointments response');
    }

    if (decoded is Map && decoded['success'] == false) {
      // Do not expose a server message that could contain patient data.
      throw Exception('Unable to load appointments. Please try again.');
    }

    return decoded;
  }
}

class DashboardSummary {
  final int appointments;
  final int scheduled;
  final int confirmed;
  final int inProgress;
  final int completed;
  final int followUpsDue;

  const DashboardSummary({
    required this.appointments,
    required this.scheduled,
    required this.confirmed,
    required this.inProgress,
    required this.completed,
    required this.followUpsDue,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final status = json['by_status'];

    final counts = status is Map<String, dynamic>
        ? status
        : <String, dynamic>{};

    int number(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return DashboardSummary(
      appointments: number(json['appointments']),
      scheduled: number(counts['scheduled']),
      confirmed: number(counts['confirmed']),
      inProgress: number(counts['in_progress']),
      completed: number(counts['completed']),
      followUpsDue: number(json['follow_ups_due']),
    );
  }
}
