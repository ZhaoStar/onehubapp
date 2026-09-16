import 'package:flutter_test/flutter_test.dart';
import 'package:onehubapp/models/oil_price_model.dart';

void main() {
  group('OilPriceItem Tests', () {
    test('OilPriceItem.fromJson correctly parses standard format', () {
      final json = {
        'city': '山东',
        'province': '山东',
        'date': '2026-08-29',
        'p92': 8.05,
        'p95': 8.64,
        'p98': 9.39,
        'p0': 7.68,
        'change92': 0.31,
        'change95': 0.33,
        'change0': 0.31,
        'prev92': 7.74,
        'prev95': 8.31,
        'prev0': 7.37,
      };

      final item = OilPriceItem.fromJson(json);
      expect(item.province, '山东');
      expect(item.city, '山东');
      expect(item.p92, 8.05);
      expect(item.p95, 8.64);
      expect(item.p98, 9.39);
      expect(item.p0, 7.68);
      expect(item.change92, 0.31);
      expect(item.prev92, 7.74);
    });

    test('OilPriceItem.fromJson correctly parses EastMoney API uppercase keys', () {
      final json = {
        'CITYNAME': '山东',
        'DIM_DATE': '2026-08-29 00:00:00',
        'V92': '8.05',
        'V95': '8.64',
        'V0': '7.68',
        'ZDE92': '0.31',
        'ZDE95': '0.33',
        'ZDE0': '0.31',
        'QE92': '7.74',
        'QE95': '8.31',
        'QE0': '7.37',
      };

      final item = OilPriceItem.fromJson(json);
      expect(item.province, '山东');
      expect(item.date, '2026-08-29');
      expect(item.p92, 8.05);
      expect(item.p95, 8.64);
      expect(item.p98, 9.39); // derived 8.64 + 0.75
      expect(item.p0, 7.68);
      expect(item.change92, 0.31);
    });
  });

  group('OilPrediction Tests', () {
    test('OilPrediction.fromJson correctly parses prediction and Shandong impact', () {
      final json = {
        'nextAdjustmentDate': '2026-09-11 24:00',
        'nextEffectiveDate': '2026-09-12 00:00',
        'workingDay': 9,
        'workingDayTotal': 10,
        'baseCrude': 83.44,
        'crudeChangeRate': 9.98,
        'estimatedChangeTons': 360,
        'estimatedChangeLiter': 0.28,
        'trendStatus': 'up',
        'trendLabel': '预计大幅上调',
        'isExceedThreshold': true,
        'shandongImpact': {
          'current92': 8.05,
          'predicted92': 8.33,
          'diffTank50L': 14.0,
          'advice': '建议提前加满油箱',
        },
      };

      final pred = OilPrediction.fromJson(json);
      expect(pred.nextAdjustmentDate, '2026-09-11 24:00');
      expect(pred.nextEffectiveDate, '2026-09-12 00:00');
      expect(pred.workingDay, 9);
      expect(pred.crudeChangeRate, 9.98);
      expect(pred.estimatedChangeLiter, 0.28);
      expect(pred.trendStatus, 'up');
      expect(pred.shandongImpact, isNotNull);
      expect(pred.shandongImpact!.current92, 8.05);
      expect(pred.shandongImpact!.predicted92, 8.33);
      expect(pred.shandongImpact!.diffTank50L, 14.0);
      expect(pred.shandongImpact!.advice, '建议提前加满油箱');
    });
  });

  group('OilPricesData Tests', () {
    test('shandong getter finds Shandong province item', () {
      final data = OilPricesData(
        list: [
          const OilPriceItem(
            province: '北京',
            city: '北京',
            date: '2026-08-29',
            p92: 8.08,
            p95: 8.60,
            p98: 9.35,
            p0: 7.72,
            change92: 0.31,
            change95: 0.33,
            change0: 0.31,
            prev92: 7.77,
            prev95: 8.27,
            prev0: 7.41,
          ),
          const OilPriceItem(
            province: '山东',
            city: '山东',
            date: '2026-08-29',
            p92: 8.05,
            p95: 8.64,
            p98: 9.39,
            p0: 7.68,
            change92: 0.31,
            change95: 0.33,
            change0: 0.31,
            prev92: 7.74,
            prev95: 8.31,
            prev0: 7.37,
          ),
        ],
        updatedAt: '2026-08-29',
      );

      expect(data.shandong, isNotNull);
      expect(data.shandong!.province, '山东');
      expect(data.shandong!.p92, 8.05);
    });
  });
}
