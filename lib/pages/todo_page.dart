import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onehubapp/core/app_colors.dart';
import 'package:onehubapp/core/app_message.dart';
import 'package:onehubapp/models/todo_model.dart';
import 'package:onehubapp/services/todo_service.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({required this.username, super.key});

  final String username;

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  List<TodoItem> _items = const [];
  TodoStats _stats = const TodoStats();
  String _searchQuery = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadData();
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? get _currentStatusFilter {
    return switch (_tabController.index) {
      1 => 'pending',
      2 => 'completed',
      _ => null,
    };
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await TodoService.listTodos(
        status: _currentStatusFilter,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _stats = res.stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      AppMessage.show(context, '加载待办失败: $e', type: AppMessageType.error);
    }
  }

  Future<void> _toggleStatus(TodoItem item) async {
    try {
      final updated = await TodoService.toggleStatus(item.id);
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((e) => e.id == item.id);
        if (idx != -1) {
          if (_currentStatusFilter != null && _currentStatusFilter != updated.status) {
            _items.removeAt(idx);
          } else {
            _items[idx] = updated;
          }
        }
      });
      _refreshStatsOnly();
      AppMessage.show(
        context,
        updated.isCompleted ? '已完成待办「${item.title}」' : '已重置待办为进行中',
        type: AppMessageType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppMessage.show(context, '操作失败: $e', type: AppMessageType.error);
    }
  }

  Future<void> _refreshStatsOnly() async {
    try {
      final stats = await TodoService.getStats();
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (_) {}
  }

  Future<void> _deleteTodo(TodoItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除待办', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('确定要删除待办「${item.title}」吗？删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await TodoService.deleteTodo(item.id);
      if (!mounted) return;
      setState(() {
        _items.removeWhere((e) => e.id == item.id);
      });
      _refreshStatsOnly();
      AppMessage.show(context, '待办已删除', type: AppMessageType.info);
    } catch (e) {
      if (!mounted) return;
      AppMessage.show(context, '删除失败: $e', type: AppMessageType.error);
    }
  }

  Future<void> _clearCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('清空已完成待办', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('确定要清空所有 ${_stats.completedCount} 条已完成的待办事项吗？清空后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('一键清空'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final count = await TodoService.clearCompletedTodos();
      _loadData();
      if (!mounted) return;
      AppMessage.show(context, '已清空 $count 条已完成待办', type: AppMessageType.info);
    } catch (e) {
      if (!mounted) return;
      AppMessage.show(context, '清空失败: $e', type: AppMessageType.error);
    }
  }


  void _openAddOrEditModal([TodoItem? item]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TodoEditSheet(
        item: item,
        onSaved: () => _loadData(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          '待办事项',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_stats.completedCount > 0)
            TextButton.icon(
              onPressed: _clearCompleted,
              icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: AppColors.error),
              label: Text('清空已完成 (${_stats.completedCount})', style: const TextStyle(color: AppColors.error, fontSize: 13)),
            ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(106),
          child: Column(
            children: [
              _buildStatsBar(),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.placeholder,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: [
                  Tab(text: '全部 (${_stats.total})'),
                  Tab(text: '待完成 (${_stats.pendingCount})'),
                  Tab(text: '已完成 (${_stats.completedCount})'),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 4,
        onPressed: () => _openAddOrEditModal(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          '新建待办',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatPill('进行中', _stats.pendingCount, AppColors.primary),
          _buildStatDivider(),
          _buildStatPill('今日截止', _stats.dueTodayCount, const Color(0xFFD97706)),
          _buildStatDivider(),
          _buildStatPill('已超时', _stats.overdueCount, AppColors.error),
          _buildStatDivider(),
          _buildStatPill('已完成', _stats.completedCount, AppColors.success),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 20, color: const Color(0xFFD8DEE9));
  }

  Widget _buildStatPill(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.icon,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索待办事项...',
          hintStyle: const TextStyle(color: AppColors.placeholder, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.placeholder, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _loadData();
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF6F8FB),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (val) {
          setState(() => _searchQuery = val.trim());
          _loadData();
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              '加载失败，请检查网络或后端服务',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
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
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  size: 46,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '暂无待办事项',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '点击右下方按钮即可新建待办，设定提醒时间',
                style: TextStyle(fontSize: 13, color: AppColors.placeholder),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => _openAddOrEditModal(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('创建第一条待办'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _TodoCard(
          item: item,
          onToggle: () => _toggleStatus(item),
          onEdit: () => _openAddOrEditModal(item),
          onDelete: () => _deleteTodo(item),
        );
      },
    );
  }
}

class _TodoCard extends StatelessWidget {
  const _TodoCard({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final TodoItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final now = DateTime.now();

    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return '今天 $h:$min';
    }
    if (local.year == now.year) {
      return '$m-$d $h:$min';
    }
    return '$y-$m-$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final isDone = item.isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? Colors.grey.shade200 : const Color(0xFFE5E9F2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(top: 2, right: 12),
                    decoration: BoxDecoration(
                      color: isDone ? AppColors.success : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDone ? AppColors.success : const Color(0xFFB0B7C6),
                        width: 2,
                      ),
                    ),
                    child: isDone
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDone ? AppColors.placeholder : AppColors.textPrimary,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (item.description != null && item.description!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          item.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDone ? Colors.grey.shade400 : AppColors.icon,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '操作',
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.placeholder),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 优先级标签
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.priority.backgroundColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.priority.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: item.priority.color,
                    ),
                  ),
                ),
                // 提醒时间标签
                if (item.remindTime != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.isReminded
                          ? const Color(0xFFF1F2F6)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: item.isReminded
                            ? const Color(0xFFDCDFE6)
                            : const Color(0xFFC7D2FE),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.isReminded
                              ? Icons.notifications_off_outlined
                              : Icons.notifications_active_rounded,
                          size: 13,
                          color: item.isReminded
                              ? AppColors.placeholder
                              : const Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatDateTime(item.remindTime!)} 提醒',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: item.isReminded
                                ? AppColors.placeholder
                                : const Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                  ),
                // 截止时间标签
                if (item.dueTime != null) ...[
                  if (item.isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.error),
                          const SizedBox(width: 4),
                          Text(
                            '超时: ${_formatDateTime(item.dueTime!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded, size: 13, color: AppColors.icon),
                          const SizedBox(width: 4),
                          Text(
                            '截止: ${_formatDateTime(item.dueTime!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.icon,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoEditSheet extends StatefulWidget {
  const _TodoEditSheet({this.item, required this.onSaved});

  final TodoItem? item;
  final VoidCallback onSaved;

  @override
  State<_TodoEditSheet> createState() => _TodoEditSheetState();
}

class _TodoEditSheetState extends State<_TodoEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TodoPriority _priority;
  DateTime? _dueTime;
  DateTime? _remindTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _descController = TextEditingController(text: widget.item?.description ?? '');
    _priority = widget.item?.priority ?? TodoPriority.medium;
    _dueTime = widget.item?.dueTime?.toLocal();
    _remindTime = widget.item?.remindTime?.toLocal();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _formatDT(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (pickedDate == null || !mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial.hour, minute: initial.minute),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  DateTime _getNextWeekend(int weekday, int hour, int minute) {
    final now = DateTime.now();
    int daysToAdd = (weekday - now.weekday + 7) % 7;
    var target = DateTime(now.year, now.month, now.day + daysToAdd, hour, minute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 7));
    }
    return target;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      if (widget.item == null) {
        await TodoService.createTodo(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          priority: _priority,
          dueTime: _dueTime,
          remindTime: _remindTime,
        );
      } else {
        await TodoService.updateTodo(
          id: widget.item!.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          priority: _priority,
          dueTime: _dueTime,
          remindTime: _remindTime,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
      AppMessage.show(
        context,
        widget.item == null ? '待办创建成功' : '待办已更新',
        type: AppMessageType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppMessage.show(context, '保存失败: $e', type: AppMessageType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.item == null ? '新建待办事项' : '编辑待办事项',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.icon),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 标题输入
              TextFormField(
                controller: _titleController,
                autofocus: widget.item == null,
                decoration: InputDecoration(
                  labelText: '待办标题 *',
                  hintText: '如：准备下午的周会汇报材料',
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return '请输入待办标题';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // 详细描述输入
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: '详细描述（可选）',
                  hintText: '补充任务背景、注意事项或关键链接...',
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 优先级设定
              const Text(
                '优先级',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: TodoPriority.values.map((p) {
                  final isSelected = _priority == p;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(p.label),
                      selected: isSelected,
                      selectedColor: p.backgroundColor,
                      backgroundColor: const Color(0xFFF3F4F6),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? p.color : AppColors.icon,
                      ),
                      side: BorderSide(
                        color: isSelected ? p.color : Colors.transparent,
                        width: 1.2,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _priority = p);
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // 到期提醒时间
              const Text(
                '到期提醒时间 (后台推送)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined, color: Color(0xFF4F46E5), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _remindTime != null
                                ? '提醒时间: ${_formatDT(_remindTime!)}'
                                : '未设置提醒（到达设定时间时后台将推送通知）',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _remindTime != null ? FontWeight.bold : FontWeight.normal,
                              color: _remindTime != null ? const Color(0xFF4F46E5) : AppColors.placeholder,
                            ),
                          ),
                        ),
                        if (_remindTime != null)
                          GestureDetector(
                            onTap: () => setState(() => _remindTime = null),
                            child: const Icon(Icons.cancel_rounded, size: 20, color: AppColors.placeholder),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _shortcutChip('30分钟后', () {
                          setState(() => _remindTime = DateTime.now().add(const Duration(minutes: 30)));
                        }),
                        _shortcutChip('1小时后', () {
                          setState(() => _remindTime = DateTime.now().add(const Duration(hours: 1)));
                        }),
                        _shortcutChip('今晚 18:00', () {
                          final now = DateTime.now();
                          setState(() => _remindTime = DateTime(now.year, now.month, now.day, 18, 0));
                        }),
                        _shortcutChip('明天 09:00', () {
                          final tom = DateTime.now().add(const Duration(days: 1));
                          setState(() => _remindTime = DateTime(tom.year, tom.month, tom.day, 9, 0));
                        }),
                        _shortcutChip('周六 09:00', () {
                          setState(() => _remindTime = _getNextWeekend(DateTime.saturday, 9, 0));
                        }),
                        _shortcutChip('周六 12:00', () {
                          setState(() => _remindTime = _getNextWeekend(DateTime.saturday, 12, 0));
                        }),
                        _shortcutChip('周日 09:00', () {
                          setState(() => _remindTime = _getNextWeekend(DateTime.sunday, 9, 0));
                        }),
                        _shortcutChip('周日 12:00', () {
                          setState(() => _remindTime = _getNextWeekend(DateTime.sunday, 12, 0));
                        }),
                        _shortcutChip('自定义选择', () async {
                          final chosen = await _pickDateTime(_remindTime ?? DateTime.now().add(const Duration(hours: 1)));
                          if (chosen != null) {
                            setState(() => _remindTime = chosen);
                          }
                        }),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 截止时间
              const Text(
                '截止时间 (可选)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final chosen = await _pickDateTime(_dueTime ?? DateTime.now().add(const Duration(days: 1)));
                        if (chosen != null) {
                          setState(() => _dueTime = chosen);
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                      label: Text(
                        _dueTime != null ? _formatDT(_dueTime!) : '选择截止日期与时间',
                        style: TextStyle(
                          color: _dueTime != null ? AppColors.textPrimary : AppColors.placeholder,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (_dueTime != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, color: AppColors.placeholder),
                      onPressed: () => setState(() => _dueTime = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          widget.item == null ? '立即创建' : '保存修改',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shortcutChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD0D7E5)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
