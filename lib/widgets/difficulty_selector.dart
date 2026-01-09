import 'package:flutter/material.dart';

/// A widget for displaying and editing difficulty level in Roman numerals (I-VI)
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
    _difficulty = widget.initialDifficulty;
  }

  @override
  void didUpdateWidget(DifficultySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDifficulty != oldWidget.initialDifficulty) {
      setState(() {
        _difficulty = widget.initialDifficulty;
      });
    }
  }

  void _incrementDifficulty() {
    int currentNum = _parseDifficultyNumber(_difficulty);
    if (currentNum < 6) {
      setState(() {
        _difficulty = _toRoman(currentNum + 1);
      });
      widget.onChanged(_difficulty);
    }
  }

  void _decrementDifficulty() {
    int currentNum = _parseDifficultyNumber(_difficulty);
    if (currentNum > 1) {
      setState(() {
        _difficulty = _toRoman(currentNum - 1);
      });
      widget.onChanged(_difficulty);
    }
  }

  int _parseDifficultyNumber(String? difficulty) {
    if (difficulty == null) return 1;

    final match = RegExp(
      r'(I{1,3}V?|VI?)',
      caseSensitive: false,
    ).firstMatch(difficulty.toUpperCase());

    if (match == null) return 1;

    final roman = match.group(0)!.toUpperCase();

    switch (roman) {
      case 'I':
        return 1;
      case 'II':
        return 2;
      case 'III':
        return 3;
      case 'IV':
        return 4;
      case 'V':
        return 5;
      case 'VI':
        return 6;
      default:
        return 1;
    }
  }

  String _toRoman(int number) {
    switch (number) {
      case 1:
        return 'I';
      case 2:
        return 'II';
      case 3:
        return 'III';
      case 4:
        return 'IV';
      case 5:
        return 'V';
      case 6:
        return 'VI';
      default:
        return 'I';
    }
  }

  String? _extractRomanNumeral(String? difficulty) {
    if (difficulty == null) return null;

    if (RegExp(r'^(I{1,3}V?|VI?)$').hasMatch(difficulty.toUpperCase())) {
      return difficulty.toUpperCase();
    }

    final match = RegExp(
      r'(I{1,3}V?|VI?)',
    ).firstMatch(difficulty.toUpperCase());
    return match?.group(0);
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Container(
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
                Icon(Icons.trending_up_rounded, color: Colors.orange, size: 20),
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
            IntrinsicHeight(
              child: Row(
                children: [
                  // Decrement button
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed:
                          widget.enabled &&
                              _parseDifficultyNumber(_difficulty) > 1
                          ? _decrementDifficulty
                          : null,
                      iconSize: 18,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
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
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _extractRomanNumeral(_difficulty) ?? 'I',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Increment button
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed:
                          widget.enabled &&
                              _parseDifficultyNumber(_difficulty) < 6
                          ? _incrementDifficulty
                          : null,
                      iconSize: 18,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
