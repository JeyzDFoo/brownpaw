import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/providers/realtime_flow_provider.dart';
import 'package:brownpaw/providers/flow_data_provider.dart';
import 'package:brownpaw/widgets/flow_chart_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FlowInformationWidget extends ConsumerWidget {
  const FlowInformationWidget({super.key, required this.riverRun});
  final RiverRun riverRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (riverRun.stationId == null) {
      return const SizedBox.shrink();
    }

    final realtimeFlow = ref.watch(
      realtimeFlowStreamProvider(riverRun.stationId!),
    );

    final historicalFlow = ref.watch(
      historicalFlowProvider(
        DailyMeansParams(
          stationId: riverRun.stationId!,
          days: 1095,
        ), // ~3 years
      ),
    );

    return realtimeFlow.when(
      data: (flowData) {
        if (flowData == null) {
          return _buildSection(
            context,
            '30-day discharge',
            Icons.show_chart,
            child: const Text('No real-time flow data available.'),
          );
        }

        // Get the most recent flow value
        final currentFlow = flowData.flow.readings.isNotEmpty
            ? flowData.flow.latestReading?.discharge
            : null;

        return Column(
          children: [
            // Current flow and range indicator
            if (currentFlow != null) _buildFlowIndicator(context, currentFlow),

            // Chart
            _buildSection(
              context,
              'Flow History',
              Icons.show_chart,
              child: SizedBox(
                height: 350,
                child: historicalFlow.when(
                  data: (historical) => FlowChart(
                    realtimeData: flowData.flow,
                    historicalData: historical,
                    stationId: riverRun.stationId!,
                  ),
                  loading: () => FlowChart(
                    realtimeData: flowData.flow,
                    stationId: riverRun.stationId!,
                  ),
                  error: (_, __) => FlowChart(
                    realtimeData: flowData.flow,
                    stationId: riverRun.stationId!,
                  ),
                ),
              ),
            ),
          ],
        );
      },
      error: (err, stack) => _buildSection(
        context,
        '30-day history (m³/s)',
        Icons.show_chart,
        child: Text('Error loading flow data: $err'),
      ),
      loading: () => _buildSection(
        context,
        '30-day history (m³/s)',
        Icons.show_chart,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  // Copied from run_details_screen.dart for consistent styling
  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon, {
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // Build flow range indicator
  Widget _buildFlowIndicator(BuildContext context, double currentFlow) {
    final hasFlowRanges =
        riverRun.minRecommendedFlow != null || riverRun.optimalFlowMin != null;

    if (!hasFlowRanges) {
      // Just show current flow without ranges
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.water_drop,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Current Flow: ${currentFlow.toStringAsFixed(1)} m³/s',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // Determine flow status
    String status;
    Color statusColor;
    IconData statusIcon;

    if (riverRun.optimalFlowMin != null && riverRun.optimalFlowMax != null) {
      if (currentFlow >= riverRun.optimalFlowMin! &&
          currentFlow <= riverRun.optimalFlowMax!) {
        status = 'Optimal';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      } else if (riverRun.minRecommendedFlow != null &&
          riverRun.maxRecommendedFlow != null &&
          currentFlow >= riverRun.minRecommendedFlow! &&
          currentFlow <= riverRun.maxRecommendedFlow!) {
        status = 'Runnable';
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
      } else if (currentFlow < (riverRun.minRecommendedFlow ?? 0)) {
        status = 'Low';
        statusColor = Colors.red;
        statusIcon = Icons.trending_down;
      } else {
        status = 'High';
        statusColor = Colors.red;
        statusIcon = Icons.trending_up;
      }
    } else if (riverRun.minRecommendedFlow != null &&
        riverRun.maxRecommendedFlow != null) {
      if (currentFlow >= riverRun.minRecommendedFlow! &&
          currentFlow <= riverRun.maxRecommendedFlow!) {
        status = 'Runnable';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      } else if (currentFlow < riverRun.minRecommendedFlow!) {
        status = 'Low';
        statusColor = Colors.red;
        statusIcon = Icons.trending_down;
      } else {
        status = 'High';
        statusColor = Colors.red;
        statusIcon = Icons.trending_up;
      }
    } else {
      status = 'Unknown';
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Current flow with status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Flow',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${currentFlow.toStringAsFixed(1)} m³/s',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Flow ranges
          Column(
            children: [
              if (riverRun.optimalFlowMin != null &&
                  riverRun.optimalFlowMax != null)
                _buildFlowRange(
                  context,
                  'Optimal',
                  riverRun.optimalFlowMin!,
                  riverRun.optimalFlowMax!,
                  Colors.green,
                ),
              if (riverRun.minRecommendedFlow != null &&
                  riverRun.maxRecommendedFlow != null) ...[
                const SizedBox(height: 8),
                _buildFlowRange(
                  context,
                  'Runnable',
                  riverRun.minRecommendedFlow!,
                  riverRun.maxRecommendedFlow!,
                  Colors.orange,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlowRange(
    BuildContext context,
    String label,
    double min,
    double max,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: ${min.toStringAsFixed(1)} - ${max.toStringAsFixed(1)} m³/s',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
