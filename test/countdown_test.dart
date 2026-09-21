import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:onehubapp/models/countdown_model.dart';
import 'package:onehubapp/pages/countdown_page.dart';
import 'package:onehubapp/services/countdown_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 2026-09-21 是周一，作为所有用例的“今天”
  final today = DateTime(2026, 9, 21);

  group('CountdownDateUtils', () {
    test('parseDateOnly 解析合法日期并拒绝非法日期', () {
      final date = CountdownDateUtils.parseDateOnly('2026-09-21');
      expect(date, DateTime(2026, 9, 21));

      expect(CountdownDateUtils.parseDateOnly('2026-02-30'), isNull);
      expect(CountdownDateUtils.parseDateOnly('2026-13-01'), isNull);
      expect(CountdownDateUtils.parseDateOnly('2026-09'), isNull);
      expect(CountdownDateUtils.parseDateOnly('abc'), isNull);
      expect(CountdownDateUtils.parseDateOnly(''), isNull);
      expect(CountdownDateUtils.parseDateOnly(null), isNull);
    });

    test('format 与 weekdayLabel', () {
      expect(CountdownDateUtils.format(DateTime(2026, 1, 5)), '2026-01-05');
      expect(CountdownDateUtils.format(DateTime(2026, 10, 1)), '2026-10-01');
      expect(CountdownDateUtils.weekdayLabel(DateTime(2026, 9, 21)), '周一');
      expect(CountdownDateUtils.weekdayLabel(DateTime(2026, 10, 1)), '周四');
    });

    test('diffDays 忽略时间只算整天', () {
      final base = DateTime(2026, 9, 21, 23, 30);
      expect(CountdownDateUtils.diffDays(DateTime(2026, 9, 24, 1), base), 3);
      expect(CountdownDateUtils.diffDays(DateTime(2026, 9, 21, 0, 1), base), 0);
      expect(CountdownDateUtils.diffDays(DateTime(2026, 9, 20), base), -1);
    });

    test('每年重复的日期自动顺延到下一次', () {
      final birthday = CountdownItem(
        id: 'a',
        title: '妈妈生日',
        targetDate: '2020-12-24',
        repeatYearly: true,
      );
      expect(CountdownDateUtils.resolveTarget(birthday, today), DateTime(2026, 12, 24));

      final passed = CountdownItem(
        id: 'b',
        title: '结婚纪念日',
        targetDate: '2019-01-01',
        repeatYearly: true,
      );
      expect(CountdownDateUtils.resolveTarget(passed, today), DateTime(2027, 1, 1));

      final sameDay = CountdownItem(
        id: 'c',
        title: '今天生日',
        targetDate: '2026-09-21',
        repeatYearly: true,
      );
      expect(CountdownDateUtils.resolveTarget(sameDay, today), DateTime(2026, 9, 21));
    });

    test('非重复日期保持原样，非法日期返回 null', () {
      expect(
        CountdownDateUtils.resolveTarget(
          const CountdownItem(id: 'c', title: '国庆', targetDate: '2026-10-01'),
          today,
        ),
        DateTime(2026, 10, 1),
      );
      expect(
        CountdownDateUtils.resolveTarget(
          const CountdownItem(id: 'd', title: '坏数据', targetDate: '2026-02-30'),
          today,
        ),
        isNull,
      );
    });
  });

  group('CountdownItem', () {
    test('toJson / fromJson 往返一致', () {
      const item = CountdownItem(
        id: 'x1',
        title: '考试倒计时',
        targetDate: '2026-10-01',
        targetTime: '09:30',
        tag: '考试',
        note: '记得带准考证',
        repeatYearly: true,
        pinned: true,
        createdAt: 123,
      );
      final restored = CountdownItem.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, item.id);
      expect(restored.title, item.title);
      expect(restored.targetDate, item.targetDate);
      expect(restored.targetTime, item.targetTime);
      expect(restored.tag, item.tag);
      expect(restored.note, item.note);
      expect(restored.repeatYearly, isTrue);
      expect(restored.pinned, isTrue);
      expect(restored.createdAt, 123);
    });

    test('fromJson 容错处理缺失字段', () {
      final item = CountdownItem.fromJson(const {'title': '只有标题'});
      expect(item.id, '');
      expect(item.targetDate, '');
      expect(item.targetTime, '');
      expect(item.repeatYearly, isFalse);
      expect(item.pinned, isFalse);
      expect(item.createdAt, 0);
    });

    test('copyWith 只覆盖传入字段', () {
      const item = CountdownItem(id: 'x', title: '标题', targetDate: '2026-10-01', tag: '工作');
      final updated = item.copyWith(pinned: true);

      expect(updated.id, 'x');
      expect(updated.title, '标题');
      expect(updated.tag, '工作');
      expect(updated.pinned, isTrue);
    });
  });

  group('CountdownEntry', () {
    test('未来 / 今天 / 过去 的展示文案', () {
      final future = CountdownEntry.fromItem(
        const CountdownItem(id: '1', title: '国庆假期', targetDate: '2026-10-01'),
        today,
      );
      expect(future.daysLeft, 10);
      expect(future.daysNumber, '10');
      expect(future.daysUnit, '天后');
      expect(future.isUpcoming, isTrue);
      expect(future.isToday, isFalse);
      expect(future.isPast, isFalse);
      expect(future.targetLabel, '2026-10-01');
      expect(future.weekdayLabel, '周四');

      final nowEntry = CountdownEntry.fromItem(
        const CountdownItem(id: '2', title: '还款日', targetDate: '2026-09-21'),
        today,
      );
      expect(nowEntry.daysLeft, 0);
      expect(nowEntry.isToday, isTrue);
      expect(nowEntry.isPast, isFalse);
      expect(nowEntry.daysNumber, '今天');
      expect(nowEntry.daysUnit, '');

      final past = CountdownEntry.fromItem(
        const CountdownItem(id: '3', title: '入职纪念', targetDate: '2026-09-11'),
        today,
      );
      expect(past.daysLeft, -10);
      expect(past.isPast, isTrue);
      expect(past.isToday, isFalse);
      expect(past.daysNumber, '10');
      expect(past.daysUnit, '天前');
    });

    test('非法日期不会显示成“今天”', () {
      final broken = CountdownEntry.fromItem(
        const CountdownItem(id: '4', title: '坏数据', targetDate: '2026-02-30'),
        today,
      );
      expect(broken.target, isNull);
      expect(broken.isToday, isFalse);
      expect(broken.isPast, isFalse);
      expect(broken.targetLabel, '--');
      expect(broken.weekdayLabel, '');
    });
  });

  group('CountdownService', () {
    List<CountdownItem> buildItems() => const [
      CountdownItem(
        id: '1',
        title: '国庆假期',
        targetDate: '2026-10-01',
        tag: '假期',
        pinned: true,
        createdAt: 3,
      ),
      CountdownItem(
        id: '2',
        title: '妈妈生日',
        targetDate: '2026-09-21',
        targetTime: '09:00',
        tag: '生日',
        repeatYearly: true,
        createdAt: 2,
      ),
      CountdownItem(
        id: '3',
        title: '信用卡还款',
        targetDate: '2026-09-15',
        tag: '还款',
        createdAt: 1,
      ),
      CountdownItem(
        id: '4',
        title: '考试报名',
        targetDate: '2026-09-25',
        createdAt: 4,
      ),
    ];

    test('enrich 补全剩余天数并按天数升序', () {
      final entries = CountdownService.enrich(buildItems(), now: today);
      expect(entries.map((e) => e.daysLeft).toList(), [-6, 0, 4, 10]);
      expect(entries.first.item.title, '信用卡还款');
    });

    test('stats 统计四项数据', () {
      final stats = CountdownService.stats(CountdownService.enrich(buildItems(), now: today));
      expect(stats.total, 4);
      expect(stats.within7, 2);
      expect(stats.today, 1);
      expect(stats.past, 1);
      expect(stats.upcoming, 3);
    });

    test('nextEvent 返回最近一个未过去的日期', () {
      final entries = CountdownService.enrich(buildItems(), now: today);
      expect(CountdownService.nextEvent(entries)?.item.title, '妈妈生日');

      final pastOnly = CountdownService.enrich([
        const CountdownItem(id: 'p', title: '已过去', targetDate: '2026-01-01'),
      ], now: today);
      expect(CountdownService.nextEvent(pastOnly), isNull);
    });

    test('availableTags 生成去重后的标签列表', () {
      expect(CountdownService.availableTags(buildItems()), ['假期', '生日', '还款']);
    });

    test('applyFilters 置顶恒排最前', () {
      final entries = CountdownService.enrich(buildItems(), now: today);
      final list = CountdownService.applyFilters(entries);

      expect(list.first.item.title, '国庆假期');
      expect(list.map((e) => e.item.title).toList(), ['国庆假期', '信用卡还款', '妈妈生日', '考试报名']);
    });

    test('applyFilters 支持标签页筛选', () {
      final entries = CountdownService.enrich(buildItems(), now: today);

      expect(
        CountdownService.applyFilters(entries, tab: 'upcoming').map((e) => e.item.title).toList(),
        ['国庆假期', '妈妈生日', '考试报名'],
      );
      expect(
        CountdownService.applyFilters(entries, tab: 'today').map((e) => e.item.title).toList(),
        ['妈妈生日'],
      );
      expect(
        CountdownService.applyFilters(entries, tab: 'past').map((e) => e.item.title).toList(),
        ['信用卡还款'],
      );
    });

    test('applyFilters 支持标签与关键词筛选', () {
      final entries = CountdownService.enrich(buildItems(), now: today);

      expect(
        CountdownService.applyFilters(entries, tag: '生日').map((e) => e.item.title).toList(),
        ['妈妈生日'],
      );
      expect(
        CountdownService.applyFilters(entries, keyword: '还款').map((e) => e.item.title).toList(),
        ['信用卡还款'],
      );
      expect(
        CountdownService.applyFilters(entries, keyword: '假期').map((e) => e.item.title).toList(),
        ['国庆假期'],
      );
      expect(CountdownService.applyFilters(entries, keyword: ' 不存在的关键词 '), isEmpty);
    });

    test('applyFilters 支持四种排序', () {
      final entries = CountdownService.enrich(buildItems(), now: today);

      expect(
        CountdownService.applyFilters(entries, sort: CountdownSort.daysDesc)
            .map((e) => e.item.title)
            .toList(),
        ['国庆假期', '考试报名', '妈妈生日', '信用卡还款'],
      );
      expect(
        CountdownService.applyFilters(entries, sort: CountdownSort.createdDesc)
            .map((e) => e.item.title)
            .toList(),
        ['国庆假期', '考试报名', '妈妈生日', '信用卡还款'],
      );
      expect(
        CountdownService.applyFilters(entries, sort: CountdownSort.title).length,
        4,
      );
    });

    test('sampleItems 生成两条示例数据', () {
      final samples = CountdownService.sampleItems(now: today);

      expect(samples.length, 2);
      expect(samples.first.title, '国庆假期');
      expect(samples.first.targetDate, '2026-10-01');
      expect(samples.first.pinned, isTrue);
      expect(samples[1].title, '妈妈生日');
      expect(samples[1].targetDate, '2026-12-24');
      expect(samples[1].repeatYearly, isTrue);
      expect(samples.every((item) => item.id.isNotEmpty), isTrue);
    });

    test('createId 生成唯一 id', () {
      final ids = List.generate(50, (_) => CountdownService.createId()).toSet();
      expect(ids.length, 50);
    });
  });

  group('CountdownService.shouldShowTodayAlert', () {
    test('同一天只提醒一次', () async {
      SharedPreferences.setMockInitialValues({});
      final entries = CountdownService.enrich([
        const CountdownItem(id: '1', title: '还款日', targetDate: '2026-09-21'),
      ], now: today);

      expect(await CountdownService.shouldShowTodayAlert(entries, now: today), isTrue);
      expect(await CountdownService.shouldShowTodayAlert(entries, now: today), isFalse);
    });

    test('当天没有到期日期时不提醒', () async {
      SharedPreferences.setMockInitialValues({});
      final entries = CountdownService.enrich([
        const CountdownItem(id: '1', title: '国庆假期', targetDate: '2026-10-01'),
      ], now: today);

      expect(await CountdownService.shouldShowTodayAlert(entries, now: today), isFalse);
    });
  });

  group('CountdownPage 界面', () {
    String plusDays(int days) =>
        CountdownDateUtils.format(DateTime.now().add(Duration(days: days)));

    testWidgets('渲染统计卡、最近日期与倒数日卡片', (tester) async {
      SharedPreferences.setMockInitialValues({
        CountdownService.storageKey: jsonEncode([
          {
            'id': '1',
            'title': '国庆假期',
            'targetDate': plusDays(10),
            'tag': '假期',
            'note': '提前规划出行路线与酒店',
            'pinned': true,
            'createdAt': 2,
          },
          {
            'id': '2',
            'title': '妈妈生日',
            'targetDate': plusDays(30),
            'targetTime': '09:00',
            'tag': '生日',
            'repeatYearly': false,
            'createdAt': 1,
          },
        ]),
      });

      await tester.pumpWidget(const MaterialApp(home: CountdownPage()));
      await tester.pumpAndSettle();

      expect(find.text('倒数日'), findsOneWidget);
      expect(find.text('全部记录'), findsOneWidget);
      expect(find.text('离你最近的重要日期'), findsOneWidget);
      expect(find.text('国庆假期'), findsWidgets);
      expect(find.text('妈妈生日'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('天后'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('无数据时展示空状态与载入示例入口', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MaterialApp(home: CountdownPage()));
      await tester.pumpAndSettle();

      expect(find.text('还没有记录任何倒数日'), findsOneWidget);
      expect(find.text('载入示例'), findsOneWidget);
      expect(find.text('新增倒数日'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('新增倒数日弹层包含中文日期选择与预设标签', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const MaterialApp(home: CountdownPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('标题 *'), findsOneWidget);
      expect(find.text('目标日期 *'), findsOneWidget);
      expect(find.text('具体时间可不填，不填按整天计算'), findsOneWidget);
      expect(find.text('生日'), findsOneWidget);
      expect(find.text('每年重复（适合生日、纪念日）'), findsOneWidget);
      expect(find.text('每月重复'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('日期选择器在 zh_CN 下显示中文按钮', (tester) async {
      SharedPreferences.setMockInitialValues({});

      // 与 lib/main.dart 中的 locale / localizationsDelegates 配置保持一致
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const CountdownPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();

      expect(find.text('确定'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('选择目标日期'), findsOneWidget);
    });
  });
}
