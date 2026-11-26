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
  final Color low;
  final Color runnable;
  final Color medium;
  final Color high;
  final Color tooHigh;

  const FlowStatusColors({
    required this.unknown,
    required this.tooLow,
    required this.low,
    required this.runnable,
    required this.medium,
    required this.high,
    required this.tooHigh,
  });

  // Riverstone, a ramp from dry to flood: ochre (too low), moss (low),
  // glacier blue (medium, the sweet spot), deep river blue (high) and red
  // clay (too high). Plain ink for "runnable". See [Riverstone].
  static const light = FlowStatusColors(
    unknown: Color(0xFF7A6A5E),
    tooLow: Color(0xFF9A6A10),
    low: Color(0xFF5B7322),
    runnable: Color(0xFF3A2B22),
    medium: Color(0xFF2C7C82),
    high: Color(0xFF2E5A9A),
    tooHigh: Color(0xFFB23A28),
  );

  static const dark = FlowStatusColors(
    unknown: Color(0xFFB5A698),
    tooLow: Color(0xFFE3B04F),
    low: Color(0xFFB4CC6E),
    runnable: Color(0xFFF1E8DE),
    medium: Color(0xFF6FC1C5),
    high: Color(0xFF93B5EE),
    tooHigh: Color(0xFFF08A78),
  );

  Color of(FlowStatus status) => switch (status) {
    FlowStatus.unknown => unknown,
    FlowStatus.tooLow => tooLow,
    FlowStatus.low => low,
    FlowStatus.medium => medium,
    FlowStatus.high => high,
    FlowStatus.tooHigh => tooHigh,
  };

  @override
  FlowStatusColors copyWith({
    Color? unknown,
    Color? tooLow,
    Color? low,
    Color? runnable,
    Color? medium,
    Color? high,
    Color? tooHigh,
  }) => FlowStatusColors(
    unknown: unknown ?? this.unknown,
    tooLow: tooLow ?? this.tooLow,
    low: low ?? this.low,
    runnable: runnable ?? this.runnable,
    medium: medium ?? this.medium,
    high: high ?? this.high,
    tooHigh: tooHigh ?? this.tooHigh,
  );

  @override
  FlowStatusColors lerp(FlowStatusColors? other, double t) {
    if (other == null) return this;
    return FlowStatusColors(
      unknown: Color.lerp(unknown, other.unknown, t)!,
      tooLow: Color.lerp(tooLow, other.tooLow, t)!,
      low: Color.lerp(low, other.low, t)!,
      runnable: Color.lerp(runnable, other.runnable, t)!,
      medium: Color.lerp(medium, other.medium, t)!,
      high: Color.lerp(high, other.high, t)!,
      tooHigh: Color.lerp(tooHigh, other.tooHigh, t)!,
    );
  }
}

extension FlowStatusStyle on FlowStatus {
  IconData get icon => switch (this) {
    FlowStatus.unknown => Icons.help_outline,
    FlowStatus.tooLow => Icons.arrow_downward,
    FlowStatus.low => Icons.trending_down,
    FlowStatus.medium => Icons.check_circle,
    FlowStatus.high => Icons.trending_up,
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
