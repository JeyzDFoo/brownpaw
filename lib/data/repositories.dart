import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'flow_alerts_repository.dart';
import 'gauge_repository.dart';
import 'push_service.dart';
import 'river_runs_repository.dart';

/// The Firestore instance the repositories use. Override in tests.
final firestoreInstanceProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final riverRunsRepositoryProvider = Provider<RiverRunsRepository>(
  (ref) => RiverRunsRepository(ref.watch(firestoreInstanceProvider)),
);

final gaugeRepositoryProvider = Provider<GaugeRepository>(
  (ref) => GaugeRepository(ref.watch(firestoreInstanceProvider)),
);

final flowAlertsRepositoryProvider = Provider<FlowAlertsRepository>(
  (ref) => FlowAlertsRepository(ref.watch(firestoreInstanceProvider)),
);

final pushServiceProvider = Provider<PushService>(
  (ref) => PushService(ref.watch(firestoreInstanceProvider)),
);
