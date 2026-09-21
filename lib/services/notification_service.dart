import 'package:flutter/foundation.dart';

import 'package:onehubapp/core/api_client.dart';
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

  static Future<NotificationListResult> listNotifications({
    bool? isRead,
    int skip = 0,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'skip': skip,
      'limit': limit,
    };
    if (isRead != null) {
      queryParams['is_read'] = isRead.toString();
    }

    final response = await ApiClient.request(
      '/api/v1/notifications',
      queryParameters: queryParams,
    );
    final data = ApiClient.asMap(response);
    final rawItems = (data['items'] as List<dynamic>?) ?? const [];

    return NotificationListResult(
      total: (data['total'] as int?) ?? 0,
      unreadCount: (data['unread_count'] as int?) ?? 0,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(AppNotificationItem.fromJson)
          .toList(),
    );
  }

  /// 未读数是角标轮询用的，失败不该打扰用户，因此这里吞掉异常返回 0
  static Future<int> getUnreadCount() async {
    try {
      final response = await ApiClient.request('/api/v1/notifications/unread-count');
      return (ApiClient.asMap(response)['unread_count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[NotificationService] getUnreadCount failed: $e');
      return 0;
    }
  }

  /// 到点提醒同样属于后台轮询，失败返回空列表
  static Future<List<AppNotificationItem>> pollDueReminders({int limit = 10}) async {
    try {
      final response = await ApiClient.request(
        '/api/v1/notifications/poll-due',
        queryParameters: {'limit': limit},
      );
      return ApiClient.asList(response)
          .whereType<Map<String, dynamic>>()
          .map(AppNotificationItem.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[NotificationService] pollDueReminders failed: $e');
      return const [];
    }
  }

  static Future<void> markAsRead(int id) async {
    await ApiClient.request('/api/v1/notifications/$id/read', method: 'PATCH');
  }

  static Future<void> markAllAsRead() async {
    await ApiClient.request('/api/v1/notifications/read-all', method: 'POST');
  }
}
