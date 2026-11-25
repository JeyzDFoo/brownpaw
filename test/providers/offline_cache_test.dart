import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/data/repositories.dart';
import 'package:brownpaw/domain/flow_ranges.dart';
import 'package:brownpaw/domain/gauges.dart';
import 'package:brownpaw/providers/gauges_provider.dart';
import 'package:brownpaw/providers/offline_cache_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/quick_log_sheet_test.dart' show FakeGauges, tamihi;

class RecordingGauges extends FakeGauges {
  RecordingGauges() : super(null);
  final watched = <String>[];
  final history = <String>[];

  @override
  Stream<StationRealtimeFlow?> watchCurrent(String stationId) {
    watched.add(stationId);
    return Stream.value(null);
  }

  @override
  Future<List<FlowPoint>> dailyFlows(
    String stationId,
    int days, {
    DateTime? now,
    FlowUnit unit = FlowUnit.cms,
  }) async {
    history.add('$stationId:$days');
    return const [];
  }
}

void main() {
  test('keeps your gauges and a year of their history cached', () async {
    final gauges = RecordingGauges();
    final gauge = Gauge(
      id: 'environment_canada_08MH001',
      title: 'Chilliwack',
      place: 'Tamihi',
      runs: [tamihi],
    );
    final container = ProviderContainer(
      overrides: [
        gaugeRepositoryProvider.overrideWithValue(gauges),
        yourGaugesProvider.overrideWithValue(AsyncValue.data([gauge])),
      ],
    );
    addTearDown(container.dispose);

    container.read(offlineCacheProvider);
    await pumpEventQueue();

    expect(gauges.watched, ['environment_canada_08MH001']);
    expect(gauges.history, ['environment_canada_08MH001:365']);
  });
}
