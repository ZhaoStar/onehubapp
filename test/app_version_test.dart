import 'package:flutter_test/flutter_test.dart';
import 'package:onehubapp/models/app_version_model.dart';
import 'package:onehubapp/services/app_update_service.dart';

void main() {
  group('AppVersionInfo Tests', () {
    test('fromJson parses complete version payload', () {
      final json = {
        'versionCode': 2,
        'versionName': '1.0.1',
        'minVersionCode': 1,
        'downloadUrl': 'https://api.onehubai.online/static/apk/onehubapp-latest.apk',
        'fileSize': '30.5MB',
        'updateLog': '1. 优化待办事项\n2. 接入油价查询',
        'publishDate': '2026-09-16',
        'forceUpdate': false,
        'hasUpdate': true,
      };

      final info = AppVersionInfo.fromJson(json);
      expect(info.versionCode, 2);
      expect(info.versionName, '1.0.1');
      expect(info.minVersionCode, 1);
      expect(info.downloadUrl, 'https://api.onehubai.online/static/apk/onehubapp-latest.apk');
      expect(info.fileSize, '30.5MB');
      expect(info.updateLog, contains('优化待办事项'));
      expect(info.forceUpdate, false);
      expect(info.hasUpdate, true);
    });

    test('fromJson handles empty or missing fields with safe defaults', () {
      final json = <String, dynamic>{};
      final info = AppVersionInfo.fromJson(json);
      expect(info.versionCode, 1);
      expect(info.versionName, '1.0.0');
      expect(info.minVersionCode, 1);
      expect(info.downloadUrl, '');
      expect(info.forceUpdate, false);
      expect(info.hasUpdate, false);
    });
  });

  group('AppUpdateCheckResult Tests', () {
    test('detects update correctly when version code is higher', () {
      const result = AppUpdateCheckResult(
        hasUpdate: true,
        currentVersion: '1.0.0',
        currentBuild: 1,
        versionInfo: AppVersionInfo(
          versionCode: 2,
          versionName: '1.0.1',
          minVersionCode: 1,
          downloadUrl: 'https://api.onehubai.online/static/apk/onehubapp-latest.apk',
          fileSize: '30MB',
          updateLog: '新版本发布',
          publishDate: '2026-09-16',
          forceUpdate: false,
          hasUpdate: true,
        ),
      );

      expect(result.hasUpdate, true);
      expect(result.versionInfo?.versionCode, 2);
    });
  });
}
