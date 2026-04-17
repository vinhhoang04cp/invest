import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/stock.dart';

/// Khối biểu đồ đường chính hiển thị diễn biến giá chứng khoán dùng chung trong trang Chi tiết.
/// Khác với Sparkline, biểu đồ này to hơn, có hiển thị trục tọa độ và có thể tương tác (chạm để xem giá).
class StockLineChart extends StatelessWidget {
  const StockLineChart({
    required this.points,
    required this.positive,
    this.height = 240,
    super.key,
  });

  final List<StockPricePoint> points;
  final bool positive;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Chưa có dữ liệu biểu đồ',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].price),
    ];
    double minY = spots.first.y;
    double maxY = spots.first.y;
    for (final FlSpot spot in spots.skip(1)) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }
    if ((maxY - minY).abs() < 1) {
      maxY += 1;
      minY -= 1;
    }

    final Color lineColor = positive ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (double value) => FlLine(
              color: Colors.white.withOpacity(.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      value.toStringAsFixed(0),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white.withOpacity(.4)),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (spots.length / 4).clamp(1, 8).toDouble(),
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.round().clamp(0, points.length - 1);
                  final StockPricePoint point = points[index];
                  return Transform.translate(
                    offset: const Offset(0, 4),
                    child: Text(
                      point.timeLabel,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white.withOpacity(.4)),
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.black.withOpacity(.6),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final StockPricePoint p = points[touchedSpot.x.toInt().clamp(0, points.length - 1)];
                  return LineTooltipItem(
                    '${p.price.toStringAsFixed(0)} đ\n${p.timeLabel}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: <Color>[
                    lineColor.withOpacity(.3),
                    lineColor.withOpacity(.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
