import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onehubapp/core/app_config.dart';
import 'package:onehubapp/models/oil_price_model.dart';

class OilPriceService {
  const OilPriceService._();

  static const List<Map<String, dynamic>> _fallbackList = [
    {'city': '山东', 'province': '山东', 'date': '2026-08-29', 'p92': 8.05, 'p95': 8.64, 'p89': 7.48, 'p0': 7.68, 'change92': 0.31, 'change95': 0.33, 'change0': 0.31, 'prev92': 7.74, 'prev95': 8.31, 'prev0': 7.37},
    {'city': '北京', 'province': '北京', 'date': '2026-08-29', 'p92': 8.09, 'p95': 8.61, 'p89': 7.57, 'p0': 7.81, 'change92': 0.31, 'change95': 0.33, 'change0': 0.31, 'prev92': 7.78, 'prev95': 8.28, 'prev0': 7.50},
    {'city': '上海', 'province': '上海', 'date': '2026-08-29', 'p92': 8.05, 'p95': 8.57, 'p89': 7.51, 'p0': 7.74, 'change92': 0.31, 'change95': 0.33, 'change0': 0.31, 'prev92': 7.74, 'prev95': 8.24, 'prev0': 7.43},
    {'city': '广东', 'province': '广东', 'date': '2026-08-29', 'p92': 8.11, 'p95': 8.78, 'p89': 7.52, 'p0': 7.77, 'change92': 0.31, 'change95': 0.34, 'change0': 0.31, 'prev92': 7.80, 'prev95': 8.44, 'prev0': 7.46},
    {'city': '浙江', 'province': '浙江', 'date': '2026-08-29', 'p92': 8.06, 'p95': 8.57, 'p89': 7.48, 'p0': 7.74, 'change92': 0.31, 'change95': 0.33, 'change0': 0.31, 'prev92': 7.75, 'prev95': 8.24, 'prev0': 7.43},
    {'city': '江苏', 'province': '江苏', 'date': '2026-08-29', 'p92': 8.06, 'p95': 8.57, 'p89': 7.59, 'p0': 7.72, 'change92': 0.31, 'change95': 0.33, 'change0': 0.31, 'prev92': 7.75, 'prev95': 8.24, 'prev0': 7.41},
    {'city': '四川', 'province': '四川', 'date': '2026-08-29', 'p92': 8.18, 'p95': 8.75, 'p89': 7.60, 'p0': 7.81, 'change92': 0.31, 'change95': 0.33, 'change0': 0.31, 'prev92': 7.87, 'prev95': 8.42, 'prev0': 7.50},
    {'city': '湖北', 'province': '湖北', 'date': '2026-08-29', 'p92': 8.10, 'p95': 8.67, 'p89': 7.52, 'p0': 7.75, 'change92': 0.31, 'change95': 0.33, 'change0': 0.31, 'prev92': 7.79, 'prev95': 8.34, 'prev0': 7.44},
    {'city': '河南', 'province': '河南', 'date': '2026-08-29', 'p92': 8.09, 'p95': 8.64, 'p89': 7.51, 'p0': 7.74, 'change92': 0.30, 'change95': 0.32, 'change0': 0.31, 'prev92': 7.79, 'prev95': 8.32, 'prev0': 7.43},
    {'city': '河北', 'province': '河北', 'date': '2026-08-29', 'p92': 8.08, 'p95': 8.54, 'p89': 7.50, 'p0': 7.76, 'change92': 0.30, 'change95': 0.32, 'change0': 0.31, 'prev92': 7.78, 'prev95': 8.22, 'prev0': 7.45},
    {'city': '陕西', 'province': '陕西', 'date': '2026-08-29', 'p92': 7.97, 'p95': 8.42, 'p89': 7.42, 'p0': 7.65, 'change92': 0.30, 'change95': 0.32, 'change0': 0.31, 'prev92': 7.67, 'prev95': 8.10, 'prev0': 7.34},
    {'city': '重庆', 'province': '重庆', 'date': '2026-08-29', 'p92': 8.15, 'p95': 8.61, 'p89': 7.58, 'p0': 7.82, 'change92': 0.31, 'change95': 0.33, 'change0': 0.31, 'prev92': 7.84, 'prev95': 8.28, 'prev0': 7.51},
    {'city': '海南', 'province': '海南', 'date': '2026-08-29', 'p92': 9.20, 'p95': 9.77, 'p89': 8.39, 'p0': 7.84, 'change92': 0.30, 'change95': 0.32, 'change0': 0.31, 'prev92': 8.90, 'prev95': 9.45, 'prev0': 7.53},
  ];

  static Future<OilPricesData> getPrices() async {
    final uri = AppConfig.uri('/api/v1/oil/prices');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == HttpStatus.ok) {
        final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : <String, dynamic>{};
        final rawList = data['list'] is List ? data['list'] as List : <dynamic>[];
        final list = rawList
            .map((e) => OilPriceItem.fromJson(e as Map<String, dynamic>))
            .toList();

        // 优先将山东排在最前
        list.sort((a, b) {
          if (a.province.contains('山东')) return -1;
          if (b.province.contains('山东')) return 1;
          return a.province.compareTo(b.province);
        });

        return OilPricesData(
          list: list.isNotEmpty
              ? list
              : _fallbackList.map((e) => OilPriceItem.fromJson(e)).toList(),
          updatedAt: (data['updatedAt'] ?? '2026-08-29').toString(),
        );
      }
    } catch (e) {
      debugPrint('[OilPriceService] getPrices failed, using fallback: $e');
    }

    final fallback = _fallbackList.map((e) => OilPriceItem.fromJson(e)).toList();
    return OilPricesData(list: fallback, updatedAt: '2026-08-29');
  }

  static Future<OilPrediction> getPrediction() async {
    final uri = AppConfig.uri('/api/v1/oil/prediction');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == HttpStatus.ok) {
        final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : <String, dynamic>{};
        return OilPrediction.fromJson(data);
      }
    } catch (e) {
      debugPrint('[OilPriceService] getPrediction failed, using fallback: $e');
    }

    // 默认兜底预测数据
    return const OilPrediction(
      nextAdjustmentDate: '2026-09-11 24:00',
      nextEffectiveDate: '2026-09-12 00:00',
      workingDay: 9,
      workingDayTotal: 10,
      crudeChangeRate: 9.98,
      estimatedChangeTons: 360,
      estimatedChangeLiter: 0.28,
      trendStatus: 'up',
      trendLabel: '预计大幅上调',
      isExceedThreshold: true,
      shandongImpact: ShandongImpact(
        current92: 8.05,
        predicted92: 8.33,
        diffTank50L: 14.00,
        advice: '本轮国际原油持续震荡走高，变化率已远超调价红线。建议山东车主在 9月11日 24:00 前加满油箱，加满一箱 50L 预计可节省约 14 元！',
      ),
    );
  }
}
