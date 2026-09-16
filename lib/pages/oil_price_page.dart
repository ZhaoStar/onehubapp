import 'package:flutter/material.dart';
import 'package:onehubapp/core/app_colors.dart';
import 'package:onehubapp/models/oil_price_model.dart';
import 'package:onehubapp/services/oil_price_service.dart';

class OilPricePage extends StatefulWidget {
  const OilPricePage({required this.username, super.key});

  final String username;

  @override
  State<OilPricePage> createState() => _OilPricePageState();
}

class _OilPricePageState extends State<OilPricePage> {
  bool _isLoading = false;
  OilPricesData? _pricesData;
  OilPrediction? _prediction;
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        OilPriceService.getPrices(),
        OilPriceService.getPrediction(),
      ]);
      if (!mounted) return;
      setState(() {
        _pricesData = results[0] as OilPricesData;
        _prediction = results[1] as OilPrediction;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: const Text(
          '全国及山东油价查询',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: '刷新数据',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading && _pricesData == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 下一轮油价调整日期与预测
                    _buildAdjustmentCard(),
                    const SizedBox(height: 16),
                    // 2. 山东省当前油价详情
                    _buildShandongCard(),
                    const SizedBox(height: 16),
                    // 3. 全国主要省市当前油价列表
                    _buildNationwideCard(),
                  ],
                ),
              ),
            ),
    );
  }

  /// 1. 下一轮油价调整日期与趋势预测
  Widget _buildAdjustmentCard() {
    final pred = _prediction;
    final isUp = pred?.trendStatus == 'up';
    final isDown = pred?.trendStatus == 'down';

    final Color statusColor = isUp
        ? const Color(0xFFE11D48)
        : (isDown ? const Color(0xFF16A34A) : const Color(0xFF64748B));
    final Color statusBg = isUp
        ? const Color(0xFFFFF1F2)
        : (isDown ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF0F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.event_note_rounded, color: Color(0xFFD97706), size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '下轮油价调整窗口',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '调价周期进度: 第 ${pred?.workingDay ?? 9}/${pred?.workingDayTotal ?? 10} 个工作日',
                      style: const TextStyle(fontSize: 12, color: AppColors.placeholder),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  pred?.trendLabel ?? '预计调价',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 下次调价时间大字凸显
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    const Text(
                      '预计调整时间',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    ),
                    const Spacer(),
                    Text(
                      '生效时间: ${pred?.nextEffectiveDate ?? '2026-09-12 00:00'}',
                      style: const TextStyle(fontSize: 11, color: AppColors.placeholder),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  pred?.nextAdjustmentDate ?? '2026-09-11 24:00',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 预测数据指标行
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: '预估调价幅度',
                  value: '${isUp ? '+' : (isDown ? '-' : '')}${pred?.estimatedChangeLiter ?? 0.28} 元/升',
                  subValue: '${isUp ? '+' : ''}${pred?.estimatedChangeTons ?? 360} 元/吨',
                  valueColor: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: '原油变化率',
                  value: '${(pred?.crudeChangeRate ?? 9.98) > 0 ? '+' : ''}${pred?.crudeChangeRate ?? 9.98}%',
                  subValue: '基准原油: \$${pred?.baseCrude ?? 83.44}',
                  valueColor: statusColor,
                ),
              ),
            ],
          ),
          if (pred?.shandongImpact?.advice != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.tips_and_updates_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pred!.shandongImpact!.advice,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subValue,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEDF0F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.placeholder)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: valueColor),
          ),
          const SizedBox(height: 1),
          Text(subValue, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  /// 2. 山东省当前油价（核心重点展示）
  Widget _buildShandongCard() {
    final sd = _pricesData?.shandong ??
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
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(Icons.local_gas_station_rounded, color: Color(0xFF0284C7), size: 20),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '山东省当前油价',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.verified_rounded, size: 16, color: Color(0xFF0284C7)),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      '指导零售限价 · 实时汇算',
                      style: TextStyle(fontSize: 12, color: AppColors.placeholder),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sd.date.isNotEmpty ? '更新: ${sd.date}' : '最新基准',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 四大标号油价宫格
          Row(
            children: [
              Expanded(
                child: _buildOilPriceBox(
                  fuelName: '92# 汽油',
                  price: sd.p92,
                  change: sd.change92,
                  accentColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                  prevPrice: sd.prev92,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOilPriceBox(
                  fuelName: '95# 汽油',
                  price: sd.p95,
                  change: sd.change95,
                  accentColor: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF5F3FF),
                  prevPrice: sd.prev95,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildOilPriceBox(
                  fuelName: '98# 汽油',
                  price: sd.p98,
                  change: sd.change95,
                  accentColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                  prevPrice: sd.p98 > 0 ? (sd.p98 - sd.change95) : 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOilPriceBox(
                  fuelName: '0# 柴油',
                  price: sd.p0,
                  change: sd.change0,
                  accentColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                  prevPrice: sd.prev0,
                ),
              ),
            ],
          ),
          // 预测对比提示
          if (_prediction?.shandongImpact != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '预计下轮山东 92# 为 ¥${_prediction!.shandongImpact!.predicted92}/升，一箱 50L 调价差额约 ${_prediction!.shandongImpact!.diffTank50L} 元',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOilPriceBox({
    required String fuelName,
    required double price,
    required double change,
    required Color accentColor,
    required Color bgColor,
    required double prevPrice,
  }) {
    final isUp = change > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fuelName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
              if (change != 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isUp ? const Color(0xFFFFE4E6) : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 10,
                        color: isUp ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                      ),
                      Text(
                        '${isUp ? '+' : ''}${change.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isUp ? const Color(0xFFE11D48) : const Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '¥${price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 3),
              const Text(
                '/升',
                style: TextStyle(fontSize: 11, color: AppColors.placeholder),
              ),
            ],
          ),
          if (prevPrice > 0) ...[
            const SizedBox(height: 2),
            Text(
              '上期: ¥${prevPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 10, color: AppColors.placeholder),
            ),
          ],
        ],
      ),
    );
  }

  /// 3. 全国其他省市油价对比参考
  Widget _buildNationwideCard() {
    final allList = _pricesData?.list ?? [];
    final filtered = _searchKeyword.isEmpty
        ? allList
        : allList.where((e) => e.province.contains(_searchKeyword) || e.city.contains(_searchKeyword)).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDF0F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '全国各省市当前油价',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '各地区指导零售限价横向对比',
                    style: TextStyle(fontSize: 11, color: AppColors.placeholder),
                  ),
                ],
              ),
              Text(
                '共 ${allList.length} 省市',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 简易省份搜索框
          TextField(
            decoration: InputDecoration(
              hintText: '搜索省份，如：北京、广东...',
              hintStyle: const TextStyle(color: AppColors.placeholder, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.placeholder),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            onChanged: (val) => setState(() => _searchKeyword = val.trim()),
          ),
          const SizedBox(height: 12),
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('省份', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                Expanded(flex: 3, child: Text('92#汽油', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                Expanded(flex: 3, child: Text('95#汽油', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
                Expanded(flex: 3, child: Text('0#柴油', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 列表项
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final item = filtered[index];
              final isShandong = item.province.contains('山东');
              return Container(
                color: isShandong ? const Color(0xFFEFF6FF) : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Text(
                            item.province,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isShandong ? FontWeight.w800 : FontWeight.w600,
                              color: isShandong ? const Color(0xFF0284C7) : AppColors.textPrimary,
                            ),
                          ),
                          if (isShandong) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('本省', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '¥${item.p92.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isShandong ? FontWeight.w800 : FontWeight.w500,
                          color: isShandong ? const Color(0xFF0284C7) : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '¥${item.p95.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        '¥${item.p0.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
