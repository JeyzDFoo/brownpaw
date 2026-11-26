import 'package:flutter/material.dart';

import '../domain/flow_ranges.dart';
import '../domain/flow_status.dart';
import '../theme/flow_status_style.dart';

/// A run's low / medium / high flows as a strip of bands, the one the
/// river is in now picked out, with the numbers where each band starts and
/// the guidebook's own words underneath.
class FlowRangeScale extends StatelessWidget {
  const FlowRangeScale({
    super.key,
    required this.ranges,
    this.status = FlowStatus.unknown,
    this.referenceOnly = false,
    this.title = 'Flow guide',
    this.showWords = true,
  });

  final FlowRanges ranges;

  /// Where the river is now; [FlowStatus.unknown] highlights nothing.
  final FlowStatus status;

  /// The numbers are read on a gauge the app can't compare with.
  final bool referenceOnly;

  /// The heading over the strip, e.g. the run's name on a gauge with
  /// several runs.
  final String title;

  /// Show the guidebook's own words under the strip.
  final bool showWords;

  List<({FlowStatus status, double? from})> get _bands {
    final r = ranges;
    return [
      if (r.low != null) (status: FlowStatus.tooLow, from: null),
      if (r.low != null)
        (
          status: r.medium == null ? FlowStatus.runnable : FlowStatus.low,
          from: r.low,
        ),
      if (r.low == null && r.medium != null)
        (status: FlowStatus.low, from: null),
      if (r.medium != null) (status: FlowStatus.medium, from: r.medium),
      if (r.low == null && r.medium == null && r.high != null)
        (status: FlowStatus.unknown, from: null),
      if (r.high != null) (status: FlowStatus.high, from: r.high),
      if (r.low == null && r.medium == null && r.high == null && r.max != null)
        (status: FlowStatus.runnable, from: null),
      if (r.max != null) (status: FlowStatus.tooHigh, from: r.max),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final bands = _bands;
    final unit = ranges.unit.symbol;

    final strip = LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth / bands.length;
        return SizedBox(
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  for (var i = 0; i < bands.length; i++)
                    Expanded(
                      child: _band(context, bands[i].status, i, bands.length),
                    ),
                ],
              ),
              for (var i = 0; i < bands.length; i++)
                if (bands[i].from case final from?)
                  Positioned(
                    left: i * w - 40,
                    width: 80,
                    top: 38,
                    child: Text(
                      FlowRanges.number(from),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );

    final words = showWords
        ? [
            if (ranges.note != null) '“${ranges.note}”',
            if (ranges.source != null) '– ${ranges.source}',
          ].join(' ')
        : '';

    return Semantics(
      label:
          '$title: ${ranges.summary}'
          '${status == FlowStatus.unknown ? '' : '. Now ${status.label}'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(unit, style: muted),
            ],
          ),
          const SizedBox(height: 6),
          strip,
          if (referenceOnly && ranges.gauge != null) ...[
            const SizedBox(height: 2),
            Text(
              'Read on ${ranges.gauge}, not the linked gauge.',
              style: muted,
            ),
          ] else if (referenceOnly) ...[
            const SizedBox(height: 2),
            Text('No online gauge to compare with yet.', style: muted),
          ],
          if (words.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(words, style: muted?.copyWith(fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _band(BuildContext context, FlowStatus band, int i, int n) {
    final theme = Theme.of(context);
    final color = band == FlowStatus.unknown
        ? theme.colorScheme.onSurfaceVariant
        : band.color(context);
    final active = band == status && status != FlowStatus.unknown;
    final radius = BorderRadius.horizontal(
      left: i == 0 ? const Radius.circular(10) : Radius.zero,
      right: i == n - 1 ? const Radius.circular(10) : Radius.zero,
    );
    return Container(
      height: 34,
      margin: EdgeInsets.only(right: i == n - 1 ? 0 : 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? color : color.withValues(alpha: 0.14),
        borderRadius: radius,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (active) ...[
                Icon(Icons.place, size: 14, color: theme.colorScheme.surface),
                const SizedBox(width: 2),
              ],
              Text(
                band == FlowStatus.unknown ? 'Below high' : band.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: active ? theme.colorScheme.surface : color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
