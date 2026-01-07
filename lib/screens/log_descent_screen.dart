import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/river_run.dart';
import '../providers/river_runs_provider.dart';
import '../providers/user_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/realtime_flow_provider.dart';

class LogDescentScreen extends ConsumerStatefulWidget {
  const LogDescentScreen({super.key});

  @override
  ConsumerState<LogDescentScreen> createState() => _LogDescentScreenState();
}

class _LogDescentScreenState extends ConsumerState<LogDescentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _flowController = TextEditingController();
  final _notesController = TextEditingController();

  // Selected run data
  String? _selectedRunId;
  String? _selectedRunName;
  String? _selectedStationId;

  DateTime _selectedDate = DateTime.now();
  int? _rating;
  String? _textLevel; // low, medium, high
  bool _isPublic = true;

  @override
  void dispose() {
    _flowController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });

      // Update flow data for the new date if a run with station is selected
      if (_selectedStationId != null && _selectedStationId!.isNotEmpty) {
        _fetchAndPopulateFlow(_selectedStationId!);
      }
    }
  }

  Future<void> _selectRiverRun(BuildContext context) async {
    final run = await showModalBottomSheet<RiverRun>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const RiverRunSelector(),
    );

    if (run != null) {
      setState(() {
        _selectedRunId = run.riverId;
        _selectedRunName = '${run.river} - ${run.name}';
        _selectedStationId = run.stationId;
      });

      // Auto-populate flow if station data is available
      if (run.stationId != null && run.stationId!.isNotEmpty) {
        _fetchAndPopulateFlow(run.stationId!);
      }
    }
  }

  Future<void> _fetchAndPopulateFlow(String stationId) async {
    try {
      final now = DateTime.now();
      final isToday =
          _selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day;

      print(
        '🌊 Fetching flow for station: $stationId, date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)} (isToday: $isToday)',
      );

      double? discharge;

      if (isToday) {
        // Fetch real-time data for today
        final flowData = await ref.read(realtimeFlowProvider(stationId).future);
        discharge = flowData?.discharge;
        print('📊 Real-time discharge: $discharge m³/s');
      } else {
        // Fetch historical data directly from Firestore for past dates
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
        print('📅 Fetching historical data for: $dateStr');

        // Normalize station ID
        String stationPath = stationId;
        if (!stationId.startsWith('Provider.')) {
          // Convert "08GA071" or "environment_canada_08GA071" to "Provider.ENVIRONMENT_CANADA_08GA071"
          if (stationId.contains('_')) {
            final parts = stationId.split('_');
            final provider = parts
                .take(parts.length - 1)
                .join('_')
                .toUpperCase();
            final station = parts.last;
            stationPath = 'Provider.${provider}_$station';
          } else {
            stationPath = 'Provider.ENVIRONMENT_CANADA_$stationId';
          }
        }

        final year = _selectedDate.year;
        final doc = await FirebaseFirestore.instance
            .collection('station_data')
            .doc(stationPath)
            .collection('readings')
            .doc(year.toString())
            .get();

        if (doc.exists) {
          final data = doc.data();
          final dailyReadings =
              data?['daily_readings'] as Map<String, dynamic>?;
          final reading = dailyReadings?[dateStr] as Map<String, dynamic>?;
          discharge = reading?['mean_discharge'] as double?;
          print('📊 Historical discharge for $dateStr: $discharge m³/s');
        } else {
          print('⚠️ No readings document found for year $year');
        }
      }

      if (discharge != null) {
        setState(() {
          _flowController.text = discharge!.toStringAsFixed(1);
        });
        print('✅ Flow populated: $discharge m³/s');
      } else {
        setState(() {
          _flowController.text = '';
        });
        print(
          'ℹ️ No discharge data available for station $stationId on ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
        );
      }
    } catch (e) {
      print('❌ Error fetching flow data: $e');
      setState(() {
        _flowController.text = '';
      });
      // Don't show error to user - just leave flow field empty
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Descent')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // River Run Selection - Required Field
            Card(
              elevation: _selectedRunId == null ? 2 : 0,
              color: _selectedRunId == null
                  ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                  : theme.colorScheme.surface,
              child: InkWell(
                onTap: () => _selectRiverRun(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.kayaking,
                        size: 32,
                        color: _selectedRunId == null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'River Run',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '*',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedRunName ?? 'Select a river run',
                              style: TextStyle(
                                fontSize: 16,
                                color: _selectedRunId == null
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                                fontWeight: _selectedRunId == null
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: _selectedRunId == null
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(DateFormat('MMM d, yyyy').format(_selectedDate)),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 16),

            // Flow
            TextFormField(
              controller: _flowController,
              decoration: const InputDecoration(
                labelText: 'Flow (m³/s)',
                hintText: 'e.g., 25.5',
                helperText: 'Water flow at time of descent (optional)',
                prefixIcon: Icon(Icons.water),
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 24),

            // Text Level
            const Text(
              'Text Level',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'low',
                  label: Text('Low'),
                  icon: Icon(Icons.trending_down),
                ),
                ButtonSegment<String>(
                  value: 'medium',
                  label: Text('Medium'),
                  icon: Icon(Icons.trending_flat),
                ),
                ButtonSegment<String>(
                  value: 'high',
                  label: Text('High'),
                  icon: Icon(Icons.trending_up),
                ),
              ],
              selected: _textLevel != null ? {_textLevel!} : {},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _textLevel = newSelection.first;
                });
              },
              emptySelectionAllowed: true,
            ),
            const SizedBox(height: 24),

            // Rating
            const Text(
              'How was it?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  icon: Icon(
                    starValue <= (_rating ?? 0)
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _rating = starValue),
                );
              }),
            ),
            if (_rating != null)
              Center(
                child: Text(
                  _getRatingLabel(_rating!),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'How was it?',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),

            // Public visibility toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share in Public Logbook'),
              subtitle: const Text(
                'Other paddlers can see your descent and learn from conditions',
              ),
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
            ),
            const SizedBox(height: 24),

            // Save Button (inside scroll view to remain accessible with keyboard)
            FilledButton(
              onPressed: _selectedRunId == null
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        // TODO: Save descent
                        Navigator.pop(context);
                      }
                    },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Save Descent', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Not great';
      case 2:
        return 'It was okay';
      case 3:
        return 'Good time';
      case 4:
        return 'Really fun!';
      case 5:
        return 'Epic!';
      default:
        return '';
    }
  }
}

/// Modal bottom sheet for selecting a river run
class RiverRunSelector extends ConsumerStatefulWidget {
  const RiverRunSelector({super.key});

  @override
  ConsumerState<RiverRunSelector> createState() => _RiverRunSelectorState();
}

class _RiverRunSelectorState extends ConsumerState<RiverRunSelector> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riverRunsAsync = ref.watch(riverRunsStreamProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Select River Run',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search Field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search rivers...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                  // Create new option
                  if (_searchQuery.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: InkWell(
                          onTap: () async {
                            final user = ref.read(userProvider).user;
                            if (user == null) {
                              // Show error - user must be logged in
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please sign in to create runs',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }

                            try {
                              // Show loading indicator
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              // Create the run in Firestore
                              final riverRunsNotifier = ref.read(
                                riverRunsProvider,
                              );
                              final searchText = _searchController.text.trim();
                              final riverId = await riverRunsNotifier.createRun(
                                name: searchText,
                                river: searchText,
                                userId: user.uid,
                              );

                              // Create a RiverRun object to return
                              final newRun = RiverRun(
                                riverId: riverId,
                                name: searchText,
                                river: searchText,
                                province: 'Unknown',
                                difficultyClass: 'Unknown',
                                createdBy: user.uid,
                                verified: false,
                                visibility: 'private',
                              );

                              // Close loading dialog
                              if (context.mounted) {
                                Navigator.pop(context);
                                // Return the new run
                                Navigator.pop(context, newRun);
                              }
                            } catch (e) {
                              // Close loading dialog
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error creating run: $e'),
                                  ),
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  size: 20,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Create "${_searchController.text.trim()}"',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Run List
            Expanded(
              child: riverRunsAsync.when(
                data: (runs) {
                  final favoritesState = ref.watch(favoritesProvider);
                  final List<RiverRun> filteredRuns;

                  if (_searchQuery.isEmpty) {
                    // Show favorites when no search query
                    debugPrint(
                      '🔍 Favorites IDs: ${favoritesState.favoriteRunIds}',
                    );
                    debugPrint('🔍 Total runs available: ${runs.length}');
                    filteredRuns = runs.where((run) {
                      final isFav = favoritesState.favoriteRunIds.contains(
                        run.riverId,
                      );
                      if (isFav) {
                        debugPrint(
                          '✅ Found favorite: ${run.riverId} - ${run.name}',
                        );
                      }
                      return isFav;
                    }).toList();
                    debugPrint(
                      '🔍 Filtered favorites count: ${filteredRuns.length}',
                    );
                  } else {
                    // Filter by search query - only search name and river
                    final searchLower = _searchQuery.toLowerCase();
                    filteredRuns = runs.where((run) {
                      final nameMatch = run.name.toLowerCase().contains(
                        searchLower,
                      );
                      final riverMatch = run.river.toLowerCase().contains(
                        searchLower,
                      );
                      final match = nameMatch || riverMatch;

                      if (match) {
                        debugPrint(
                          '🔍 Match: "${run.river} - ${run.name}" (nameMatch: $nameMatch, riverMatch: $riverMatch)',
                        );
                      }

                      return match;
                    }).toList();

                    // Sort favorites to the top
                    filteredRuns.sort((a, b) {
                      final aIsFav = favoritesState.favoriteRunIds.contains(
                        a.riverId,
                      );
                      final bIsFav = favoritesState.favoriteRunIds.contains(
                        b.riverId,
                      );

                      if (aIsFav && !bIsFav) return -1;
                      if (!aIsFav && bIsFav) return 1;

                      // If both favorites or both not, sort by river then name
                      final riverCompare = a.river.compareTo(b.river);
                      if (riverCompare != 0) return riverCompare;
                      return a.name.compareTo(b.name);
                    });
                    debugPrint(
                      '🔍 Search "$_searchQuery" returned ${filteredRuns.length} results',
                    );
                  }

                  if (filteredRuns.isEmpty && _searchQuery.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_outline,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No favorites yet',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start typing to search for runs',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (filteredRuns.isEmpty && _searchQuery.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.7),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No runs found',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: () {
                              // Create a temporary RiverRun with the search query
                              final newRun = RiverRun(
                                riverId:
                                    'temp_${DateTime.now().millisecondsSinceEpoch}',
                                name: _searchController.text.trim(),
                                river: _searchController.text.trim(),
                                province: 'Unknown',
                                difficultyClass: 'Unknown',
                              );
                              Navigator.pop(context, newRun);
                            },
                            icon: const Icon(Icons.add),
                            label: Text(
                              'Create "${_searchController.text.trim()}"',
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredRuns.length,
                    itemBuilder: (context, index) {
                      final run = filteredRuns[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.kayaking,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                        title: Text(run.name),
                        subtitle: Text(
                          '${run.river} • ${run.difficultyClass}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, run),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
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
                        'Error loading runs',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          error.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
