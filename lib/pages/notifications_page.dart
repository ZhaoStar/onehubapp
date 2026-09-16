import 'package:flutter/material.dart';
import 'package:onehubapp/core/app_colors.dart';
import 'package:onehubapp/core/app_message.dart';
import 'package:onehubapp/models/notification_model.dart';
import 'package:onehubapp/pages/todo_page.dart';
import 'package:onehubapp/services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({required this.username, super.key});

  final String username;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = false;
  bool? _isReadFilter;
  int _unreadCount = 0;
  List<AppNotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await NotificationService.listNotifications(
        isRead: _isReadFilter,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _unreadCount = res.unreadCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppMessage.show(context, '获取通知失败: $e', type: AppMessageType.error);
    }
  }

  Future<void> _markRead(AppNotificationItem item) async {
    if (item.isRead) return;
    try {
      await NotificationService.markAsRead(item.id);
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((e) => e.id == item.id);
        if (idx != -1) {
          _items[idx] = item.copyWith(isRead: true);
          if (_unreadCount > 0) _unreadCount--;
        }
      });
    } catch (e) {
      if (!mounted) return;
      AppMessage.show(context, '标记已读失败: $e', type: AppMessageType.error);
    }
  }

  Future<void> _markAllRead() async {
    if (_unreadCount == 0) return;
    try {
      await NotificationService.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _items = _items.map((e) => e.copyWith(isRead: true)).toList();
        _unreadCount = 0;
      });
      AppMessage.show(context, '所有通知已标为已读', type: AppMessageType.success);
    } catch (e) {
      if (!mounted) return;
      AppMessage.show(context, '操作失败: $e', type: AppMessageType.error);
    }
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            const Text(
              '通知中心',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount 未读',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('全部已读', style: TextStyle(color: AppColors.primary)),
            ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadNotifications,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                _filterChip('全部', null),
                const SizedBox(width: 8),
                _filterChip('仅未读', false),
                const SizedBox(width: 8),
                _filterChip('已读', true),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: AppColors.primary,
        child: _buildList(),
      ),
    );
  }

  Widget _filterChip(String label, bool? value) {
    final isSelected = _isReadFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.icon,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _isReadFilter = value);
          _loadNotifications();
        }
      },
    );
  }

  Widget _buildList() {
    if (_isLoading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '暂无新通知',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '当待办到达设定提醒时间时，这里将实时收到推送',
                style: TextStyle(fontSize: 13, color: AppColors.placeholder),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _items.length,
      itemBuilder: (ctx, idx) {
        final item = _items[idx];
        return _NotificationCard(
          item: item,
          onTap: () {
            _markRead(item);
            if (item.type == 'todo_reminder') {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TodoPage(username: widget.username),
                ),
              );
            }
          },
          timeStr: _formatTime(item.createdAt),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.timeStr,
  });

  final AppNotificationItem item;
  final VoidCallback onTap;
  final String timeStr;

  @override
  Widget build(BuildContext context) {
    final isUnread = !item.isRead;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUnread ? const Color(0xFFC7D2FE) : const Color(0xFFE5E9F2),
            width: isUnread ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isUnread ? const Color(0xFFEEF2FF) : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.type == 'todo_reminder'
                    ? Icons.alarm_on_rounded
                    : Icons.notifications_rounded,
                color: isUnread ? const Color(0xFF4F46E5) : AppColors.icon,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: isUnread ? AppColors.textSecondary : AppColors.icon,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 11, color: AppColors.placeholder),
                      ),
                      if (item.type == 'todo_reminder')
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '查看待办',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
