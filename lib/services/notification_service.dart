import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onehubapp/core/api_error.dart';
import 'package:onehubapp/core/app_config.dart';
import 'package:onehubapp/core/auth_session.dart';
import 'package:onehubapp/models/notification_model.dart';

class NotificationListResult {
  const NotificationListResult({
    required this.total,
    required this.unreadCount,
    required this.items,
  });

  final int total;
  final int unreadCount;
  final List<AppNotificationItem> items;
}

class NotificationService {
  const NotificationService._();

  static Future<Map<String, String>> _authHeaders() async {
    final session = await AuthSession.restore();
    if (session == null) {
      throw kUnauthorizedException;
    }
    return {
      HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
      HttpHeaders.contentTypeHeader: 'application/json',
      HttpHeaders.acceptHeader: 'application/json',
    };
  }

  static Future<NotificationListResult> listNotifications({
    bool? isRead,
    int skip = 0,
    int limit = 50,
  }) async {
    final headers = await _authHeaders();
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (isRead != null) {
      queryParams['is_read'] = isRead.toString();
    }

    final uri = AppConfig.uri('/api/v1/notifications', queryParams);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == HttpStatus.ok) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final total = (data['total'] as int?) ?? 0;
      final unreadCount = (data['unread_count'] as int?) ?? 0;
      final rawItems = (data['items'] as List<dynamic>?) ?? [];
      final items = rawItems
          .map((e) => AppNotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return NotificationListResult(
        total: total,
        unreadCount: unreadCount,
        items: items,
      );
    }

    throw ApiException(
      describeHttpStatus(response.statusCode),
      statusCode: response.statusCode,
    );
  }

  static Future<int> getUnreadCount() async {
    try {
      final headers = await _authHeaders();
      final uri = AppConfig.uri('/api/v1/notifications/unread-count');
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == HttpStatus.ok) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return (data['unread_count'] as int?) ?? 0;
      }
      debugPrint(
        '[NotificationService] getUnreadCount: HTTP ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('[NotificationService] getUnreadCount failed: $e');
    }
    return 0;
  }

  static Future<List<AppNotificationItem>> pollDueReminders({int limit = 10}) async {
    try {
      final headers = await _authHeaders();
      final uri = AppConfig.uri(
        '/api/v1/notifications/poll-due',
        {'limit': limit.toString()},
      );
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == HttpStatus.ok) {
        final rawItems = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        return rawItems
            .map((e) => AppNotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint(
        '[NotificationService] pollDueReminders: HTTP ${response.statusCode}',
      );
    } catch (e) {
      debugPrint('[NotificationService] pollDueReminders failed: $e');
    }
    return const [];
  }

  static Future<void> markAsRead(int id) async {
    final headers = await _authHeaders();
    final uri = AppConfig.uri('/api/v1/notifications/$id/read');
    final response = await http.patch(uri, headers: headers);

    if (response.statusCode != HttpStatus.ok) {
      throw ApiException(
      describeHttpStatus(response.statusCode),
      statusCode: response.statusCode,
    );
    }
  }

  static Future<void> markAllAsRead() async {
    final headers = await _authHeaders();
    final uri = AppConfig.uri('/api/v1/notifications/read-all');
    final response = await http.post(uri, headers: headers);

    if (response.statusCode != HttpStatus.ok) {
      throw ApiException(
      describeHttpStatus(response.statusCode),
      statusCode: response.statusCode,
    );
    }
  }
}
