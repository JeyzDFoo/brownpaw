import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A line of flow over time. With [filled], shades the area under it and
/// draws a baseline, for the larger chart on a gauge page.
class FlowSparkline extends StatelessWidget {
  const FlowSparkline({
    super.key,
    required this.values,
    this.width = 76,
    this.height = 32,
    this.filled = false,
    this.semanticLabel,
  });

  final List<double> values;
  final double width;
  final double height;
  final bool filled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chart = SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparkPainter(
          values: values,
          color: theme.colorScheme.primary,
          baseline: theme.colorScheme.outlineVariant,
          filled: filled,
        ),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: chart);
    return Semantics(label: semanticLabel, image: true, child: chart);
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.color,
    required this.baseline,
    required this.filled,
  });

  final List<double> values;
  final Color color;
  final Color baseline;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = filled ? 3.0 : 2.5;
    final pad = stroke;
    final bottom = filled ? size.height - 10 : size.height - pad;
    if (filled) {
      canvas.drawLine(
        Offset(0, bottom),
        Offset(size.width, bottom),
        Paint()
          ..color = baseline
          ..strokeWidth = 1,
      );
    }
    if (values.length < 2) return;

    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span = hi - lo == 0 ? 1.0 : hi - lo;
    final top = pad;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          i / (values.length - 1) * size.width,
          bottom - (values[i] - lo) / span * (bottom - top),
        ),
    ];
    final line = Path()..addPolygon(points, false);

    if (filled) {
      final area = Path()
        ..moveTo(0, bottom)
        ..addPolygon(points, false)
        ..lineTo(size.width, bottom)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.10));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.color != color || old.filled != filled;
}
