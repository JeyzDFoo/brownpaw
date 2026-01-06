import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/providers/river_runs_provider.dart';
import 'package:brownpaw/screens/run_details_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  RiverRun? _selectedRiver;
  double _sheetHeight = 0.5; // 0.0 to 1.0, representing percentage of screen

  static const double _minSheetHeight = 0.3;
  static const double _maxSheetHeight = 0.9;

  void _onMarkerTapped(RiverRun river) {
    setState(() {
      _selectedRiver = river;
      _sheetHeight = 0.6;
    });
  }

  String _getDifficultyNumber(String difficultyClass) {
    // Extract the first difficulty number from strings like "Class III", "IV/IV+", "II-III"
    final match = RegExp(r'(?:Class\s+)?([IVX]+)').firstMatch(difficultyClass);
    if (match != null) {
      return match.group(1)!;
    }

    // If no Roman numerals found, try regular numbers
    final numberMatch = RegExp(r'(\d+)').firstMatch(difficultyClass);
    if (numberMatch != null) {
      return numberMatch.group(1)!;
    }

    return '?';
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
            width: 30,
            height: 30,
            child: GestureDetector(
              onTap: () => _onMarkerTapped(river),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedRiver?.riverId == river.riverId
                      ? Colors.orange
                      : Colors.blue,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getDifficultyNumber(river.difficultyClass),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
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
            top: MediaQuery.of(context).size.height * (1 - _sheetHeight),
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final delta = -details.delta.dy / screenHeight;
                  _sheetHeight = (_sheetHeight + delta).clamp(
                    _minSheetHeight,
                    _maxSheetHeight,
                  );
                });
              },
              onVerticalDragEnd: (details) {
                // Close if dragged down quickly or below threshold
                if (details.primaryVelocity! > 500 ||
                    _sheetHeight < _minSheetHeight + 0.05) {
                  setState(() {
                    _selectedRiver = null;
                    _sheetHeight = 0.5;
                  });
                }
                // Otherwise, stay wherever it's dropped
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
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
                    // Run details content
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: RunDetailsScreen(runId: _selectedRiver!.riverId),
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
