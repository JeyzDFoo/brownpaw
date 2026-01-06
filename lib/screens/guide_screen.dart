import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../models/river_run.dart';
import '../providers/river_runs_provider.dart';
import 'run_details_screen.dart';

class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  List<RiverRun> _currentRuns = [];
  final TextEditingController _searchController = TextEditingController();
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // Default center on Canada
  static const LatLng _defaultCenter = LatLng(54.0, -100.0);
  static const double _defaultZoom = 4.0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToRun(String runId, List<RiverRun> runs) {
    final index = runs.indexWhere((run) => run.riverId == runId);
    if (index != -1) {
      // Set selection using provider
      if (mounted) {
        ref.read(selectedRunIdProvider.notifier).state = runId;
      }

      // Wait a frame for the UI to update, then scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _itemScrollController.isAttached) {
          _itemScrollController.scrollTo(
            index: index,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.2, // Position item 20% from the top of viewport
          );
        }
      });

      // Clear selection after a longer delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && ref.read(selectedRunIdProvider) == runId) {
          ref.read(selectedRunIdProvider.notifier).state = null;
        }
      });
    }
  }

  void _updateMapMarkers(List<RiverRun> runs) {
    // Avoid unnecessary updates
    if (_runsAreEqual(runs, _currentRuns)) return;

    _markers.clear();
    _currentRuns = runs;

    for (var run in runs) {
      // Try putInCoordinates first, then coordinates
      final coords = run.putInCoordinates ?? run.coordinates;

      if (coords != null &&
          coords['latitude'] != null &&
          coords['longitude'] != null) {
        final position = LatLng(coords['latitude']!, coords['longitude']!);

        final difficultyMin = run.difficultyMin ?? 1;

        _markers.add(
          Marker(
            point: position,
            width: 30.0 + (difficultyMin * 3.0),
            height: 30.0 + (difficultyMin * 3.0),
            child: GestureDetector(
              onTap: () {
                _scrollToRun(run.riverId, _currentRuns);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.location_pin,
                    color: _getDifficultyColor(difficultyMin),
                    size: 30.0 + (difficultyMin * 3.0),
                    shadows: const [
                      Shadow(blurRadius: 3, color: Colors.black45),
                    ],
                  ),
                  Positioned(
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        run.difficultyClass.replaceAll('Class ', ''),
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // Update camera to show all markers
    if (_markers.isNotEmpty) {
      _fitMapToMarkers();
    }
  }

  Color _getDifficultyColor(int difficulty) {
    // Color gradient from easy to hard
    if (difficulty <= 2) return Colors.green;
    if (difficulty <= 3) return Colors.blue;
    if (difficulty <= 4) return Colors.orange;
    return Colors.red;
  }

  bool _runsAreEqual(List<RiverRun> a, List<RiverRun> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].riverId != b[i].riverId) return false;
    }
    return true;
  }

  void _fitMapToMarkers() {
    if (_markers.isEmpty) return;

    double minLat = _markers.first.point.latitude;
    double maxLat = _markers.first.point.latitude;
    double minLng = _markers.first.point.longitude;
    double maxLng = _markers.first.point.longitude;

    for (var marker in _markers) {
      if (marker.point.latitude < minLat) minLat = marker.point.latitude;
      if (marker.point.latitude > maxLat) maxLat = marker.point.latitude;
      if (marker.point.longitude < minLng) minLng = marker.point.longitude;
      if (marker.point.longitude > maxLng) maxLng = marker.point.longitude;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  Widget _buildMapHero() {
    final mapExpanded = ref.watch(mapExpandedProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: mapExpanded ? MediaQuery.of(context).size.height * 0.6 : 250,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.brownpaw.brownclaw',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'expand_map',
                  onPressed: () {
                    ref.read(mapExpandedProvider.notifier).state = !mapExpanded;
                  },
                  child: Icon(
                    mapExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                ),
                if (_markers.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'fit_bounds',
                    onPressed: _fitMapToMarkers,
                    child: const Icon(Icons.fit_screen),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryProvider);
    final filteredRunsAsync = ref.watch(filteredRiverRunsProvider);

    return Column(
      children: [
        // Search Bar at top
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search rivers...',
              hintText: 'River name, region, or province',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
          ),
        ),
        _buildMapHero(),
        _buildFilters(),
        Expanded(
          child: filteredRunsAsync.when(
            data: (runs) {
              // Update map markers with current runs
              if (!_runsAreEqual(runs, _currentRuns)) {
                Future.microtask(() {
                  if (mounted) {
                    _updateMapMarkers(runs);
                  }
                });
              }

              return _buildRunPickerList(runs);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              debugPrint('Error: $error');
              debugPrint('Stack: $stack');

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Database Error',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(riverRunsStreamProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRunPickerList(List<RiverRun> runs) {
    final selectedRunId = ref.watch(selectedRunIdProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Tap a marker on the map or select a run below',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            itemPositionsListener: _itemPositionsListener,
            itemCount: runs.length,
            itemBuilder: (context, index) {
              final run = runs[index];
              final difficultyMin = run.difficultyMin ?? 1;
              final isSelected = selectedRunId == run.riverId;

              return AnimatedContainer(
                key: ValueKey(run.riverId),
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).cardTheme.color ??
                            Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: SizedBox(
                      width: 56,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(
                            difficultyMin,
                          ).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.water,
                              color: _getDifficultyColor(difficultyMin),
                              size: 20,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              run.difficultyClass.replaceAll('Class ', ''),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getDifficultyColor(difficultyMin),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    title: Text(
                      run.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          [
                            run.province,
                            if (run.region?.isNotEmpty == true) run.region,
                          ].join(' • '),
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
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              RunDetailsScreen(runId: run.riverId),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
