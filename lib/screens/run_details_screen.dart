import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:map_launcher/map_launcher.dart';
import '../models/river_run.dart';
import '../models/descent.dart';
import '../widgets/flow_information_widget.dart';
import '../providers/favorites_provider.dart';
import '../providers/descents_provider.dart';
import '../providers/user_provider.dart';
import '../providers/realtime_flow_provider.dart';
import '../widgets/log_descent_dialog.dart';

class RunDetailsScreen extends ConsumerWidget {
  final String runId;

  const RunDetailsScreen({super.key, required this.runId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).user;
    final favoritesState = ref.watch(favoritesProvider);
    final isFavorite = favoritesState.isFavorite(runId);
    final descentCount = ref.watch(runDescentCountProvider(runId));
    return Scaffold(
      appBar: AppBar(title: const Text('Run Details')),
      // Floating action button for logging descents
      floatingActionButton: user != null
          ? FloatingActionButton.extended(
              onPressed: () => _showLogDescentDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(
                descentCount.when(
                  data: (count) =>
                      count > 0 ? 'Log Descent ($count)' : 'Log Descent',
                  loading: () => 'Log Descent',
                  error: (_, __) => 'Log Descent',
                ),
              ),
            )
          : null,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                _buildHeader(context, run),

                // Quick Stats Row
                _buildQuickStats(context, run),

                // Flow Information with Charts
                FlowInformationWidget(riverRun: run),

                // Logistics Section (Access, Shuttle, Permits)
                _buildLogisticsSection(context, run),

                // Safety & Info Section (Hazards, Scouting)
                _buildSafetySection(context, run),

                // Locations Section
                _buildLocationsSection(context, run),

                // Description Section
                _buildDescriptionSection(context, run),

                // Images Section
                if (run.images?.isNotEmpty == true)
                  _buildImagesSection(context, run),

                // Public Descents Section
                _buildPublicDescentsSection(context, ref),

                // Source Section
                _buildSourceSection(context, run),

                const SizedBox(height: 24), // Bottom padding
              ],
            ),
          );
        },
      ),
    );
  }

  // HEADER SECTION
  Widget _buildHeader(BuildContext context, RiverRun run) {
    return Consumer(
      builder: (context, ref, child) {
        final user = ref.watch(userProvider).user;
        final favoritesState = ref.watch(favoritesProvider);
        final isFavorite = favoritesState.isFavorite(runId);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.secondaryContainer,
              ],
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Province badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        run.region != null
                            ? '${run.province} • ${run.region}'
                            : run.province,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Run name
                    Text(
                      run.name,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Difficulty
                    Text(
                      run.difficultyClass,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons in top right corner
              Positioned(
                top: 16,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Navigate to Put-in button
                    if (run.putInCoordinates != null)
                      IconButton(
                        icon: const Icon(Icons.navigation),
                        onPressed: () => _navigateToPutIn(context, run),
                        tooltip: 'Navigate to Put-in',
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(0.9),
                        ),
                      ),
                    if (run.putInCoordinates != null) const SizedBox(width: 8),
                    // Favorite button
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : null,
                      ),
                      onPressed: user != null
                          ? () => ref
                                .read(favoritesProvider.notifier)
                                .toggleFavorite(runId)
                          : null,
                      tooltip: isFavorite
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surface.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // QUICK STATS ROW
  Widget _buildQuickStats(BuildContext context, RiverRun run) {
    final stats = <Map<String, dynamic>>[];

    // Always show difficulty
    stats.add({
      'label': 'Difficulty',
      'value': run.difficultyText,
      'icon': Icons.waves,
    });

    // Add length if available
    if (run.length != null) {
      stats.add({
        'label': 'Length',
        'value': run.length!,
        'icon': Icons.straighten,
      });
    }

    // Add time if available
    if (run.estimatedTime != null) {
      stats.add({
        'label': 'Time',
        'value': run.estimatedTime!,
        'icon': Icons.schedule,
      });
    }

    // Add season if available
    if (run.season != null) {
      stats.add({
        'label': 'Season',
        'value': run.season!,
        'icon': Icons.calendar_today,
      });
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: stats
            .map(
              (stat) => Expanded(
                child: _buildStatItem(
                  context,
                  stat['label'] as String,
                  stat['value'] as String,
                  stat['icon'] as IconData,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // IMAGES SECTION
  Widget _buildImagesSection(BuildContext context, RiverRun run) {
    if (run.images == null || run.images!.isEmpty)
      return const SizedBox.shrink();

    return _buildSection(
      context,
      'Photos',
      Icons.photo_library,
      child: SizedBox(
        height: 200,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: run.images!.length,
          itemBuilder: (context, index) {
            final image = run.images![index];
            return Container(
              width: 300,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      image['url'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Theme.of(context).colorScheme.surfaceVariant,
                        child: const Icon(Icons.broken_image),
                      ),
                    ),
                    if (image['caption'] != null)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: Text(
                            image['caption']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // LOGISTICS SECTION
  Widget _buildLogisticsSection(BuildContext context, RiverRun run) {
    final items = <Widget>[];

    if (run.access != null && run.access!.isNotEmpty) {
      items.add(
        _buildInfoItem(context, 'Access', run.access!, Icons.directions_car),
      );
    }

    if (run.shuttle != null && run.shuttle!.isNotEmpty) {
      items.add(
        _buildInfoItem(
          context,
          'Shuttle',
          run.shuttle!,
          Icons.transfer_within_a_station,
        ),
      );
    }

    if (run.permits != null && run.permits!.isNotEmpty) {
      items.add(
        _buildInfoItem(context, 'Permits', run.permits!, Icons.assignment),
      );
    }

    if (run.gradient != null && run.gradient!.isNotEmpty) {
      items.add(
        _buildInfoItem(context, 'Gradient', run.gradient!, Icons.trending_down),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      context,
      'Logistics',
      Icons.info_outline,
      child: Column(
        children: items
            .expand((item) => [item, const SizedBox(height: 12)])
            .take(items.length * 2 - 1)
            .toList(),
      ),
    );
  }

  // SAFETY SECTION
  Widget _buildSafetySection(BuildContext context, RiverRun run) {
    final items = <Widget>[];

    if (run.hazards != null && run.hazards!.isNotEmpty) {
      items.add(
        _buildWarningItem(context, 'Hazards', run.hazards!, Icons.warning),
      );
    }

    if (run.scouting != null && run.scouting!.isNotEmpty) {
      items.add(
        _buildInfoItem(context, 'Scouting', run.scouting!, Icons.search),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      context,
      'Safety & Scouting',
      Icons.security,
      child: Column(
        children: items
            .expand((item) => [item, const SizedBox(height: 12)])
            .take(items.length * 2 - 1)
            .toList(),
      ),
    );
  }

  // LOCATIONS SECTION
  Widget _buildLocationsSection(BuildContext context, RiverRun run) {
    if (run.putIn == null && run.takeOut == null)
      return const SizedBox.shrink();

    return _buildSection(
      context,
      'Locations',
      Icons.location_on,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (run.putIn != null) ...[
            _buildLocationItem(
              context,
              'Put In',
              run.putIn!,
              run.putInCoordinates,
            ),
          ],
          if (run.putIn != null && run.takeOut != null)
            const SizedBox(height: 16),
          if (run.takeOut != null) ...[
            _buildLocationItem(
              context,
              'Take Out',
              run.takeOut!,
              run.takeOutCoordinates,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationItem(
    BuildContext context,
    String label,
    String description,
    Map<String, double>? coordinates,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (coordinates != null)
              GestureDetector(
                onTap: () => _openInMaps(coordinates),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map,
                        size: 14,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Open in Maps',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(description),
        if (coordinates != null) ...[
          const SizedBox(height: 4),
          Text(
            '${coordinates['latitude']!.toStringAsFixed(5)}, ${coordinates['longitude']!.toStringAsFixed(5)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  // DESCRIPTION SECTION
  Widget _buildDescriptionSection(BuildContext context, RiverRun run) {
    String? text;

    // Prefer description over fullText since fullText often contains navigation menu items
    if (run.description?.isNotEmpty == true) {
      text = run.description!;
    } else if (run.fullText?.isNotEmpty == true) {
      // Clean up fullText by removing common navigation menu items
      text = _cleanFullText(run.fullText!);
    }

    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return _buildSection(
      context,
      'Description',
      Icons.description,
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  // Helper method to clean up fullText content
  String? _cleanFullText(String fullText) {
    // Remove common navigation menu items that get scraped
    final menuItems = [
      'BCWhitewater',
      'Projects',
      'Rivers',
      'Get Involved',
      'About',
      'Our Team',
      'Partners',
      'Contact',
      'Home',
      'Navigation',
      'Menu',
    ];

    String cleaned = fullText;
    for (String item in menuItems) {
      cleaned = cleaned.replaceAll(RegExp('\\b$item\\b'), '').trim();
    }

    // Clean up extra whitespace and newlines
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Return null if the cleaned text is too short (likely just menu items)
    return cleaned.length > 20 ? cleaned : null;
  }

  // SOURCE SECTION
  Widget _buildSourceSection(BuildContext context, RiverRun run) {
    if (run.source == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Source: ${run.source}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (run.sourceUrl != null)
            Expanded(
              child: GestureDetector(
                onTap: () => _launchUrl(run.sourceUrl!),
                child: Text(
                  run.sourceUrl!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // PUBLIC DESCENTS SECTION
  Widget _buildPublicDescentsSection(BuildContext context, WidgetRef ref) {
    final publicDescents = ref.watch(publicDescentsProvider(runId));

    return publicDescents.when(
      data: (descents) {
        if (descents.isEmpty) return const SizedBox.shrink();

        return _buildSection(
          context,
          'Recent Descents (${descents.length})',
          Icons.people,
          child: Column(
            children: descents.take(10).map((descent) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDescentItem(context, descent),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDescentItem(BuildContext context, Descent descent) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM d, yyyy').format(descent.date),
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (descent.rating != null)
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < descent.rating! ? Icons.star : Icons.star_border,
                      size: 14,
                      color: Colors.amber,
                    ),
                  ),
                ),
            ],
          ),
          if (descent.flow != null) ...[
            const SizedBox(height: 4),
            Text(
              'Flow: ${descent.flow!.toStringAsFixed(1)} ${descent.flowUnit ?? "m³/s"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (descent.notes != null && descent.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              descent.notes!,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // HELPER WIDGETS
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

  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String content,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(content),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarningItem(
    BuildContext context,
    String label,
    String content,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(content),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Show log descent dialog
  void _showLogDescentDialog(BuildContext context, WidgetRef ref) async {
    final run = await FirebaseFirestore.instance
        .collection('river_runs')
        .doc(runId)
        .get()
        .then((doc) => doc.exists ? RiverRun.fromFirestore(doc) : null);

    if (run == null || !context.mounted) return;

    // Get current flow if available
    double? currentFlow;
    if (run.stationId != null) {
      final flowData = await ref.read(
        realtimeFlowStreamProvider(run.stationId!).future,
      );
      currentFlow = flowData?.flow.latestReading?.discharge;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => LogDescentDialog(
        runId: runId,
        runName: run.name,
        initialFlow: currentFlow,
        stationId: run.stationId,
        difficulty: run.difficultyClass,
      ),
    );
  }

  // Navigate to put-in location using available map apps
  Future<void> _navigateToPutIn(BuildContext context, RiverRun run) async {
    if (run.putInCoordinates == null) return;

    final latitude = run.putInCoordinates!['latitude']!;
    final longitude = run.putInCoordinates!['longitude']!;

    try {
      final availableMaps = await MapLauncher.installedMaps;

      if (availableMaps.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No map applications found on device'),
            ),
          );
        }
        return;
      }

      // If only one map app is available, launch it directly
      if (availableMaps.length == 1) {
        await availableMaps.first.showMarker(
          coords: Coords(latitude, longitude),
          title: '${run.name} Put-in',
        );
        return;
      }

      // If multiple map apps are available, show selection dialog
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          builder: (BuildContext context) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Choose Map App',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...availableMaps.map(
                    (map) => ListTile(
                      leading: Image.asset(map.icon, width: 30, height: 30),
                      title: Text(map.mapName),
                      onTap: () async {
                        Navigator.pop(context);
                        await map.showMarker(
                          coords: Coords(latitude, longitude),
                          title: '${run.name} Put-in',
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error launching map: $e')));
      }
    }
  }

  // Launch URL in browser
  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // Open coordinates in maps app
  Future<void> _openInMaps(Map<String, double> coordinates) async {
    final lat = coordinates['latitude'];
    final lng = coordinates['longitude'];
    if (lat == null || lng == null) return;

    // Use Apple Maps on iOS, Google Maps on Android
    final url = Uri.parse('https://maps.apple.com/?q=$lat,$lng');
    final googleUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    }
  }
}
