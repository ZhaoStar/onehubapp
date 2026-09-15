class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.type,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String title;
  final String content;
  final String type;
  final int? relatedId;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      type: (json['type'] as String?) ?? 'todo_reminder',
      relatedId: json['related_id'] as int?,
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotificationItem copyWith({
    int? id,
    int? userId,
    String? title,
    String? content,
    String? type,
    int? relatedId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
