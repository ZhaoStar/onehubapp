import 'package:onehubapp/core/api_client.dart';
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

  static Future<TodoListResult> listTodos({
    String? status,
    String? priority,
    String? search,
    int skip = 0,
    int limit = 50,
  }) async {
    final queryParams = <String, dynamic>{
      'skip': skip,
      'limit': limit,
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

    final response = await ApiClient.request(
      '/api/v1/todos',
      queryParameters: queryParams,
    );
    final data = ApiClient.asMap(response);
    final rawItems = (data['items'] as List<dynamic>?) ?? const [];

    return TodoListResult(
      total: (data['total'] as int?) ?? 0,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(TodoItem.fromJson)
          .toList(),
      stats: TodoStats.fromJson(data['stats'] as Map<String, dynamic>?),
    );
  }

  static Future<TodoStats> getStats() async {
    final response = await ApiClient.request('/api/v1/todos/stats');
    return TodoStats.fromJson(ApiClient.asMap(response));
  }

  static Future<TodoItem> createTodo({
    required String title,
    String? description,
    TodoPriority priority = TodoPriority.medium,
    DateTime? dueTime,
    DateTime? remindTime,
  }) async {
    final response = await ApiClient.request(
      '/api/v1/todos',
      method: 'POST',
      data: {
        'title': title,
        'description': description?.isNotEmpty == true ? description : null,
        'priority': priority.toApiString(),
        'due_time': dueTime?.toUtc().toIso8601String(),
        'remind_time': remindTime?.toUtc().toIso8601String(),
      },
    );
    return TodoItem.fromJson(ApiClient.asMap(response));
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

    final response = await ApiClient.request(
      '/api/v1/todos/$id',
      method: 'PUT',
      data: payload,
    );
    return TodoItem.fromJson(ApiClient.asMap(response));
  }

  static Future<TodoItem> toggleStatus(int id) async {
    final response = await ApiClient.request(
      '/api/v1/todos/$id/toggle',
      method: 'PATCH',
    );
    return TodoItem.fromJson(ApiClient.asMap(response));
  }

  static Future<void> deleteTodo(int id) async {
    await ApiClient.request('/api/v1/todos/$id', method: 'DELETE');
  }

  static Future<int> clearCompletedTodos() async {
    final response = await ApiClient.request(
      '/api/v1/todos/completed/clear',
      method: 'DELETE',
    );
    return (ApiClient.asMap(response)['count'] as int?) ?? 0;
  }
}
