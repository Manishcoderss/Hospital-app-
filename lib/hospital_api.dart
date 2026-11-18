import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart';

class HospitalApiException implements Exception {
  const HospitalApiException(
    this.message, {
    this.status,
    this.uncertain = false,
  });
  final String message;
  final int? status;
  final bool uncertain;
  @override
  String toString() => message;
}

class HospitalResult {
  const HospitalResult(this.data, {this.bytes, this.contentType});
  final Object? data;
  final Uint8List? bytes;
  final String? contentType;
}

class HospitalApi {
  HospitalApi(this.session, {http.Client? client, String? baseUrl})
    : client = client ?? http.Client(),
      baseUrl = baseUrl ?? ApiConfig.baseUrl;
  AuthSession session;
  final http.Client client;
  final String baseUrl;
  void close() => client.close();

  Uri resolve(
    Map<String, dynamic> operation,
    Map<String, String> parameters,
    Map<String, String> query,
  ) {
    var path = operation['path'] as String;
    path = path.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (match) {
      final key = match.group(1)!;
      final value = parameters[key]?.trim();
      if (value == null || value.isEmpty) {
        throw HospitalApiException('Choose ${label(key)} first.');
      }
      return Uri.encodeComponent(value);
    });
    final uri = path == '/../health'
        ? Uri.parse('${baseUrl.replaceFirst(RegExp(r'/v1/?$'), '')}/health')
        : Uri.parse('${baseUrl.replaceFirst(RegExp(r'/$'), '')}$path');
    return uri.replace(
      queryParameters: {
        for (final e in query.entries)
          if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
      },
    );
  }

  Future<HospitalResult> execute(
    Map<String, dynamic> operation, {
    Map<String, String> parameters = const {},
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
    List<http.MultipartFile> files = const [],
    Map<String, String> fields = const {},
  }) async {
    final method = operation['method'] as String;
    final uri = resolve(operation, parameters, query);
    final http.BaseRequest request;
    if ((operation['multipart'] as List? ?? []).isNotEmpty) {
      request = http.MultipartRequest(method, uri)
        ..files.addAll(files)
        ..fields.addAll(fields);
    } else {
      request = http.Request(method, uri)
        ..headers['Content-Type'] = 'application/json';
      if (body != null && body.isNotEmpty) {
        (request as http.Request).body = jsonEncode(body);
      }
    }
    request.headers.addAll({
      'Accept': 'application/json',
      if (session.accessToken.isNotEmpty)
        'Authorization':
            'Bearer ${operation['path'] == '/auth/refresh' ? session.refreshToken : session.accessToken}',
    });
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 25)),
      ).timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw HospitalApiException(
        method == 'GET' ? 'The hospital server took too long. Please retry.' : 'The result is not confirmed. Refresh the record before trying again.',
        uncertain: method != 'GET',
      );
    } catch (_) {
      throw HospitalApiException(
        method == 'GET'
            ? 'Unable to connect. Check your connection and retry.'
            : 'The result is not confirmed. Refresh the record before trying again.',
        uncertain: method != 'GET',
      );
    }
    if (response.statusCode == 401) {
      throw const HospitalApiException(
        'Your session has expired. Sign in again.',
        status: 401,
      );
    }
    if (response.statusCode == 403) {
      throw const HospitalApiException(
        'Your hospital account does not have permission for this action.',
        status: 403,
      );
    }
    if (response.statusCode == 404) {
      throw const HospitalApiException(
        'This record or service is no longer available.',
        status: 404,
      );
    }
    if (response.statusCode == 429) {
      throw const HospitalApiException(
        'Too many requests. Please wait and try again.',
        status: 429,
      );
    }
    Object? decoded;
    final type = response.headers['content-type'] ?? '';
    if (type.contains('json') ||
        response.body.trimLeft().startsWith('{') ||
        response.body.trimLeft().startsWith('[')) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw HospitalApiException(
          'The hospital server returned an unreadable response.',
          uncertain: method != 'GET',
        );
      }
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is Map && decoded['success'] == false) {
      final message = decoded is Map ? decoded['message'] : null;
      throw HospitalApiException(
        message is String && message.length < 500 ? message : 'The hospital could not complete this action. Check the details and retry.',
        status: response.statusCode,
        uncertain: method != 'GET' && response.statusCode >= 500,
      );
    }
    if (response.statusCode == 204) return const HospitalResult(null);
    if (decoded != null) {
      return HospitalResult(
        decoded is Map && decoded.containsKey('data')
            ? decoded['data']
            : decoded,
      );
    }
    if (type.contains('pdf') ||
        type.contains('image/') ||
        type.contains('octet-stream') ||
        type.contains('csv')) {
      return HospitalResult(null, bytes: response.bodyBytes, contentType: type);
    }
    throw HospitalApiException(
      'The hospital server returned an unsupported response.',
      uncertain: method != 'GET',
    );
  }

  Future<Object?> get(
    String path, {
    Map<String, String> query = const {},
  }) async =>
      (await execute({'method': 'GET', 'path': path}, query: query)).data;
  static List<Map<String, dynamic>> rows(Object? data) {
    final value = data is Map
        ? data['items'] ?? data['results'] ?? data['records']
        : data;
    if (value is! List || value.any((x) => x is! Map<String, dynamic>)) {
      throw const HospitalApiException(
        'This list could not be read. Please retry.',
      );
    }
    return value.cast<Map<String, dynamic>>();
  }
}

String label(String key) => key
    .replaceAll('_', ' ')
    .split(' ')
    .map((s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1))
    .join(' ');
