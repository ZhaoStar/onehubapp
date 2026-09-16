import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onehubapp/core/auth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final user = <String, dynamic>{'id': 1, 'username': 'tester'};

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AuthSession.clear();
  });

  group('AuthSession', () {
    test('勾选「记住登录」时，内存与磁盘都有会话', () async {
      await AuthSession.start(
        accessToken: 'token-a',
        user: user,
        remember: true,
      );

      expect(AuthSession.current?.accessToken, 'token-a');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), 'token-a');
    });

    test('不勾选「记住登录」时，内存仍有会话、磁盘为空', () async {
      await AuthSession.start(
        accessToken: 'token-b',
        user: user,
        remember: false,
      );

      expect(AuthSession.current?.accessToken, 'token-b');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
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

    test('save 会同时更新内存与磁盘', () async {
      await AuthSession.save('token-d', user);

      expect(AuthSession.current?.accessToken, 'token-d');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), 'token-d');
    });

    test('clear 同时清除内存与磁盘', () async {
      await AuthSession.start(
        accessToken: 'token-e',
        user: user,
        remember: true,
      );

      await AuthSession.clear();

      expect(AuthSession.current, isNull);
      expect(await AuthSession.restore(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
    });
  });
}
