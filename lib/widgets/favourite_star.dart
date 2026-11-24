import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/favorites_provider.dart';
import '../providers/gauges_provider.dart';

/// Sets runs as favourites (true) or not (false). A provider so tests can
/// swap in a fake.
final setFavouritesProvider =
    Provider<Future<void> Function(Iterable<String> runIds, bool favourite)>(
      (ref) =>
          (runIds, favourite) => ref
              .read(favoritesProvider.notifier)
              .setFavourites(runIds, favourite),
    );

/// A star that favourites a run, or every run on a gauge. Filled when any
/// of [runIds] is a favourite; tapping then clears them all.
class FavouriteStar extends ConsumerWidget {
  const FavouriteStar({
    super.key,
    required this.runIds,
    this.what = 'favourites',
    this.compact = false,
  });

  final List<String> runIds;

  /// What's being starred, for the tooltip: "run", "gauge".
  final String what;

  /// Smaller, for tiles and cards.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favourites = ref.watch(favouriteRunIdsProvider);
    final on = runIds.any(favourites.contains);
    final theme = Theme.of(context);
    return IconButton(
      tooltip: on ? 'Remove $what from favourites' : 'Add $what to favourites',
      isSelected: on,
      visualDensity: compact ? VisualDensity.compact : null,
      iconSize: compact ? 22 : 26,
      icon: Icon(Icons.star_border, color: theme.colorScheme.onSurfaceVariant),
      selectedIcon: const Icon(Icons.star, color: Color(0xFFF5A623)),
      onPressed: () async {
        await ref.read(setFavouritesProvider)(runIds, !on);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..removeCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                on ? 'Removed from favourites' : 'Added to favourites',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
      },
    );
  }
}
