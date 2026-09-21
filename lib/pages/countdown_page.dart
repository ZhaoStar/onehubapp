import 'package:flutter/material.dart';
import 'package:onehubapp/core/app_colors.dart';
import 'package:onehubapp/core/app_message.dart';
import 'package:onehubapp/models/countdown_model.dart';
import 'package:onehubapp/services/countdown_service.dart';

/// 倒数日 / 重要日期（仿 PC 端 onehubfront 的 CountdownView.vue）
///
/// 与 PC 端一致：数据只保存在本机，不调用服务端接口。
class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  State<CountdownPage> createState() => _CountdownPageState();
}

class _CountdownPageState extends State<CountdownPage>
    with SingleTickerProviderStateMixin {
  static const Color _pageBackground = Color(0xFFF7F8FC);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _todayColor = Color(0xFFDB2777);

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<CountdownItem> _items = const [];
  bool _isLoading = true;
  String _keyword = '';
  String _selectedTag = '';
  CountdownSort _sort = CountdownSort.daysAsc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging && mounted) {
      setState(() {});
    }
  }

  String get _currentTab => switch (_tabController.index) {
    1 => 'upcoming',
    2 => 'today',
    3 => 'past',
    _ => 'all',
  };

  List<CountdownEntry> get _entries => CountdownService.enrich(_items);

  List<CountdownEntry> _visibleEntries(List<CountdownEntry> entries) {
    return CountdownService.applyFilters(
      entries,
      tab: _currentTab,
      keyword: _keyword,
      tag: _selectedTag,
      sort: _sort,
    );
  }

  // -------------------------------------------------------------- 数据操作

  Future<void> _load() async {
    final items = await CountdownService.load();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
    await _maybeShowTodayAlert();
  }

  Future<void> _persist(List<CountdownItem> next) async {
    setState(() => _items = next);
    await CountdownService.save(next);
  }

  Future<void> _maybeShowTodayAlert() async {
    final entries = _entries;
    final shouldShow = await CountdownService.shouldShowTodayAlert(entries);
    if (!shouldShow || !mounted) return;
    _showTodayAlertDialog(entries);
  }

  void _showTodayAlertDialog(List<CountdownEntry> entries) {
    final todayEvents = entries.where((entry) => entry.isToday).toList();
    if (todayEvents.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '今天有 ${todayEvents.length} 个重要日期',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in todayEvents)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.item.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (entry.item.targetTime.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                entry.item.targetTime,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.item.note.isEmpty ? '今天到期，别忘了处理' : entry.item.note,
                        style: const TextStyle(fontSize: 13, color: AppColors.icon),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditSheet([CountdownItem? item]) async {
    final result = await showModalBottomSheet<CountdownItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountdownEditSheet(item: item),
    );
    if (result == null || !mounted) return;

    final exists = _items.any((row) => row.id == result.id);
    final next = exists
        ? _items.map((row) => row.id == result.id ? result : row).toList()
        : [..._items, result];
    await _persist(next);
    if (!mounted) return;
    AppMessage.show(
      context,
      exists ? '倒数日已更新' : '倒数日已创建',
      type: AppMessageType.success,
    );
  }

  Future<void> _togglePin(CountdownItem item) async {
    final next = _items
        .map((row) => row.id == item.id ? row.copyWith(pinned: !row.pinned) : row)
        .toList();
    await _persist(next);
  }

  Future<void> _deleteItem(CountdownItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除倒数日', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('确定要删除「${item.title}」吗？删除后不可恢复。'),
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
    if (confirmed != true || !mounted) return;

    await _persist(_items.where((row) => row.id != item.id).toList());
    if (!mounted) return;
    AppMessage.show(context, '倒数日已删除', type: AppMessageType.info);
  }

  Future<void> _loadSamples() async {
    final samples = CountdownService.sampleItems();
    await _persist([..._items, ...samples]);
    if (!mounted) return;
    AppMessage.show(
      context,
      '已载入 ${samples.length} 条示例倒数日',
      type: AppMessageType.success,
    );
  }

  // ------------------------------------------------------------------ 界面

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final stats = CountdownService.stats(entries);

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          '倒数日',
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
          if (stats.today > 0)
            IconButton(
              tooltip: '今天有 ${stats.today} 个重要日期',
              icon: Badge.count(
                count: stats.today,
                backgroundColor: _todayColor,
                child: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
              ),
              onPressed: () => _showTodayAlertDialog(entries),
            ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _load,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(106),
          child: Column(
            children: [
              _buildStatsBar(stats),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.placeholder,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                tabs: [
                  Tab(text: '全部 (${stats.total})'),
                  Tab(text: '即将到来 (${stats.upcoming})'),
                  Tab(text: '今天 (${stats.today})'),
                  Tab(text: '已过去 (${stats.past})'),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 4,
        onPressed: () => _openEditSheet(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          '新增倒数日',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody(entries)),
        ],
      ),
    );
  }

  Widget _buildStatsBar(CountdownStats stats) {
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
          _buildStatPill('全部记录', stats.total, AppColors.primary),
          _buildStatDivider(),
          _buildStatPill('7 天内', stats.within7, const Color(0xFFD97706)),
          _buildStatDivider(),
          _buildStatPill('就是今天', stats.today, _todayColor),
          _buildStatDivider(),
          _buildStatPill('已经过去', stats.past, const Color(0xFF64748B)),
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
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.icon, fontWeight: FontWeight.w500),
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
          hintText: '搜索标题、备注或标签…',
          hintStyle: const TextStyle(color: AppColors.placeholder, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.placeholder, size: 20),
          suffixIcon: _keyword.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _keyword = '');
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
        onChanged: (val) => setState(() => _keyword = val.trim()),
      ),
    );
  }

  Widget _buildBody(List<CountdownEntry> entries) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_items.isEmpty) return _buildEmptyState();

    final tags = CountdownService.availableTags(_items);
    final nextEvent = CountdownService.nextEvent(entries);
    final visible = _visibleEntries(entries);

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          if (nextEvent != null) ...[
            _buildSpotlight(nextEvent),
            const SizedBox(height: 12),
          ],
          _buildToolbar(tags),
          if (visible.isEmpty)
            _buildFilteredEmpty()
          else
            ...visible.map(_buildCard),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(color: Color(0xFFFDF2F8), shape: BoxShape.circle),
              child: const Icon(Icons.hourglass_bottom_rounded, size: 44, color: _todayColor),
            ),
            const SizedBox(height: 18),
            const Text(
              '还没有记录任何倒数日',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              '记录生日、纪念日、考试或还款日，每天自动告诉你还剩多少天',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.placeholder, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () => _openEditSheet(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('新增倒数日'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _loadSamples,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('载入示例'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: const Icon(Icons.filter_alt_off_rounded, size: 34, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          const Text(
            '没有符合筛选条件的倒数日',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            '换个关键词或标签再试试',
            style: TextStyle(fontSize: 13, color: AppColors.placeholder),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotlight(CountdownEntry entry) {
    final extra = <String>[
      '${entry.targetLabel}（${entry.weekdayLabel}）',
      if (entry.item.targetTime.isNotEmpty) entry.item.targetTime,
      if (entry.item.tag.isNotEmpty) entry.item.tag,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hourglass_bottom_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '离你最近的重要日期',
                  style: TextStyle(fontSize: 12, color: Color(0xFFDBEAFE), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.isToday ? '就是今天' : '还有 ${entry.daysLeft} 天',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFDE68A)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  extra,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFDBEAFE)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(List<String> tags) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: tags.isEmpty
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTagChip('全部标签', _selectedTag.isEmpty, () {
                          setState(() => _selectedTag = '');
                        }),
                        for (final tag in tags)
                          _buildTagChip(tag, _selectedTag == tag, () {
                            setState(() => _selectedTag = _selectedTag == tag ? '' : tag);
                          }),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          _buildSortButton(),
        ],
      ),
    );
  }

  Widget _buildTagChip(String label, bool active, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFE0F2FE),
        backgroundColor: Colors.white,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: active ? const Color(0xFF0369A1) : AppColors.icon,
        ),
        side: BorderSide(
          color: active ? const Color(0xFF0369A1) : _borderColor,
          width: 1,
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<CountdownSort>(
      tooltip: '排序方式',
      initialValue: _sort,
      onSelected: (value) => setState(() => _sort = value),
      itemBuilder: (context) => [
        for (final option in CountdownSort.values)
          PopupMenuItem<CountdownSort>(
            value: option,
            child: Text(option.label, style: const TextStyle(fontSize: 14)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 16, color: AppColors.icon),
            const SizedBox(width: 4),
            Text(
              _sort.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.icon),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(CountdownEntry entry) {
    final item = entry.item;
    final dateText = entry.weekdayLabel.isEmpty
        ? entry.targetLabel
        : '${entry.targetLabel}（${entry.weekdayLabel}）';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDaysBadge(entry),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: entry.isPast ? AppColors.placeholder : AppColors.textPrimary,
                        ),
                      ),
                      if (item.pinned)
                        _buildMetaTag(Icons.push_pin_rounded, '置顶', const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
                      if (item.tag.isNotEmpty)
                        _buildMetaTag(null, item.tag, const Color(0xFF0369A1), const Color(0xFFE0F2FE)),
                      if (item.repeatYearly)
                        _buildMetaTag(Icons.repeat_rounded, '每年重复', const Color(0xFF047857), const Color(0xFFECFDF5)),
                    ],
                  ),
                  if (item.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.icon, height: 1.35),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.placeholder),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.targetTime.isEmpty ? dateText : '$dateText ${item.targetTime}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.icon),
                        ),
                      ),
                    ],
                  ),
                  if (entry.isPast) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 13, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 5),
                        Text(
                          '已过去 ${entry.daysLeft.abs()} 天',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  icon: item.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: const Color(0xFF7C3AED),
                  background: const Color(0xFFF5F3FF),
                  tooltip: item.pinned ? '取消置顶' : '置顶',
                  onTap: () => _togglePin(item),
                ),
                const SizedBox(height: 6),
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF0284C7),
                  background: const Color(0xFFF0F7FF),
                  tooltip: '编辑',
                  onTap: () => _openEditSheet(item),
                ),
                const SizedBox(height: 6),
                _buildActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFEF4444),
                  background: const Color(0xFFFEF2F2),
                  tooltip: '删除',
                  onTap: () => _deleteItem(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysBadge(CountdownEntry entry) {
    final (Color background, Color foreground, Color border) = _badgeColors(entry);
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              entry.daysNumber,
              style: TextStyle(
                fontSize: entry.isToday ? 17 : 24,
                fontWeight: FontWeight.w900,
                color: foreground,
                height: 1.1,
              ),
            ),
          ),
          if (entry.daysUnit.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              entry.daysUnit,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: foreground),
            ),
          ],
        ],
      ),
    );
  }

  (Color, Color, Color) _badgeColors(CountdownEntry entry) {
    if (entry.isToday) {
      return (const Color(0xFFFDF2F8), _todayColor, const Color(0xFFFBCFE8));
    }
    if (entry.isPast) {
      return (const Color(0xFFF1F5F9), const Color(0xFF64748B), _borderColor);
    }
    if (entry.daysLeft <= 7) {
      return (const Color(0xFFFEF3C7), const Color(0xFFB45309), const Color(0xFFFDE68A));
    }
    return (const Color(0xFFEFF6FF), const Color(0xFF1D4ED8), const Color(0xFFBFDBFE));
  }

  Widget _buildMetaTag(IconData? icon, String label, Color color, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required Color background,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 30,
            height: 30,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

/// 新增 / 编辑倒数日弹层，字段与 PC 端弹窗保持一致
class _CountdownEditSheet extends StatefulWidget {
  const _CountdownEditSheet({this.item});

  final CountdownItem? item;

  @override
  State<_CountdownEditSheet> createState() => _CountdownEditSheetState();
}

class _CountdownEditSheetState extends State<_CountdownEditSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;

  late DateTime _targetDate;
  TimeOfDay? _targetTime;
  String _tag = '';
  bool _repeatYearly = false;
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: item?.title ?? '');
    _noteController = TextEditingController(text: item?.note ?? '');
    _targetDate =
        CountdownDateUtils.parseDateOnly(item?.targetDate) ?? CountdownDateUtils.todayStart();
    _targetTime = _parseTime(item?.targetTime);
    _tag = item?.tag ?? '';
    _repeatYearly = item?.repeatYearly ?? false;
    _pinned = item?.pinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static TimeOfDay? _parseTime(String? value) {
    final parts = (value ?? '').split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 50, 12, 31),
      helpText: '选择目标日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => _targetDate = CountdownDateUtils.startOfDay(picked));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _targetTime ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: '选择具体时间',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => _targetTime = picked);
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    Navigator.of(context).pop(
      CountdownItem(
        id: widget.item?.id ?? CountdownService.createId(),
        title: title,
        targetDate: CountdownDateUtils.format(_targetDate),
        targetTime: _targetTime == null ? '' : _formatTime(_targetTime!),
        tag: _tag,
        note: _noteController.text.trim(),
        repeatYearly: _repeatYearly,
        pinned: _pinned,
        createdAt: widget.item?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final dateLabel =
        '${CountdownDateUtils.format(_targetDate)}（${CountdownDateUtils.weekdayLabel(_targetDate)}）';

    // 用 Material 而不是带背景色的 Container 作根节点：
    // ListTile 的水波纹要画在最近的 Material 上，被 DecoratedBox 挡住时新版 Flutter 会直接断言报错
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
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
                    widget.item == null ? '新增倒数日' : '编辑倒数日',
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

              TextFormField(
                controller: _titleController,
                autofocus: widget.item == null,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: '标题 *',
                  hintText: '例如：国庆假期、妈妈生日、考试倒计时',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? '请填写倒数日标题' : null,
              ),
              const SizedBox(height: 14),

              const Text(
                '目标日期 *',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.primary),
                      label: Text(
                        dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _pickTime,
                      icon: const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
                      label: Text(
                        _targetTime == null ? '选择时间' : _formatTime(_targetTime!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _targetTime == null ? AppColors.placeholder : AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (_targetTime != null)
                    IconButton(
                      tooltip: '清除时间',
                      icon: const Icon(Icons.clear_rounded, size: 20, color: AppColors.placeholder),
                      onPressed: () => setState(() => _targetTime = null),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '具体时间可不填，不填按整天计算',
                style: TextStyle(fontSize: 12, color: AppColors.placeholder),
              ),
              const SizedBox(height: 16),

              const Text(
                '标签（可选）',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in CountdownService.presetTags)
                    ChoiceChip(
                      label: Text(tag),
                      selected: _tag == tag,
                      showCheckmark: false,
                      selectedColor: const Color(0xFFE0F2FE),
                      backgroundColor: const Color(0xFFF3F4F6),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _tag == tag ? const Color(0xFF0369A1) : AppColors.icon,
                      ),
                      side: BorderSide(
                        color: _tag == tag ? const Color(0xFF0369A1) : Colors.transparent,
                        width: 1.2,
                      ),
                      onSelected: (selected) => setState(() => _tag = selected ? tag : ''),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '补充说明，例如：提前订蛋糕、记得带准考证…',
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              CheckboxListTile(
                value: _repeatYearly,
                onChanged: (val) => setState(() => _repeatYearly = val ?? false),
                title: const Text(
                  '每年重复（适合生日、纪念日）',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              CheckboxListTile(
                value: _pinned,
                onChanged: (val) => setState(() => _pinned = val ?? false),
                title: const Text(
                  '置顶显示',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submit,
                  child: Text(
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
}
