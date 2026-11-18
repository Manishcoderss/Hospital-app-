import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'doctor_dashboard_service.dart';

class BookingException implements Exception {
  const BookingException(
    this.message, {
    this.uncertain = false,
    this.statusCode,
  });
  final String message;
  final bool uncertain;
  final int? statusCode;
}

class AppointmentBookingService {
  AppointmentBookingService({http.Client? client})
    : _client = client ?? http.Client();
  final http.Client _client;
  void close() => _client.close();

  Map<String, String> _headers(AuthSession session) => {
    'Authorization': 'Bearer ${session.accessToken}',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<Object?> _get(
    AuthSession session,
    String path, [
    Map<String, String>? query,
  ]) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${DoctorDashboardService.baseUrl}/$path')
                .replace(queryParameters: query),
            headers: _headers(session),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 401) {
        throw const BookingException('Session expired. Please sign in again.');
      }
      if (response.statusCode == 403) {
        throw const BookingException(
          'Booking access is unavailable. Ask your administrator to check your doctor profile and permissions.',
          statusCode: 403,
        );
      }
      if (path == 'doctors/me' && response.statusCode == 404) {
        throw const BookingException(
          'No linked doctor profile.',
          statusCode: 404,
        );
      }
      if (response.statusCode != 200) {
        throw const BookingException(
          'Unable to load booking options. Please retry.',
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map || body['success'] != true) {
        throw const FormatException();
      }
      return body['data'];
    } on BookingException {
      rethrow;
    } catch (_) {
      throw const BookingException(
        'Unable to load booking options. Please retry.',
      );
    }
  }

  List<Map<String, dynamic>> _rows(Object? value) {
    if (value is! List ||
        value.any(
          (item) =>
              item is! Map<String, dynamic> ||
              item['id'] is! String ||
              (item['id'] as String).isEmpty,
        )) {
      throw const BookingException(
        'Booking options could not be read. Please retry.',
      );
    }
    return value.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> doctors(AuthSession session) async =>
      _rows(
        await _get(session, 'doctors/dropdown', {'available_only': 'true'}),
      );

  Future<String> ownDoctorId(AuthSession session) async {
    final data = await _get(session, 'doctors/me');
    if (data is! Map ||
        data['id'] is! String ||
        (data['id'] as String).isEmpty) {
      throw const BookingException(
        'Your doctor profile could not be loaded. Contact your administrator.',
      );
    }
    return data['id'] as String;
  }

  Future<List<Map<String, dynamic>>> patients(
    AuthSession session,
    String search,
  ) async {
    final data = await _get(session, 'patients/dropdown', {
      'module': 'appointments',
      'q': search.trim(),
      'per_page': '20',
    });
    if (data is! Map) {
      throw const BookingException('Patient search could not be read.');
    }
    return _rows(data['items']);
  }

  Future<List<String>> slots(
    AuthSession session,
    String doctorId,
    String date,
  ) async {
    final data = await _get(
      session,
      'doctors/${Uri.encodeComponent(doctorId)}/availability',
      {'date': date},
    );
    if (data is! Map ||
        data['is_available'] is! bool ||
        data['slots'] is! List) {
      throw const BookingException('Doctor availability could not be read.');
    }
    final result = <String>[];
    for (final slot in data['slots'] as List) {
      if (slot is! Map ||
          slot['available'] is! bool ||
          slot['time'] is! String ||
          !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$')
              .hasMatch(slot['time'] as String)) {
        throw const BookingException('Doctor availability could not be read.');
      }
      if (data['is_available'] == true && slot['available'] == true) {
        result.add(slot['time'] as String);
      }
    }
    return result;
  }

  Future<String> book(
    AuthSession session, {
    required String patientId,
    required String doctorId,
    required String date,
    required String time,
    String reason = '',
    String symptoms = '',
    bool followUp = false,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${DoctorDashboardService.baseUrl}/appointments/'),
            headers: _headers(session),
            body: jsonEncode({
              'patient_id': patientId,
              'doctor_id': doctorId,
              'date': date,
              'time': time,
              if (reason.trim().isNotEmpty) 'reason': reason.trim(),
              if (symptoms.trim().isNotEmpty) 'symptoms': symptoms.trim(),
              'is_follow_up': followUp,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const BookingException(
        'Booking result could not be confirmed. Check Appointments in the hospital portal before booking again.',
        uncertain: true,
      );
    }
    if ([400, 401, 403, 404, 409, 422].contains(response.statusCode)) {
      throw BookingException(switch (response.statusCode) {
        401 => 'Session expired. Please sign in again.',
        403 => 'Booking is not permitted. Ask your administrator to check your doctor profile and permissions.',
        409 => 'This time is no longer available. Choose another slot.',
        _ =>
          'The booking was rejected. Check the patient, doctor, date and time.',
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
      throw const BookingException(
        'Booking result could not be confirmed. Check Appointments in the hospital portal before booking again.',
        uncertain: true,
      );
    }
  }
}
