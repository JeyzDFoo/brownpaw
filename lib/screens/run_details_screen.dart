import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/river_run.dart';

class RunDetailsScreen extends StatelessWidget {
  final String runId;

  const RunDetailsScreen({super.key, required this.runId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('river_runs')
            .doc(runId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Run not found'));
          }

          final run = RiverRun.fromFirestore(snapshot.data!);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  run.name,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  run.region.isNotEmpty
                      ? '${run.river} - ${run.region}'
                      : run.river,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),

                // Difficulty
                _buildInfoCard(
                  context,
                  'Difficulty',
                  run.difficultyText,
                  Icons.waves,
                ),
                const SizedBox(height: 16),

                // Length
                if (run.length != null) ...[
                  _buildInfoCard(
                    context,
                    'Length',
                    '${run.length} km',
                    Icons.straighten,
                  ),
                  const SizedBox(height: 16),
                ],

                // Gradient
                if (run.gradient != null) ...[
                  _buildInfoCard(
                    context,
                    'Gradient',
                    '${run.gradient} m/km',
                    Icons.trending_down,
                  ),
                  const SizedBox(height: 16),
                ],

                // Estimated Time
                if (run.estimatedTime != null) ...[
                  _buildInfoCard(
                    context,
                    'Estimated Time',
                    run.estimatedTime!,
                    Icons.schedule,
                  ),
                  const SizedBox(height: 16),
                ],

                // Season
                if (run.season != null) ...[
                  _buildInfoCard(
                    context,
                    'Season',
                    run.season!,
                    Icons.calendar_today,
                  ),
                  const SizedBox(height: 16),
                ],

                // Flow Information
                if (run.minRecommendedFlow != null ||
                    run.maxRecommendedFlow != null) ...[
                  _buildFlowCard(context, run),
                  const SizedBox(height: 16),
                ],

                // Description
                if (run.description != null && run.description!.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.description,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Description',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(run.description!),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Permits
                if (run.permits != null && run.permits!.isNotEmpty) ...[
                  _buildTextCard(
                    context,
                    'Permits & Access',
                    run.permits!,
                    Icons.info,
                  ),
                  const SizedBox(height: 16),
                ],

                // Hazards
                if (run.hazards != null && run.hazards!.isNotEmpty) ...[
                  _buildTextCard(
                    context,
                    'Hazards',
                    run.hazards!,
                    Icons.warning,
                    isWarning: true,
                  ),
                  const SizedBox(height: 16),
                ],

                // Put In / Take Out
                if (run.putIn != null || run.takeOut != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Locations',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          if (run.putIn != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Put In:',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(run.putIn!),
                          ],
                          if (run.takeOut != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Take Out:',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(run.takeOut!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Source
                if (run.source != null) ...[
                  Text(
                    'Source: ${run.source}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.visible,
                    softWrap: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowCard(BuildContext context, RiverRun run) {
    String flowText = '';
    if (run.minRecommendedFlow != null && run.maxRecommendedFlow != null) {
      flowText =
          '${run.minRecommendedFlow} - ${run.maxRecommendedFlow} ${run.flowUnit}';
    } else if (run.minRecommendedFlow != null) {
      flowText = 'Min: ${run.minRecommendedFlow} ${run.flowUnit}';
    } else if (run.maxRecommendedFlow != null) {
      flowText = 'Max: ${run.maxRecommendedFlow} ${run.flowUnit}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.water_drop,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recommended Flow',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(flowText, style: Theme.of(context).textTheme.titleLarge),
            if (run.optimalFlowMin != null || run.optimalFlowMax != null) ...[
              const SizedBox(height: 8),
              Text(
                'Optimal: ${run.optimalFlowMin ?? ''} - ${run.optimalFlowMax ?? ''} ${run.flowUnit}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextCard(
    BuildContext context,
    String title,
    String content,
    IconData icon, {
    bool isWarning = false,
  }) {
    return Card(
      color: isWarning ? Theme.of(context).colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isWarning
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(content),
          ],
        ),
      ),
    );
  }
}
