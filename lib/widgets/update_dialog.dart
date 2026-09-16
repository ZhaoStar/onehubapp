import 'package:flutter/material.dart';
import 'package:onehubapp/core/app_colors.dart';
import 'package:onehubapp/core/app_message.dart';
import 'package:onehubapp/models/app_version_model.dart';
import 'package:onehubapp/services/app_update_service.dart';

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    required this.versionInfo,
    required this.currentVersion,
    super.key,
  });

  final AppVersionInfo versionInfo;
  final String currentVersion;

  /// 静态弹出方法
  static Future<void> show(
    BuildContext context, {
    required AppVersionInfo versionInfo,
    required String currentVersion,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !versionInfo.forceUpdate,
      builder: (_) => UpdateDialog(
        versionInfo: versionInfo,
        currentVersion: currentVersion,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _downloadStatusText = '';
  String? _downloadedApkPath;

  Future<void> _startDownload() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _downloadStatusText = '准备开始下载...';
    });

    try {
      final apkPath = await AppUpdateService.downloadApk(
        downloadUrl: widget.versionInfo.downloadUrl,
        onProgress: (progress, received, total) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            if (total > 0) {
              final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
              final totMb = (total / (1024 * 1024)).toStringAsFixed(1);
              _downloadStatusText = '${(progress * 100).toInt()}%  ($recMb MB / $totMb MB)';
            } else {
              final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
              _downloadStatusText = '$recMb MB';
            }
          });
        },
      );

      if (!mounted) return;

      if (apkPath != null) {
        setState(() {
          _downloadedApkPath = apkPath;
          _downloadStatusText = '下载完成，正在唤起安装...';
        });

        final installed = await AppUpdateService.installApk(
          apkPath,
          downloadUrl: widget.versionInfo.downloadUrl,
        );

        if (!installed && mounted) {
          AppMessage.show(context, '若无法自动调起安装，已为您尝试在浏览器打开下载', type: AppMessageType.info);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadStatusText = '下载失败: $e';
      });
      AppMessage.show(context, '下载更新失败，请稍后重试或使用浏览器下载', type: AppMessageType.error);
    }
  }

  void _openInBrowser() {
    AppUpdateService.openInBrowser(widget.versionInfo.downloadUrl);
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.versionInfo;

    return PopScope(
      canPop: !info.forceUpdate && !_isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 头部图标与标题
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '发现新版本',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Text(
                                'v${info.versionName}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '当前版本: v${widget.currentVersion} · 大小: ${info.fileSize}',
                          style: const TextStyle(fontSize: 12, color: AppColors.placeholder),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 更新日志列表框
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEDF0F7)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.notes_rounded, size: 14, color: Color(0xFF64748B)),
                          SizedBox(width: 6),
                          Text(
                            '更新内容：',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        info.updateLog.isNotEmpty ? info.updateLog : '性能优化与体验改进',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 下载进度展示区域
              if (_isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _downloadStatusText,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    if (_progress > 0)
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 底部操作按钮
              Row(
                children: [
                  if (!info.forceUpdate && !_isDownloading) ...[
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('稍后提醒', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 6,
                    child: ElevatedButton(
                      onPressed: _isDownloading
                          ? (_downloadedApkPath != null
                              ? () => AppUpdateService.installApk(_downloadedApkPath!, downloadUrl: info.downloadUrl)
                              : null)
                          : _startDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _isDownloading
                            ? (_downloadedApkPath != null ? '安装升级包' : '正在下载...')
                            : '立即更新',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              // 如果遇到异常，提供网页直链下载选项
              if (!_isDownloading) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: _openInBrowser,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      '使用浏览器下载安装包',
                      style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
