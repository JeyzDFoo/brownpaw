import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tab bar icons drawn in code rather than taken from an icon font, so they
/// never depend on a font file the browser may have cached from an older
/// build. Each comes in an outline (unselected) and filled (selected) form.
enum NavGlyph { logbook, gauges, community, me, add }

class NavIcon extends StatelessWidget {
  const NavIcon(this.glyph, {super.key, this.filled = false, this.color});

  final NavGlyph glyph;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = iconTheme.size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _NavIconPainter(
          glyph,
          filled: filled,
          color: color ?? iconTheme.color ?? Colors.black,
        ),
      ),
    );
  }
}

class _NavIconPainter extends CustomPainter {
  _NavIconPainter(this.glyph, {required this.filled, required this.color});

  final NavGlyph glyph;
  final bool filled;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw on a 24-unit grid, like Material icons.
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (glyph) {
      case NavGlyph.logbook:
        _logbook(canvas, stroke, fill);
      case NavGlyph.gauges:
        _gauge(canvas, stroke, fill);
      case NavGlyph.community:
        _community(canvas, stroke, fill);
      case NavGlyph.me:
        _person(canvas, stroke, fill, const Offset(12, 0), 1);
      case NavGlyph.add:
        final bar = Paint()
          ..color = color
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), bar);
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), bar);
    }
  }

  // An open book. Filled: solid pages with a gap for the spine.
  void _logbook(Canvas canvas, Paint stroke, Paint fill) {
    Path page(bool left) {
      final s = left ? -1.0 : 1.0;
      final x = 12 + (filled ? 0.9 * s : 0.0);
      return Path()
        ..moveTo(x, 6.5)
        ..cubicTo(x + 2.5 * s, 4.8, x + 5.5 * s, 4.6, 12 + 8.8 * s, 5.2)
        ..lineTo(12 + 8.8 * s, 18.2)
        ..cubicTo(x + 5.5 * s, 17.6, x + 2.5 * s, 17.8, x, 19.5)
        ..close();
    }

    for (final left in [true, false]) {
      final p = page(left);
      if (filled) canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    }
  }

  // A dial with a needle. Filled: a heavier dial.
  void _gauge(Canvas canvas, Paint stroke, Paint fill) {
    const c = Offset(12, 15.5);
    const r = 8.5;
    final dial = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = filled ? 2.6 : 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      math.pi * 0.95,
      math.pi * 1.1,
      false,
      dial,
    );
    canvas.drawLine(c, const Offset(16.4, 9.6), dial);
    canvas.drawCircle(c, filled ? 2.2 : 1.6, fill);
  }

  // A head and shoulders, centred on [at].dx.
  void _person(Canvas canvas, Paint stroke, Paint fill, Offset at, double s) {
    final head = Offset(at.dx, 8 * s + at.dy);
    final body = Path()
      ..moveTo(at.dx - 7 * s, 20 * s + at.dy)
      ..cubicTo(
        at.dx - 7 * s,
        15.5 * s + at.dy,
        at.dx - 4 * s,
        13.5 * s + at.dy,
        at.dx,
        13.5 * s + at.dy,
      )
      ..cubicTo(
        at.dx + 4 * s,
        13.5 * s + at.dy,
        at.dx + 7 * s,
        15.5 * s + at.dy,
        at.dx + 7 * s,
        20 * s + at.dy,
      )
      ..close();
    if (filled) {
      canvas.drawCircle(head, 3.6 * s, fill);
      canvas.drawPath(body, fill);
    }
    canvas.drawCircle(head, 3.6 * s, stroke);
    canvas.drawPath(body, stroke);
  }

  void _community(Canvas canvas, Paint stroke, Paint fill) {
    _person(canvas, stroke, fill, const Offset(8, 1.5), 0.82);
    _person(canvas, stroke, fill, const Offset(16, 1.5), 0.82);
  }

  @override
  bool shouldRepaint(_NavIconPainter old) =>
      old.glyph != glyph || old.filled != filled || old.color != color;
}
