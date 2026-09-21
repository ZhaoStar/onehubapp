import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onehubapp/core/token_vault.dart';

class AuthSession {
  const AuthSession._();

  /// 旧版本曾把令牌明文存在 SharedPreferences 里的键名。
  /// 现在仅用于迁移：一旦读到就搬进安全存储并删除明文副本。
  static const _legacyAccessTokenKey = 'access_token';

  /// 用户资料不是凭据，继续放在 SharedPreferences，避免每次启动都解一次密钥
  static const _userKey = 'user';

  /// 令牌的落盘实现，默认写入系统安全存储
  static TokenVault _vault = SecureTokenVault();

  /// 仅测试使用：替换令牌落盘实现
  @visibleForTesting
  static set vault(TokenVault value) => _vault = value;

  /// 当前会话（仅内存）。
  ///
  /// 登录成功后**始终**写入这里，与是否勾选「记住登录状态」无关 ——
  /// 勾选框只决定是否同时写入磁盘（即是否支持下次启动自动登录）。
  /// 服务层通过 [restore] 取 token，因此内存会话必须存在，
  /// 否则取消勾选后所有鉴权接口都会失败。
  static AuthSessionData? _current;

  static AuthSessionData? get current => _current;

  /// 仅测试使用：丢掉内存会话，用来模拟「应用重启」
  @visibleForTesting
  static void resetMemory() => _current = null;

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
    final accessToken = await _readToken(prefs);
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

  /// 读取令牌，同时把旧版本遗留的明文令牌迁移进安全存储。
  static Future<String?> _readToken(SharedPreferences prefs) async {
    final token = await _vault.read();
    final legacyToken = prefs.getString(_legacyAccessTokenKey);

    if (legacyToken != null && legacyToken.isNotEmpty) {
      if (token == null || token.isEmpty) {
        await _vault.write(legacyToken);
        await prefs.remove(_legacyAccessTokenKey);
        return legacyToken;
      }
      // 安全存储里已有令牌，直接删掉遗留的明文副本
      await prefs.remove(_legacyAccessTokenKey);
    }

    return token;
  }

  static Future<void> _persist(
    String accessToken,
    Map<String, dynamic> user,
  ) async {
    await _vault.write(accessToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
    // 令牌只进安全存储，明文键位顺手清掉
    await prefs.remove(_legacyAccessTokenKey);
  }

  static Future<void> _clearPersisted() async {
    await _vault.delete();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyAccessTokenKey);
    await prefs.remove(_userKey);
  }
}

class AuthSessionData {
  const AuthSessionData({required this.accessToken, required this.user});

  final String accessToken;
  final Map<String, dynamic> user;
}
