import 'package:flutter/material.dart';

import '../domain/flow_status.dart';
import '../theme/flow_status_style.dart';

/// A compact "Low / Runnable / Good / High" badge: colour, icon and word,
/// so it reads without relying on colour.
class FlowStatusChip extends StatelessWidget {
  final FlowStatus status;

  /// Larger text and padding, for the top of a run or gauge page.
  final bool large;

  const FlowStatusChip({super.key, required this.status, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = status.color(context);
    final fg = color;
    final textStyle =
        (large
                ? Theme.of(context).textTheme.titleSmall
                : Theme.of(context).textTheme.labelMedium)
            ?.copyWith(color: fg, fontWeight: FontWeight.w800);

    return Semantics(
      label: 'Flow status: ${status.label}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 8,
          vertical: large ? 6 : 3,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: large ? 18 : 14, color: fg),
            SizedBox(width: large ? 6 : 4),
            Text(status.label, style: textStyle),
          ],
        ),
      ),
    );
  }
}
