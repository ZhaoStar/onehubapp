import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:onehubapp/core/api_error.dart';
import 'package:onehubapp/core/app_config.dart';
import 'package:onehubapp/core/auth_session.dart';
import 'package:onehubapp/models/todo_model.dart';

class TodoListResult {
  const TodoListResult({
    required this.total,
    required this.items,
    required this.stats,
  });

  final int total;
  final List<TodoItem> items;
  final TodoStats stats;
}

class TodoService {
  const TodoService._();

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

  static Future<TodoListResult> listTodos({
    String? status,
    String? priority,
    String? search,
    int skip = 0,
    int limit = 50,
  }) async {
    final headers = await _authHeaders();
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (priority != null && priority.isNotEmpty) {
      queryParams['priority'] = priority;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final uri = AppConfig.uri('/api/v1/todos', queryParams);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == HttpStatus.ok) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final total = (data['total'] as int?) ?? 0;
      final rawItems = (data['items'] as List<dynamic>?) ?? [];
      final items = rawItems
          .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final stats = TodoStats.fromJson(data['stats'] as Map<String, dynamic>?);
      return TodoListResult(total: total, items: items, stats: stats);
    }

    throw ApiException(
      describeHttpStatus(response.statusCode),
      statusCode: response.statusCode,
    );
  }

  static Future<TodoStats> getStats() async {
    final headers = await _authHeaders();
    final uri = AppConfig.uri('/api/v1/todos/stats');
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == HttpStatus.ok) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return TodoStats.fromJson(data);
    }

    throw ApiException(
      describeHttpStatus(response.statusCode),
      statusCode: response.statusCode,
    );
  }

  static Future<TodoItem> createTodo({
    required String title,
    String? description,
    TodoPriority priority = TodoPriority.medium,
    DateTime? dueTime,
    DateTime? remindTime,
  }) async {
    final headers = await _authHeaders();
    final uri = AppConfig.uri('/api/v1/todos');
    final body = jsonEncode({
      'title': title,
      'description': description?.isNotEmpty == true ? description : null,
      'priority': priority.toApiString(),
      'due_time': dueTime?.toUtc().toIso8601String(),
      'remind_time': remindTime?.toUtc().toIso8601String(),
    });

    final response = await http.post(uri, headers: headers, body: body);

    if (response.statusCode == HttpStatus.created) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return TodoItem.fromJson(data);
    }

    throw ApiException(
      describeHttpStatus(response.statusCode),
      statusCode: response.statusCode,
    );
  }

  static Future<TodoItem> updateTodo({
    required int id,
    String? title,
    String? description,
    TodoPriority? priority,
    String? status,
    DateTime? dueTime,
    DateTime? remindTime,
    bool clearDueTime = false,
    bool clearRemindTime = false,
  }) async {
    final headers = await _authHeaders();
    final uri = AppConfig.uri('/api/v1/todos/$id');
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (priority != null) payload['priority'] = priority.toApiString();
    if (status != null) payload['status'] = status;
    if (dueTime != null) {
      payload['due_time'] = dueTime.toUtc().toIso8601String();
    } else if (clearDueTime) {
      payload['due_time'] = null;
    }
    if (remindTime != null) {
      payload['remind_time'] = remindTime.toUtc().toIso8601String();
    } else if (clearRemindTime) {
      payload['remind_time'] = null;
    }

    final response = await http.put(uri, headers: headers, body: jsonEncode(payload));

    if (response.statusCode == HttpStatus.ok) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return TodoItem.fromJson(data);
    }

    throw ApiException(
      describeHttpStatus(response.statusCode),
      statusCode: response.statusCode,
    );
  }

  static Future<TodoItem> toggleStatus(int id) async {
    final headers = await _authHeaders();
    final uri = AppConfig.uri('/api/v1/todos/$id/toggle');
    final response = await http.patch(uri, headers: headers);

    if (response.statusCode == HttpStatus.ok) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return TodoItem.fromJson(data);
    }

    throw ApiException(
      describeHttpStatus(response.statusCode),
      statusCode: response.statusCode,
    );
  }

  static Future<void> deleteTodo(int id) async {
    final headers = await _authHeaders();
    final uri = AppConfig.uri('/api/v1/todos/$id');
    final response = await http.delete(uri, headers: headers);

    if (response.statusCode != HttpStatus.noContent && response.statusCode != HttpStatus.ok) {
      throw ApiException(
      describeHttpStatus(response.statusCode),
      statusCode: response.statusCode,
    );
    }
  }

  static Future<int> clearCompletedTodos() async {
    final headers = await _authHeaders();
    final uri = AppConfig.uri('/api/v1/todos/completed/clear');
    final response = await http.delete(uri, headers: headers);

    if (response.statusCode == HttpStatus.ok) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (data['count'] as int?) ?? 0;
    }
    throw ApiException(
      describeHttpStatus(response.statusCode),
      statusCode: response.statusCode,
    );
  }
}

