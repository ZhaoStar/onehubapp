import 'package:flutter_test/flutter_test.dart';
import 'package:onehubapp/core/api_error.dart';

void main() {
  group('describeHttpStatus', () {
    test('401 提示重新登录', () {
      expect(describeHttpStatus(401), '登录已过期，请重新登录');
    });

    test('403 提示无权限', () {
      expect(describeHttpStatus(403), '没有权限执行该操作');
    });

    test('404 提示内容不存在', () {
      expect(describeHttpStatus(404), '请求的内容不存在');
    });

    test('5xx 统一提示服务器异常', () {
      expect(describeHttpStatus(500), '服务器开小差了，请稍后重试');
      expect(describeHttpStatus(502), '服务器开小差了，请稍后重试');
      expect(describeHttpStatus(503), '服务器开小差了，请稍后重试');
    });

    test('未覆盖的状态码回退到通用文案并带上码值', () {
      expect(describeHttpStatus(418), '请求失败（HTTP 418）');
    });
  });

  group('ApiException', () {
    test('toString 只返回文案，不暴露类名与 URI', () {
      const e = ApiException('登录已过期，请重新登录', statusCode: 401);
      expect(e.toString(), '登录已过期，请重新登录');
      expect(e.toString().contains('Exception'), isFalse);
      expect(e.toString().contains('uri'), isFalse);
    });

    test('页面拼接后的最终文案可读', () {
      const e = ApiException('登录已过期，请重新登录', statusCode: 401);
      expect('加载待办失败: $e', '加载待办失败: 登录已过期，请重新登录');
    });

    test('保留状态码供日志排查', () {
      const e = ApiException('请求失败', statusCode: 500);
      expect(e.statusCode, 500);
    });

    test('kUnauthorizedException 为 401', () {
      expect(kUnauthorizedException.statusCode, 401);
      expect(kUnauthorizedException.toString(), '登录已过期，请重新登录');
    });
  });
}
