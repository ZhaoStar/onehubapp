class AppConfig {
  const AppConfig._();

  static const String apiHost = 'api.onehubai.online';
  static const String apiScheme = 'https';

  static Uri uri(String path, [Map<String, dynamic>? queryParameters]) {
    if (apiScheme == 'https') {
      return Uri.https(apiHost, path, queryParameters);
    }
    return Uri.http(apiHost, path, queryParameters);
  }
}
