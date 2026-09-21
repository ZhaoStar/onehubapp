import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onehubapp/core/api_client.dart';
import 'package:onehubapp/core/api_error.dart';

void main() {
  final requestOptions = RequestOptions(path: '/api/v1/todos');

  Response<dynamic> responseWith(Object? data) =>
      Response<dynamic>(requestOptions: requestOptions, data: data);

  DioException errorOf(DioExceptionType type, {Response<dynamic>? response}) =>
      DioException(requestOptions: requestOptions, type: type, response: response);

  group('readApiMessage', () {
    test('优先取 detail，其次 message', () {
      expect(readApiMessage({'detail': '明细错误'}), '明细错误');
      expect(readApiMessage({'message': '业务提示'}), '业务提示');
      expect(readApiMessage({'detail': '', 'message': '兜底提示'}), '兜底提示');
    });

    test('兼容原始 JSON 字符串，取不到时返回 null', () {
      expect(readApiMessage('{"message":"字符串报文"}'), '字符串报文');
      expect(readApiMessage('不是 JSON'), isNull);
      expect(readApiMessage(''), isNull);
      expect(readApiMessage(null), isNull);
      expect(readApiMessage({'detail': ['字段级错误']}), isNull);
    });
  });

  group('ApiClient.toApiException', () {
    test('各类超时给出统一文案', () {
      for (final type in <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(
          ApiClient.toApiException(errorOf(type)).message,
          '网络连接超时，请检查网络后重试',
        );
      }
    });

    test('断网、取消、证书异常各有对应文案', () {
      expect(
        ApiClient.toApiException(errorOf(DioExceptionType.connectionError)).message,
        '网络连接失败，请检查网络后重试',
      );
      expect(
        ApiClient.toApiException(errorOf(DioExceptionType.cancel)).message,
        '请求已取消',
      );
      expect(
        ApiClient.toApiException(errorOf(DioExceptionType.badCertificate)).message,
        '服务器证书校验失败，请稍后重试',
      );
      expect(
        ApiClient.toApiException(errorOf(DioExceptionType.unknown)).message,
        '网络异常，请稍后重试',
      );
    });

    test('4xx 优先展示服务端文案并保留状态码', () {
      final error = ApiClient.toApiException(
        errorOf(
          DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: requestOptions,
            statusCode: 400,
            data: {'message': '标题不能为空'},
          ),
        ),
      );

      expect(error.message, '标题不能为空');
      expect(error.statusCode, 400);
      // toString 只返回文案，页面拼接后不会露出技术细节
      expect(error.toString(), '标题不能为空');
    });

    test('服务端没有给出文案时回退到状态码文案', () {
      final error = ApiClient.toApiException(
        errorOf(
          DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: requestOptions,
            statusCode: 401,
            data: '',
          ),
        ),
      );

      expect(error.message, describeHttpStatus(401));
      expect(error.statusCode, 401);
    });
  });

  group('ApiClient.asMap / asList', () {
    test('对象与数组都能从 JSON 字符串里解析出来', () {
      expect(ApiClient.asMap(responseWith({'a': 1})), {'a': 1});
      expect(ApiClient.asMap(responseWith('{"a":1}'))['a'], 1);
      expect(ApiClient.asList(responseWith([1, 2])), [1, 2]);
      expect(ApiClient.asList(responseWith('[1,2]')), [1, 2]);
    });

    test('内容不可解析时返回空集合而不是抛异常', () {
      expect(ApiClient.asMap(responseWith('不是 JSON')), isEmpty);
      expect(ApiClient.asMap(responseWith(null)), isEmpty);
      expect(ApiClient.asList(responseWith({'a': 1})), isEmpty);
    });
  });

  group('ApiClient.streamFileForm', () {
    test('普通字段与文件字段一起提交', () {
      final form = ApiClient.streamFileForm(
        field: 'file',
        streamFactory: () => Stream<List<int>>.fromIterable([
          [1, 2, 3],
        ]),
        length: 3,
        filename: 'video.mp4.part0',
        fields: {'chunk_index': '0'},
      );

      expect(form.fields.map((entry) => entry.key), contains('chunk_index'));
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'video.mp4.part0');
      expect(form.files.single.value.length, 3);
    });
  });
}
