import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 访问令牌的落盘方式。
///
/// 抽成接口有两个目的：单测可以替换掉依赖原生 Keystore / Keychain 的实现；
/// 将来更换存储方案时只需要改这一处。
abstract class TokenVault {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> delete();
}

/// 基于系统安全存储的实现：Android 走 Keystore 加密，iOS / macOS 走 Keychain。
class SecureTokenVault implements TokenVault {
  SecureTokenVault({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// 键名带应用前缀，避免与其它库写入的条目混淆
  static const String storageKey = 'onehubapp_access_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: storageKey);
    } catch (error) {
      // 个别机型 Keystore 异常时会抛错，按「未登录」处理，不因此让应用崩溃
      debugPrint('读取安全存储失败: $error');
      return null;
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await _storage.write(key: storageKey, value: token);
    } catch (error) {
      debugPrint('写入安全存储失败: $error');
    }
  }

  @override
  Future<void> delete() async {
    try {
      await _storage.delete(key: storageKey);
    } catch (error) {
      debugPrint('清除安全存储失败: $error');
    }
  }
}
