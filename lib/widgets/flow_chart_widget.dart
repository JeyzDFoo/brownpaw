import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/realtime_flow.dart';
import '../models/historical_flow.dart';

class ChartDisplayMode {
  final String id;
  final String label;
  final bool isRealtime;
  final int? year;
  final int days;

  const ChartDisplayMode({
    required this.id,
    required this.label,
    required this.isRealtime,
    this.year,
    required this.days,
  });

  static const twoWeeks = ChartDisplayMode(
    id: 'twoWeeks',
    label: '2 weeks',
    isRealtime: true,
    days: 14,
  );

  static const thirtyDays = ChartDisplayMode(
    id: 'thirtyDays',
    label: '30 days',
    isRealtime: true,
    days: 30,
  );

  static ChartDisplayMode forYear(int year) => ChartDisplayMode(
    id: 'year_$year',
    label: '$year',
    isRealtime: false,
    year: year,
    days: 365,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartDisplayMode &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class FlowChart extends StatefulWidget {
  final RealtimeFlow? realtimeData;
  final HistoricalFlow? historicalData;
  final String stationId;

  const FlowChart({
    super.key,
    this.realtimeData,
    this.historicalData,
    required this.stationId,
  });

  @override
  State<FlowChart> createState() => _FlowChartState();
}

class _FlowChartState extends State<FlowChart> {
  ChartDisplayMode _displayMode = ChartDisplayMode.thirtyDays;
  List<ChartDisplayMode> _availableModes = [];

  @override
  void initState() {
    super.initState();
    _updateAvailableModes();
  }

  @override
  void didUpdateWidget(FlowChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.historicalData != widget.historicalData) {
      _updateAvailableModes();
    }
  }

  void _updateAvailableModes() {
    final modes = <ChartDisplayMode>[
      ChartDisplayMode.twoWeeks,
      ChartDisplayMode.thirtyDays,
    ];

    // Add year options based on available historical data
    if (widget.historicalData != null &&
        widget.historicalData!.readings.isNotEmpty) {
      final years =
          widget.historicalData!.readings
              .map((r) => r.dateTime.year)
              .toSet()
              .toList()
            ..sort((a, b) => b.compareTo(a)); // Most recent first

      for (final year in years) {
        modes.add(ChartDisplayMode.forYear(year));
      }
    }

    setState(() {
      _availableModes = modes;
      // Reset to default if current mode is no longer available
      if (!_availableModes.contains(_displayMode)) {
        _displayMode = ChartDisplayMode.thirtyDays;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Display mode selector
        _buildDisplayModeSelector(context),
        const SizedBox(height: 12),

        // Chart
        Expanded(child: _buildChart(context)),
      ],
    );
  }

  Widget _buildDisplayModeSelector(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: _availableModes.map((mode) {
          final isSelected = _displayMode == mode;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(mode.label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _displayMode = mode;
                  });
                }
              },
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    // Get the appropriate data based on display mode
    final spots = _getChartData();

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
                // Skip first/last labels to prevent crowding
                if (value == spots.first.x || value == spots.last.x) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _formatXAxisLabel(value),
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
                return LineTooltipItem(
                  _formatTooltip(touchedSpot.x, touchedSpot.y),
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

  List<FlSpot> _getChartData() {
    final spots = <FlSpot>[];

    if (_displayMode.isRealtime) {
      // Use realtime data
      if (widget.realtimeData == null) return spots;

      final cutoffDate = DateTime.now().subtract(
        Duration(days: _displayMode.days),
      );

      for (final reading in widget.realtimeData!.readings) {
        if (reading.discharge != null &&
            reading.timestamp.isAfter(cutoffDate)) {
          spots.add(
            FlSpot(
              reading.timestamp.millisecondsSinceEpoch.toDouble(),
              reading.discharge!,
            ),
          );
        }
      }
    } else {
      // Use historical data for specific year
      if (widget.historicalData == null) return spots;

      final targetYear = _displayMode.year;
      if (targetYear == null) return spots;

      for (final reading in widget.historicalData!.readings) {
        if (reading.discharge != null && reading.dateTime.year == targetYear) {
          spots.add(
            FlSpot(
              reading.dateTime.millisecondsSinceEpoch.toDouble(),
              reading.discharge!,
            ),
          );
        }
      }
    }

    return spots;
  }

  String _formatXAxisLabel(double value) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      value.toInt(),
    ).toLocal();

    if (_displayMode.isRealtime) {
      // For realtime: Show date and time
      return DateFormat('MMM d\nh:mm a').format(timestamp);
    } else {
      // For yearly: Show month and day
      return DateFormat('MMM d').format(timestamp);
    }
  }

  String _formatTooltip(double x, double y) {
    final timestamp = DateTime.fromMillisecondsSinceEpoch(x.toInt()).toLocal();

    if (_displayMode.isRealtime) {
      return '${DateFormat('MMM d, h:mm a').format(timestamp)}\n${y.toStringAsFixed(2)} m³/s';
    } else {
      return '${DateFormat('MMM d, yyyy').format(timestamp)}\n${y.toStringAsFixed(2)} m³/s';
    }
  }
}
