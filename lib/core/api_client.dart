import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:onehubapp/core/api_error.dart';
import 'package:onehubapp/core/app_config.dart';
import 'package:onehubapp/core/auth_session.dart';

/// 全局统一的 HTTP 客户端。
///
/// 集中处理四件事，省掉每个页面各写一遍的样板代码：
/// 1. baseUrl 与连接 / 读写超时；
/// 2. 自动附带登录令牌；
/// 3. 把网络层异常翻译成可直接展示的 [ApiException]；
/// 4. 解析服务端返回的错误文案。
class ApiClient {
  const ApiClient._();

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  static Dio? _dio;

  /// 全局实例（惰性创建）
  static Dio get dio => _dio ??= _createDio();

  /// 仅测试使用：替换全局实例
  @visibleForTesting
  static set dio(Dio value) => _dio = value;

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: '${AppConfig.apiScheme}://${AppConfig.apiHost}',
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: sendTimeout,
        responseType: ResponseType.json,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = await AuthSession.restore();
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          handler.next(options);
        },
      ),
    );

    return dio;
  }

  /// 统一请求入口。
  ///
  /// 非 2xx、超时、断网等情况都会抛出 [ApiException]，
  /// 页面直接 `AppMessage.show(context, '操作失败: $e')` 即可，不会露出技术细节。
  static Future<Response<dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? queryParameters,
    Object? data,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await dio.request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        options: (options ?? Options()).copyWith(method: method),
      );
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// 把服务端返回体规整成 JSON 对象。
  ///
  /// 服务端未声明 `application/json` 时 dio 会给出字符串，
  /// 这里统一兜住，避免每个调用点各写一次类型判断。
  static Map<String, dynamic> asMap(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (error) {
        debugPrint('解析响应内容失败: $error');
      }
    }
    return const <String, dynamic>{};
  }

  /// 把服务端返回体规整成 JSON 数组。
  static List<dynamic> asList(Response<dynamic> response) {
    final data = response.data;
    if (data is List) return data;
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is List) return decoded;
      } catch (error) {
        debugPrint('解析响应内容失败: $error');
      }
    }
    return const <dynamic>[];
  }

  /// 构造「单个文件 + 若干普通字段」的流式表单，用于分片上传这类场景。
  ///
  /// 直接把数据流交给 dio，不必先把整个分片读进内存；
  /// [streamFactory] 用工厂而不是现成实例，是为了让 dio 在重试时能重新打开一次数据源。
  static FormData streamFileForm({
    required String field,
    required Stream<List<int>> Function() streamFactory,
    required int length,
    required String filename,
    Map<String, dynamic>? fields,
  }) {
    return FormData.fromMap({
      ...?fields,
      field: MultipartFile.fromStream(streamFactory, length, filename: filename),
    });
  }

  /// 把 Dio 的异常翻译成带友好文案的 [ApiException]
  static ApiException toApiException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException('网络连接超时，请检查网络后重试');
      case DioExceptionType.connectionError:
        return const ApiException('网络连接失败，请检查网络后重试');
      case DioExceptionType.cancel:
        return const ApiException('请求已取消');
      case DioExceptionType.badCertificate:
        return const ApiException('服务器证书校验失败，请稍后重试');
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        return ApiException(
          readApiMessage(error.response?.data) ?? describeHttpStatus(statusCode),
          statusCode: statusCode,
        );
      case DioExceptionType.unknown:
        return const ApiException('网络异常，请稍后重试');
    }
  }
}
