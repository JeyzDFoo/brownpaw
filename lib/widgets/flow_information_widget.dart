import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/providers/realtime_flow_provider.dart';
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

    return realtimeFlow.when(
      data: (flowData) {
        if (flowData == null) {
          return _buildSection(
            context,
            'Real-Time Flow',
            Icons.show_chart,
            child: const Text('No real-time flow data available.'),
          );
        }
        return _buildSection(
          context,
          'Real-Time Flow',
          Icons.show_chart,
          child: SizedBox(
            height: 200,
            child: FlowChart(flowData: flowData.flow),
          ),
        );
      },
      error: (err, stack) => _buildSection(
        context,
        'Real-Time Flow',
        Icons.show_chart,
        child: Text('Error loading flow data: $err'),
      ),
      loading: () => _buildSection(
        context,
        'Real-Time Flow',
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
}
