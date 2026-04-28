import 'package:flutter/material.dart';

/// Ordered list of difficulty levels including modifiers.
const List<String> _kDifficultyLevels = [
  'I',
  'II',
  'II+',
  'III-',
  'III',
  'III+',
  'IV-',
  'IV',
  'IV+',
  'V-',
  'V',
  'V+',
  'VI',
];

/// A widget for displaying and editing difficulty level in Roman numerals (I-VI)
/// with +/- modifiers.
class DifficultySelector extends StatefulWidget {
  final String? initialDifficulty;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const DifficultySelector({
    super.key,
    this.initialDifficulty,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<DifficultySelector> createState() => _DifficultySelectorState();
}

class _DifficultySelectorState extends State<DifficultySelector> {
  late String? _difficulty;

  @override
  void initState() {
    super.initState();
    _difficulty = _snapToLevel(widget.initialDifficulty);
  }

  @override
  void didUpdateWidget(DifficultySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDifficulty != oldWidget.initialDifficulty) {
      setState(() {
        _difficulty = _snapToLevel(widget.initialDifficulty);
      });
    }
  }

  /// Snaps a raw difficulty string (e.g. "IV/IV+", "III-IV") to the nearest
  /// level in [_kDifficultyLevels]. Returns null if raw is null.
  String? _snapToLevel(String? raw) {
    if (raw == null) return null;
    if (_kDifficultyLevels.contains(raw)) return raw;
    // Try extracting the first Roman numeral + optional modifier
    final match = RegExp(
      r'(VI|V\+|V-|V|IV\+|IV-|IV|III\+|III-|III|II\+|II|I)',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match != null) {
      final candidate = match.group(0)!.toUpperCase();
      if (_kDifficultyLevels.contains(candidate)) return candidate;
      // Strip modifier and fall back to base
      final base = RegExp(
        r'(VI|V|IV|III|II|I)',
        caseSensitive: false,
      ).firstMatch(candidate)?.group(0)?.toUpperCase();
      if (base != null && _kDifficultyLevels.contains(base)) return base;
    }
    return null;
  }

  int _currentIndex() {
    if (_difficulty == null) return 4; // default: III
    final idx = _kDifficultyLevels.indexOf(_difficulty!);
    return idx >= 0 ? idx : 4;
  }

  void _increment() {
    final idx = _currentIndex();
    if (idx < _kDifficultyLevels.length - 1) {
      setState(() => _difficulty = _kDifficultyLevels[idx + 1]);
      widget.onChanged(_difficulty);
    }
  }

  void _decrement() {
    final idx = _currentIndex();
    if (idx > 0) {
      setState(() => _difficulty = _kDifficultyLevels[idx - 1]);
      widget.onChanged(_difficulty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex();
    final canDecrement = widget.enabled && idx > 0;
    final canIncrement = widget.enabled && idx < _kDifficultyLevels.length - 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up_rounded,
                color: Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Difficulty',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Decrement button
              _StepButton(
                icon: Icons.remove,
                enabled: canDecrement,
                onPressed: _decrement,
              ),
              const SizedBox(width: 12),
              // Difficulty display
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Text(
                    _difficulty ?? 'III',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Increment button
              _StepButton(
                icon: Icons.add,
                enabled: canIncrement,
                onPressed: _increment,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: IconButton(
        icon: Icon(icon),
        onPressed: enabled ? onPressed : null,
        iconSize: 18,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}
