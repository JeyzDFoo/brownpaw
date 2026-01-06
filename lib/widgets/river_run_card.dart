import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_run.dart';
import '../providers/favorites_provider.dart';
import '../providers/realtime_flow_provider.dart';
import '../screens/run_details_screen.dart';

class RiverRunCard extends ConsumerWidget {
  final RiverRun run;

  const RiverRunCard({super.key, required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(run.riverId));

    // Watch real-time flow data if station ID is available
    final realtimeFlow = run.stationId != null
        ? ref.watch(realtimeFlowProvider(run.stationId!))
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RunDetailsScreen(runId: run.riverId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Favorite heart
              IconButton(
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: () {
                  ref
                      .read(favoritesProvider.notifier)
                      .toggleFavorite(run.riverId);
                },
                iconSize: 28,
                color: isFavorite
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),

              // Run details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      run.difficultyClass,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        run.province,
                        if (run.region?.isNotEmpty == true) run.region,
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (run.length != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.straighten,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            run.length!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ],
                    // Display latest discharge if available
                    if (realtimeFlow?.hasValue == true &&
                        realtimeFlow!.value?.discharge != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.water, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            '${realtimeFlow.value!.discharge!.toStringAsFixed(1)} m³/s',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (realtimeFlow.value!.trend != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              realtimeFlow.value!.trend == 'rising'
                                  ? Icons.trending_up
                                  : realtimeFlow.value!.trend == 'falling'
                                  ? Icons.trending_down
                                  : Icons.trending_flat,
                              size: 14,
                              color: Colors.green,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
