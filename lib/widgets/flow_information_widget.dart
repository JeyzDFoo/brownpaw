import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_run.dart';
import '../providers/flow_data_provider.dart';
import 'flow_chart_widget.dart';

/// A widget that displays flow information for a river run including
/// recommended and optimal flow ranges, as well as gauge station data,
/// current flow readings, and historical flow charts.
class FlowInformationWidget extends ConsumerWidget {
  final RiverRun run;
  final EdgeInsets? padding;

  const FlowInformationWidget({super.key, required this.run, this.padding});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFlowData =
        run.minRecommendedFlow != null ||
        run.maxRecommendedFlow != null ||
        run.optimalFlowMin != null ||
        run.optimalFlowMax != null;

    if (!hasFlowData && run.gaugeStation == null && run.stationId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context),
          const SizedBox(height: 16),
          _buildContent(context, ref, hasFlowData),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.water_drop, color: Theme.of(context).primaryColor, size: 24),
        const SizedBox(width: 8),
        Text(
          'Flow Information',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, bool hasFlowData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current flow reading (if station ID available)
        if (run.stationId != null) ...[
          _buildCurrentFlow(context, ref),
          const SizedBox(height: 16),
        ],
        // Flow ranges
        if (hasFlowData) ...[
          _buildFlowRanges(context),
          const SizedBox(height: 16),
        ],
        // Gauge station info
        if (run.gaugeStation != null) ...[
          _buildGaugeInfo(context),
          const SizedBox(height: 16),
        ],
        // Historical flow chart
        if (run.stationId != null) _buildFlowChart(context, ref),
      ],
    );
  }

  Widget _buildCurrentFlow(BuildContext context, WidgetRef ref) {
    final stationLevelAsync = ref.watch(stationLevelProvider(run.stationId!));

    return stationLevelAsync.when(
      data: (stationLevel) {
        if (stationLevel == null) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final hasDischarge = stationLevel.discharge != null;
        final hasLevel = stationLevel.level != null;

        if (!hasDischarge && !hasLevel) {
          return const SizedBox.shrink();
        }

        // Determine if current flow is within recommended range
        Color statusColor = theme.colorScheme.onSurface;
        String statusText = '';

        if (hasDischarge &&
            run.minRecommendedFlow != null &&
            run.maxRecommendedFlow != null) {
          if (stationLevel.discharge! < run.minRecommendedFlow!) {
            statusColor = Colors.red;
            statusText = 'Low';
          } else if (stationLevel.discharge! > run.maxRecommendedFlow!) {
            statusColor = Colors.orange;
            statusText = 'High';
          } else {
            statusColor = Colors.green;
            statusText = 'Good';
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primaryColor.withOpacity(0.15),
                theme.primaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.primaryColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Flow',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  if (statusText.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor, width: 1.5),
                      ),
                      child: Text(
                        statusText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (hasDischarge) ...[
                    Expanded(
                      child: _buildCurrentFlowValue(
                        context,
                        'Discharge',
                        stationLevel.discharge!,
                        stationLevel.dischargeUnit,
                        stationLevel.trend,
                      ),
                    ),
                  ],
                  if (hasDischarge && hasLevel) const SizedBox(width: 16),
                  if (hasLevel) ...[
                    Expanded(
                      child: _buildCurrentFlowValue(
                        context,
                        'Level',
                        stationLevel.level!,
                        stationLevel.levelUnit,
                        stationLevel.trend,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Updated ${_formatTimestamp(stationLevel.timestamp)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildCurrentFlowValue(
    BuildContext context,
    String label,
    double value,
    String unit,
    String trend,
  ) {
    final theme = Theme.of(context);
    IconData trendIcon;
    Color trendColor;

    switch (trend.toLowerCase()) {
      case 'rising':
        trendIcon = Icons.trending_up;
        trendColor = Colors.blue;
        break;
      case 'falling':
        trendIcon = Icons.trending_down;
        trendColor = Colors.orange;
        break;
      default:
        trendIcon = Icons.trending_flat;
        trendColor = Colors.grey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${value.toStringAsFixed(1)} $unit',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(trendIcon, size: 20, color: trendColor),
          ],
        ),
      ],
    );
  }

  Widget _buildFlowChart(BuildContext context, WidgetRef ref) {
    final params = DailyMeansParams(stationId: run.stationId!, days: 30);
    final dailyMeansAsync = ref.watch(dailyMeansProvider(params));

    return dailyMeansAsync.when(
      data: (dailyMeans) {
        if (dailyMeans.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: FlowChartWidget(
            flowData: dailyMeans,
            run: run,
            showDischarge: true,
          ),
        );
      },
      loading: () => Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) {
        print('Error loading flow chart: $error');
        return const SizedBox.shrink();
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildFlowRanges(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFlowRange(
          context,
          'Recommended',
          run.minRecommendedFlow,
          run.maxRecommendedFlow,
          run.flowUnit,
          isPrimary: true,
        ),
        const SizedBox(height: 12),
        _buildFlowRange(
          context,
          'Optimal',
          run.optimalFlowMin,
          run.optimalFlowMax,
          run.flowUnit,
        ),
      ],
    );
  }

  Widget _buildFlowRange(
    BuildContext context,
    String label,
    double? min,
    double? max,
    String unit, {
    bool isPrimary = false,
  }) {
    // Don't show if no data
    if (min == null && max == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final textColor = isPrimary
        ? theme.primaryColor
        : theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPrimary
            ? theme.primaryColor.withOpacity(0.1)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPrimary
              ? theme.primaryColor.withOpacity(0.3)
              : theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label Flow',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatFlowRange(min, max, unit),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: textColor,
                    fontWeight: isPrimary ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (isPrimary) Icon(Icons.star, color: theme.primaryColor, size: 20),
        ],
      ),
    );
  }

  String _formatFlowRange(double? min, double? max, String unit) {
    if (min != null && max != null) {
      if (min == max) {
        return '${min.toStringAsFixed(1)} $unit';
      }
      return '${min.toStringAsFixed(1)} - ${max.toStringAsFixed(1)} $unit';
    } else if (min != null) {
      return '${min.toStringAsFixed(1)}+ $unit';
    } else if (max != null) {
      return 'Up to ${max.toStringAsFixed(1)} $unit';
    }
    return 'No data';
  }

  Widget _buildGaugeInfo(BuildContext context) {
    final gaugeStation = run.gaugeStation!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sensors,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Gauge Station',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (gaugeStation['name'] != null) ...[
            Text(
              gaugeStation['name']!,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (gaugeStation['code'] != null)
            Text(
              'Station: ${gaugeStation['code']}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
