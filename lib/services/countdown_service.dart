import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onehubapp/models/countdown_model.dart';

/// 统计卡数据，对应 PC 端顶部四张卡
class CountdownStats {
  const CountdownStats({
    this.total = 0,
    this.upcoming = 0,
    this.within7 = 0,
    this.today = 0,
    this.past = 0,
  });

  final int total;
  final int upcoming;
  final int within7;
  final int today;
  final int past;
}

/// 排序方式，与 PC 端下拉保持一致
enum CountdownSort {
  daysAsc('days-asc', '剩余天数从少到多'),
  daysDesc('days-desc', '剩余天数从多到少'),
  createdDesc('created-desc', '按创建时间'),
  title('title', '按标题');

  const CountdownSort(this.key, this.label);

  final String key;
  final String label;
}

/// 倒数日本地存储与计算
///
/// 与 PC 端一样存在本机（localStorage → SharedPreferences），不上传服务器。
class CountdownService {
  const CountdownService._();

  static const String storageKey = 'onehub-countdowns';
  static const String todayAlertKey = 'onehub-countdown-alert-date';
  static const List<String> presetTags = ['生日', '纪念日', '考试', '假期', '还款', '工作', '出行'];

  static Future<List<CountdownItem>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CountdownItem.fromJson)
          .where((item) => item.title.isNotEmpty && item.targetDate.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('读取倒数日失败: $e');
      return const [];
    }
  }

  static Future<void> save(List<CountdownItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        storageKey,
        jsonEncode(items.map((item) => item.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('保存倒数日失败: $e');
    }
  }

  static String createId() {
    final random = math.Random();
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = random.nextInt(1 << 32).toRadixString(36);
    return 'cd-$stamp-$salt';
  }

  /// 补全剩余天数，并按剩余天数升序（与 PC 端一致）
  static List<CountdownEntry> enrich(List<CountdownItem> items, {DateTime? now}) {
    final today = CountdownDateUtils.todayStart(now);
    final entries = items
        .map((item) => CountdownEntry.fromItem(item, today))
        .toList()
      ..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return entries;
  }

  static CountdownStats stats(List<CountdownEntry> entries) {
    return CountdownStats(
      total: entries.length,
      upcoming: entries.where((entry) => entry.isUpcoming).length,
      within7: entries
          .where((entry) => entry.isUpcoming && entry.daysLeft <= 7)
          .length,
      today: entries.where((entry) => entry.isToday).length,
      past: entries.where((entry) => entry.isPast).length,
    );
  }

  /// 离现在最近的那个重要日期
  static CountdownEntry? nextEvent(List<CountdownEntry> entries) {
    for (final entry in entries) {
      if (entry.isUpcoming) return entry;
    }
    return null;
  }

  static List<String> availableTags(List<CountdownItem> items) {
    final tags = <String>[];
    for (final item in items) {
      if (item.tag.isNotEmpty && !tags.contains(item.tag)) tags.add(item.tag);
    }
    return tags;
  }

  /// 标签页 / 搜索 / 标签筛选 / 排序，规则与 PC 端一致：置顶永远在最前
  static List<CountdownEntry> applyFilters(
    List<CountdownEntry> entries, {
    String tab = 'all',
    String keyword = '',
    String tag = '',
    CountdownSort sort = CountdownSort.daysAsc,
  }) {
    var list = entries.toList();

    switch (tab) {
      case 'upcoming':
        list = list.where((entry) => entry.isUpcoming).toList();
      case 'today':
        list = list.where((entry) => entry.isToday).toList();
      case 'past':
        list = list.where((entry) => entry.isPast).toList();
    }

    if (tag.isNotEmpty) {
      list = list.where((entry) => entry.item.tag == tag).toList();
    }

    final needle = keyword.trim().toLowerCase();
    if (needle.isNotEmpty) {
      list = list.where((entry) {
        final item = entry.item;
        return item.title.toLowerCase().contains(needle) ||
            item.note.toLowerCase().contains(needle) ||
            item.tag.toLowerCase().contains(needle);
      }).toList();
    }

    list.sort((a, b) {
      final pin = (b.item.pinned ? 1 : 0).compareTo(a.item.pinned ? 1 : 0);
      if (pin != 0) return pin;
      return switch (sort) {
        CountdownSort.daysAsc => a.daysLeft.compareTo(b.daysLeft),
        CountdownSort.daysDesc => b.daysLeft.compareTo(a.daysLeft),
        CountdownSort.createdDesc =>
          b.item.createdAt.compareTo(a.item.createdAt),
        CountdownSort.title => a.item.title.compareTo(b.item.title),
      };
    });

    return list;
  }

  /// 今天是否还有需要提醒、且今天尚未提醒过（对应 PC 端的 ALERT_KEY）
  static Future<bool> shouldShowTodayAlert(
    List<CountdownEntry> entries, {
    DateTime? now,
  }) async {
    if (!entries.any((entry) => entry.isToday)) return false;
    final label = CountdownDateUtils.format(CountdownDateUtils.todayStart(now));
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(todayAlertKey) == label) return false;
      await prefs.setString(todayAlertKey, label);
      return true;
    } catch (e) {
      debugPrint('记录今日提醒失败: $e');
      return true;
    }
  }

  /// 空状态下的示例数据，与 PC 端 loadSamples 一致
  static List<CountdownItem> sampleItems({DateTime? now}) {
    final today = CountdownDateUtils.todayStart(now);
    String plus(int days) =>
        CountdownDateUtils.format(today.add(Duration(days: days)));

    var birthday = DateTime(today.year, 12, 24);
    if (birthday.isBefore(today)) {
      birthday = DateTime(today.year + 1, 12, 24);
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    return [
      CountdownItem(
        id: createId(),
        title: '国庆假期',
        targetDate: plus(10),
        tag: '假期',
        note: '提前规划出行路线与酒店',
        pinned: true,
        createdAt: stamp,
      ),
      CountdownItem(
        id: createId(),
        title: '妈妈生日',
        targetDate: CountdownDateUtils.format(birthday),
        targetTime: '09:00',
        tag: '生日',
        note: '提前订蛋糕，记得打电话',
        repeatYearly: true,
        createdAt: stamp + 1,
      ),
    ];
  }
}
