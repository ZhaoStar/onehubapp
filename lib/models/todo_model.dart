import 'package:flutter/material.dart';

enum TodoPriority {
  low,
  medium,
  high;

  static TodoPriority fromString(String? val) {
    return switch (val?.toLowerCase()) {
      'high' => TodoPriority.high,
      'low' => TodoPriority.low,
      _ => TodoPriority.medium,
    };
  }

  String toApiString() {
    return name;
  }

  String get label => switch (this) {
        TodoPriority.high => '高优',
        TodoPriority.medium => '普通',
        TodoPriority.low => '低优',
      };

  Color get color => switch (this) {
        TodoPriority.high => const Color(0xFFD13B3B),
        TodoPriority.medium => const Color(0xFFD97706),
        TodoPriority.low => const Color(0xFF16A34A),
      };

  Color get backgroundColor => switch (this) {
        TodoPriority.high => const Color(0xFFFDE8E8),
        TodoPriority.medium => const Color(0xFFFEF3C7),
        TodoPriority.low => const Color(0xFFDCFCE7),
      };
}

class TodoItem {
  const TodoItem({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.dueTime,
    this.remindTime,
    required this.isReminded,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int userId;
  final String title;
  final String? description;
  final TodoPriority priority;
  final String status;
  final DateTime? dueTime;
  final DateTime? remindTime;
  final bool isReminded;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == 'completed';

  bool get isOverdue {
    if (isCompleted || dueTime == null) return false;
    return dueTime!.isBefore(DateTime.now());
  }

  bool get isDueToday {
    if (dueTime == null) return false;
    final now = DateTime.now();
    final d = dueTime!.toLocal();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: TodoPriority.fromString(json['priority'] as String?),
      status: (json['status'] as String?) ?? 'pending',
      dueTime: json['due_time'] != null
          ? DateTime.tryParse(json['due_time'] as String)
          : null,
      remindTime: json['remind_time'] != null
          ? DateTime.tryParse(json['remind_time'] as String)
          : null,
      isReminded: (json['is_reminded'] as bool?) ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'priority': priority.toApiString(),
      'status': status,
      'due_time': dueTime?.toIso8601String(),
      'remind_time': remindTime?.toIso8601String(),
      'is_reminded': isReminded,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TodoItem copyWith({
    int? id,
    int? userId,
    String? title,
    String? description,
    TodoPriority? priority,
    String? status,
    DateTime? dueTime,
    DateTime? remindTime,
    bool? isReminded,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueTime: dueTime ?? this.dueTime,
      remindTime: remindTime ?? this.remindTime,
      isReminded: isReminded ?? this.isReminded,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TodoStats {
  const TodoStats({
    this.total = 0,
    this.pendingCount = 0,
    this.completedCount = 0,
    this.dueTodayCount = 0,
    this.overdueCount = 0,
  });

  final int total;
  final int pendingCount;
  final int completedCount;
  final int dueTodayCount;
  final int overdueCount;

  factory TodoStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TodoStats();
    return TodoStats(
      total: (json['total'] as int?) ?? 0,
      pendingCount: (json['pending_count'] as int?) ?? 0,
      completedCount: (json['completed_count'] as int?) ?? 0,
      dueTodayCount: (json['due_today_count'] as int?) ?? 0,
      overdueCount: (json['overdue_count'] as int?) ?? 0,
    );
  }
}
