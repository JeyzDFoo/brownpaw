import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/descent.dart';
import '../providers/descents_provider.dart';

class EditDescentDialog extends StatefulWidget {
  final Descent descent;
  final WidgetRef ref;

  const EditDescentDialog({
    super.key,
    required this.descent,
    required this.ref,
  });

  @override
  State<EditDescentDialog> createState() => _EditDescentDialogState();
}

class _EditDescentDialogState extends State<EditDescentDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late TextEditingController _flowController;
  late TextEditingController _notesController;
  late int? _rating;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.descent.date;
    _flowController = TextEditingController(
      text: widget.descent.flow?.toStringAsFixed(1) ?? '',
    );
    _notesController = TextEditingController(text: widget.descent.notes ?? '');
    _rating = widget.descent.rating;
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await widget.ref
        .read(descentsProvider.notifier)
        .updateDescent(
          descentId: widget.descent.id,
          date: _selectedDate,
          flow: _flowController.text.isNotEmpty
              ? double.tryParse(_flowController.text)
              : null,
          flowUnit: _flowController.text.isNotEmpty ? 'cms' : null,
          notes: _notesController.text.isNotEmpty
              ? _notesController.text
              : null,
          rating: _rating,
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Descent updated successfully'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update descent'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Descent'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Run name (read-only)
              Text(
                widget.descent.runName,
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
                    onPressed: () => setState(() {
                      _rating = _rating == starValue ? null : starValue;
                    }),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
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
