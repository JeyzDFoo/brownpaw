import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/providers/river_runs_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  RiverRun? _selectedRiver;

  void _onMarkerTapped(RiverRun river) {
    setState(() {
      _selectedRiver = river;
    });
  }

  List<Marker> _buildMarkers(List<RiverRun> rivers) {
    debugPrint('===== Building Markers =====');
    debugPrint('Total rivers: ${rivers.length}');

    // Debug first few rivers
    for (var i = 0; i < rivers.length && i < 3; i++) {
      debugPrint('River ${i + 1}: ${rivers[i].name}');
      debugPrint('  coordinates: ${rivers[i].coordinates}');
      debugPrint('  putInCoordinates: ${rivers[i].putInCoordinates}');
    }

    final markers = rivers
        .where((river) {
          // Try coordinates first, then putInCoordinates as fallback
          return river.coordinates != null || river.putInCoordinates != null;
        })
        .map((river) {
          // Use coordinates if available, otherwise use putInCoordinates
          final coords = river.coordinates ?? river.putInCoordinates!;

          return Marker(
            point: LatLng(coords['latitude']!, coords['longitude']!),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _onMarkerTapped(river),
              child: Icon(
                Icons.water_drop,
                color: _selectedRiver?.riverId == river.riverId
                    ? Colors.orange
                    : Colors.blue,
                size: 30,
              ),
            ),
          );
        })
        .toList();

    debugPrint('Rivers with coordinates: ${markers.length}');
    if (markers.isNotEmpty) {
      debugPrint('First marker at: ${markers.first.point}');
    }
    debugPrint('===========================');

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final riverRunsAsync = ref.watch(riverRunsStreamProvider);

    return Stack(
      children: [
        // Map
        RepaintBoundary(
          child: riverRunsAsync.when(
            data: (rivers) => FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(
                  49.2827,
                  -123.1207,
                ), // Vancouver, BC
                initialZoom: 9.0,
                minZoom: 6.0,
                maxZoom: 15.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedRiver = null;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.brownpaw.app',
                  maxNativeZoom: 19,
                  maxZoom: 15,
                  keepBuffer: 2,
                  panBuffer: 1,
                  tileBuilder: (context, widget, tile) {
                    return widget;
                  },
                ),
                MarkerLayer(markers: _buildMarkers(rivers)),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Error loading rivers: $error')),
          ),
        ),

        // Bottom sheet
        if (_selectedRiver != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 5) {
                  setState(() {
                    _selectedRiver = null;
                  });
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedRiver!.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedRiver!.river} - ${_selectedRiver!.province}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.7),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 16,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedRiver!.difficultyClass,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (_selectedRiver!.length != null) ...[
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.straighten,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.7),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedRiver!.length!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                // TODO: Navigate to river detail
                              },
                              child: const Text('View Details'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
