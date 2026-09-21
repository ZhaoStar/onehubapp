import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onehubapp/core/auth_session.dart';
import 'package:onehubapp/core/token_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final user = <String, dynamic>{'id': 1, 'username': 'tester'};
  late Map<String, String> secureStore;

  setUp(() async {
    secureStore = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secureStore);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AuthSession.clear();
    secureStore.clear();
    AuthSession.resetMemory();
  });

  group('AuthSession', () {
    test('勾选「记住登录」时，内存与安全存储都有会话', () async {
      await AuthSession.start(
        accessToken: 'token-a',
        user: user,
        remember: true,
      );

      expect(AuthSession.current?.accessToken, 'token-a');
      expect(secureStore[SecureTokenVault.storageKey], 'token-a');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('access_token'),
        isNull,
        reason: '令牌不应再以明文写入 SharedPreferences',
      );
    });

    test('不勾选「记住登录」时，内存仍有会话、磁盘为空', () async {
      await AuthSession.start(
        accessToken: 'token-b',
        user: user,
        remember: false,
      );

      expect(AuthSession.current?.accessToken, 'token-b');

      expect(secureStore[SecureTokenVault.storageKey], isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user'), isNull);
    });

    test('不勾选「记住登录」时，服务层仍能取到 token（回归测试）', () async {
      await AuthSession.start(
        accessToken: 'token-c',
        user: user,
        remember: false,
      );

      final restored = await AuthSession.restore();
      expect(restored, isNotNull);
      expect(restored?.accessToken, 'token-c');
      expect(restored?.user['username'], 'tester');
    });

    test('restore 优先返回内存会话', () async {
      await AuthSession.start(
        accessToken: 'token-memory',
        user: user,
        remember: true,
      );
      expect((await AuthSession.restore())?.accessToken, 'token-memory');
    });

    test('重启后能从安全存储恢复会话', () async {
      await AuthSession.start(
        accessToken: 'token-disk',
        user: user,
        remember: true,
      );
      AuthSession.resetMemory();

      final restored = await AuthSession.restore();
      expect(restored?.accessToken, 'token-disk');
      expect(restored?.user['username'], 'tester');
    });

    test('旧版本明文令牌会在读取时迁移进安全存储并删除明文副本', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'access_token': 'legacy-token',
        'user': jsonEncode(user),
      });
      AuthSession.resetMemory();

      final restored = await AuthSession.restore();

      expect(restored?.accessToken, 'legacy-token');
      expect(secureStore[SecureTokenVault.storageKey], 'legacy-token');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
    });

    test('安全存储里已有令牌时，残留的明文副本会被清掉', () async {
      secureStore[SecureTokenVault.storageKey] = 'secure-token';
      SharedPreferences.setMockInitialValues(<String, Object>{
        'access_token': 'legacy-token',
        'user': jsonEncode(user),
      });
      AuthSession.resetMemory();

      final restored = await AuthSession.restore();

      expect(restored?.accessToken, 'secure-token');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
    });

    test('save 会同时更新内存与安全存储', () async {
      await AuthSession.save('token-e', user);

      expect(AuthSession.current?.accessToken, 'token-e');
      expect(secureStore[SecureTokenVault.storageKey], 'token-e');
    });

    test('clear 同时清除内存、安全存储与磁盘', () async {
      await AuthSession.start(
        accessToken: 'token-f',
        user: user,
        remember: true,
      );

      await AuthSession.clear();

      expect(AuthSession.current, isNull);
      expect(await AuthSession.restore(), isNull);
      expect(secureStore[SecureTokenVault.storageKey], isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user'), isNull);
    });
  });
}
