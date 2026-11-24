import 'package:flutter/material.dart';

import '../domain/flow_status.dart';

/// Colours for [FlowStatus], registered on the app theme so light and dark
/// mode each get readable values. Always pair the colour with
/// [FlowStatusStyle.icon] and [FlowStatus.label]; colour alone is not enough
/// for colour-blind paddlers or bright sun.
@immutable
class FlowStatusColors extends ThemeExtension<FlowStatusColors> {
  final Color unknown;
  final Color tooLow;
  final Color runnable;
  final Color good;
  final Color tooHigh;

  const FlowStatusColors({
    required this.unknown,
    required this.tooLow,
    required this.runnable,
    required this.good,
    required this.tooHigh,
  });

  // Riverstone: glacier blue for "good", plain ink for "runnable", ochre
  // and red clay for out of range. See [Riverstone].
  static const light = FlowStatusColors(
    unknown: Color(0xFF7A6A5E),
    tooLow: Color(0xFF9A6A10),
    runnable: Color(0xFF3A2B22),
    good: Color(0xFF2C7C82),
    tooHigh: Color(0xFFB23A28),
  );

  static const dark = FlowStatusColors(
    unknown: Color(0xFFB5A698),
    tooLow: Color(0xFFE3B04F),
    runnable: Color(0xFFF1E8DE),
    good: Color(0xFF6FC1C5),
    tooHigh: Color(0xFFF08A78),
  );

  Color of(FlowStatus status) => switch (status) {
    FlowStatus.unknown => unknown,
    FlowStatus.tooLow => tooLow,
    FlowStatus.runnable => runnable,
    FlowStatus.good => good,
    FlowStatus.tooHigh => tooHigh,
  };

  @override
  FlowStatusColors copyWith({
    Color? unknown,
    Color? tooLow,
    Color? runnable,
    Color? good,
    Color? tooHigh,
  }) => FlowStatusColors(
    unknown: unknown ?? this.unknown,
    tooLow: tooLow ?? this.tooLow,
    runnable: runnable ?? this.runnable,
    good: good ?? this.good,
    tooHigh: tooHigh ?? this.tooHigh,
  );

  @override
  FlowStatusColors lerp(FlowStatusColors? other, double t) {
    if (other == null) return this;
    return FlowStatusColors(
      unknown: Color.lerp(unknown, other.unknown, t)!,
      tooLow: Color.lerp(tooLow, other.tooLow, t)!,
      runnable: Color.lerp(runnable, other.runnable, t)!,
      good: Color.lerp(good, other.good, t)!,
      tooHigh: Color.lerp(tooHigh, other.tooHigh, t)!,
    );
  }
}

extension FlowStatusStyle on FlowStatus {
  IconData get icon => switch (this) {
    FlowStatus.unknown => Icons.help_outline,
    FlowStatus.tooLow => Icons.arrow_downward,
    FlowStatus.runnable => Icons.check,
    FlowStatus.good => Icons.check_circle,
    FlowStatus.tooHigh => Icons.arrow_upward,
  };

  Color color(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<FlowStatusColors>() ??
        (theme.brightness == Brightness.dark
            ? FlowStatusColors.dark
            : FlowStatusColors.light);
    return colors.of(this);
  }
}
