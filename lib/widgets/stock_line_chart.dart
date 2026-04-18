import 'package:fl_chart/fl_chart.dart'; // Package biểu đồ
import 'package:flutter/material.dart';

import '../models/stock.dart'; // StockPricePoint

// =============================================================================
// StockLineChart — Biểu đồ đường giá lớn trong màn hình Chi tiết
// =============================================================================
//
// Khác với MiniSparkline:
//   - MiniSparkline: nhỏ, không tương tác, tự fetch data
//   - StockLineChart: lớn, có trục tọa độ, có tooltip chạm, NHẬN data từ parent
//
// Dữ liệu vào: List<StockPricePoint> (mảng điểm giá đã có sẵn từ parent)
// Hiển thị: LineChart của fl_chart library với:
//   - Trục Y trái: giá (làm tròn, không thập phân)
//   - Trục X dưới: nhãn thời gian (HH:mm hoặc DD/MM)
//   - Đường cong mượt (isCurved: true)
//   - Gradient bên dưới đường
//   - Tooltip khi chạm: hiện "giá\nthời gian"
// =============================================================================

/// Biểu đồ đường giá lớn — dùng trong StockDetailScreen.
///
/// Widget stateless vì không có state nội bộ:
/// mọi dữ liệu nhận qua constructor, không tự fetch API.
class StockLineChart extends StatelessWidget {
  const StockLineChart({
    required this.points,    // Danh sách điểm giá để vẽ
    required this.positive,  // true = giá tăng → màu xanh; false = đỏ
    this.height = 240,       // Chiều cao biểu đồ (px), mặc định 240
    super.key,
  });

  final List<StockPricePoint> points;
  final bool positive;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Nếu không có dữ liệu → hiển thị placeholder text thay vì crash
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

    // Chuyển List<StockPricePoint> → List<FlSpot> cho fl_chart
    // FlSpot(x, y): x = chỉ số thứ tự (0, 1, 2...), y = giá
    // Collection for: syntax nhanh tạo list từ nhóm phép tính
    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].price),
    ];

    // Tính dải giá min/max để biểu đồ fit đúng
    double minY = spots.first.y;
    double maxY = spots.first.y;
    for (final FlSpot spot in spots.skip(1)) { // skip(1): bỏ phần tử đầu (đã dùng làm mặc định)
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }
    // Guard: dải giá < 1đ → mở rộng ±1 để tránh biểu đồ hoàn toàn phẳng
    if ((maxY - minY).abs() < 1) {
      maxY += 1;
      minY -= 1;
    }

    // Màu đường: xanh nếu tăng, đỏ nếu giảm
    final Color lineColor = positive ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          // ── Grid Lines ──────────────────────────────────
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false, // Ẩn đường dọc (chỉ ngang)
            horizontalInterval: (maxY - minY) / 4, // Chia 4 khoảng đều
            getDrawingHorizontalLine: (double value) => FlLine(
              color: Colors.white.withOpacity(.05), // Rất mờ, gần như tàng hình
              strokeWidth: 1,
            ),
          ),

          // ── Trục tọa độ ─────────────────────────────────
          titlesData: FlTitlesData(
            show: true,
            // Trục Y trái: hiển thị giá
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48, // Chiều rộng dành cho label trục Y
                getTitlesWidget: (double value, TitleMeta meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      value.toStringAsFixed(0), // Không thập phân: "125000"
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white.withOpacity(.4)),
                    ),
                  );
                },
              ),
            ),
            // Trục X dưới: hiển thị time labels
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                // Hiển thị khoảng N/4 label đều (tránh chồng chéo)
                // clamp(1, 8): đảm bảo interval trong khoảng [1, 8]
                interval: (spots.length / 4).clamp(1, 8).toDouble(),
                getTitlesWidget: (double value, TitleMeta meta) {
                  final int index = value.round().clamp(0, points.length - 1);
                  final StockPricePoint point = points[index];
                  return Transform.translate(
                    offset: const Offset(0, 4), // Dịch nhẹ xuống để tránh dính vào trục
                    child: Text(
                      point.timeLabel, // Nhãn thời gian (đã format sẵn trong StockPricePoint)
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.white.withOpacity(.4)),
                    ),
                  );
                },
              ),
            ),
            // Ẩn trục phải và trên
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),

          // ── Border ──────────────────────────────────────
          borderData: FlBorderData(show: false), // Không có border xung quanh biểu đồ

          // ── Phạm vi trục ────────────────────────────────
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,

          // ── Tooltip khi chạm ────────────────────────────
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true, // fl_chart tự xử lý gesture
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.black.withOpacity(.6),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  // Lấy điểm tương ứng từ danh sách gốc (dùng x index)
                  final StockPricePoint p =
                      points[touchedSpot.x.toInt().clamp(0, points.length - 1)];
                  return LineTooltipItem(
                    // Format: "125000 đ\n14:30" — \n ngắt dòng trong tooltip
                    '${p.price.toStringAsFixed(0)} đ\n${p.timeLabel}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  );
                }).toList();
              },
            ),
          ),

          // ── Dữ liệu đường vẽ ────────────────────────────
          lineBarsData: <LineChartBarData>[
            LineChartBarData(
              spots: spots,
              isCurved: true,  // Đường cong Bezier (mượt hơn đường thẳng)
              color: lineColor,
              barWidth: 3,     // Độ dày đường (3px = vừa đủ nhìn rõ)
              dotData: const FlDotData(show: false), // Ẩn dots để gọn gàng
              // Vùng tô màu gradient bên dưới đường giá
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: <Color>[
                    lineColor.withOpacity(.3),  // Đậm ở trên (gần đường)
                    lineColor.withOpacity(.05), // Mờ ở dưới (gần trục X)
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
