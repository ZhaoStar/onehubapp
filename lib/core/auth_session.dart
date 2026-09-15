import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  const AuthSession._();

  static const _accessTokenKey = 'access_token';
  static const _userKey = 'user';

  static Future<AuthSessionData?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);
    final rawUser = prefs.getString(_userKey);
    if (accessToken == null || accessToken.isEmpty || rawUser == null) {
      return null;
    }

    try {
      final user = jsonDecode(rawUser) as Map<String, dynamic>;
      return AuthSessionData(accessToken: accessToken, user: user);
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> save(
    String accessToken,
    Map<String, dynamic> user,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_userKey);
  }
}

class AuthSessionData {
  const AuthSessionData({required this.accessToken, required this.user});

  final String accessToken;
  final Map<String, dynamic> user;
}
