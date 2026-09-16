import 'package:flutter_test/flutter_test.dart';
import 'package:onehubapp/models/notification_model.dart';
import 'package:onehubapp/models/todo_model.dart';

void main() {
  final baseTodoJson = <String, dynamic>{
    'id': 1,
    'user_id': 7,
    'title': '写周报',
    'description': '本周进展',
    'priority': 'high',
    'status': 'pending',
    'due_time': '2026-09-20T10:00:00.000Z',
    'remind_time': '2026-09-20T09:00:00.000Z',
    'is_reminded': true,
    'completed_at': null,
    'created_at': '2026-09-15T08:00:00.000Z',
    'updated_at': '2026-09-15T09:00:00.000Z',
  };

  group('TodoPriority', () {
    test('fromString 大小写不敏感', () {
      expect(TodoPriority.fromString('high'), TodoPriority.high);
      expect(TodoPriority.fromString('HIGH'), TodoPriority.high);
      expect(TodoPriority.fromString('Low'), TodoPriority.low);
      expect(TodoPriority.fromString('medium'), TodoPriority.medium);
    });

    test('fromString 对未知值与 null 回退到 medium', () {
      expect(TodoPriority.fromString('urgent'), TodoPriority.medium);
      expect(TodoPriority.fromString(null), TodoPriority.medium);
      expect(TodoPriority.fromString(''), TodoPriority.medium);
    });

    test('toApiString 与后端字段一致', () {
      expect(TodoPriority.high.toApiString(), 'high');
      expect(TodoPriority.medium.toApiString(), 'medium');
      expect(TodoPriority.low.toApiString(), 'low');
    });

    test('label 为中文展示文案', () {
      expect(TodoPriority.high.label, '高优');
      expect(TodoPriority.medium.label, '普通');
      expect(TodoPriority.low.label, '低优');
    });
  });

  group('TodoItem.fromJson', () {
    test('完整字段解析', () {
      final item = TodoItem.fromJson(baseTodoJson);
      expect(item.id, 1);
      expect(item.userId, 7);
      expect(item.title, '写周报');
      expect(item.description, '本周进展');
      expect(item.priority, TodoPriority.high);
      expect(item.status, 'pending');
      expect(item.isReminded, isTrue);
      expect(item.dueTime, isNotNull);
      expect(item.remindTime, isNotNull);
      expect(item.completedAt, isNull);
      expect(item.isCompleted, isFalse);
    });

    test('可选字段缺失时不抛异常', () {
      final item = TodoItem.fromJson(<String, dynamic>{
        'id': 2,
        'user_id': 7,
        'title': '仅必填字段',
        'created_at': '2026-09-15T08:00:00.000Z',
        'updated_at': '2026-09-15T08:00:00.000Z',
      });
      expect(item.description, isNull);
      expect(item.priority, TodoPriority.medium);
      expect(item.status, 'pending');
      expect(item.dueTime, isNull);
      expect(item.remindTime, isNull);
      expect(item.isReminded, isFalse);
      expect(item.completedAt, isNull);
    });

    test('toJson 往返后关键字段保持一致', () {
      final item = TodoItem.fromJson(baseTodoJson);
      final restored = TodoItem.fromJson(item.toJson());
      expect(restored.id, item.id);
      expect(restored.userId, item.userId);
      expect(restored.title, item.title);
      expect(restored.priority, item.priority);
      expect(restored.status, item.status);
      expect(restored.isReminded, item.isReminded);
      expect(restored.dueTime, item.dueTime);
    });
  });

  group('TodoItem 派生属性', () {
    TodoItem build({String status = 'pending', String? dueTime}) {
      return TodoItem.fromJson(<String, dynamic>{
        'id': 1,
        'user_id': 1,
        'title': 't',
        'status': status,
        'due_time': dueTime,
        'created_at': '2026-09-15T08:00:00.000Z',
        'updated_at': '2026-09-15T08:00:00.000Z',
      });
    }

    test('isCompleted 只在 status 为 completed 时为真', () {
      expect(build(status: 'completed').isCompleted, isTrue);
      expect(build(status: 'pending').isCompleted, isFalse);
    });

    test('isOverdue 对已完成的待办恒为假', () {
      final past = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      expect(build(status: 'completed', dueTime: past).isOverdue, isFalse);
    });

    test('isOverdue 对无截止时间的待办恒为假', () {
      expect(build().isOverdue, isFalse);
    });

    test('isOverdue 对已过期未完成的待办为真', () {
      final past = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      expect(build(dueTime: past).isOverdue, isTrue);
    });

    test('isOverdue 对未来时间为假', () {
      final future = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String();
      expect(build(dueTime: future).isOverdue, isFalse);
    });

    test('isDueToday 只认当天', () {
      final today = DateTime.now().toIso8601String();
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      expect(build(dueTime: today).isDueToday, isTrue);
      expect(build(dueTime: yesterday).isDueToday, isFalse);
      expect(build().isDueToday, isFalse);
    });

    test('copyWith 只覆盖传入的字段', () {
      final item = build(status: 'pending');
      final updated = item.copyWith(title: '新标题', status: 'completed');
      expect(updated.title, '新标题');
      expect(updated.status, 'completed');
      expect(updated.id, item.id);
      expect(updated.userId, item.userId);
      expect(updated.createdAt, item.createdAt);
    });
  });

  group('TodoStats.fromJson', () {
    test('传入 null 返回全零默认值', () {
      final stats = TodoStats.fromJson(null);
      expect(stats.total, 0);
      expect(stats.pendingCount, 0);
      expect(stats.completedCount, 0);
      expect(stats.dueTodayCount, 0);
      expect(stats.overdueCount, 0);
    });

    test('字段缺失时逐项回退到 0', () {
      final stats = TodoStats.fromJson(<String, dynamic>{'total': 5});
      expect(stats.total, 5);
      expect(stats.pendingCount, 0);
      expect(stats.completedCount, 0);
    });

    test('完整字段解析', () {
      final stats = TodoStats.fromJson(<String, dynamic>{
        'total': 10,
        'pending_count': 6,
        'completed_count': 4,
        'due_today_count': 2,
        'overdue_count': 1,
      });
      expect(stats.total, 10);
      expect(stats.pendingCount, 6);
      expect(stats.completedCount, 4);
      expect(stats.dueTodayCount, 2);
      expect(stats.overdueCount, 1);
    });
  });

  group('AppNotificationItem.fromJson', () {
    test('完整字段解析', () {
      final item = AppNotificationItem.fromJson(<String, dynamic>{
        'id': 3,
        'user_id': 1,
        'title': '待办到期',
        'content': '记得写周报',
        'type': 'todo_reminder',
        'related_id': 42,
        'is_read': true,
        'created_at': '2026-09-16T01:00:00.000Z',
      });
      expect(item.id, 3);
      expect(item.userId, 1);
      expect(item.title, '待办到期');
      expect(item.content, '记得写周报');
      expect(item.type, 'todo_reminder');
      expect(item.relatedId, 42);
      expect(item.isRead, isTrue);
    });

    test('可选字段缺失时回退到默认值', () {
      final item = AppNotificationItem.fromJson(<String, dynamic>{
        'id': 4,
        'user_id': 1,
        'title': 't',
        'content': 'c',
        'created_at': '2026-09-16T01:00:00.000Z',
      });
      expect(item.type, 'todo_reminder');
      expect(item.relatedId, isNull);
      expect(item.isRead, isFalse);
    });

    test('copyWith 可单独标记已读', () {
      final item = AppNotificationItem.fromJson(<String, dynamic>{
        'id': 5,
        'user_id': 1,
        'title': 't',
        'content': 'c',
        'created_at': '2026-09-16T01:00:00.000Z',
      });
      expect(item.isRead, isFalse);
      expect(item.copyWith(isRead: true).isRead, isTrue);
      expect(item.copyWith(isRead: true).id, item.id);
    });
  });
}
