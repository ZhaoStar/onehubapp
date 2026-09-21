/// 倒数日 / 重要日期
///
/// 字段与 PC 端（onehubfront 的 CountdownView.vue）保持一致，数据保存在本机。
/// targetDate 固定为 yyyy-MM-dd，targetTime 为 HH:mm（空表示按整天算）。
class CountdownItem {
  const CountdownItem({
    required this.id,
    required this.title,
    required this.targetDate,
    this.targetTime = '',
    this.tag = '',
    this.note = '',
    this.repeatYearly = false,
    this.pinned = false,
    this.createdAt = 0,
  });

  factory CountdownItem.fromJson(Map<String, dynamic> json) {
    return CountdownItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      targetDate: (json['targetDate'] ?? '').toString(),
      targetTime: (json['targetTime'] ?? '').toString(),
      tag: (json['tag'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
      repeatYearly: json['repeatYearly'] == true,
      pinned: json['pinned'] == true,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'targetDate': targetDate,
    'targetTime': targetTime,
    'tag': tag,
    'note': note,
    'repeatYearly': repeatYearly,
    'pinned': pinned,
    'createdAt': createdAt,
  };

  CountdownItem copyWith({
    String? title,
    String? targetDate,
    String? targetTime,
    String? tag,
    String? note,
    bool? repeatYearly,
    bool? pinned,
  }) {
    return CountdownItem(
      id: id,
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      targetTime: targetTime ?? this.targetTime,
      tag: tag ?? this.tag,
      note: note ?? this.note,
      repeatYearly: repeatYearly ?? this.repeatYearly,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt,
    );
  }

  final String id;
  final String title;
  final String targetDate;
  final String targetTime;
  final String tag;
  final String note;
  final bool repeatYearly;
  final bool pinned;
  final int createdAt;
}

/// 计算过剩余天数的倒数日，对应 PC 端的 enrichedList 项
class CountdownEntry {
  const CountdownEntry({
    required this.item,
    required this.target,
    required this.daysLeft,
  });

  factory CountdownEntry.fromItem(CountdownItem item, DateTime today) {
    final target = CountdownDateUtils.resolveTarget(item, today);
    return CountdownEntry(
      item: item,
      target: target,
      daysLeft: target == null ? 0 : CountdownDateUtils.diffDays(target, today),
    );
  }

  final CountdownItem item;
  final DateTime? target;
  final int daysLeft;

  bool get isToday => target != null && daysLeft == 0;
  bool get isPast => target != null && daysLeft < 0;
  bool get isUpcoming => target != null && daysLeft >= 0;

  /// 卡片左侧的大数字：今天 / 剩余天数
  String get daysNumber => isToday ? '今天' : '${daysLeft.abs()}';

  /// 大数字下方的单位：天后 / 天前
  String get daysUnit {
    if (isToday) return '';
    return daysLeft > 0 ? '天后' : '天前';
  }

  String get targetLabel =>
      target == null ? '--' : CountdownDateUtils.format(target!);

  String get weekdayLabel =>
      target == null ? '' : CountdownDateUtils.weekdayLabel(target!);
}

/// 倒数日用到的日期计算（纯函数，方便单测）
class CountdownDateUtils {
  const CountdownDateUtils._();

  static const List<String> weekdayNames = ['日', '一', '二', '三', '四', '五', '六'];

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime todayStart([DateTime? now]) => startOfDay(now ?? DateTime.now());

  /// 解析 yyyy-MM-dd，非法日期（如 2 月 30 日）返回 null
  static DateTime? parseDateOnly(String? value) {
    final parts = (value ?? '').split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    final date = DateTime(year, month, day);
    if (date.month != month || date.day != day) return null;
    return date;
  }

  static String format(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  static String weekdayLabel(DateTime date) => '周${weekdayNames[date.weekday % 7]}';

  static int diffDays(DateTime target, DateTime base) =>
      startOfDay(target).difference(startOfDay(base)).inDays;

  /// 每年重复的日期自动顺延到下一次（生日、纪念日）
  static DateTime? resolveTarget(CountdownItem item, DateTime today) {
    final base = parseDateOnly(item.targetDate);
    if (base == null) return null;
    if (!item.repeatYearly) return base;

    final start = startOfDay(today);
    var occurrence = DateTime(start.year, base.month, base.day);
    if (occurrence.isBefore(start)) {
      occurrence = DateTime(start.year + 1, base.month, base.day);
    }
    return occurrence;
  }
}
