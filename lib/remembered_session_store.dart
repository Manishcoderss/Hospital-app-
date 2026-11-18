import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class SavedSignIn {
  const SavedSignIn(this.refreshToken, this.email);
  final String refreshToken, email;
}

class RememberedSessionStore {
  RememberedSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const key = 'samagati.remembered_session.v1';
  static const disabledKey = 'samagati.remembered_session.disabled';

  Future<SavedSignIn?> read() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(disabledKey) == true) return null;
    final raw = await _storage.read(key: key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      if (data is! Map ||
          data['refresh_token'] is! String ||
          (data['refresh_token'] as String).isEmpty ||
          data['email'] is! String) {
        throw const FormatException();
      }
      return SavedSignIn(
        data['refresh_token'] as String,
        data['email'] as String,
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(disabledKey, true)) {
      throw StateError('Unable to disable the previous saved session');
    }
    await _storage.write(
      key: key,
      value: jsonEncode({
        'refresh_token': session.refreshToken,
        'email': session.email,
      }),
    );
    if (!await preferences.setBool(disabledKey, false)) {
      throw StateError('Unable to enable saved sign-in');
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setBool(disabledKey, true)) {
      throw StateError('Unable to disable saved sign-in');
    }
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // The persistent flag prevents reuse even if native deletion fails.
    }
  }
}
