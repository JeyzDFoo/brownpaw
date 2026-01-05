import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/daily_mean.dart';
import '../models/river_run.dart';

/// A chart widget displaying historical flow data over time.
class FlowChartWidget extends StatelessWidget {
  final List<DailyMean> flowData;
  final RiverRun run;
  final bool showDischarge;

  const FlowChartWidget({
    super.key,
    required this.flowData,
    required this.run,
    this.showDischarge = true,
  });

  @override
  Widget build(BuildContext context) {
    if (flowData.isEmpty) {
      return _buildEmptyState(context);
    }

    final dataToDisplay = showDischarge
        ? flowData.where((d) => d.discharge != null).toList()
        : flowData.where((d) => d.level != null).toList();

    if (dataToDisplay.isEmpty) {
      return _buildEmptyState(context);
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChartHeader(context),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              _buildChartData(context, dataToDisplay),
              duration: const Duration(milliseconds: 250),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartHeader(BuildContext context) {
    final theme = Theme.of(context);
    final label = showDischarge ? 'Flow' : 'Level';
    final unit = showDischarge ? run.flowUnit : 'm';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label History (${flowData.length} days)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            unit,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            Text(
              'No historical flow data available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData(BuildContext context, List<DailyMean> data) {
    final theme = Theme.of(context);
    final spots = _createSpots(data);

    // Calculate min/max values for Y-axis
    final values = spots.map((spot) => spot.y).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxValue - minValue) * 0.1;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxValue - minValue) / 4,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: theme.colorScheme.outline.withOpacity(0.2),
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: (spots.length / 5).ceilToDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= data.length) {
                return const SizedBox.shrink();
              }
              final date = data[index].dateTime;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${date.month}/${date.day}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            interval: (maxValue - minValue) / 4,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toStringAsFixed(1),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
          bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
        ),
      ),
      minX: 0,
      maxX: (data.length - 1).toDouble(),
      minY: minValue - padding,
      maxY: maxValue + padding,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: theme.primaryColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: data.length <= 30,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: theme.primaryColor,
                strokeWidth: 1,
                strokeColor: theme.colorScheme.surface,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: theme.primaryColor.withOpacity(0.1),
          ),
        ),
        // Add recommended flow range if available
        if (showDischarge && run.minRecommendedFlow != null)
          _buildRecommendedFlowLine(
            context,
            data.length,
            run.minRecommendedFlow!,
            Colors.green.withOpacity(0.5),
          ),
        if (showDischarge && run.maxRecommendedFlow != null)
          _buildRecommendedFlowLine(
            context,
            data.length,
            run.maxRecommendedFlow!,
            Colors.orange.withOpacity(0.5),
          ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => theme.colorScheme.surface,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final index = spot.x.toInt();
              if (index < 0 || index >= data.length) {
                return null;
              }
              final date = data[index].dateTime;
              final value = spot.y.toStringAsFixed(1);
              final unit = showDischarge ? run.flowUnit : 'm';
              return LineTooltipItem(
                '${date.month}/${date.day}/${date.year}\n$value $unit',
                theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  List<FlSpot> _createSpots(List<DailyMean> data) {
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      final value = showDischarge ? data[i].discharge : data[i].level;
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
      }
    }
    return spots;
  }

  LineChartBarData _buildRecommendedFlowLine(
    BuildContext context,
    int dataLength,
    double value,
    Color color,
  ) {
    return LineChartBarData(
      spots: [FlSpot(0, value), FlSpot((dataLength - 1).toDouble(), value)],
      isCurved: false,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: [5, 5],
    );
  }
}
