import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:onehubapp/services/app_update_service.dart';

/// 用可控的数据流替代真实网络，便于验证取消、超时与临时文件清理
class _FakeClient extends http.BaseClient {
  _FakeClient(this.onSend);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) onSend;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => onSend(request);
}

const String _downloadUrl = 'https://api.onehubai.online/static/apk/onehubapp-latest.apk';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late String apkPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('onehubapp_update_test');
    apkPath = '${tempDir.path}/onehubapp_update.apk';
    // getTemporaryDirectory 依赖平台通道，测试中指向临时目录
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getTemporaryDirectory' ? tempDir.path : null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('下载成功时写完整文件并把进度回调推到 100%', () async {
    final chunks = List<List<int>>.generate(4, (i) => List<int>.filled(1024, i));
    final progress = <double>[];
    final client = _FakeClient(
      (_) async => http.StreamedResponse(Stream.fromIterable(chunks), 200, contentLength: 4096),
    );

    final path = await AppUpdateService.downloadApk(
      downloadUrl: _downloadUrl,
      client: client,
      onProgress: (value, _, _) => progress.add(value),
    );

    expect(path, apkPath);
    final file = File(path!);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), 4096);
    expect(progress.last, 1.0);
  });

  test('取消下载时抛 DownloadCanceledException 且不残留半截 APK', () async {
    final controller = StreamController<List<int>>();
    var cancelled = false;
    final client = _FakeClient(
      (_) async => http.StreamedResponse(controller.stream, 200, contentLength: 4096),
    );

    final future = AppUpdateService.downloadApk(
      downloadUrl: _downloadUrl,
      client: client,
      shouldCancel: () => cancelled,
      onProgress: (_, _, _) {},
    );

    controller.add(List<int>.filled(1024, 0));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    cancelled = true;
    controller.add(List<int>.filled(1024, 1));

    await expectLater(future, throwsA(isA<DownloadCanceledException>()));
    await controller.close();
    expect(File(apkPath).existsSync(), isFalse);
  });

  test('传输中断时报错并清理已写入的临时文件', () async {
    final controller = StreamController<List<int>>();
    final client = _FakeClient(
      (_) async => http.StreamedResponse(controller.stream, 200, contentLength: 4096),
    );

    final future = AppUpdateService.downloadApk(
      downloadUrl: _downloadUrl,
      client: client,
      onProgress: (_, _, _) {},
    );

    controller.add(List<int>.filled(1024, 0));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    controller.addError(const SocketException('连接被重置'));
    await controller.close();

    await expectLater(future, throwsA(isA<SocketException>()));
    expect(File(apkPath).existsSync(), isFalse);
  });

  test('服务端迟迟不返回响应头时按超时报错，不再无限等待', () async {
    final client = _FakeClient((_) => Completer<http.StreamedResponse>().future);

    await expectLater(
      AppUpdateService.downloadApk(
        downloadUrl: _downloadUrl,
        client: client,
        responseTimeout: const Duration(milliseconds: 50),
        onProgress: (_, _, _) {},
      ),
      throwsA(predicate((Object? e) => e.toString().contains('下载超时'))),
    );
  });

  test('传输中途卡住时按超时报错并清理临时文件', () async {
    final controller = StreamController<List<int>>();
    final client = _FakeClient(
      (_) async => http.StreamedResponse(controller.stream, 200, contentLength: 4096),
    );

    final future = AppUpdateService.downloadApk(
      downloadUrl: _downloadUrl,
      client: client,
      stallTimeout: const Duration(milliseconds: 50),
      onProgress: (_, _, _) {},
    );

    controller.add(List<int>.filled(1024, 0));

    await expectLater(
      future,
      throwsA(predicate((Object? e) => e.toString().contains('下载超时'))),
    );
    await controller.close();
    expect(File(apkPath).existsSync(), isFalse);
  });

  test('服务端返回非 200 时直接报错', () async {
    final client = _FakeClient(
      (_) async => http.StreamedResponse(const Stream<List<int>>.empty(), 404, contentLength: 0),
    );

    await expectLater(
      AppUpdateService.downloadApk(
        downloadUrl: _downloadUrl,
        client: client,
        onProgress: (_, _, _) {},
      ),
      throwsA(predicate((Object? e) => e.toString().contains('404'))),
    );
  });

  test('非 Android 平台默认按已授权安装处理', () async {
    expect(await AppUpdateService.canInstallApk(), isTrue);
    expect(await AppUpdateService.openInstallPermissionSettings(), isFalse);
  });
}