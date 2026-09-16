import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:onehubapp/models/app_version_model.dart';

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
  static Future<String?> downloadApk({
    required String downloadUrl,
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final streamedResponse = await httpClient.send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception('下载请求失败，HTTP 状态码: ${streamedResponse.statusCode}');
      }

      final totalBytes = streamedResponse.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/onehubapp_update.apk';
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int receivedBytes = 0;

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
          onProgress(progress, receivedBytes, totalBytes);
        } else {
          onProgress(0.5, receivedBytes, 0);
        }
      }

      await sink.flush();
      await sink.close();
      onProgress(1.0, receivedBytes, totalBytes);
      return savePath;
    } catch (e) {
      debugPrint('APK 下载异常: $e');
      rethrow;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// 调起安装器安装 APK，若失败则回退到浏览器下载
  static Future<bool> installApk(String filePath, {String? downloadUrl}) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final result = await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
        if (result.type == ResultType.done) {
          return true;
        }
        debugPrint('OpenFilex 提示: ${result.message}');
      }
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
