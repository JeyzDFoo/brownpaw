import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/river_runs_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/river_run_card.dart';

class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteRunsAsync = ref.watch(favoriteRiverRunsProvider);
    final favoritesCount = ref.watch(favoritesCountProvider);
    final favoritesState = ref.watch(favoritesProvider);
    final user = ref.watch(userProvider).user;

    // Debug output
    debugPrint('Favourites Screen - User: ${user?.uid}');
    debugPrint('Favourites State - Count: $favoritesCount');
    debugPrint('Favourites State - IDs: ${favoritesState.favoriteRunIds}');
    debugPrint('Favourites State - Loading: ${favoritesState.isLoading}');
    debugPrint('Favourites State - Error: ${favoritesState.errorMessage}');

    if (user == null) {
      return _buildSignInPrompt(context);
    }

    return Column(
      children: [
        Expanded(
          child: favoriteRunsAsync.when(
            data: (runs) {
              debugPrint('Favourite runs data: ${runs.length} runs');
              if (runs.isEmpty) {
                return _buildEmptyState(context);
              }
              return _buildFavoritesList(runs, favoritesCount);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading favourites',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Sign in to save favourites',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Create an account to bookmark your favourite river runs and access them across devices.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'No favourites yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the heart icon on any river run to add it to your favourites.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList(List runs, int count) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: runs.length,
      itemBuilder: (context, index) {
        return RiverRunCard(run: runs[index]);
      },
    );
  }
}
