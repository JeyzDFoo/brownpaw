import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/descents_provider.dart';
import '../providers/realtime_flow_provider.dart';

class LogDescentDialog extends ConsumerStatefulWidget {
  final String runId;
  final String runName;
  final double? initialFlow;
  final String? stationId;
  final String? difficulty;

  const LogDescentDialog({
    super.key,
    required this.runId,
    required this.runName,
    this.initialFlow,
    this.stationId,
    this.difficulty,
  });

  @override
  ConsumerState<LogDescentDialog> createState() => _LogDescentDialogState();
}

class _LogDescentDialogState extends ConsumerState<LogDescentDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  final _flowController = TextEditingController();
  final _notesController = TextEditingController();
  int? _rating;
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // Pre-populate flow if available
    if (widget.initialFlow != null) {
      _flowController.text = widget.initialFlow!.toStringAsFixed(1);
    } else if (widget.stationId != null) {
      // Fetch the most recent flow if no initial flow provided
      _fetchMostRecentFlow();
    }
  }

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

  Future<void> _fetchMostRecentFlow() async {
    if (widget.stationId == null) return;

    try {
      print('🌊 Fetching most recent flow for station: ${widget.stationId}');

      // Normalize station ID
      String stationPath = widget.stationId!;
      if (!stationPath.startsWith('Provider.')) {
        if (stationPath.contains('_')) {
          final parts = stationPath.split('_');
          final provider = parts.take(parts.length - 1).join('_').toUpperCase();
          final station = parts.last;
          stationPath = 'Provider.${provider}_$station';
        } else {
          stationPath = 'Provider.ENVIRONMENT_CANADA_$stationPath';
        }
      }

      print('📅 Fetching most recent daily average for: $stationPath');

      // Fetch the most recent year's data
      final year = DateTime.now().year;
      final doc = await FirebaseFirestore.instance
          .collection('station_data')
          .doc(stationPath)
          .collection('readings')
          .doc(year.toString())
          .get();

      if (doc.exists) {
        final data = doc.data();
        final dailyReadings = data?['daily_readings'] as Map<String, dynamic>?;

        if (dailyReadings != null && dailyReadings.isNotEmpty) {
          // Get the most recent date with data
          final sortedDates = dailyReadings.keys.toList()..sort();
          final mostRecentDate = sortedDates.last;

          final reading =
              dailyReadings[mostRecentDate] as Map<String, dynamic>?;
          final discharge = reading?['mean_discharge'] as double?;

          print('💧 Most recent daily discharge ($mostRecentDate): $discharge');

          if (discharge != null && mounted) {
            setState(() {
              _flowController.text = discharge.toStringAsFixed(1);
            });
          }
        } else {
          print('❌ No daily readings found');
        }
      } else {
        print(
          '❌ No document found for station path: $stationPath, year: $year',
        );
      }
    } catch (e) {
      print('❌ Error fetching flow: $e');
      // Silently fail - user can manually enter flow
    }
  }

  Future<void> _updateFlowForDate(DateTime date) async {
    // This method is no longer used but kept for backwards compatibility
    await _fetchMostRecentFlow();
  }

  Future<void> _saveDescent() async {
    if (!_formKey.currentState!.validate()) return;

    final descentId = await ref
        .read(descentsProvider.notifier)
        .addDescent(
          runId: widget.runId,
          runName: widget.runName,
          date: _selectedDate,
          flow: _flowController.text.isNotEmpty
              ? double.tryParse(_flowController.text)
              : null,
          flowUnit: _flowController.text.isNotEmpty ? 'cms' : null,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
          rating: _rating,
          difficulty: widget.difficulty,
          isPublic: _isPublic,
        );

    if (descentId != null && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descent logged successfully!')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to log descent')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final descentsState = ref.watch(descentsProvider);

    return AlertDialog(
      title: const Text('Log Descent'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Run name
              Text(
                widget.runName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
              const SizedBox(height: 8),

              // Flow
              TextFormField(
                controller: _flowController,
                decoration: const InputDecoration(
                  labelText: 'Flow (m³/s)',
                  hintText: 'Optional',
                  prefixIcon: Icon(Icons.water),
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),

              // Rating
              const Text('Rating'),
              const SizedBox(height: 8),
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
                    ),
                    onPressed: () => setState(() => _rating = starValue),
                  );
                }),
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
              // Public visibility toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Make Public'),
                subtitle: const Text(
                  'Record this descent in the public logbook',
                ),
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: descentsState.isLoading
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: descentsState.isLoading ? null : _saveDescent,
          child: descentsState.isLoading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
