import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:onehubapp/models/app_version_model.dart';

/// 用户主动取消下载时抛出，调用方据此把「取消」和「失败」区分开
class DownloadCanceledException implements Exception {
  const DownloadCanceledException();

  @override
  String toString() => '已取消下载';
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    required this.currentBuild,
    this.versionInfo,
  });

  final bool hasUpdate;
  final String currentVersion;
  final int currentBuild;
  final AppVersionInfo? versionInfo;
}

class AppUpdateService {
  static const String _versionUrl = 'https://api.onehubai.online/api/v1/app/version/latest';
  static const MethodChannel _installerChannel = MethodChannel('onehubapp/installer');

  /// 建立 TCP 连接的最长等待时间
  static const Duration defaultConnectTimeout = Duration(seconds: 15);
  /// 等待响应头的最长等待时间
  static const Duration defaultResponseTimeout = Duration(seconds: 20);
  /// 两个数据块之间允许的最长间隔，超过即判定为网络卡死
  static const Duration defaultStallTimeout = Duration(seconds: 30);
  /// 唤起系统安装器后等待回调的最长时间
  static const Duration defaultInstallTimeout = Duration(seconds: 20);
  /// 进度回调的最小间隔，避免高频刷新拖慢界面
  static const Duration progressReportInterval = Duration(milliseconds: 200);

  /// 检查是否有新版本
  static Future<AppUpdateCheckResult> checkUpdate() async {
    String currentVersion = '1.0.0';
    int currentBuild = 1;

    try {
      final pkg = await PackageInfo.fromPlatform();
      currentVersion = pkg.version;
      currentBuild = int.tryParse(pkg.buildNumber) ?? 1;
    } catch (e) {
      debugPrint('读取本地版本信息失败，使用默认值: $e');
    }

    try {
      final uri = Uri.parse(_versionUrl).replace(
        queryParameters: {
          'current_build': '$currentBuild',
          'current_version': currentVersion,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final body = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        if (body['code'] == 200 && body['data'] is Map<String, dynamic>) {
          final info = AppVersionInfo.fromJson(body['data'] as Map<String, dynamic>);
          final hasUpdate = info.hasUpdate || info.versionCode > currentBuild;
          return AppUpdateCheckResult(
            hasUpdate: hasUpdate,
            currentVersion: currentVersion,
            currentBuild: currentBuild,
            versionInfo: info,
          );
        }
      }
    } catch (e) {
      debugPrint('在线检测更新失败: $e');
    }

    return AppUpdateCheckResult(
      hasUpdate: false,
      currentVersion: currentVersion,
      currentBuild: currentBuild,
    );
  }

  /// 流式下载 APK 文件，并实时回调进度 (0.0 ~ 1.0)
  ///
  /// [shouldCancel] 返回 true 时立即中断下载并抛出 [DownloadCanceledException]；
  /// 连接、响应头、数据传输任一环节超时都会抛异常，不会无限期挂起；
  /// 失败或取消时会删除未下载完的临时文件，避免残留半个 APK 被误安装。
  /// [responseTimeout]、[stallTimeout] 不传时使用默认值，可在调试或测试中收窄。
  static Future<String?> downloadApk({
    required String downloadUrl,
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
    bool Function()? shouldCancel,
    http.Client? client,
    Duration? responseTimeout,
    Duration? stallTimeout,
  }) async {
    final ownsClient = client == null;
    final httpClient =
        client ?? IOClient(HttpClient()..connectionTimeout = defaultConnectTimeout);
    final headerTimeout = responseTimeout ?? defaultResponseTimeout;
    final dataTimeout = stallTimeout ?? defaultStallTimeout;

    File? targetFile;
    IOSink? sink;
    var completed = false;
    var lastReportAt = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final streamedResponse = await httpClient.send(request).timeout(headerTimeout);

      if (streamedResponse.statusCode != 200) {
        throw Exception('下载请求失败，HTTP 状态码: ${streamedResponse.statusCode}');
      }

      final totalBytes = streamedResponse.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      targetFile = File('${tempDir.path}/onehubapp_update.apk');
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      sink = targetFile.openWrite();
      var receivedBytes = 0;

      await for (final chunk in streamedResponse.stream.timeout(dataTimeout)) {
        if (shouldCancel?.call() ?? false) {
          throw const DownloadCanceledException();
        }

        sink.add(chunk);
        receivedBytes += chunk.length;

        // 按时间间隔上报进度，避免每个数据块都触发一次界面刷新
        final now = DateTime.now();
        final reachedEnd = totalBytes > 0 && receivedBytes >= totalBytes;
        if (reachedEnd || now.difference(lastReportAt) >= progressReportInterval) {
          lastReportAt = now;
          onProgress(
            totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.5,
            receivedBytes,
            totalBytes,
          );
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;
      completed = true;
      onProgress(1.0, receivedBytes, totalBytes);
      return targetFile.path;
    } on DownloadCanceledException {
      debugPrint('APK 下载已取消');
      rethrow;
    } on TimeoutException {
      throw Exception('下载超时（网络过慢或连接已中断），请重试或改用浏览器下载');
    } catch (e) {
      debugPrint('APK 下载异常: $e');
      rethrow;
    } finally {
      if (sink != null) {
        try {
          await sink.close();
        } catch (e) {
          debugPrint('关闭下载文件流失败: $e');
        }
      }
      if (!completed && targetFile != null) {
        try {
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
        } catch (e) {
          debugPrint('清理未完成的 APK 失败: $e');
        }
      }
      if (ownsClient) {
        httpClient.close();
      }
    }
  }

  /// 判断当前设备是否允许本应用安装 APK
  ///
  /// Android 8.0 起即使声明了 REQUEST_INSTALL_PACKAGES，用户仍须手动打开
  /// 「安装未知应用」开关，未授权时安装器会被系统静默拦截、界面看起来像卡死。
  static Future<bool> canInstallApk() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _installerChannel.invokeMethod<bool>('canRequestPackageInstalls') ?? true;
    } catch (e) {
      debugPrint('查询安装权限失败，按已授权处理: $e');
      return true;
    }
  }

  /// 跳转到系统「安装未知应用」授权页面
  static Future<bool> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _installerChannel.invokeMethod<bool>('openInstallPermissionSettings') ?? false;
    } catch (e) {
      debugPrint('打开安装权限设置页失败: $e');
      return false;
    }
  }

  /// 调起安装器安装 APK，若失败则回退到浏览器下载
  static Future<bool> installApk(String filePath, {String? downloadUrl}) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final result = await OpenFilex.open(
          filePath,
          type: 'application/vnd.android.package-archive',
        ).timeout(defaultInstallTimeout);
        if (result.type == ResultType.done) {
          return true;
        }
        debugPrint('OpenFilex 提示: ${result.message}');
      }
    } on TimeoutException {
      // 个别机型不会回调结果，超时不等于失败，交由用户手动确认
      debugPrint('唤起安装器等待超时，可能已在后台弹出安装界面');
      return true;
    } catch (e) {
      debugPrint('调起应用安装器异常: $e');
    }

    // 兜底方案：使用外部浏览器直接打开下载链接
    if (downloadUrl != null && downloadUrl.isNotEmpty) {
      return openInBrowser(downloadUrl);
    }
    return false;
  }

  /// 使用系统浏览器打开下载链接
  static Future<bool> openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      return ok;
    } catch (e) {
      debugPrint('浏览器打开更新链接失败: $e');
      return false;
    }
  }
}
