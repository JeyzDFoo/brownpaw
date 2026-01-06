import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
      // Update flow for the selected date
      await _updateFlowForDate(picked);
    }
  }

  Future<void> _updateFlowForDate(DateTime date) async {
    if (widget.stationId == null) return;

    try {
      final flowData = await ref.read(
        realtimeFlowStreamProvider(widget.stationId!).future,
      );

      if (flowData == null) return;

      // Find the reading closest to the selected date
      final readings = flowData.flow.readings;
      if (readings.isEmpty) return;

      // Find reading for the selected date (or closest one)
      double? flowForDate;
      Duration? smallestDiff;

      for (final reading in readings) {
        if (reading.discharge == null) continue;

        final diff = reading.timestamp.difference(date).abs();
        if (smallestDiff == null || diff < smallestDiff) {
          smallestDiff = diff;
          flowForDate = reading.discharge;
        }
      }

      if (flowForDate != null && mounted) {
        setState(() {
          _flowController.text = flowForDate!.toStringAsFixed(1);
        });
      }
    } catch (e) {
      // Silently fail - user can manually enter flow
    }
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
