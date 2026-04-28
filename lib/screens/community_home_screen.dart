import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/river_run.dart';
import '../models/descent.dart';
import '../providers/descents_provider.dart';
import '../providers/river_runs_provider.dart';
import '../providers/realtime_flow_provider.dart';
import '../providers/user_provider.dart';

class CommunityHomeScreen extends ConsumerWidget {
  const CommunityHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userData = ref.watch(userProvider);
    final feedAsync = ref.watch(communityFeedProvider);
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final favoriteRunsValue = ref.watch(favoriteRiverRunsProvider);

    final rawName =
        userData.userData?['displayName'] as String? ??
        userData.user?.displayName ??
        userData.user?.email?.split('@').first ??
        'Paddler';
    final firstName = rawName.split(' ').first;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return CustomScrollView(
      slivers: [
        // ── Greeting ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $firstName 👋',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Here's what's happening in the community.",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Favourites — Conditions ────────────────────────────────────────────
        const SliverToBoxAdapter(
          child: _SectionHeader(
            icon: Icons.water_drop_outlined,
            title: 'Favourites — Conditions',
          ),
        ),
        SliverToBoxAdapter(
          child: favoriteRunsValue.when(
            data: (runs) {
              if (runs.isEmpty) {
                return const _EmptyHint(
                  message: 'Add favourite runs to see conditions here.',
                );
              }
              return SizedBox(
                height: 116,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: runs.length,
                  itemBuilder: (_, i) => _FavouriteConditionCard(run: runs[i]),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 116,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) =>
                const _EmptyHint(message: 'Could not load favourites.'),
          ),
        ),

        // ── Community Activity ─────────────────────────────────────────────────
        const SliverToBoxAdapter(
          child: _SectionHeader(
            icon: Icons.people_outline,
            title: 'Community Activity',
          ),
        ),
        feedAsync.when(
          data: (descents) {
            if (descents.isEmpty) {
              return const SliverToBoxAdapter(
                child: _EmptyHint(message: 'No public descents logged yet.'),
              );
            }
            return SliverList.builder(
              itemCount: descents.length,
              itemBuilder: (_, i) =>
                  _CommunityDescentCard(descent: descents[i]),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, __) => const SliverToBoxAdapter(
            child: _EmptyHint(message: 'Could not load community activity.'),
          ),
        ),

        // ── Leaderboard ────────────────────────────────────────────────────────
        const SliverToBoxAdapter(
          child: _SectionHeader(
            icon: Icons.emoji_events_outlined,
            title: 'Leaderboard',
          ),
        ),
        SliverToBoxAdapter(
          child: leaderboardAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const _EmptyHint(
                  message: 'No public descents logged yet.',
                );
              }
              return _LeaderboardList(entries: entries);
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) =>
                const _EmptyHint(message: 'Could not load leaderboard.'),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ─── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Hint ────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final String message;

  const _EmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }
}

// ─── Favourite Condition Card ──────────────────────────────────────────────────

class _FavouriteConditionCard extends ConsumerWidget {
  final RiverRun run;

  const _FavouriteConditionCard({required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowAsync = run.stationId != null
        ? ref.watch(realtimeFlowStreamProvider(run.stationId!))
        : const AsyncValue<StationRealtimeFlow?>.data(null);

    final currentFlow = flowAsync.valueOrNull?.discharge;
    final trend = flowAsync.valueOrNull?.trend;

    // Hide cards with no data once loading is complete.
    if (!flowAsync.isLoading && currentFlow == null) {
      return const SizedBox.shrink();
    }

    Color statusColor;
    String statusLabel;

    if (currentFlow == null) {
      statusColor = Colors.grey;
      statusLabel = 'Loading…';
    } else if (run.optimalFlowMin != null &&
        run.optimalFlowMax != null &&
        currentFlow >= run.optimalFlowMin! &&
        currentFlow <= run.optimalFlowMax!) {
      statusColor = const Color(0xFF43A047);
      statusLabel = 'Optimal';
    } else if (run.minRecommendedFlow != null &&
        run.maxRecommendedFlow != null &&
        currentFlow >= run.minRecommendedFlow! &&
        currentFlow <= run.maxRecommendedFlow!) {
      statusColor = const Color(0xFF1E88E5);
      statusLabel = 'Runnable';
    } else if (run.maxRecommendedFlow != null &&
        currentFlow > run.maxRecommendedFlow!) {
      statusColor = const Color(0xFFE53935);
      statusLabel = 'High';
    } else if (run.minRecommendedFlow != null &&
        currentFlow < run.minRecommendedFlow!) {
      statusColor = const Color(0xFFFF6F00);
      statusLabel = 'Low';
    } else {
      statusColor = const Color(0xFF1E88E5);
      statusLabel = 'Info';
    }

    final trendSymbol = switch (trend) {
      'rising' => ' ↑',
      'falling' => ' ↓',
      _ => '',
    };

    final displayName = run.name.length > 18
        ? '${run.name.substring(0, 16)}…'
        : run.name;

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12, bottom: 4, top: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            if (currentFlow != null)
              Text(
                '${currentFlow.toStringAsFixed(1)} ${run.flowUnit}$trendSymbol',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              )
            else
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Community Descent Card ────────────────────────────────────────────────────

class _CommunityDescentCard extends StatelessWidget {
  final Descent descent;

  const _CommunityDescentCard({required this.descent});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, y').format(descent.date);
    final hasNotes = descent.notes != null && descent.notes!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Difficulty badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  descent.difficulty ?? '—',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Run name, date, notes
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      descent.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                    if (hasNotes) ...[
                      const SizedBox(height: 4),
                      Text(
                        descent.notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Rating + flow (right-aligned)
              if (descent.rating != null || descent.flow != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (descent.rating != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          Text(
                            ' ${descent.rating}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    if (descent.flow != null)
                      Text(
                        '${descent.flow!.toStringAsFixed(1)} ${descent.flowUnit ?? ''}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Leaderboard ──────────────────────────────────────────────────────────────

class _LeaderboardList extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const _LeaderboardList({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            for (int i = 0; i < entries.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 56,
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withOpacity(0.5),
                ),
              _LeaderboardRow(entry: entries[i], rank: i + 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;

  const _LeaderboardRow({required this.entry, required this.rank});

  static const _medalColors = [
    Color(0xFFFFD700), // Gold
    Color(0xFFC0C0C0), // Silver
    Color(0xFFCD7F32), // Bronze
  ];

  @override
  Widget build(BuildContext context) {
    final name =
        entry.displayName ??
        'Paddler #${entry.userId.substring(0, 5).toUpperCase()}';
    final isTopThree = rank <= 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Rank / medal
          SizedBox(
            width: 28,
            child: isTopThree
                ? Icon(Icons.circle, size: 20, color: _medalColors[rank - 1])
                : Text(
                    '$rank',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.45),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),
          // Avatar
          CircleAvatar(
            radius: 17,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Count
          Text(
            '${entry.descentCount}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'runs',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
