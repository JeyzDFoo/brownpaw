// Renders the real app screens used for the App Store screenshots.
//
// Skipped in normal test runs. To regenerate:
//   STORE_SHOTS=1 flutter test test/store_screenshots
// then run tool/store_assets/compose.py to frame them with captions.
// Raw screens land in build/store_screens/.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:brownpaw/data/location_service.dart';
import 'package:brownpaw/data/repositories.dart';
import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/data/push_service.dart';
import 'package:brownpaw/providers/descents_provider.dart';
import 'package:brownpaw/providers/flow_alerts_provider.dart';
import 'package:brownpaw/providers/favorites_provider.dart';
import 'package:brownpaw/providers/gauges_provider.dart';
import 'package:brownpaw/widgets/favourite_star.dart';
import 'package:brownpaw/providers/offline_cache_provider.dart';
import 'package:brownpaw/providers/river_runs_provider.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/screens/gauge_screen.dart';
import 'package:brownpaw/screens/home_screen.dart';
import 'package:brownpaw/screens/run_details_screen.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:brownpaw/widgets/map_tiles.dart';
import 'package:brownpaw/widgets/quick_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sample_data.dart';

final _enabled = Platform.environment.containsKey('STORE_SHOTS');

/// iPhone 6.9" (1320 x 2868) in points, with its safe areas.
const _size = Size(440, 956);
const _ratio = 3.0;
const _top = 62.0;
const _bottom = 34.0;

class _Location extends LocationService {
  @override
  Future<LocationAccess> access() async => LocationAccess.granted;
  @override
  Future<LocationAccess> ask() async => LocationAccess.granted;
  // A few metres from the Tamihi bridge put-in.
  @override
  Future<LatLng?> currentPosition() async =>
      (latitude: 49.0719, longitude: -121.8372);
}

class _Alerts implements FlowAlertsController {
  @override
  Future<PushResult> turnOn(RiverRun run) async => PushResult.enabled;
  @override
  Future<void> turnOff(RiverRun run) async {}
}

Future<void> _loadFonts() async {
  final nunito = FontLoader('Nunito');
  for (final w in [500, 600, 700, 800, 900]) {
    nunito.addFont(
      Future.value(
        ByteData.sublistView(File('fonts/Nunito-$w.ttf').readAsBytesSync()),
      ),
    );
  }
  await nunito.load();
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File(
            '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

final _boundary = GlobalKey();

Future<void> _pumpApp(
  WidgetTester tester,
  Widget home, {
  ThemeMode mode = ThemeMode.light,
  Set<String> favourites = const {},
  Set<String> alerted = const {},
}) async {
  SharedPreferences.setMockInitialValues({'location_prompt_dismissed': true});
  tester.view.physicalSize = _size * _ratio;
  tester.view.devicePixelRatio = _ratio;
  tester.view.padding = const FakeViewPadding(
    top: _top * _ratio,
    bottom: _bottom * _ratio,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _top * _ratio,
    bottom: _bottom * _ratio,
  );
  addTearDown(tester.view.reset);

  final now = DateTime.now();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allDescentsProvider.overrideWith((ref) => Stream.value(logbook(now))),
        riverRunsStreamProvider.overrideWith((ref) => Stream.value(runs)),
        riverRunProvider.overrideWith(
          (ref, id) =>
              Stream.value(runs.where((r) => r.riverId == id).firstOrNull),
        ),
        locationServiceProvider.overrideWithValue(_Location()),
        gaugeRepositoryProvider.overrideWithValue(SampleGauges(now)),
        favouriteRunIdsProvider.overrideWith((ref) => favourites),
        isFavoriteProvider.overrideWith((ref, id) => favourites.contains(id)),
        setFavouritesProvider.overrideWith((ref) => (ids, on) async {}),
        flowAlertsControllerProvider.overrideWithValue(_Alerts()),
        alertedRunIdsProvider.overrideWith((ref) => Stream.value(alerted)),
      ],
      child: RepaintBoundary(
        key: _boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _push(WidgetTester tester, Widget page) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.push(MaterialPageRoute<void>(builder: (_) => page));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester, String name) async {
  // Let asset images (the paw mark) decode before capturing.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: _ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/store_screens/$name.png')
      ..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);
  setUp(() {
    OfflineCache.enabled = false;
    MapTiles.enabled = false;
  });

  final favourites = {
    tamihi.riverId,
    upperCheak.riverId,
    seymourLower.riverId,
    upperMamquam.riverId,
  };

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final suffix = mode == ThemeMode.dark ? '_dark' : '';

    testWidgets('logbook$suffix', skip: !_enabled, (tester) async {
      await _pumpApp(tester, const MyHomePage(tabIndex: 0), mode: mode);
      await _save(tester, '1_logbook$suffix');
    });

    testWidgets('quick log$suffix', skip: !_enabled, (tester) async {
      await _pumpApp(tester, const MyHomePage(tabIndex: 0), mode: mode);
      final context = tester.element(find.byType(MyHomePage));
      showQuickLog(context, run: tamihi);
      await tester.pumpAndSettle();
      await _save(tester, '2_quick_log$suffix');
    });

    testWidgets('gauges$suffix', skip: !_enabled, (tester) async {
      await _pumpApp(
        tester,
        const MyHomePage(tabIndex: 1),
        mode: mode,
        favourites: favourites,
      );
      await _save(tester, '3_gauges$suffix');
    });

    testWidgets('gauge$suffix', skip: !_enabled, (tester) async {
      await _pumpApp(
        tester,
        const MyHomePage(tabIndex: 1),
        mode: mode,
        favourites: favourites,
        alerted: {tamihi.riverId},
      );
      await _push(
        tester,
        GaugeScreen(gaugeId: GaugeRepository.docIdFor(chilliwackSlesse)),
      );
      await _save(tester, '4_gauge$suffix');
    });

    testWidgets('guide$suffix', skip: !_enabled, (tester) async {
      await _pumpApp(
        tester,
        const MyHomePage(tabIndex: 2),
        mode: mode,
        favourites: favourites,
      );
      await tester.tap(find.byIcon(Icons.view_list_outlined).first);
      await tester.pumpAndSettle();
      await _save(tester, '5_guide$suffix');
    });

    testWidgets('run$suffix', skip: !_enabled, (tester) async {
      await _pumpApp(
        tester,
        const MyHomePage(tabIndex: 2),
        mode: mode,
        favourites: favourites,
      );
      await _push(tester, RunDetailsScreen(runId: tamihi.riverId));
      await _save(tester, '6_run$suffix');
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -700));
      await tester.pumpAndSettle();
      await _save(tester, '6_run_scrolled$suffix');
    });
  }
}
