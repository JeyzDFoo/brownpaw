import 'package:flutter/material.dart';
import '../models/river_run.dart';

/// A widget that displays flow information for a river run including
/// recommended and optimal flow ranges, as well as gauge station data.
class FlowInformationWidget extends StatelessWidget {
  final RiverRun run;
  final EdgeInsets? padding;

  const FlowInformationWidget({super.key, required this.run, this.padding});

  @override
  Widget build(BuildContext context) {
    final hasFlowData =
        run.minRecommendedFlow != null ||
        run.maxRecommendedFlow != null ||
        run.optimalFlowMin != null ||
        run.optimalFlowMax != null;

    if (!hasFlowData && run.gaugeStation == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context),
          const SizedBox(height: 16),
          _buildContent(context, hasFlowData),
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

  Widget _buildContent(BuildContext context, bool hasFlowData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasFlowData) ...[
          _buildFlowRanges(context),
          if (run.gaugeStation != null) const SizedBox(height: 16),
        ],
        if (run.gaugeStation != null) _buildGaugeInfo(context),
      ],
    );
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
