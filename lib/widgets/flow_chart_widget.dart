import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/realtime_flow.dart';

class FlowChart extends StatelessWidget {
  final RealtimeFlow flowData;

  const FlowChart({super.key, required this.flowData});

  @override
  Widget build(BuildContext context) {
    if (flowData.readings.isEmpty) {
      return const Center(child: Text('No recent flow data available.'));
    }

    final spots = <FlSpot>[];
    for (final reading in flowData.readings) {
      if (reading.discharge != null) {
        spots.add(
          FlSpot(
            reading.timestamp.millisecondsSinceEpoch.toDouble(),
            reading.discharge!,
          ),
        );
      }
    }

    if (spots.isEmpty) {
      return const Center(child: Text('No discharge data to display.'));
    }

    // Calculate y-axis range with deadband (10% padding on each side)
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yRange = maxY - minY;
    final yDeadband = yRange * 0.1;

    return LineChart(
      LineChartData(
        minY: minY - yDeadband,
        maxY: maxY + yDeadband,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: null, // Let fl_chart decide
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
              strokeWidth: 0.8,
              dashArray: [5, 5], // Dashed lines
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: null,
              getTitlesWidget: (value, meta) {
                // Skip labels that are too close to the edges to prevent overlap
                final range = meta.max - meta.min;
                if (meta.max - value < range * 0.03 ||
                    value - meta.min < range * 0.03) {
                  return const SizedBox.shrink();
                }

                // Format large numbers more compactly
                String label;
                if (value >= 1000) {
                  label = '${(value / 1000).toStringAsFixed(1)}k';
                } else if (value >= 100) {
                  label = value.toStringAsFixed(0);
                } else if (value >= 10) {
                  label = value.toStringAsFixed(1);
                } else {
                  label = value.toStringAsFixed(2);
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: (spots.last.x - spots.first.x) / 4,
              getTitlesWidget: (value, meta) {
                // Suppress the label at the first data point to avoid crowding
                if (value == spots.first.x) {
                  return const SizedBox.shrink();
                }
                final timestamp = DateTime.fromMillisecondsSinceEpoch(
                  value.toInt(),
                ).toLocal();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('MMM d\nh:mm a').format(timestamp),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
            width: 1.2,
          ),
        ),
        clipData: const FlClipData.all(),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final timestamp = DateTime.fromMillisecondsSinceEpoch(
                  touchedSpot.x.toInt(),
                ).toLocal();
                final discharge = touchedSpot.y;
                return LineTooltipItem(
                  '${DateFormat('MMM d, h:mm a').format(timestamp)}\n${discharge.toStringAsFixed(2)} m³/s',
                  TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.4,
            barWidth: 3,
            color: Theme.of(context).colorScheme.primary,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.4),
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.primary.withOpacity(0.05),
                ],
              ),
            ),
            showingIndicators: [],
          ),
        ],
      ),
    );
  }
}
