import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ONEHUB APP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static final Uri _captchaUri = Uri.https(
    'api.onehubai.online',
    '/api/v1/auth/captcha',
  );
  static final Uri _loginUri = Uri.https(
    'api.onehubai.online',
    '/api/v1/auth/login',
  );
  static final Uri _meUri = Uri.https('api.onehubai.online', '/api/v1/auth/me');

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();

  bool _rememberLogin = true;
  bool _obscurePassword = true;
  bool _isBootstrapping = true;
  bool _isCaptchaLoading = false;
  bool _isLoginLoading = false;
  String? _captchaKey;
  Uint8List? _captchaBytes;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    var restored = false;
    try {
      final session = await AuthSession.restore();
      if (session != null) {
        final user = await _fetchMe(session.accessToken);
        await AuthSession.save(session.accessToken, user);
        restored = true;
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => WorkstationPage(username: _displayName(user)),
          ),
        );
        return;
      }
    } catch (_) {
      await AuthSession.clear();
      if (mounted) {
        AppMessage.show(context, '登录状态已过期，请重新登录', type: AppMessageType.warning);
      }
    } finally {
      if (mounted && !restored) {
        setState(() {
          _isBootstrapping = false;
        });
        await _loadCaptcha();
      }
    }
  }

  Future<Map<String, dynamic>> _fetchMe(String accessToken) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(_meUri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $accessToken',
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode == HttpStatus.ok) {
        return jsonDecode(body) as Map<String, dynamic>;
      }
      throw const FormatException('登录状态已过期，请重新登录');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _loadCaptcha({bool clearError = true}) async {
    setState(() {
      _isCaptchaLoading = true;
      if (clearError) {
        _errorText = null;
      }
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(_captchaUri);
      final response = await request.close();
      final captchaKey = response.headers.value('x-captcha-key');

      if (response.statusCode != HttpStatus.ok || captchaKey == null) {
        throw const FormatException('验证码获取失败，请稍后重试');
      }

      final bytes = await consolidateHttpClientResponseBytes(response);
      if (!mounted) return;
      setState(() {
        _captchaKey = captchaKey;
        _captchaBytes = bytes;
        _captchaController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captchaKey = null;
        _captchaBytes = null;
        _errorText = '验证码加载失败，请点击验证码区域重试';
      });
    } finally {
      client.close(force: true);
      if (mounted) {
        setState(() {
          _isCaptchaLoading = false;
        });
      }
    }
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      AppMessage.show(context, '请完整填写登录信息', type: AppMessageType.warning);
      return;
    }
    if (_captchaKey == null) {
      setState(() {
        _errorText = '请先获取验证码';
      });
      AppMessage.show(context, '请先获取验证码', type: AppMessageType.warning);
      return;
    }

    setState(() {
      _isLoginLoading = true;
      _errorText = null;
    });

    final client = HttpClient();
    try {
      final request = await client.postUrl(_loginUri);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
          'captcha_key': _captchaKey,
          'captcha_code': _captchaController.text.trim(),
        }),
      );

      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode == HttpStatus.ok) {
        final payload = jsonDecode(body) as Map<String, dynamic>;
        final token = payload['token'] as Map<String, dynamic>?;
        final accessToken = token?['access_token']?.toString();
        final user = payload['user'] as Map<String, dynamic>?;
        if (accessToken == null || accessToken.isEmpty || user == null) {
          throw const FormatException('登录响应异常，请稍后重试');
        }
        if (_rememberLogin) {
          await AuthSession.save(accessToken, user);
        } else {
          await AuthSession.clear();
        }
        if (!mounted) return;
        AppMessage.show(context, '登录成功，正在进入工作台', type: AppMessageType.success);
        await Future<void>.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => WorkstationPage(username: _displayName(user)),
          ),
        );
        return;
      }

      throw FormatException(_readApiError(body));
    } catch (error) {
      if (!mounted) return;
      final message = error is FormatException ? error.message : '登录失败，请稍后重试';
      setState(() {
        _errorText = message;
      });
      AppMessage.show(context, message, type: AppMessageType.error);
      await _loadCaptcha(clearError: false);
      _captchaController.clear();
    } finally {
      client.close(force: true);
      if (mounted) {
        setState(() {
          _isLoginLoading = false;
        });
      }
    }
  }

  String _readApiError(String body) {
    try {
      final payload = jsonDecode(body);
      final detail = payload is Map<String, dynamic> ? payload['detail'] : null;
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map<String, dynamic> && first['msg'] is String) {
          return first['msg'] as String;
        }
      }
    } catch (_) {
      return '登录失败，请检查账号、密码和验证码';
    }
    return '登录失败，请检查账号、密码和验证码';
  }

  String _displayName(Map<String, dynamic> user) {
    return (user['nickname'] ?? user['username'] ?? 'OneHub 用户').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isBootstrapping
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 720;
                  final padding = compact ? 20.0 : 28.0;
                  final headerGap = compact ? 18.0 : 42.0;
                  final titleGap = compact ? 6.0 : 12.0;
                  final formGap = compact ? 16.0 : 30.0;
                  final fieldGap = compact ? 10.0 : 18.0;
                  final actionGap = compact ? 10.0 : 20.0;
                  final buttonHeight = compact ? 50.0 : 60.0;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: 18,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: SizedBox(
                          height: constraints.maxHeight - 36,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                LoginHeader(compact: compact),
                                SizedBox(height: headerGap),
                                Text(
                                  '欢迎回来',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: compact ? 26 : 32,
                                    height: 1.12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: titleGap),
                                Text(
                                  '请登录您的 OneHub 账号以继续',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: compact ? 14 : 17,
                                    height: 1.25,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                SizedBox(height: formGap),
                                AppTextField(
                                  controller: _usernameController,
                                  label: '用户名',
                                  hintText: '请输入用户名',
                                  icon: Icons.person_outline_rounded,
                                  compact: compact,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '请输入用户名';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: fieldGap),
                                AppTextField(
                                  controller: _passwordController,
                                  label: '密码',
                                  hintText: '请输入登录密码',
                                  icon: Icons.lock_outline_rounded,
                                  compact: compact,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  suffix: IconButton(
                                    tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.icon,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return '请输入登录密码';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: fieldGap),
                                CaptchaInput(
                                  controller: _captchaController,
                                  imageBytes: _captchaBytes,
                                  isLoading: _isCaptchaLoading,
                                  compact: compact,
                                  onRefresh: _loadCaptcha,
                                ),
                                SizedBox(height: actionGap),
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 40,
                                      width: 40,
                                      child: Checkbox(
                                        value: _rememberLogin,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberLogin = value ?? false;
                                          });
                                        },
                                        side: const BorderSide(
                                          color: AppColors.border,
                                          width: 1.4,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '记住登录状态',
                                        style: TextStyle(
                                          fontSize: compact ? 15 : 16,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        AppMessage.show(
                                          context,
                                          '请联系管理员重置密码',
                                          type: AppMessageType.info,
                                        );
                                      },
                                      child: const Text('忘记密码'),
                                    ),
                                  ],
                                ),
                                if (_errorText != null) ...[
                                  SizedBox(height: compact ? 6 : 8),
                                  Text(
                                    _errorText!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                                SizedBox(height: actionGap),
                                SizedBox(
                                  height: buttonHeight,
                                  child: FilledButton.icon(
                                    onPressed: _isLoginLoading
                                        ? null
                                        : _submitLogin,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: AppColors.primary
                                          .withValues(alpha: 0.56),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      elevation: 8,
                                      shadowColor: AppColors.primary.withValues(
                                        alpha: 0.22,
                                      ),
                                    ),
                                    icon: _isLoginLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.6,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            Icons.login_rounded,
                                            size: compact ? 27 : 30,
                                          ),
                                    label: Text(
                                      _isLoginLoading ? '登录中' : '登录',
                                      style: TextStyle(
                                        fontSize: compact ? 18 : 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class LoginHeader extends StatelessWidget {
  const LoginHeader({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OneHubLogo(size: compact ? 46 : 52),
        SizedBox(width: compact ? 12 : 16),
        Expanded(
          child: Text(
            'ONEHUB APP',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        OutlinedButton(
          onPressed: () {
            AppMessage.show(context, '内部工具入口暂未开放', type: AppMessageType.info);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 9 : 12,
            ),
            minimumSize: const Size(48, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: Text(
            '内部工具入口',
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class WorkstationPage extends StatefulWidget {
  const WorkstationPage({required this.username, super.key});

  final String username;

  @override
  State<WorkstationPage> createState() => _WorkstationPageState();
}

class _WorkstationPageState extends State<WorkstationPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const WorkstationTopBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [ServicesSection(onServiceTap: _showPlaceholder)],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: WorkstationBottomNav(
        selectedIndex: _selectedIndex,
        onChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index != 0) {
            _showPlaceholder(['Discovery', 'Messages', 'Profile'][index - 1]);
          }
        },
      ),
    );
  }

  void _showPlaceholder(String feature) {
    if (feature == '视频转MP3') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VideoToMp3Page(username: widget.username),
        ),
      );
      return;
    }
    AppMessage.show(context, '$feature 功能建设中', type: AppMessageType.info);
  }
}

class WorkstationTopBar extends StatelessWidget {
  const WorkstationTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: '菜单',
            onPressed: () {
              AppMessage.show(context, '菜单功能建设中', type: AppMessageType.info);
            },
            icon: const Icon(
              Icons.menu_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'OneHub',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '通知',
            onPressed: () {
              AppMessage.show(context, '暂无新通知', type: AppMessageType.info);
            },
            icon: const Icon(Icons.notifications_none_rounded, size: 28),
          ),
        ],
      ),
    );
  }
}

class ServicesSection extends StatelessWidget {
  const ServicesSection({required this.onServiceTap, super.key});

  final ValueChanged<String> onServiceTap;

  static const _services = [
    ServiceItem(
      title: '视频转MP3',
      subtitle: '快速提取视频音轨，支持批量处理',
      icon: Icons.video_library_outlined,
      color: AppColors.primary,
    ),
    ServiceItem(
      title: '抖音下载',
      subtitle: '无水印视频高速解析与下载工具',
      icon: Icons.download_rounded,
      color: AppColors.success,
    ),
    ServiceItem(
      title: 'AI 配置',
      subtitle: '管理模型参数与 API 访问令牌',
      icon: Icons.smart_toy_outlined,
      color: AppColors.neutralIcon,
    ),
    ServiceItem(
      title: '用户管理',
      subtitle: '权限设置、活动日志与账号审计',
      icon: Icons.manage_accounts_outlined,
      color: AppColors.primary,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '服务列表',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => onServiceTap('全部服务'),
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: _services.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 22,
            crossAxisSpacing: 22,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            final service = _services[index];
            return ServiceCard(
              service: service,
              onTap: () => onServiceTap(service.title),
            );
          },
        ),
      ],
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({required this.service, required this.onTap, super.key});

  final ServiceItem service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: service.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(service.icon, color: service.color, size: 30),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.icon,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                service.title,
                maxLines: 2,
                overflow: TextOverflow.fade,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  service.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkstationBottomNav extends StatelessWidget {
  const WorkstationBottomNav({
    required this.selectedIndex,
    required this.onChanged,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onChanged,
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primary,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          selectedIcon: Icon(
            Icons.home_repair_service_rounded,
            color: Colors.white,
          ),
          icon: Icon(Icons.home_repair_service_outlined),
          label: '主页',
        ),
        NavigationDestination(
          selectedIcon: Icon(Icons.explore_rounded, color: Colors.white),
          icon: Icon(Icons.explore_outlined),
          label: '发现',
        ),
        NavigationDestination(
          selectedIcon: Icon(Icons.message_rounded, color: Colors.white),
          icon: Icon(Icons.message_outlined),
          label: '消息',
        ),
        NavigationDestination(
          selectedIcon: Icon(Icons.person_rounded, color: Colors.white),
          icon: Icon(Icons.person_outline_rounded),
          label: '个人中心',
        ),
      ],
    );
  }
}

class ServiceItem {
  const ServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class VideoToMp3Page extends StatefulWidget {
  const VideoToMp3Page({required this.username, super.key});

  final String username;

  @override
  State<VideoToMp3Page> createState() => _VideoToMp3PageState();
}

class _VideoToMp3PageState extends State<VideoToMp3Page> {
  static final Uri _createTaskUri = Uri.https(
    'api.onehubai.online',
    '/api/v1/convert/',
  );
  static final Uri _tasksUri = Uri.https(
    'api.onehubai.online',
    '/api/v1/convert/tasks',
  );
  static const double _maxFileSize = 500 * 1024 * 1024;

  PlatformFile? _selectedFile;
  bool _isPickingFile = false;
  bool _isSubmitting = false;
  bool _isLoadingTasks = false;
  bool _isClearingHistory = false;
  double _localProgress = 0;
  String? _submitHint;
  List<ConversionTask> _tasks = const [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (_isPickingFile || _isSubmitting) return;
    setState(() {
      _isPickingFile = true;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: false,
        withReadStream: true,
      );

      final file = result != null && result.files.isNotEmpty
          ? result.files.first
          : null;
      if (!mounted || file == null) return;

      if ((file.path ?? '').isEmpty && file.readStream == null) {
        AppMessage.show(
          context,
          '没有读取到视频文件内容，请重新选择',
          type: AppMessageType.error,
        );
        return;
      }
      if (file.size > _maxFileSize) {
        AppMessage.show(
          context,
          '当前仅支持 500MB 以内的视频文件',
          type: AppMessageType.warning,
        );
        return;
      }

      setState(() {
        _selectedFile = file;
        _submitHint = null;
      });
      AppMessage.show(
        context,
        '已选择 ${file.name}',
        type: AppMessageType.success,
      );
    } catch (error, stackTrace) {
      debugPrint('Video picker failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      final message = '$error';
      AppMessage.show(
        context,
        message.length > 90 ? '选择视频失败，请查看控制台日志' : '选择视频失败：$message',
        type: AppMessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  Future<void> _submitConversion() async {
    final file = _selectedFile;
    if (_isSubmitting ||
        file == null ||
        ((file.path ?? '').isEmpty && file.readStream == null)) {
      AppMessage.show(context, '请先选择一个视频文件', type: AppMessageType.warning);
      return;
    }

    final session = await AuthSession.restore();
    if (session == null) {
      if (!mounted) return;
      AppMessage.show(context, '登录状态已失效，请重新登录', type: AppMessageType.warning);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _localProgress = 0.16;
      _submitHint = '正在上传视频并创建转换任务...';
    });

    try {
      final request = http.MultipartRequest('POST', _createTaskUri)
        ..headers[HttpHeaders.authorizationHeader] =
            'Bearer ${session.accessToken}'
        ..fields['bitrate'] = '192k'
        ..fields['sample_rate'] = '44100'
        ..fields['channels'] = '2';

      final multipartFile = file.readStream != null
          ? http.MultipartFile(
              'file',
              file.readStream!,
              file.size,
              filename: file.name,
            )
          : await http.MultipartFile.fromPath(
              'file',
              file.path!,
              filename: file.name,
            );

      request.files.add(multipartFile);

      setState(() {
        _localProgress = 0.52;
      });
      final streamedResponse = await request.send();
      final body = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == HttpStatus.ok) {
        setState(() {
          _localProgress = 1;
          _selectedFile = null;
          _submitHint = '转换任务已创建，后台正在处理';
        });
        if (!mounted) return;
        AppMessage.show(context, '转换任务创建成功', type: AppMessageType.success);
        await _refreshTasks(showLoading: false);
        return;
      }

      throw FormatException(_readApiMessage(body, fallback: '创建转换任务失败，请稍后重试'));
    } catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? error.message
          : '上传失败，请检查网络后重试';
      AppMessage.show(context, message, type: AppMessageType.error);
      setState(() {
        _submitHint = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _localProgress = 0;
        });
      }
    }
  }

  Future<void> _refreshTasks({bool showLoading = true}) async {
    final session = await AuthSession.restore();
    if (session == null) return;

    if (showLoading && mounted) {
      setState(() {
        _isLoadingTasks = true;
      });
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(
        _tasksUri.replace(queryParameters: {'limit': '20', 'skip': '0'}),
      );
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${session.accessToken}',
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode != HttpStatus.ok) {
        throw FormatException(_readApiMessage(body, fallback: '加载转换历史失败'));
      }

      final payload = jsonDecode(body) as Map<String, dynamic>;
      final items = (payload['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ConversionTask.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        _tasks = items;
      });
      _syncPolling(items);
    } catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? error.message
          : '加载转换历史失败，请稍后重试';
      AppMessage.show(context, message, type: AppMessageType.error);
    } finally {
      client.close(force: true);
      if (mounted && showLoading) {
        setState(() {
          _isLoadingTasks = false;
        });
      }
    }
  }

  Future<void> _clearHistory() async {
    if (_isClearingHistory || _tasks.isEmpty) return;
    final session = await AuthSession.restore();
    if (session == null) return;

    setState(() {
      _isClearingHistory = true;
    });

    final client = HttpClient();
    try {
      final request = await client.deleteUrl(_tasksUri);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${session.accessToken}',
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode != HttpStatus.ok) {
        throw FormatException(_readApiMessage(body, fallback: '清空历史失败'));
      }

      if (!mounted) return;
      setState(() {
        _tasks = const [];
      });
      _syncPolling(const []);
      AppMessage.show(context, '转换历史已清空', type: AppMessageType.success);
    } catch (error) {
      if (!mounted) return;
      final message = error is FormatException ? error.message : '清空历史失败，请稍后重试';
      AppMessage.show(context, message, type: AppMessageType.error);
    } finally {
      client.close(force: true);
      if (mounted) {
        setState(() {
          _isClearingHistory = false;
        });
      }
    }
  }

  Future<void> _deleteTask(ConversionTask task) async {
    final session = await AuthSession.restore();
    if (session == null) return;

    final client = HttpClient();
    try {
      final request = await client.deleteUrl(
        Uri.https('api.onehubai.online', '/api/v1/convert/tasks/${task.id}'),
      );
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${session.accessToken}',
      );
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode != HttpStatus.ok) {
        throw FormatException(_readApiMessage(body, fallback: '删除记录失败'));
      }

      if (!mounted) return;
      AppMessage.show(context, '记录已删除', type: AppMessageType.success);
      await _refreshTasks(showLoading: false);
    } catch (error) {
      if (!mounted) return;
      final message = error is FormatException ? error.message : '删除记录失败，请稍后重试';
      AppMessage.show(context, message, type: AppMessageType.error);
    } finally {
      client.close(force: true);
    }
  }

  void _handleTaskAction(String action, ConversionTask task) {
    switch (action) {
      case 'download':
        AppMessage.show(context, '下载功能下一步我可以继续帮你接上', type: AppMessageType.info);
        break;
      case 'delete':
        _deleteTask(task);
        break;
    }
  }

  void _syncPolling(List<ConversionTask> tasks) {
    final hasActiveTask = tasks.any((task) => task.isActive);
    if (!hasActiveTask) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    _pollTimer ??= Timer.periodic(const Duration(seconds: 6), (_) {
      _refreshTasks(showLoading: false);
    });
  }

  String _readApiMessage(String body, {required String fallback}) {
    try {
      final payload = jsonDecode(body);
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        final message = payload['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      return fallback;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final trimmedName = widget.username.trim();
    final avatarText = trimmedName.isEmpty
        ? 'U'
        : trimmedName.substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 88,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '视频转 MP3',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      AppMessage.show(
                        context,
                        '暂无新通知',
                        type: AppMessageType.info,
                      );
                    },
                    icon: const Icon(Icons.notifications_none_rounded),
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      avatarText,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refreshTasks,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                  children: [
                    _VideoPickerPanel(
                      selectedFile: _selectedFile,
                      isBusy: _isPickingFile || _isSubmitting,
                      onTap: _pickVideo,
                    ),
                    if (_submitHint != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _submitHint!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (_isSubmitting) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: _localProgress <= 0 ? null : _localProgress,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 68,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submitConversion,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.56,
                          ),
                          disabledBackgroundColor: AppColors.primary.withValues(
                            alpha: 0.4,
                          ),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.autorenew_rounded, size: 28),
                        label: Text(
                          _isSubmitting ? '正在转换' : '开始转换',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '转换历史',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _isClearingHistory ? null : _clearHistory,
                          child: Text(_isClearingHistory ? '清空中...' : '清空历史'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingTasks)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_tasks.isEmpty)
                      const _EmptyHistoryCard()
                    else
                      ..._tasks.map(
                        (task) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _ConversionTaskCard(
                            task: task,
                            onAction: _handleTaskAction,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPickerPanel extends StatelessWidget {
  const _VideoPickerPanel({
    required this.selectedFile,
    required this.isBusy,
    required this.onTap,
  });

  final PlatformFile? selectedFile;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 1.4),
          ),
          child: Column(
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 56,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '点击选择视频文件',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                selectedFile == null
                    ? '支持 MP4、MOV、AVI、MKV、WEBM 等常用视频格式'
                    : '${selectedFile!.name}\n${ConversionTask.formatBytes(selectedFile!.size)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '最大支持 500MB',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.history_rounded, color: AppColors.primary, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '还没有转换记录，先选择一个视频开始吧',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversionTaskCard extends StatelessWidget {
  const _ConversionTaskCard({required this.task, required this.onAction});

  final ConversionTask task;
  final void Function(String action, ConversionTask task) onAction;

  @override
  Widget build(BuildContext context) {
    final statusColor = task.statusColor;
    final actionIcon = task.isCompleted
        ? Icons.download_rounded
        : task.isFailed
        ? Icons.delete_outline_rounded
        : Icons.close_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              task.isActive
                  ? Icons.autorenew_rounded
                  : task.isCompleted
                  ? Icons.music_note_rounded
                  : Icons.error_outline_rounded,
              color: statusColor,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  task.secondaryLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: task.isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: task.isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                if (task.isActive && task.progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: task.progress! / 100,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.10,
                      ),
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () =>
                onAction(task.isCompleted ? 'download' : 'delete', task),
            icon: Icon(actionIcon, color: statusColor),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => onAction(value, task),
            itemBuilder: (context) => [
              if (task.isCompleted)
                const PopupMenuItem<String>(
                  value: 'download',
                  child: Text('下载 MP3'),
                ),
              const PopupMenuItem<String>(value: 'delete', child: Text('删除记录')),
            ],
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.icon),
          ),
        ],
      ),
    );
  }
}

class ConversionTask {
  const ConversionTask({
    required this.id,
    required this.originalFilename,
    required this.status,
    required this.createdAt,
    required this.fileSize,
    required this.outputFilename,
    required this.outputSize,
    required this.progress,
  });

  factory ConversionTask.fromJson(Map<String, dynamic> json) {
    return ConversionTask(
      id: '${json['id'] ?? ''}',
      originalFilename:
          (json['original_filename'] ?? json['filename'] ?? '未命名文件').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: (json['created_at'] ?? json['updated_at'] ?? '').toString(),
      fileSize: _readInt(
        json['file_size'] ?? json['input_size'] ?? json['source_size'],
      ),
      outputFilename: (json['output_filename'] ?? json['result_filename'] ?? '')
          .toString(),
      outputSize: _readInt(json['output_size'] ?? json['result_size']),
      progress: _readProgress(
        json['progress'] ?? json['percent'] ?? json['progress_percent'],
      ),
    );
  }

  final String id;
  final String originalFilename;
  final String status;
  final String createdAt;
  final int? fileSize;
  final String outputFilename;
  final int? outputSize;
  final double? progress;

  bool get isCompleted {
    final normalized = status.toLowerCase();
    return ['success', 'completed', 'done', 'finished'].contains(normalized);
  }

  bool get isFailed {
    final normalized = status.toLowerCase();
    return ['failed', 'error'].contains(normalized);
  }

  bool get isActive {
    final normalized = status.toLowerCase();
    return [
      'pending',
      'queued',
      'processing',
      'running',
      'converting',
    ].contains(normalized);
  }

  String get displayTitle {
    if (isCompleted && outputFilename.isNotEmpty) return outputFilename;
    return originalFilename;
  }

  String get secondaryLine {
    if (isCompleted) {
      return '${_formatDate(createdAt)} • ${formatBytes(outputSize ?? fileSize ?? 0)}';
    }
    if (isActive) {
      final percentText = progress == null ? '' : '${progress!.round()}% ';
      return '$percentText转换中...';
    }
    return '转换失败，请重新提交';
  }

  Color get statusColor {
    if (isCompleted) return AppColors.primary;
    if (isFailed) return AppColors.error;
    return AppColors.primary;
  }

  static String formatBytes(num value) {
    if (value <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = value.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final digits = size >= 10 || unitIndex == 0 ? 0 : 1;
    return '${size.toStringAsFixed(digits)} ${units[unitIndex]}';
  }

  static String _formatDate(String raw) {
    if (raw.isEmpty) return '刚刚';
    try {
      final parsed = DateTime.parse(raw).toLocal();
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');
      return '${parsed.year}-$month-$day';
    } catch (_) {
      return raw;
    }
  }

  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _readProgress(Object? value) {
    if (value is num) {
      final progress = value.toDouble();
      return progress > 100 ? 100 : progress;
    }
    if (value is String) {
      final progress = double.tryParse(value);
      if (progress == null) return null;
      return progress > 100 ? 100 : progress;
    }
    return null;
  }
}

class OneHubLogo extends StatelessWidget {
  const OneHubLogo({this.size = 56, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: const CustomPaint(painter: OneHubLogoPainter()),
    );
  }
}

class OneHubLogoPainter extends CustomPainter {
  const OneHubLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()..color = Colors.white;
    final center = Offset(size.width / 2, size.height / 2);
    final points = [
      Offset(size.width * 0.22, size.height * 0.32),
      Offset(size.width * 0.28, size.height * 0.72),
      Offset(size.width * 0.74, size.height * 0.26),
      Offset(size.width * 0.78, size.height * 0.62),
    ];

    for (final point in points) {
      canvas.drawLine(center, point, linePaint);
    }
    canvas.drawCircle(center, size.width * 0.1, fillPaint);
    for (final point in points) {
      canvas.drawCircle(point, size.width * 0.095, fillPaint);
      canvas.drawCircle(
        point,
        size.width * 0.04,
        Paint()..color = AppColors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.compact,
    this.obscureText = false,
    this.suffix,
    this.textInputAction,
    this.validator,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final bool compact;
  final bool obscureText;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: compact ? 14 : 15,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        SizedBox(
          height: compact ? 54 : 60,
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            textInputAction: textInputAction,
            validator: validator,
            decoration: AppInputDecoration.field(
              hintText: hintText,
              icon: icon,
              compact: compact,
              suffix: suffix,
            ),
          ),
        ),
      ],
    );
  }
}

class CaptchaInput extends StatelessWidget {
  const CaptchaInput({
    required this.controller,
    required this.imageBytes,
    required this.isLoading,
    required this.compact,
    required this.onRefresh,
    super.key,
  });

  final TextEditingController controller;
  final Uint8List? imageBytes;
  final bool isLoading;
  final bool compact;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final inputHeight = compact ? 54.0 : 60.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '验证码',
          style: TextStyle(
            fontSize: compact ? 14 : 15,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                height: inputHeight,
                child: TextFormField(
                  controller: controller,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入验证码';
                    }
                    return null;
                  },
                  decoration: AppInputDecoration.field(
                    hintText: '验证码',
                    icon: Icons.verified_user_outlined,
                    compact: compact,
                  ),
                ),
              ),
            ),
            SizedBox(width: compact ? 12 : 16),
            SizedBox(
              height: inputHeight,
              width: compact ? 118 : 132,
              child: OutlinedButton(
                onPressed: isLoading ? null : onRefresh,
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.captchaBackground,
                  side: const BorderSide(color: AppColors.border, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : imageBytes == null
                    ? const Icon(Icons.refresh_rounded, color: AppColors.icon)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.memory(
                          imageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          gaplessPlayback: true,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AppInputDecoration {
  const AppInputDecoration._();

  static InputDecoration field({
    required String hintText,
    required IconData icon,
    required bool compact,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: AppColors.placeholder,
        fontSize: compact ? 17 : 19,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: AppColors.icon, size: compact ? 25 : 28),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 18,
        vertical: compact ? 15 : 18,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.8),
      ),
    );
  }
}

class AuthSession {
  const AuthSession._();

  static const _accessTokenKey = 'access_token';
  static const _userKey = 'user';

  static Future<AuthSessionData?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString(_accessTokenKey);
    final rawUser = prefs.getString(_userKey);
    if (accessToken == null || accessToken.isEmpty || rawUser == null) {
      return null;
    }

    try {
      final user = jsonDecode(rawUser) as Map<String, dynamic>;
      return AuthSessionData(accessToken: accessToken, user: user);
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> save(
    String accessToken,
    Map<String, dynamic> user,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_userKey);
  }
}

class AuthSessionData {
  const AuthSessionData({required this.accessToken, required this.user});

  final String accessToken;
  final Map<String, dynamic> user;
}

enum AppMessageType { success, error, warning, info }

class AppMessage {
  const AppMessage._();

  static void show(
    BuildContext context,
    String message, {
    AppMessageType type = AppMessageType.info,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: const Duration(milliseconds: 2200),
        margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        padding: EdgeInsets.zero,
        dismissDirection: DismissDirection.up,
        content: AppMessageView(message: message, type: type),
      ),
    );
  }
}

class AppMessageView extends StatelessWidget {
  const AppMessageView({required this.message, required this.type, super.key});

  final String message;
  final AppMessageType type;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(type);
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: style.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(style.icon, color: style.foreground, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: style.foreground,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _MessageStyle _styleFor(AppMessageType type) {
    return switch (type) {
      AppMessageType.success => const _MessageStyle(
        icon: Icons.check_circle_rounded,
        foreground: Color(0xFF126B35),
        background: Color(0xFFEAF8EF),
        border: Color(0xFFB7E6C6),
      ),
      AppMessageType.error => const _MessageStyle(
        icon: Icons.error_rounded,
        foreground: Color(0xFF9D1E1E),
        background: Color(0xFFFDECEC),
        border: Color(0xFFF4B9B9),
      ),
      AppMessageType.warning => const _MessageStyle(
        icon: Icons.info_rounded,
        foreground: Color(0xFF855500),
        background: Color(0xFFFFF5DE),
        border: Color(0xFFF2D28D),
      ),
      AppMessageType.info => const _MessageStyle(
        icon: Icons.info_rounded,
        foreground: AppColors.primary,
        background: Color(0xFFEAF3FF),
        border: Color(0xFFBBD5F5),
      ),
    };
  }
}

class _MessageStyle {
  const _MessageStyle({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;
}

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0666C8);
  static const Color success = Color(0xFF088A37);
  static const Color neutralIcon = Color(0xFFDDDEE4);
  static const Color background = Color(0xFFFFFAFF);
  static const Color captchaBackground = Color(0xFFF0EEF3);
  static const Color border = Color(0xFFC1C9DC);
  static const Color textPrimary = Color(0xFF1D1D24);
  static const Color textSecondary = Color(0xFF2E3445);
  static const Color placeholder = Color(0xFFA2A9B7);
  static const Color icon = Color(0xFF747C8D);
  static const Color error = Color(0xFFD13B3B);
}
