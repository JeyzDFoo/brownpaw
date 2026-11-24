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
