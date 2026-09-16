class OilPriceItem {
  const OilPriceItem({
    required this.province,
    required this.city,
    required this.date,
    required this.p92,
    required this.p95,
    required this.p98,
    required this.p0,
    required this.change92,
    required this.change95,
    required this.change0,
    required this.prev92,
    required this.prev95,
    required this.prev0,
  });

  factory OilPriceItem.fromJson(Map<String, dynamic> json) {
    final p92 = _toDouble(json['p92'] ?? json['V92']);
    final p95 = _toDouble(json['p95'] ?? json['V95']);
    final p98 = _toDouble(json['p98'] ?? json['V98']) > 0
        ? _toDouble(json['p98'] ?? json['V98'])
        : (p95 > 0 ? double.parse((p95 + 0.75).toStringAsFixed(2)) : 0.0);
    final p0 = _toDouble(json['p0'] ?? json['V0']);

    final change92 = _toDouble(json['change92'] ?? json['ZDE92']);
    final change95 = _toDouble(json['change95'] ?? json['ZDE95']);
    final change0 = _toDouble(json['change0'] ?? json['ZDE0']);

    final prev92 = _toDouble(json['prev92'] ?? json['QE92']);
    final prev95 = _toDouble(json['prev95'] ?? json['QE95']);
    final prev0 = _toDouble(json['prev0'] ?? json['QE0']);

    final prov = (json['province'] ?? json['city'] ?? json['CITYNAME'] ?? '').toString();

    return OilPriceItem(
      province: prov,
      city: (json['city'] ?? prov).toString(),
      date: (json['date'] ?? json['DIM_DATE'] ?? '').toString().split(' ').first,
      p92: p92,
      p95: p95,
      p98: p98,
      p0: p0,
      change92: change92,
      change95: change95,
      change0: change0,
      prev92: prev92 > 0 ? prev92 : (p92 - change92),
      prev95: prev95 > 0 ? prev95 : (p95 - change95),
      prev0: prev0 > 0 ? prev0 : (p0 - change0),
    );
  }

  final String province;
  final String city;
  final String date;
  final double p92;
  final double p95;
  final double p98;
  final double p0;
  final double change92;
  final double change95;
  final double change0;
  final double prev92;
  final double prev95;
  final double prev0;

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}

class ShandongImpact {
  const ShandongImpact({
    required this.current92,
    required this.predicted92,
    required this.diffTank50L,
    required this.advice,
  });

  factory ShandongImpact.fromJson(Map<String, dynamic> json) {
    return ShandongImpact(
      current92: OilPriceItem._toDouble(json['current92']),
      predicted92: OilPriceItem._toDouble(json['predicted92']),
      diffTank50L: OilPriceItem._toDouble(json['diffTank50L']),
      advice: (json['advice'] ?? '').toString(),
    );
  }

  final double current92;
  final double predicted92;
  final double diffTank50L;
  final String advice;
}

class OilPrediction {
  const OilPrediction({
    required this.nextAdjustmentDate,
    required this.nextEffectiveDate,
    required this.workingDay,
    required this.workingDayTotal,
    required this.crudeChangeRate,
    required this.estimatedChangeTons,
    required this.estimatedChangeLiter,
    required this.trendStatus,
    required this.trendLabel,
    required this.isExceedThreshold,
    this.baseCrude = 83.44,
    this.shandongImpact,
  });

  factory OilPrediction.fromJson(Map<String, dynamic> json) {
    return OilPrediction(
      nextAdjustmentDate: (json['nextAdjustmentDate'] ?? '').toString(),
      nextEffectiveDate: (json['nextEffectiveDate'] ?? '').toString(),
      workingDay: (json['workingDay'] as num?)?.toInt() ?? 0,
      workingDayTotal: (json['workingDayTotal'] as num?)?.toInt() ?? 10,
      crudeChangeRate: OilPriceItem._toDouble(json['crudeChangeRate']),
      estimatedChangeTons: (json['estimatedChangeTons'] as num?)?.toInt() ?? 0,
      estimatedChangeLiter: OilPriceItem._toDouble(json['estimatedChangeLiter']),
      trendStatus: (json['trendStatus'] ?? 'hold').toString(),
      trendLabel: (json['trendLabel'] ?? '').toString(),
      isExceedThreshold: json['isExceedThreshold'] == true,
      baseCrude: OilPriceItem._toDouble(json['baseCrude']) > 0
          ? OilPriceItem._toDouble(json['baseCrude'])
          : 83.44,
      shandongImpact: json['shandongImpact'] is Map<String, dynamic>
          ? ShandongImpact.fromJson(json['shandongImpact'] as Map<String, dynamic>)
          : null,
    );
  }

  final String nextAdjustmentDate;
  final String nextEffectiveDate;
  final int workingDay;
  final int workingDayTotal;
  final double crudeChangeRate;
  final int estimatedChangeTons;
  final double estimatedChangeLiter;
  final String trendStatus; // 'up', 'down', 'hold'
  final String trendLabel;
  final bool isExceedThreshold;
  final double baseCrude;
  final ShandongImpact? shandongImpact;
}

class OilPricesData {
  const OilPricesData({
    required this.list,
    required this.updatedAt,
  });

  final List<OilPriceItem> list;
  final String updatedAt;

  OilPriceItem? get shandong {
    for (final item in list) {
      if (item.province.contains('山东') || item.city.contains('山东')) {
        return item;
      }
    }
    return null;
  }
}
