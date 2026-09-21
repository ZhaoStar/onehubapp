class AppVersionInfo {
  const AppVersionInfo({
    required this.versionCode,
    required this.versionName,
    required this.minVersionCode,
    required this.downloadUrl,
    required this.fileSize,
    required this.updateLog,
    required this.publishDate,
    required this.forceUpdate,
    required this.hasUpdate,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 1,
      versionName: (json['versionName'] ?? '1.0.0').toString(),
      minVersionCode: (json['minVersionCode'] as num?)?.toInt() ?? 1,
      downloadUrl: (json['downloadUrl'] ?? '').toString(),
      fileSize: (json['fileSize'] ?? '').toString(),
      updateLog: (json['updateLog'] ?? '').toString(),
      publishDate: (json['publishDate'] ?? '').toString(),
      forceUpdate: json['forceUpdate'] == true,
      hasUpdate: json['hasUpdate'] == true,
    );
  }

  final int versionCode;
  final String versionName;
  final int minVersionCode;
  final String downloadUrl;
  final String fileSize;
  final String updateLog;
  final String publishDate;
  final bool forceUpdate;
  final bool hasUpdate;

  /// 带版本号的下载地址
  ///
  /// 线上静态 APK 走 Cloudflare 缓存（Cache-Control 4 小时），地址不变时
  /// 刚发布的新版本仍会下载到旧安装包，因此追加版本号作为缓存击穿参数。
  String get freshDownloadUrl {
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null || uri.host.isEmpty) return downloadUrl;
    return uri
        .replace(queryParameters: {...uri.queryParameters, 'v': '$versionCode'})
        .toString();
  }
}
