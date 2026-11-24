import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/flow_status.dart';
import '../models/river_run.dart';
import '../providers/favorites_provider.dart';
import '../providers/realtime_flow_provider.dart';
import '../screens/run_details_screen.dart';
import 'flow_status_chip.dart';

/// A run in a list: name, class and region, then live flow with a
/// "Low / Runnable / Good / High" status so it answers "is it in?" at a
/// glance. The favourite toggle sits at the trailing edge, away from the
/// thumb's natural tap point on the card.
class RiverRunCard extends ConsumerWidget {
  final RiverRun run;

  const RiverRunCard({super.key, required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final isFavorite = ref.watch(isFavoriteProvider(run.riverId));

    final liveFlow = run.stationId != null
        ? ref.watch(realtimeFlowStreamProvider(run.stationId!)).value
        : null;
    final discharge = liveFlow?.discharge;
    final trendSymbol = switch (liveFlow?.trend) {
      'rising' => ' ↑',
      'falling' => ' ↓',
      _ => '',
    };

    final place = (run.region?.isNotEmpty ?? false)
        ? run.region!
        : run.province;
    final subtitle = [
      run.difficultyClass,
      place,
      if (run.length != null) run.length!,
    ].join(' · ');

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
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: muted),
                    if (discharge != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${discharge.toStringAsFixed(1)} m³/s$trendSymbol',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (run.hasFlowRanges) ...[
                            const SizedBox(width: 8),
                            FlowStatusChip(status: run.flowStatus(discharge)),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                color: isFavorite
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
                iconSize: 26,
                onPressed: () {
                  ref
                      .read(favoritesProvider.notifier)
                      .toggleFavorite(run.riverId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
