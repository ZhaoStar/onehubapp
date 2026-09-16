/// 接口调用失败。
///
/// [toString] 直接返回可展示的文案，因此页面里的
/// `AppMessage.show(context, '加载失败: $e')` 不会把异常类名、
/// 请求 URI 等技术细节暴露给用户。
///
/// 例：用户看到「加载待办失败: 登录已过期，请重新登录」，
/// 而不是「HttpException: 获取待办列表失败: 401, uri: https://...」。
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  /// 面向用户的提示文案。
  final String message;

  /// 对应的 HTTP 状态码，仅用于日志与排查。
  final int? statusCode;

  @override
  String toString() => message;
}

/// 未登录或登录态已失效。
const ApiException kUnauthorizedException = ApiException(
  '登录已过期，请重新登录',
  statusCode: 401,
);

/// 把 HTTP 状态码翻译成用户能看懂的提示。
String describeHttpStatus(int statusCode) {
  return switch (statusCode) {
    400 => '请求参数有误',
    401 => '登录已过期，请重新登录',
    403 => '没有权限执行该操作',
    404 => '请求的内容不存在',
    409 => '数据有冲突，请刷新后重试',
    422 => '提交的数据格式不正确',
    429 => '操作太频繁，请稍后再试',
    >= 500 => '服务器开小差了，请稍后重试',
    _ => '请求失败（HTTP $statusCode）',
  };
}
