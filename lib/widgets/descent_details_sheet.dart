import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/descent.dart';
import '../providers/descents_provider.dart';

class DescentDetailsSheet extends StatefulWidget {
  final Descent descent;
  final ScrollController scrollController;
  final WidgetRef ref;

  const DescentDetailsSheet({
    super.key,
    required this.descent,
    required this.scrollController,
    required this.ref,
  });

  @override
  State<DescentDetailsSheet> createState() => _DescentDetailsSheetState();
}

class _DescentDetailsSheetState extends State<DescentDetailsSheet> {
  late DateTime _selectedDate;
  late TextEditingController _flowController;
  late TextEditingController _notesController;
  late int? _rating;
  late bool _isPublic;
  bool _isSaving = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.descent.date;
    _flowController = TextEditingController(
      text: widget.descent.flow?.toStringAsFixed(1) ?? '',
    );
    _notesController = TextEditingController(text: widget.descent.notes ?? '');
    _rating = widget.descent.rating;
    _isPublic = widget.descent.isPublic;

    _flowController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _flowController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 1), _saveChanges);
  }

  void _onImmediateChange() {
    _debounceTimer?.cancel();
    _saveChanges();
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
      _onImmediateChange();
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      await widget.ref
          .read(descentsProvider.notifier)
          .updateDescent(
            descentId: widget.descent.id,
            date: _selectedDate,
            flow: _flowController.text.isNotEmpty
                ? double.tryParse(_flowController.text)
                : null,
            flowUnit: _flowController.text.isNotEmpty
                ? (widget.descent.flowUnit ?? 'cms')
                : null,
            notes: _notesController.text.isNotEmpty
                ? _notesController.text
                : null,
            rating: _rating,
            isPublic: _isPublic,
          );

      if (mounted) {
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (_isSaving) ...[
                const SizedBox(width: 12),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Header with gradient
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'descent_${widget.descent.id}',
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.kayaking,
                      size: 36,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.descent.runName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectDate(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surface.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat(
                                  'EEEE, MMMM d, yyyy',
                                ).format(_selectedDate),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                // Rating prominently displayed
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.withOpacity(0.2),
                        Colors.amber.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Your Rating',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _rating = index + 1;
                              });
                              _onImmediateChange();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Icon(
                                (_rating != null && index < _rating!)
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 32,
                                color: Colors.amber,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      if (_rating != null)
                        Text(
                          '$_rating/5',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade700,
                              ),
                        )
                      else
                        Text(
                          'Tap to rate',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                              ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Flow Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flow',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _flowController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter flow rate',
                        suffixText: widget.descent.flowUnit ?? 'cms',
                        prefixIcon: const Icon(Icons.water_drop_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Difficulty (read-only)
                if (widget.descent.difficulty != null)
                  InfoCard(
                    icon: Icons.trending_up_rounded,
                    label: 'Difficulty',
                    value: widget.descent.difficulty!,
                    unit: '',
                    color: Colors.orange,
                  ),

                const SizedBox(height: 16),

                // Visibility Toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isPublic
                        ? Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer.withOpacity(0.3)
                        : Theme.of(context).colorScheme.surfaceContainerHighest
                              .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isPublic
                          ? Theme.of(
                              context,
                            ).colorScheme.tertiary.withOpacity(0.3)
                          : Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _isPublic
                              ? Theme.of(context).colorScheme.tertiaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isPublic ? Icons.public_rounded : Icons.lock_rounded,
                          size: 20,
                          color: _isPublic
                              ? Theme.of(
                                  context,
                                ).colorScheme.onTertiaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isPublic ? 'Public Descent' : 'Private Descent',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isPublic
                                  ? 'Visible in public logbook'
                                  : 'Only visible to you',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPublic,
                        onChanged: (value) {
                          setState(() {
                            _isPublic = value;
                          });
                          _onImmediateChange();
                        },
                      ),
                    ],
                  ),
                ),

                // Photos Section
                if (widget.descent.photos != null &&
                    widget.descent.photos!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Photos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.descent.photos!.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 120,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Image.network(
                              widget.descent.photos![index],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.3),
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

                // Notes Section
                const SizedBox(height: 20),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 5,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Add notes about your descent...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                  ),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),

                // Metadata Section
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Details',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      MetadataRow(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Logged',
                        value: DateFormat(
                          'MMM d, yyyy \'at\' h:mm a',
                        ).format(widget.descent.createdAt),
                      ),
                      if (widget.descent.updatedAt != null) ...[
                        const SizedBox(height: 8),
                        MetadataRow(
                          icon: Icons.edit_outlined,
                          label: 'Updated',
                          value: DateFormat(
                            'MMM d, yyyy \'at\' h:mm a',
                          ).format(widget.descent.updatedAt!),
                        ),
                      ],
                      const SizedBox(height: 8),
                      MetadataRow(
                        icon: Icons.fingerprint_rounded,
                        label: 'ID',
                        value: widget.descent.id.substring(0, 8),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Delete Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(context);
                          },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete Descent'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withOpacity(0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.errorContainer.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            size: 32,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        title: const Text('Delete Descent'),
        content: const Text(
          'Are you sure you want to delete this descent? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await widget.ref
                  .read(descentsProvider.notifier)
                  .deleteDescent(widget.descent.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle : Icons.error,
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          success
                              ? 'Descent deleted'
                              : 'Failed to delete descent',
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const InfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: color.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MetadataRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const MetadataRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
