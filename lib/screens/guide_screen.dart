import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/river_run.dart';
import 'run_details_screen.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  String? _selectedProvince;
  String? _selectedRegion;
  List<String> _provinces = [];
  List<String> _regions = [];
  String? _filterError;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  List<RiverRun> _currentRuns = [];

  // Default center on Canada
  static const LatLng _defaultCenter = LatLng(54.0, -100.0);
  static const double _defaultZoom = 4.0;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    try {
      setState(() {
        _filterError = null;
      });

      // Load provinces
      final provinceSnapshot = await FirebaseFirestore.instance
          .collection('river_runs')
          .get();

      final provinces = <String>{};
      final regions = <String>{};

      for (var doc in provinceSnapshot.docs) {
        final data = doc.data();
        if (data['province'] != null) {
          provinces.add(data['province']);
        }
        if (data['region'] != null && data['region'].toString().isNotEmpty) {
          regions.add(data['region']);
        }
      }

      setState(() {
        _provinces = provinces.toList()..sort();
        _regions = regions.toList()..sort();
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading filter options: $e');
      debugPrint('Stack trace: $stackTrace');

      setState(() {
        _filterError = 'Failed to load filter options: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading filters: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadFilterOptions,
            ),
          ),
        );
      }
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('river_runs')
        .orderBy('river');

    if (_selectedProvince != null) {
      query = query.where('province', isEqualTo: _selectedProvince);
    }

    if (_selectedRegion != null) {
      query = query.where('region', isEqualTo: _selectedRegion);
    }

    return query;
  }

  void _updateMapMarkers(List<RiverRun> runs) {
    setState(() {
      _markers.clear();
      _currentRuns = runs;

      for (var run in runs) {
        // Try putInCoordinates first, then coordinates
        final coords = run.putInCoordinates ?? run.coordinates;

        if (coords != null &&
            coords['latitude'] != null &&
            coords['longitude'] != null) {
          final position = LatLng(coords['latitude']!, coords['longitude']!);

          _markers.add(
            Marker(
              markerId: MarkerId(run.riverId),
              position: position,
              infoWindow: InfoWindow(
                title: run.name,
                snippet: '${run.difficultyClass} • ${run.river}',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          RunDetailsScreen(runId: run.riverId),
                    ),
                  );
                },
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _getMarkerColor(run.difficultyMin),
              ),
            ),
          );
        }
      }

      // Update camera to show all markers
      if (_markers.isNotEmpty && _mapController != null) {
        _fitMapToMarkers();
      }
    });
  }

  double _getMarkerColor(int? difficultyMin) {
    if (difficultyMin == null) return BitmapDescriptor.hueBlue;
    if (difficultyMin <= 2) return BitmapDescriptor.hueGreen;
    if (difficultyMin == 3) return BitmapDescriptor.hueYellow;
    if (difficultyMin == 4) return BitmapDescriptor.hueOrange;
    return BitmapDescriptor.hueRed;
  }

  void _fitMapToMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (var marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng)
        minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng)
        maxLng = marker.position.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  Widget _buildMapHero() {
    return SizedBox(
      height: 300,
      child: GoogleMap(
        onMapCreated: (controller) {
          _mapController = controller;
        },
        initialCameraPosition: const CameraPosition(
          target: _defaultCenter,
          zoom: _defaultZoom,
        ),
        markers: _markers,
        mapType: MapType.terrain,
        myLocationButtonEnabled: true,
        myLocationEnabled: true,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_filterError != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _filterError!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadFilterOptions,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('province_$_selectedProvince'),
                  decoration: const InputDecoration(
                    labelText: 'Province',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedProvince,
                  isExpanded: true,
                  items: _provinces.isEmpty
                      ? null
                      : [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'All Provinces',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ..._provinces.map(
                            (province) => DropdownMenuItem<String>(
                              value: province,
                              child: Text(
                                province,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                  onChanged: _provinces.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            final oldProvince = _selectedProvince;
                            _selectedProvince = value;
                            // Clear region filter when province changes
                            if (value != oldProvince) {
                              _selectedRegion = null;
                            }
                          });
                        },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('region_$_selectedRegion'),
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedRegion,
                  isExpanded: true,
                  items: _regions.isEmpty
                      ? null
                      : [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'All Regions',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ..._regions.map(
                            (region) => DropdownMenuItem<String>(
                              value: region,
                              child: Text(
                                region,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                  onChanged: _regions.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            _selectedRegion = value;
                          });
                        },
                ),
              ),
            ],
          ),
          if (_selectedProvince != null || _selectedRegion != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedProvince = null;
                        _selectedRegion = null;
                      });
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Filters'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMapHero(),
        _buildFilters(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _buildQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                final errorMessage = error.toString();

                // Print detailed error information
                debugPrint('Firestore Error: $error');
                if (snapshot.stackTrace != null) {
                  debugPrint('Stack Trace: ${snapshot.stackTrace}');
                }

                // Show error details in console
                print('=== FIRESTORE ERROR DETAILS ===');
                print('Error Type: ${error.runtimeType}');
                print('Error Message: $errorMessage');
                print('Current Query Filters:');
                print('  Province: $_selectedProvince');
                print('  Region: $_selectedRegion');
                print('==============================');

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
                          errorMessage,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            // Force rebuild to retry the query
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                // Clear markers when no runs
                if (_markers.isNotEmpty) {
                  setState(() {
                    _markers.clear();
                    _currentRuns = [];
                  });
                }

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.explore,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedProvince != null || _selectedRegion != null
                            ? 'No runs match your filters'
                            : 'No runs found',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedProvince != null || _selectedRegion != null
                            ? 'Try adjusting your filter settings'
                            : 'Check back later for new runs',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }

              final runs = snapshot.data!.docs
                  .map((doc) => RiverRun.fromFirestore(doc))
                  .toList();

              // Update map markers with current runs
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _updateMapMarkers(runs);
              });

              return ListView.builder(
                itemCount: runs.length,
                itemBuilder: (context, index) {
                  final run = runs[index];

                  final title = run.name;
                  final subtitle = [
                    run.province,
                    if (run.region?.isNotEmpty == true) run.region,
                    run.difficultyClass,
                  ].where((s) => s != null && s.isNotEmpty).join(' • ');

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.water,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(title),
                      subtitle: Text(subtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RunDetailsScreen(runId: run.riverId),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
