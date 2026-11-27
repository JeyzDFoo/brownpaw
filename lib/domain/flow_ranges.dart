import '../data/gauge_repository.dart';
import '../models/river_run.dart';

/// What a run's flow numbers are measured in.
enum FlowUnit {
  /// Discharge, cubic metres per second.
  cms('m³/s'),

  /// Water level (stage) on the gauge, in metres.
  metres('m'),

  /// Tidal current speed, knots: at a tidal wave like Skookumchuck, the
  /// predicted max flood.
  knots('kt');

  const FlowUnit(this.symbol);
  final String symbol;

  static FlowUnit parse(Object? raw) {
    final s = raw?.toString().trim().toLowerCase();
    if (s == 'm' || s == 'metres' || s == 'meters') return FlowUnit.metres;
    if (s == 'kt' || s == 'kn' || s == 'kts' || s == 'knots') {
      return FlowUnit.knots;
    }
    return FlowUnit.cms;
  }

  /// How a flow or speed reads aloud.
  String get spoken => switch (this) {
    FlowUnit.cms => 'cubic metres per second',
    FlowUnit.metres => 'metres',
    FlowUnit.knots => 'knots',
  };
}

/// A run's low / medium / high flows, the way BC paddlers describe them:
/// "Low: 25 cms, Medium: 50 cms, High: 100 cms". Each number is where that
/// level starts. Any of them may be missing.
class FlowRanges {
  const FlowRanges({
    this.unit = FlowUnit.cms,
    this.low,
    this.medium,
    this.high,
    this.max,
    this.station,
    this.gauge,
    this.note,
    this.source,
  });

  final FlowUnit unit;

  /// Below this it's too low to bother.
  final double? low;

  /// Where medium starts: the sweet spot for most paddlers.
  final double? medium;

  /// Where high starts.
  final double? high;

  /// Above this it's too high for most.
  final double? max;

  /// The `station_current` id the numbers are read on, if it's an online
  /// gauge the app knows.
  final String? station;

  /// The gauge the numbers are read on when it isn't the run's linked
  /// gauge, in words: "the staff gauge at the take out".
  final String? gauge;

  /// The source's own words.
  final String? note;

  /// Who said so, e.g. "BC Whitewater".
  final String? source;

  bool get isEmpty =>
      low == null && medium == null && high == null && max == null;

  /// Reads `flowRanges` as stored on a run or in the bundled table.
  /// Null when it has no numbers.
  static FlowRanges? fromMap(Map<String, dynamic>? map, {String? source}) {
    if (map == null) return null;
    double? n(String key) {
      final v = map[key];
      return v is num && v.isFinite ? v.toDouble() : null;
    }

    String? s(String key) {
      final v = map[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final ranges = FlowRanges(
      unit: FlowUnit.parse(map['unit']),
      low: n('low'),
      medium: n('medium'),
      high: n('high'),
      max: n('max'),
      station: s('station'),
      gauge: s('gauge'),
      note: s('note'),
      source: s('source') ?? source,
    );
    return ranges.isEmpty ? null : ranges;
  }

  /// The older min / optimal / max fields, in discharge.
  static FlowRanges? fromLegacy(RiverRun run) {
    final ranges = FlowRanges(
      low: run.minRecommendedFlow,
      medium: run.optimalFlowMin,
      high: run.optimalFlowMax,
      max: run.maxRecommendedFlow,
    );
    return ranges.isEmpty ? null : ranges;
  }

  /// Whether these numbers are read on [run]'s own linked gauge, so the
  /// app can compare them with its readings. Otherwise they're shown as a
  /// reference only.
  bool readOnGaugeOf(RiverRun run) {
    if (gauge != null) return false;
    final linked = run.stationId;
    if (linked == null || linked.isEmpty) return false;
    if (station == null) return true;
    return GaugeRepository.docIdFor(station!) ==
        GaugeRepository.docIdFor(linked);
  }

  /// "25", "2.1", "1,300".
  static String number(double v) {
    if (v == v.roundToDouble()) {
      final s = v.round().toString();
      if (s.length <= 3) return s;
      final b = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
        b.write(s[i]);
      }
      return b.toString();
    }
    return v < 10
        ? '${double.parse(v.toStringAsFixed(2))}'
        : v.toStringAsFixed(1);
  }

  /// "Low 25 · Medium 50 · High 100 m³/s".
  String get summary {
    final parts = [
      if (low != null) 'Low ${number(low!)}',
      if (medium != null) 'Medium ${number(medium!)}',
      if (high != null) 'High ${number(high!)}',
      if (max != null) 'Max ${number(max!)}',
    ];
    return '${parts.join(' · ')} ${unit.symbol}';
  }
}

final _cache = Expando<_Cached>();

class _Cached {
  const _Cached(this.ranges);
  final FlowRanges? ranges;
}

extension RiverRunFlowRanges on RiverRun {
  /// What this run's gauge number is in: knots at a tidal spot, else
  /// discharge. (Runs judged on the stick still record discharge.)
  FlowUnit get readingUnit =>
      FlowUnit.parse(flowUnit) == FlowUnit.knots ||
          ranges?.unit == FlowUnit.knots
      ? FlowUnit.knots
      : FlowUnit.cms;

  /// This run's low / medium / high flows, from the backend: the run's
  /// `flowRanges` map, else its older min / optimal fields. Null when it
  /// has neither. (Firestore keeps its own offline copy.)
  FlowRanges? get ranges {
    final hit = _cache[this];
    if (hit != null) return hit.ranges;
    final found = FlowRanges.fromMap(flowRanges) ?? FlowRanges.fromLegacy(this);
    _cache[this] = _Cached(found);
    return found;
  }
}
