import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/providers/river_runs_provider.dart';
import 'package:brownpaw/providers/favorites_provider.dart';
import 'package:brownpaw/screens/run_details_screen.dart';

// Custom tween for smooth LatLng animation
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end})
    : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    final lat = begin!.latitude + (end!.latitude - begin!.latitude) * t;
    final lng = begin!.longitude + (end!.longitude - begin!.longitude) * t;
    return LatLng(lat, lng);
  }
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  RiverRun? _selectedRiver;
  double _sheetHeight = 0.5; // 0.0 to 1.0, representing percentage of screen
  late AnimationController _animationController;
  Animation<LatLng>? _positionAnimation;
  Animation<double>? _zoomAnimation;
  LatLng? _userLocation;

  static const double _minSheetHeight = 0.3;
  static const double _maxSheetHeight = 0.9;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onMarkerTapped(RiverRun river) {
    // Smoothly animate map to selected river, positioning marker above bottom sheet
    final coords = river.coordinates ?? river.putInCoordinates;
    if (coords != null) {
      final currentCenter = _mapController.camera.center;
      final currentZoom = _mapController.camera.zoom;
      final targetPosition = LatLng(
        coords['latitude']! - 0.01,
        coords['longitude']!,
      );
      const targetZoom = 14.0;

      // Create animations for position and zoom
      _positionAnimation =
          LatLngTween(begin: currentCenter, end: targetPosition).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOutCubic,
            ),
          );

      _zoomAnimation = Tween<double>(begin: currentZoom, end: targetZoom)
          .animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOutCubic,
            ),
          );

      // Listen to animation updates
      void updateMap() {
        if (_positionAnimation != null && _zoomAnimation != null) {
          _mapController.move(_positionAnimation!.value, _zoomAnimation!.value);
        }
      }

      _animationController.addListener(updateMap);

      // Start animation and clean up listener when done
      _animationController.forward(from: 0).then((_) {
        _animationController.removeListener(updateMap);
      });
    }

    setState(() {
      _selectedRiver = river;
      _sheetHeight = 0.6;
    });
  }

  Future<void> _centerOnUserLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions are permanently denied, we cannot request permissions.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition();

      // Store user location and trigger rebuild
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      // Animate to user's location
      final currentCenter = _mapController.camera.center;
      final currentZoom = _mapController.camera.zoom;
      final userLocation = LatLng(position.latitude, position.longitude);
      const targetZoom = 12.0;

      _positionAnimation = LatLngTween(begin: currentCenter, end: userLocation)
          .animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOutCubic,
            ),
          );

      _zoomAnimation = Tween<double>(begin: currentZoom, end: targetZoom)
          .animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOutCubic,
            ),
          );

      void updateMap() {
        if (_positionAnimation != null && _zoomAnimation != null) {
          _mapController.move(_positionAnimation!.value, _zoomAnimation!.value);
        }
      }

      _animationController.addListener(updateMap);

      _animationController.forward(from: 0).then((_) {
        _animationController.removeListener(updateMap);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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

  Marker _buildUserLocationMarker() {
    return Marker(
      point: _userLocation!,
      width: 20,
      height: 20,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.blue, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
          ),
        ),
      ),
    );
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
                  if (_selectedRiver != null) {
                    setState(() {
                      _selectedRiver = null;
                    });
                  }
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
                if (_userLocation != null)
                  MarkerLayer(markers: [_buildUserLocationMarker()]),
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
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
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

        // Location button
        Positioned(
          bottom: _selectedRiver != null
              ? MediaQuery.of(context).size.height * _sheetHeight + 20
              : 20,
          right: 20,
          child: FloatingActionButton(
            heroTag: "location_button",
            onPressed: _centerOnUserLocation,
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}
