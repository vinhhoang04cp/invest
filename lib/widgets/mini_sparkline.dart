import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/stock.dart';
import '../services/api_service.dart';

class MiniSparkline extends StatefulWidget {
  const MiniSparkline({
    required this.symbol,
    this.height = 48,
    this.lineColor,
    super.key,
  });

  final String symbol;
  final double height;
  final Color? lineColor;

  static final Map<String, Future<List<StockPricePoint>>> _cache =
      <String, Future<List<StockPricePoint>>>{};

  static void invalidateCache([String? symbol]) {
    if (symbol == null) {
      _cache.clear();
    } else {
      _cache.remove(symbol);
    }
  }

  @override
  State<MiniSparkline> createState() => _MiniSparklineState();
}

class _MiniSparklineState extends State<MiniSparkline> {

  late Future<List<StockPricePoint>> _future;
  final ApiService _apiService = ApiService.instance;

  @override
  void initState() {
    super.initState();
    _future = MiniSparkline._cache[widget.symbol] ??=
        _apiService.fetchIntradayPrices(widget.symbol);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: FutureBuilder<List<StockPricePoint>>(
        future: MiniSparkline._cache[widget.symbol] ?? _future,
        builder: (BuildContext context, AsyncSnapshot<List<StockPricePoint>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SparklineSkeleton();
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                '—',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            );
          }
          final List<StockPricePoint> points = snapshot.data!;
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
            maxY = maxY + 1;
            minY = minY - 1;
          }
          final Color lineColor = widget.lineColor ?? Theme.of(context).colorScheme.primary;
          return LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              minX: 0,
              maxX: (spots.length - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: lineColor,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: <Color>[
                        lineColor.withOpacity(.25),
                        lineColor.withOpacity(.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SparklineSkeleton extends StatelessWidget {
  const _SparklineSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.3),
          ),
        );
      },
    );
  }
}
