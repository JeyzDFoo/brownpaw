import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/realtime_flow.dart';

class FlowChart extends StatefulWidget {
  final RealtimeFlow flowData;
  const FlowChart({super.key, required this.flowData});

  @override
  State<FlowChart> createState() => _FlowChartState();
}

class _FlowChartState extends State<FlowChart> {
  int? _selectedSpotIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.flowData.readings.isEmpty) {
      return const Center(child: Text('No recent flow data available.'));
    }

    final spots = <FlSpot>[];
    for (final reading in widget.flowData.readings) {
      if (reading.level != null) {
        spots.add(
          FlSpot(
            reading.timestamp.millisecondsSinceEpoch.toDouble(),
            reading.level!,
          ),
        );
      }
    }

    if (spots.isEmpty) {
      return const Center(child: Text('No level data to display.'));
    }

    return LineChart(
      LineChartData(
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
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    '${value.toStringAsFixed(1)}m',
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
                );
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
        lineTouchData: LineTouchData(
          handleBuiltInTouches: false, // Disable default behavior
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (response == null || response.lineBarSpots == null) {
              return;
            }
            if (event is FlTapUpEvent) {
              final index = response.lineBarSpots!.first.spotIndex;
              setState(() {
                if (_selectedSpotIndex == index) {
                  _selectedSpotIndex = null; // Untoggle on second tap
                } else {
                  _selectedSpotIndex = index;
                }
              });
            }
          },
          getTouchedSpotIndicator:
              (LineChartBarData barData, List<int> spotIndexes) {
                return spotIndexes.map((spotIndex) {
                  return TouchedSpotIndicatorData(
                    FlLine(
                      color: Colors.transparent, // Don't show the vertical line
                    ),
                    FlDotData(
                      getDotPainter: (spot, percent, barData, index) {
                        // This is the persistent dot on the chart
                        return FlDotCirclePainter(
                          radius: 8,
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 2,
                          strokeColor: Theme.of(context).colorScheme.surface,
                        );
                      },
                    ),
                  );
                }).toList();
              },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (LineBarSpot spot) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),

            tooltipBorder: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final timestamp = DateTime.fromMillisecondsSinceEpoch(
                  spot.x.toInt(),
                );
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(2)} m\n${DateFormat('MMM d, h:mm a').format(timestamp)}',
                  TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                );
              }).toList();
            },
          ),
        ),
        showingTooltipIndicators: _selectedSpotIndex != null
            ? [
                ShowingTooltipIndicators([
                  LineBarSpot(
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    0, // Bar index (we only have one line)
                    spots[_selectedSpotIndex!],
                  ),
                ]),
              ]
            : [],
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
            showingIndicators: _selectedSpotIndex != null
                ? [_selectedSpotIndex!]
                : [],
          ),
        ],
      ),
    );
  }
}
