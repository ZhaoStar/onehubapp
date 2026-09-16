import 'package:flutter_test/flutter_test.dart';
import 'package:onehubapp/models/todo_model.dart';

void main() {
  group('TodoItem DateTime & Logic Tests', () {
    test('TodoItem formatting and state calculations', () {
      final now = DateTime.now();
      final item = TodoItem(
        id: 1,
        userId: 1,
        title: '测试待办',
        description: '详细测试说明',
        priority: TodoPriority.high,
        status: 'pending',
        dueTime: now.add(const Duration(hours: 2)),
        remindTime: now.add(const Duration(minutes: 30)),
        isReminded: false,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now,
      );

      expect(item.isCompleted, isFalse);
      expect(item.isOverdue, isFalse);
      expect(item.isDueToday, isTrue);
      expect(item.priority.label, '高优');
    });

    test('Overdue item correctly identifies overdue state', () {
      final now = DateTime.now();
      final overdueItem = TodoItem(
        id: 2,
        userId: 1,
        title: '逾期待办',
        priority: TodoPriority.medium,
        status: 'pending',
        dueTime: now.subtract(const Duration(hours: 1)),
        isReminded: true,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      );

      expect(overdueItem.isOverdue, isTrue);
    });

    test('Completed item is never overdue even if past due', () {
      final now = DateTime.now();
      final completedItem = TodoItem(
        id: 3,
        userId: 1,
        title: '已完成待办',
        priority: TodoPriority.low,
        status: 'completed',
        dueTime: now.subtract(const Duration(hours: 1)),
        isReminded: true,
        completedAt: now,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
      );

      expect(completedItem.isCompleted, isTrue);
      expect(completedItem.isOverdue, isFalse);
    });
  });
}
