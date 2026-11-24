// Sample Lower Mainland data for the App Store screenshots.
//
// Run names, classes and put-ins follow the BC Whitewater guide; gauge
// codes and names are real Water Survey of Canada stations. Flows and the
// logbook are made up but plausible for a wet late-November week.

import 'dart:math' as math;

import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/domain/gauges.dart';
import 'package:brownpaw/models/descent.dart';
import 'package:brownpaw/models/realtime_flow.dart';
import 'package:brownpaw/models/river_run.dart';

Map<String, double> _ll(double lat, double lng) => {
  'latitude': lat,
  'longitude': lng,
};

RiverRun _run({
  required String id,
  required String river,
  required String name,
  required String cls,
  String? station,
  String? stationName,
  (double, double)? good,
  (double, double)? range,
  Map<String, double>? putIn,
  Map<String, double>? takeOut,
  String? time,
  String? putInText,
  String? takeOutText,
  String? hazards,
  String? description,
  String? fullText,
}) => RiverRun(
  riverId: id,
  name: name,
  river: river,
  province: 'BC',
  region: 'South Coast',
  difficultyClass: cls,
  description: description,
  stationId: station,
  verified: true,
  optimalFlowMin: good?.$1,
  optimalFlowMax: good?.$2,
  minRecommendedFlow: range?.$1,
  maxRecommendedFlow: range?.$2,
  gaugeStation: stationName == null ? null : {'name': stationName},
  putInCoordinates: putIn,
  takeOutCoordinates: takeOut,
  estimatedTime: time,
  putIn: putInText,
  takeOut: takeOutText,
  hazards: hazards,
  source: 'BC Whitewater',
  sourceUrl: 'https://www.bcwhitewater.org/reaches/$id',
  fullText: fullText,
);

const chilliwackSlesse = '08MH103';
const cheakamusMillar = '08GA072';
const cheakamusBrackendale = '08GA043';
const mamquam = '08GA075';
const seymourStation = '08GA030';
const elaho = '08GA071';
const coquitlamStation = '08MH002';

final tamihi = _run(
  id: 'chilliwack-river-tamihi-to-pointa-vista',
  river: 'Chilliwack',
  name: 'Tamihi to Pointa Vista',
  cls: 'III, one IV-',
  station: chilliwackSlesse,
  stationName: 'CHILLIWACK RIVER ABOVE SLESSE CREEK',
  good: (25, 60),
  range: (15, 90),
  putIn: _ll(49.0717, -121.8370),
  takeOut: _ll(49.0785, -121.8748),
  time: '2 hours',
  putInText:
      'Tamihi bridge on Chilliwack Lake Road. Put in river left, above the '
      'Tamihi rapid if you want to run it.',
  takeOutText: 'Pointa Vista day-use area, river right.',
  hazards:
      'Tamihi rapid (IV-) is right below the bridge: scout from the road. '
      'Wood moves every winter, so look before committing to blind '
      'channels.',
  description:
      'Continuous boulder gardens, especially at higher levels, and the '
      "Fraser Valley's most popular after-work run.",
  fullText:
      'Tamihi to Pointa Vista\n'
      'Length of Run\n: 7 km\n'
      'Special Considerations\n: Busy with rafts in summer.\n'
      'Scenery\n: Second-growth forest and gravel bars.\n',
);

final canyon = _run(
  id: 'chilliwack-canyon-camp-foley-to-slesse',
  river: 'Chilliwack',
  name: 'Camp Foley to Slesse',
  cls: 'IV-',
  station: chilliwackSlesse,
  good: (30, 70),
  range: (20, 100),
  putIn: _ll(49.0999, -121.6285),
);

final slesseTamihi = _run(
  id: 'chilliwack-river-slesse-to-tamihi',
  river: 'Chilliwack',
  name: 'Slesse to Tamihi',
  cls: 'III',
  station: chilliwackSlesse,
  good: (25, 65),
  range: (15, 90),
  putIn: _ll(49.0769, -121.7136),
);

final upperCheak = _run(
  id: 'cheakamus-river-upper',
  river: 'Cheakamus',
  name: 'Upper',
  cls: 'IV',
  station: cheakamusMillar,
  stationName: 'CHEAKAMUS RIVER ABOVE MILLAR CREEK',
  good: (15, 35),
  range: (10, 50),
  putIn: _ll(50.0716, -123.0370),
);

final calCheak = _run(
  id: 'cheakamus-river-cal-cheak',
  river: 'Cheakamus',
  name: 'Cal-Cheak',
  cls: 'III',
  station: cheakamusMillar,
  good: (15, 40),
  range: (10, 55),
  putIn: _ll(50.0654, -123.1040),
);

final paradiseValley = _run(
  id: 'cheakamus-paradise-valley',
  river: 'Cheakamus',
  name: 'Paradise Valley',
  cls: 'II (III)',
  station: cheakamusBrackendale,
  stationName: 'CHEAKAMUS RIVER NEAR BRACKENDALE',
  good: (30, 80),
  range: (20, 120),
  putIn: _ll(49.8900, -123.1811),
);

final upperMamquam = _run(
  id: 'mamquam-river-upper',
  river: 'Mamquam',
  name: 'Upper',
  cls: 'III-IV',
  station: mamquam,
  stationName: 'MAMQUAM RIVER ABOVE RING CREEK',
  good: (15, 35),
  range: (10, 45),
  putIn: _ll(49.7174, -122.9951),
);

final seymourLower = _run(
  id: 'seymour-river-lower-run',
  river: 'Seymour',
  name: 'Lower',
  cls: 'II (III-)',
  station: seymourStation,
  stationName: 'SEYMOUR RIVER NEAR NORTH VANCOUVER',
  good: (15, 45),
  range: (8, 70),
  putIn: _ll(49.3218, -123.0139),
);

final elahoSquamish = _run(
  id: 'elaho-squamish',
  river: 'Elaho',
  name: 'Elaho-Squamish',
  cls: 'III (IV-)',
  station: elaho,
  stationName: 'ELAHO RIVER NEAR THE MOUTH',
  good: (100, 250),
  range: (60, 400),
  putIn: _ll(50.1145, -123.4291),
);

final coquitlam = _run(
  id: 'coquitlam',
  river: 'Coquitlam',
  name: 'Coquitlam',
  cls: 'III (IV-)',
  station: coquitlamStation,
  stationName: 'COQUITLAM RIVER AT PORT COQUITLAM',
  good: (20, 60),
  range: (12, 90),
  putIn: _ll(49.3379, -122.7715),
);

final chehalis = _run(
  id: 'chehalis-river-lower-aka-statlu-chehalis',
  river: 'Chehalis',
  name: 'Lower',
  cls: 'III-IV-',
  putIn: _ll(49.3491, -121.9977),
);

final lynn = _run(
  id: 'lynn-creek',
  river: 'Lynn Creek',
  name: 'Lynn Creek',
  cls: 'III-IV',
  putIn: _ll(49.3429, -123.0179),
);

final runs = [
  tamihi,
  canyon,
  slesseTamihi,
  upperCheak,
  calCheak,
  paradiseValley,
  upperMamquam,
  seymourLower,
  elahoSquamish,
  coquitlam,
  chehalis,
  lynn,
];

/// Two weeks of hourly flows per station: the shape of the hydrograph and
/// where it ends now.
const _flows = {
  chilliwackSlesse: (start: 22.0, end: 30.0, storm: 0.55),
  cheakamusMillar: (start: 21.0, end: 27.2, storm: 0.35),
  cheakamusBrackendale: (start: 48.0, end: 64.0, storm: 0.4),
  mamquam: (start: 26.0, end: 34.0, storm: 0.7),
  seymourStation: (start: 14.0, end: 22.6, storm: 0.5),
  elaho: (start: 95.0, end: 70.0, storm: 0.0),
  coquitlamStation: (start: 18.0, end: 31.5, storm: 0.6),
};

List<FlowReading> hourly(String station, DateTime now, {int days = 14}) {
  final f = _flows[station]!;
  final hours = days * 24;
  return [
    for (var h = hours; h >= 0; h--)
      FlowReading(
        timestamp: now.subtract(Duration(hours: h, minutes: 12)),
        discharge: _shape(f, 1 - h / hours),
      ),
  ];
}

/// A wet fortnight: two storm pulses then a rise into today.
double _shape(({double start, double end, double storm}) f, double t) {
  double pulse(double at, double width, double height) =>
      height * math.exp(-math.pow((t - at) / width, 2));
  final base = f.start + (f.end - f.start) * math.pow(t, 2.2);
  final storms =
      pulse(0.22, 0.07, f.start * f.storm) +
      pulse(0.55, 0.09, f.start * f.storm * 0.8) +
      // Today's rain: still coming up.
      pulse(1.04, 0.06, f.start * f.storm * 0.9);
  final wiggle = 0.3 * math.sin(t * 60) * f.start / 40;
  return double.parse((base + storms + wiggle).toStringAsFixed(2));
}

double currentFlow(String station) {
  final f = _flows[station]!;
  return double.parse(_shape(f, 1).toStringAsFixed(1));
}

class SampleGauges implements GaugeRepository {
  SampleGauges(this.now);
  final DateTime now;

  String _code(String stationId) => stationId.split('_').last.toUpperCase();

  @override
  Future<double?> flowOn(
    String stationId,
    DateTime day, {
    DateTime? now,
  }) async => _flows.containsKey(_code(stationId))
      ? currentFlow(_code(stationId))
      : null;

  @override
  Future<StationRealtimeFlow?> getCurrent(String stationId) async =>
      _current(stationId);

  StationRealtimeFlow? _current(String stationId) {
    final code = _code(stationId);
    if (!_flows.containsKey(code)) return null;
    return StationRealtimeFlow(
      stationId: stationId,
      flow: RealtimeFlow(readings: hourly(code, now)),
    );
  }

  @override
  Stream<StationRealtimeFlow?> watchCurrent(String stationId) =>
      Stream.value(_current(stationId));

  @override
  Stream<Map<String, StationSummary>> watchStations() => Stream.value({
    for (final run in runs)
      if (run.stationId case final id?)
        GaugeRepository.docIdFor(id): StationSummary(
          name: run.gaugeStation?['name'],
          flow: currentFlow(id),
          readingTime: now.subtract(const Duration(minutes: 12)),
        ),
  });

  @override
  Future<List<FlowPoint>> dailyFlows(
    String stationId,
    int days, {
    DateTime? now,
  }) async {
    final code = _code(stationId);
    if (!_flows.containsKey(code)) return const [];
    final today = this.now;
    final f = _flows[code]!;
    return [
      for (var d = days; d >= 1; d--)
        (
          time: today.subtract(Duration(days: d)),
          flow: f.start * (0.7 + 0.5 * math.sin(d / days * math.pi * 3).abs()),
        ),
    ];
  }
}

Descent _log(
  RiverRun run,
  DateTime date,
  double? flow,
  List<String> crew, {
  String? notes,
  int? rating,
}) => Descent(
  id: '${run.riverId}-${date.toIso8601String()}',
  runId: run.riverId,
  runName: '${run.river} - ${run.name}',
  userId: 'me',
  date: date,
  flow: flow,
  flowUnit: 'm³/s',
  crew: crew,
  notes: notes,
  rating: rating,
  createdAt: date,
);

List<Descent> logbook(DateTime now) {
  final y = now.year;
  return [
    _log(
      tamihi,
      DateTime(y, 11, 22),
      36.1,
      ['Sam', 'Priya'],
      notes: 'Juicy level. Clean line right of the Tamihi hole.',
      rating: 5,
    ),
    _log(upperCheak, DateTime(y, 11, 16), 24.8, ['Alex']),
    _log(seymourLower, DateTime(y, 11, 11), 19.4, ['Priya', 'Jordan']),
    _log(upperMamquam, DateTime(y, 11, 2), 28.3, ['Sam']),
    _log(coquitlam, DateTime(y, 10, 26), 27.0, ['Alex', 'Sam']),
    _log(tamihi, DateTime(y, 10, 19), 29.5, ['Jordan']),
    _log(calCheak, DateTime(y, 9, 28), 22.0, ['Priya']),
    _log(elahoSquamish, DateTime(y, 8, 17), 210, ['Sam', 'Alex', 'Priya']),
    _log(elahoSquamish, DateTime(y, 8, 3), 236, ['Sam']),
    _log(calCheak, DateTime(y, 7, 20), 31.0, ['Jordan']),
    _log(upperCheak, DateTime(y, 7, 6), 29.0, ['Alex']),
    _log(upperCheak, DateTime(y, 6, 21), 33.0, ['Alex', 'Sam']),
    _log(canyon, DateTime(y, 6, 7), 58.0, ['Sam']),
    _log(tamihi, DateTime(y, 5, 24), 52.0, ['Priya']),
    _log(slesseTamihi, DateTime(y, 5, 10), 48.0, ['Priya', 'Jordan']),
    _log(upperMamquam, DateTime(y, 5, 3), 30.0, ['Sam']),
    _log(tamihi, DateTime(y, 4, 19), 33.0, ['Sam']),
    _log(chehalis, DateTime(y, 4, 5), null, ['Alex', 'Jordan']),
    _log(seymourLower, DateTime(y, 3, 15), 25.0, ['Priya']),
    _log(tamihi, DateTime(y, 2, 22), 26.0, ['Sam']),
    _log(coquitlam, DateTime(y, 1, 25), 34.0, ['Alex']),
    _log(tamihi, DateTime(y - 1, 12, 7), 41.0, ['Sam']),
    _log(lynn, DateTime(y - 1, 11, 23), null, ['Priya']),
  ];
}
