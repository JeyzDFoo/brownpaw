import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/river_run.dart';
import '../providers/river_runs_provider.dart';

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
      });
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
                      setState(() => _searchQuery = value.toLowerCase());
                    },
                  ),
                ],
              ),
            ),

            // Run List
            Expanded(
              child: riverRunsAsync.when(
                data: (runs) {
                  final filteredRuns = _searchQuery.isEmpty
                      ? runs
                      : runs.where((run) {
                          final searchLower = _searchQuery.toLowerCase();
                          return run.name.toLowerCase().contains(searchLower) ||
                              run.river.toLowerCase().contains(searchLower) ||
                              (run.region?.toLowerCase().contains(
                                    searchLower,
                                  ) ??
                                  false);
                        }).toList();

                  if (filteredRuns.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
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
