import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  const AuthSession._();

  static const _accessTokenKey = 'access_token';
  static const _userKey = 'user';

  /// 当前会话（仅内存）。
  ///
  /// 登录成功后**始终**写入这里，与是否勾选「记住登录状态」无关 ——
  /// 勾选框只决定是否同时写入磁盘（即是否支持下次启动自动登录）。
  /// 服务层通过 [restore] 取 token，因此内存会话必须存在，
  /// 否则取消勾选后所有鉴权接口都会失败。
  static AuthSessionData? _current;

  static AuthSessionData? get current => _current;

  /// 登录成功后调用。
  ///
  /// [remember] 为 false 时只保留在内存中，应用重启后需重新登录。
  static Future<void> start({
    required String accessToken,
    required Map<String, dynamic> user,
    required bool remember,
  }) async {
    _current = AuthSessionData(accessToken: accessToken, user: user);
    if (remember) {
      await _persist(accessToken, user);
    } else {
      await _clearPersisted();
    }
  }

  /// 取当前会话：优先内存，其次磁盘。
  static Future<AuthSessionData?> restore() async {
    if (_current != null) return _current;

    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);
    final rawUser = prefs.getString(_userKey);
    if (accessToken == null || accessToken.isEmpty || rawUser == null) {
      return null;
    }

    try {
      final user = jsonDecode(rawUser) as Map<String, dynamic>;
      final data = AuthSessionData(accessToken: accessToken, user: user);
      _current = data;
      return data;
    } catch (_) {
      await clear();
      return null;
    }
  }

  /// 写入内存并持久化（用于刷新用户信息等场景）。
  static Future<void> save(
    String accessToken,
    Map<String, dynamic> user,
  ) async {
    _current = AuthSessionData(accessToken: accessToken, user: user);
    await _persist(accessToken, user);
  }

  static Future<void> clear() async {
    _current = null;
    await _clearPersisted();
  }

  static Future<void> _persist(
    String accessToken,
    Map<String, dynamic> user,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<void> _clearPersisted() async {
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
