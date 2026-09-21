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

/// 弹窗所处阶段，避免用单个布尔值表达「下载中 / 已下载 / 安装中」而留下卡死分支
enum _UpdateStage { idle, downloading, downloaded, installing, failed }

class _UpdateDialogState extends State<UpdateDialog> with WidgetsBindingObserver {
  _UpdateStage _stage = _UpdateStage.idle;
  double _progress = 0.0;
  String _statusText = '';
  String _errorText = '';
  String? _apkPath;
  bool _cancelRequested = false;
  bool _installAllowed = true;
  /// 待安装包与本机已安装版本签名不一致，系统必定拒绝覆盖安装
  bool _signatureConflict = false;
  final Stopwatch _downloadWatch = Stopwatch();

  bool get _isDownloading => _stage == _UpdateStage.downloading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshInstallPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 关闭弹窗时中断仍在进行的下载，避免后台残留半个 APK
    _cancelRequested = true;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从「安装未知应用」设置页返回后重新判断权限，用户可直接继续安装
    if (state == AppLifecycleState.resumed) {
      _refreshInstallPermission();
    }
  }

  Future<void> _refreshInstallPermission() async {
    final allowed = await AppUpdateService.canInstallApk();
    if (!mounted || allowed == _installAllowed) return;
    setState(() => _installAllowed = allowed);
  }

  Future<void> _startDownload() async {
    if (_stage == _UpdateStage.downloading) return;

    setState(() {
      _stage = _UpdateStage.downloading;
      _progress = 0.0;
      _errorText = '';
      _statusText = '准备开始下载...';
      _cancelRequested = false;
      _signatureConflict = false;
    });
    _downloadWatch
      ..reset()
      ..start();

    try {
      final apkPath = await AppUpdateService.downloadApk(
        downloadUrl: widget.versionInfo.freshDownloadUrl,
        shouldCancel: () => _cancelRequested,
        onProgress: (progress, received, total) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _statusText = _describeProgress(progress, received, total);
          });
        },
      );

      _downloadWatch.stop();
      if (!mounted || apkPath == null) return;

      // 先比对签名：签名不一致时系统安装器只会报「签名冲突」，直接安装只会白白失败
      final compatible = await AppUpdateService.isSignatureCompatible(apkPath);
      if (!mounted) return;

      setState(() {
        _apkPath = apkPath;
        _stage = _UpdateStage.downloaded;
        _signatureConflict = compatible == false;
        _statusText = _signatureConflict
            ? '安装包已下载完成，但与当前安装版本的签名不一致'
            : '安装包已下载完成';
      });

      if (_signatureConflict) return;

      await _install();
    } on DownloadCanceledException {
      _downloadWatch.stop();
      if (!mounted) return;
      setState(() {
        _stage = _UpdateStage.idle;
        _progress = 0.0;
        _statusText = '';
      });
      AppMessage.show(context, '已取消下载', type: AppMessageType.info);
    } catch (e) {
      _downloadWatch.stop();
      if (!mounted) return;
      setState(() {
        _stage = _UpdateStage.failed;
        _errorText = '$e';
        _statusText = '';
      });
    }
  }

  Future<void> _install() async {
    final apkPath = _apkPath;
    if (apkPath == null) return;

    setState(() {
      _stage = _UpdateStage.installing;
      _statusText = '正在唤起系统安装器...';
    });

    final installed = await AppUpdateService.installApk(
      apkPath,
      downloadUrl: widget.versionInfo.freshDownloadUrl,
    );

    await _refreshInstallPermission();
    if (!mounted) return;

    setState(() {
      _stage = _UpdateStage.downloaded;
      _statusText = installed
          ? '已调起安装界面，请按系统提示完成安装'
          : '未能自动调起安装界面，可点击「手动安装」重试';
    });

    if (!installed) {
      AppMessage.show(context, '未能自动打开安装器，请点击「手动安装」或改用浏览器下载', type: AppMessageType.info);
    }
  }

  void _cancelDownload() {
    setState(() => _cancelRequested = true);
  }

  String _describeProgress(double progress, int received, int total) {
    final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
    final seconds = _downloadWatch.elapsedMilliseconds / 1000;
    final speedMb = seconds > 0 ? received / 1024 / 1024 / seconds : 0.0;
    final speedText = speedMb > 0.05 ? ' · ${speedMb.toStringAsFixed(2)} MB/s' : '';

    if (total > 0) {
      final totMb = (total / (1024 * 1024)).toStringAsFixed(1);
      return '${(progress * 100).toInt()}%  ($recMb / $totMb MB)$speedText';
    }
    return '$recMb MB$speedText';
  }

  void _openInBrowser() {
    AppUpdateService.openInBrowser(widget.versionInfo.freshDownloadUrl);
  }

  bool get _primaryBusy =>
      _stage == _UpdateStage.downloading || _stage == _UpdateStage.installing;

  String get _primaryLabel {
    switch (_stage) {
      case _UpdateStage.downloading:
        return '正在下载...';
      case _UpdateStage.installing:
        return '正在唤起安装...';
      case _UpdateStage.downloaded:
        return '手动安装';
      case _UpdateStage.failed:
        return '重新下载';
      case _UpdateStage.idle:
        return '立即更新';
    }
  }

  VoidCallback? get _primaryAction {
    if (_primaryBusy) return null;
    if (_stage == _UpdateStage.downloaded) return _install;
    return _startDownload;
  }

  /// 下载结果提示条：失败给原因，成功但未授权安装时给出直达设置页的入口
  Widget _buildStatusBanner() {
    final failed = _stage == _UpdateStage.failed;
    final conflict = _signatureConflict && !failed;
    final Color accent;
    final Color background;
    if (failed) {
      accent = const Color(0xFFDC2626);
      background = const Color(0xFFFEF2F2);
    } else if (conflict) {
      accent = const Color(0xFFB45309);
      background = const Color(0xFFFFFBEB);
    } else {
      accent = const Color(0xFF059669);
      background = const Color(0xFFECFDF5);
    }
    final needPermission = !failed && !conflict && _apkPath != null && !_installAllowed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                failed
                    ? Icons.error_outline_rounded
                    : conflict
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  failed ? '下载失败：$_errorText' : _statusText,
                  style: TextStyle(fontSize: 12, height: 1.4, color: accent),
                ),
              ),
            ],
          ),
          if (conflict) ...[
            const SizedBox(height: 6),
            const Text(
              '当前安装的 OneHub 与新安装包使用的签名不同，系统会拒绝覆盖安装。'
              '请先卸载手机上的旧版本（登录数据保存在服务器，重新登录即可恢复），'
              '再重新安装；也可以点击下方「使用浏览器下载安装包」手动安装。',
              style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFFB45309)),
            ),
          ],
          if (needPermission) ...[
            const SizedBox(height: 6),
            const Text(
              '系统尚未允许本应用安装应用，请先开启「安装未知应用」再点击手动安装。',
              style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFFB45309)),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: AppUpdateService.openInstallPermissionSettings,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('去开启', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.versionInfo;

    return PopScope(
      canPop: !info.forceUpdate,
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

              // 下载进度与结果提示区域
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
                    Expanded(
                      child: Text(
                        _statusText,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (_progress > 0)
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else if (_statusText.isNotEmpty || _errorText.isNotEmpty) ...[
                _buildStatusBanner(),
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
                  if (_isDownloading) ...[
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: _cancelDownload,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('取消下载', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 6,
                    child: ElevatedButton(
                      onPressed: _primaryAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _primaryLabel,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              // 任意阶段都保留网页直链下载入口，自动安装失败时仍有退路
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
