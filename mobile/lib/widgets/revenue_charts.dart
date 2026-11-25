import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RevenueAnalyticsPanel extends StatelessWidget {
  final Map<String, dynamic> analytics;
  const RevenueAnalyticsPanel({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final dailyRaw = (analytics['dailyRevenue'] as List?) ?? [];
    final daily = dailyRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final breakdownRaw = (analytics['paymentBreakdown'] as List?) ?? [];
    final breakdown = breakdownRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final lowStockCount = (analytics['lowStockCount'] as num?)?.toInt() ?? 0;
    final avgOrder = (analytics['avgOrderValue'] as num?)?.toDouble() ?? 0.0;
    final voidCount = (analytics['voidedItemCount'] as num?)?.toInt() ?? 0;

    final maxRev = daily.isEmpty
        ? 1.0
        : daily
            .map((d) => (d['revenue'] as num?)?.toDouble() ?? 0.0)
            .fold<double>(1.0, (a, b) => a > b ? a : b);

    final fmt = NumberFormat.compactCurrency(locale: 'vi_VN', symbol: 'đ');

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _miniMetric('AOV (TB/đơn)', fmt.format(avgOrder), const Color(0xFF0284C7)),
              _miniMetric('Món bị hủy', '$voidCount món', const Color(0xFFDC2626)),
              _miniMetric(
                'Cảnh báo kho',
                '$lowStockCount NL sắp hết',
                lowStockCount > 0 ? const Color(0xFFD97706) : const Color(0xFF059669),
              ),
            ],
          ),
          if (daily.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Biểu đồ doanh thu 7 ngày gần nhất',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: daily.map((d) {
                  final rev = (d['revenue'] as num?)?.toDouble() ?? 0.0;
                  final ratio = maxRev > 0 ? (rev / maxRev).clamp(0.06, 1.0) : 0.06;
                  final label = (d['label'] ?? '').toString();
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            rev > 0 ? fmt.format(rev) : '0',
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 66 * ratio,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF2563EB), Color(0xFF0F172A)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Tỷ trọng kênh thanh toán',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: breakdown.map((b) {
                final method = (b['method'] ?? '').toString();
                final pct = (b['percent'] as num?)?.toDouble() ?? 0.0;
                final amt = (b['amount'] as num?)?.toDouble() ?? 0.0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    '$method: ${pct.toStringAsFixed(0)}% (${fmt.format(amt)})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(val, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
