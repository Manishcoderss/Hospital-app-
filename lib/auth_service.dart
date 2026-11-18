import 'api_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class LoginException implements Exception {
  const LoginException(this.message);
  final String message;
}

// Access tokens stay in memory. Opt-in session persistence stores only the
// refresh token and email using platform secure storage; never the password.
class AuthSession {
  const AuthSession(
    this.accessToken,
    this.refreshToken,
    this.name,
    this.email, {
    this.role = 'unknown',
  });
  final String accessToken;
  final String refreshToken;
  final String name;
  final String email;
  final String role;
}

class AuthService {
  AuthService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<AuthSession> login(String email, String password) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 20));
      final Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw const LoginException(
          'Server returned an invalid response. Please try again.',
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const LoginException(
          'Unexpected login response. Please try again.',
        );
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] != true) {
        final message = decoded['message'];
        throw LoginException(
          message is String && message.isNotEmpty
              ? message
              : 'Login failed. Please check your email and password.',
        );
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic> ||
          data['access_token'] is! String ||
          (data['access_token'] as String).isEmpty ||
          data['refresh_token'] is! String ||
          (data['refresh_token'] as String).isEmpty ||
          data['user'] is! Map<String, dynamic>) {
        throw const LoginException(
          'Incomplete login response. Please try again.',
        );
      }
      final user = data['user'] as Map<String, dynamic>;
      if (user['force_password_reset'] == true) {
        throw const LoginException(
          'Please reset your password on the hospital portal before signing in.',
        );
      }
      if (user['is_active'] == false) {
        throw const LoginException(
          'Your account is inactive. Please contact your administrator.',
        );
      }
      return AuthSession(
        data['access_token'] as String,
        data['refresh_token'] as String,
        user['full_name'] is String ? user['full_name'] as String : 'Welcome',
        user['email'] is String ? user['email'] as String : email.trim(),
        role: _role(user, data['access_token'] as String),
      );
    } on TimeoutException {
      throw const LoginException('Connection timed out. Please try again.');
    } on http.ClientException {
      throw const LoginException(
        'Unable to connect. Please check your internet connection.',
      );
    }
  }

  void close() => _client.close();

  Future<AuthSession> restoreSession(String refreshToken) async {
    try {
      final refresh = await _client
          .post(
            Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
            headers: {
              'Authorization': 'Bearer $refreshToken',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if ([400, 401, 403].contains(refresh.statusCode)) {
        throw const SessionRestoreException(
          'Your saved sign-in has expired. Please sign in again.',
          invalidSession: true,
        );
      }
      if (refresh.statusCode != 200) {
        throw const SessionRestoreException(
          'Unable to restore saved sign-in. Please retry or sign in.',
        );
      }
      final body = jsonDecode(refresh.body);
      final data = body is Map && body['success'] == true ? body['data'] : null;
      if (data is! Map ||
          data['access_token'] is! String ||
          (data['access_token'] as String).isEmpty) {
        throw const FormatException();
      }
      final access = data['access_token'] as String;
      final profile = await _client
          .get(
            Uri.parse('${ApiConfig.baseUrl}/auth/me'),
            headers: {
              'Authorization': 'Bearer $access',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 20));
      if ([401, 403].contains(profile.statusCode)) {
        throw const SessionRestoreException(
          'Your saved sign-in is no longer valid. Please sign in again.',
          invalidSession: true,
        );
      }
      if (profile.statusCode != 200) {
        throw const SessionRestoreException(
          'Unable to check saved sign-in. Please retry or sign in.',
        );
      }
      final decoded = jsonDecode(profile.body);
      final user = decoded is Map && decoded['success'] == true
          ? decoded['data']
          : null;
      if (user is! Map<String, dynamic>) throw const FormatException();
      if (user['is_active'] == false || user['force_password_reset'] == true) {
        throw const SessionRestoreException(
          'Please sign in again and check your account status in the hospital portal.',
          invalidSession: true,
        );
      }
      return AuthSession(
        access,
        data['refresh_token'] is String &&
                (data['refresh_token'] as String).isNotEmpty
            ? data['refresh_token'] as String
            : refreshToken,
        user['full_name'] is String ? user['full_name'] as String : 'Welcome',
        user['email'] is String ? user['email'] as String : '',
        role: _role(user, access),
      );
    } on SessionRestoreException {
      rethrow;
    } on TimeoutException {
      throw const SessionRestoreException(
        'Connection timed out while restoring sign-in. Please retry.',
      );
    } on http.ClientException {
      throw const SessionRestoreException(
        'Unable to connect. Retry saved sign-in when your connection is available.',
      );
    } catch (_) {
      throw const SessionRestoreException(
        'Unable to restore saved sign-in. Please retry or sign in.',
      );
    }
  }

  // Claims choose the UI only. The backend must authorize every medical request.
  String _role(Map<String, dynamic> user, String token) {
    if (user['role'] is String && (user['role'] as String).trim().isNotEmpty) {
      return (user['role'] as String).trim().toLowerCase();
    }
    try {
      final parts = token.split('.');
      if (parts.length != 3) return 'unknown';
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return claims is Map && claims['role'] is String
          ? (claims['role'] as String).trim().toLowerCase()
          : 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }
}

class SessionRestoreException extends LoginException {
  const SessionRestoreException(super.message, {this.invalidSession = false});
  final bool invalidSession;
}
