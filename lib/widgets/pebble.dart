import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A filled pebble card, optionally tappable. The building block for cards
/// across the app.
class PebbleCard extends StatelessWidget {
  const PebbleCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.seed,
    this.radius,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Picks one of the pebble shapes, so neighbouring cards differ slightly.
  /// Pass something stable per item, such as its id.
  final Object? seed;

  /// Overrides [seed].
  final BorderRadius? radius;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? Pebble.alternating(seed);
    return Material(
      color: color ?? Riverstone.of(context).card,
      shape: Pebble.shape(r),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

/// A small heading above a group, such as "Recent".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          fontSize: 13,
          letterSpacing: 0.3,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The paw logo as a line drawing in the brand orange (or [color]).
class BrownpawMark extends StatelessWidget {
  const BrownpawMark({super.key, this.size = 36, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'images/brownpaw-mark.png',
      width: size,
      height: size,
      color: color ?? Riverstone.of(context).accent,
      colorBlendMode: BlendMode.srcIn,
      excludeFromSemantics: true,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Placeholder pebbles shown while a screen's first data loads, in the
/// shape of what's coming, so the page doesn't jump when it arrives.
/// Fades in gently, so a quick load never flashes it.
class LoadingPebbles extends StatelessWidget {
  const LoadingPebbles({
    super.key,
    this.count = 4,
    this.height = 84,
    this.header = false,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
  });

  /// How many card-shaped pebbles.
  final int count;
  final double height;

  /// A row of three small tiles on top, like the logbook's season stats.
  final bool header;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = Riverstone.of(context);
    final fill = Color.alphaBlend(p.faint.withValues(alpha: 0.6), p.paper);
    Widget block(double h, BorderRadius r) => Container(
      height: h,
      decoration: BoxDecoration(color: fill, borderRadius: r),
    );
    return Semantics(
      label: 'Loading',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: const Interval(0.3, 1, curve: Curves.easeOut),
        builder: (context, t, child) => Opacity(opacity: t, child: child),
        child: ListView(
          padding: padding,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            if (header) ...[
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: block(78, Pebble.alternating(i))),
                  ],
                ],
              ),
              const SizedBox(height: 24),
            ],
            for (var i = 0; i < count; i++) ...[
              block(height, Pebble.alternating(i)),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
