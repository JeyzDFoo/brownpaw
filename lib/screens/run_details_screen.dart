import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/gauge_repository.dart';
import '../domain/flow_alert.dart';
import '../domain/flow_ranges.dart';
import '../domain/flow_status.dart';
import '../domain/gauges.dart';
import '../domain/run_guide.dart';
import '../domain/run_suggestion.dart' show distanceKm;
import '../models/descent.dart';
import '../models/realtime_flow.dart';
import '../models/river_run.dart';
import '../providers/descents_provider.dart';
import '../providers/gauges_provider.dart';
import '../providers/realtime_flow_provider.dart';
import '../providers/river_runs_provider.dart';
import '../router.dart';
import '../widgets/alert_bell.dart';
import '../widgets/favourite_star.dart';
import '../widgets/flow_sparkline.dart';
import '../widgets/flow_range_scale.dart';
import '../widgets/flow_status_chip.dart';
import '../widgets/map_tiles.dart';
import '../widgets/quick_log_sheet.dart';
import 'gauges_screen.dart' show TrendIcon;
import '../theme/app_theme.dart';
import '../widgets/pebble.dart';

/// A run's guide page: how it's running now, getting there, what to watch
/// for, and what it's like. Content comes from the BC Whitewater guide.
class RunDetailsScreen extends ConsumerWidget {
  const RunDetailsScreen({super.key, required this.runId});
  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final runAsync = ref.watch(riverRunProvider(runId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          FavouriteStar(runIds: [runId], what: 'run'),
          const SizedBox(width: 4),
        ],
      ),
      body: runAsync.when(
        loading: () => const LoadingPebbles(count: 3, height: 140),
        error: (e, _) => const Center(child: Text("Couldn't load this run")),
        data: (run) => run == null
            ? const Center(child: Text('Run not found'))
            : RunGuide(run: run),
      ),
    );
  }
}

/// The body of a run page, separate from the loading so it can be tested
/// with a run in hand.
class RunGuide extends ConsumerWidget {
  const RunGuide({super.key, required this.run});
  final RiverRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sections = guideSections(run.fullText);
    final length = sections['length of run'] ?? run.length;
    final shuttle =
        sections['length of shuttle'] ??
        sections['length of shuttle (one way)'] ??
        run.shuttle;
    final grade = run.difficultyText;

    final hazards = <String>[
      if (_has(run.scouting)) run.scouting!,
      if (_has(run.hazards)) run.hazards!,
      if (_has(sections['special considerations']))
        sections['special considerations']!,
    ];
    final about = <(String?, String)>[
      if (_has(run.description)) (null, run.description!),
      if (_has(sections['description'])) (null, sections['description']!),
      if (_has(sections['character'])) ('Character', sections['character']!),
      if (_has(sections['scenery'])) ('Scenery', sections['scenery']!),
    ];
    final logistics = <(String, String)>[
      if (_has(run.season)) ('When to go', run.season!),
      if (_has(sections['gauge and levels']))
        ('Levels', sections['gauge and levels']!),
      if (_has(shuttle)) ('Shuttle', shuttle!),
      if (_has(sections['directions']))
        ('Getting there', sections['directions']!),
      if (_has(run.access)) ('Access', run.access!),
      if (_has(run.permits)) ('Permits', run.permits!),
      if (_has(sections['camping and food']))
        ('Camping and food', sections['camping and food']!),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        if (run.river.isNotEmpty && run.river != run.name)
          Text(
            run.river,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        Text(
          runLabel(run),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (grade.isNotEmpty)
              _Fact(
                Icons.terrain_outlined,
                grade.startsWith('Class') ? grade : 'Class $grade',
              ),
            if (_has(run.estimatedTime))
              _Fact(Icons.schedule, run.estimatedTime!),
            if (_has(length)) _Fact(Icons.straighten, length!),
          ],
        ),
        const SizedBox(height: 18),
        _Conditions(run: run),
        const SizedBox(height: 12),
        _Actions(run: run),
        if (_point(run.putInCoordinates) != null ||
            _point(run.takeOutCoordinates) != null) ...[
          const SizedBox(height: 24),
          const _Heading('Put-in and take-out'),
          const SizedBox(height: 10),
          _AccessMap(run: run),
          const SizedBox(height: 10),
          _AccessPoint(
            label: 'Put-in',
            color: _putInColor,
            point: _point(run.putInCoordinates),
            description: run.putIn,
          ),
          const SizedBox(height: 10),
          _AccessPoint(
            label: 'Take-out',
            color: _takeOutColor,
            point: _point(run.takeOutCoordinates),
            description: run.takeOut,
          ),
        ],
        if (hazards.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _Heading('Hazards and scouting'),
          const SizedBox(height: 10),
          _Hazards(items: hazards),
        ],
        if (about.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _Heading('The run'),
          const SizedBox(height: 10),
          for (final (title, body) in about) ...[
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            _ExpandableText(body),
            const SizedBox(height: 12),
          ],
        ],
        if (logistics.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _Heading('Logistics'),
          const SizedBox(height: 10),
          for (final (title, body) in logistics) ...[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            _ExpandableText(body, lines: 4),
            const SizedBox(height: 12),
          ],
        ],
        if (run.images?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          const _Heading('Photos'),
          const SizedBox(height: 10),
          _Photos(images: run.images!),
        ],
        const SizedBox(height: 24),
        _YourDescents(run: run),
        if (_has(run.sourceUrl) || run.source != null) ...[
          const SizedBox(height: 24),
          _Source(run: run),
        ],
      ],
    );
  }
}

const _putInColor = Color(0xFF2E7D32);
const _takeOutColor = Color(0xFFC62828);

bool _has(String? s) => s != null && s.trim().isNotEmpty;

LatLng? _point(Map<String, double>? c) {
  final lat = c?['latitude'], lng = c?['longitude'];
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}

Future<void> _open(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => SectionLabel(text);
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Flow now, its status for this run, and the gauge it's read from.
class _Conditions extends ConsumerWidget {
  const _Conditions({required this.run});
  final RiverRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final station = run.stationId;
    final card = BoxDecoration(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: Pebble.a,
    );

    final ranges = run.ranges;
    final comparable = ranges != null && ranges.readOnGaugeOf(run);

    if (station == null || station.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No online gauge is linked to this run.', style: muted),
            if (ranges != null) ...[
              const SizedBox(height: 14),
              FlowRangeScale(ranges: ranges, referenceOnly: true),
            ],
          ],
        ),
      );
    }

    final gaugeId = GaugeRepository.docIdFor(station);
    final gauge = ref.watch(gaugeProvider(gaugeId)).valueOrNull;
    final current = ref.watch(realtimeFlowStreamProvider(station));
    final all = current.valueOrNull?.readings ?? const <FlowReading>[];
    // Runs read on the stick (the Cheakamus, the Chilliwack) lead with
    // the level in metres; the rest with m³/s.
    var unit = comparable ? ranges.unit : FlowUnit.cms;
    if (unit == FlowUnit.metres && readingsIn(all, unit).isEmpty) {
      unit = FlowUnit.cms;
    }
    final readings = readingsIn(all, unit);
    final value = readings.isEmpty ? null : valueIn(readings.last, unit);
    final latest = all.isEmpty ? null : all.last;
    final trend = trendOf(dischargeReadings(all));
    final status = run.flowStatus(latest?.discharge, level: latest?.level);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: Pebble.a),
      child: InkWell(
        borderRadius: Pebble.a,
        onTap: () => context.push(AppRoutes.gauge(gaugeId)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NOW', style: muted),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              value == null
                                  ? '–'
                                  : value.toStringAsFixed(
                                      unit == FlowUnit.metres ? 2 : 1,
                                    ),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              unit.symbol,
                              style: theme.textTheme.titleSmall,
                            ),
                            if (trend != null) ...[
                              const SizedBox(width: 6),
                              TrendIcon(trend, size: 18),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  FlowSparkline(
                    points: hourlyWindow(readings, 7, unit: unit),
                    width: 88,
                    height: 40,
                  ),
                ],
              ),
              if (status != FlowStatus.unknown) ...[
                const SizedBox(height: 8),
                FlowStatusChip(status: status),
              ],
              const SizedBox(height: 14),
              if (ranges != null)
                FlowRangeScale(
                  ranges: ranges,
                  status: status,
                  referenceOnly: !comparable,
                )
              else
                Text('No flow guide for this run yet.', style: muted),
              const Divider(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.water_drop_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      gauge?.title ?? 'Gauge $station',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    readings.isEmpty ? '' : updatedAgo(readings.last.timestamp),
                    style:
                        readings.isNotEmpty && isStale(readings.last.timestamp)
                        ? muted?.copyWith(color: Riverstone.of(context).low)
                        : muted,
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.run});
  final RiverRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final putIn = _point(run.putInCoordinates);
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => showQuickLog(context, run: run),
            icon: const Icon(Icons.add),
            label: const Text('Log this run'),
          ),
        ),
        if (putIn != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              // The app theme's outlined button is a heavy black box;
              // here it sits beside a pill, so it matches that shape.
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: const StadiumBorder(),
                foregroundColor: theme.colorScheme.primary,
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () =>
                  _open(directionsUri(putIn.latitude, putIn.longitude)),
              icon: const Icon(Icons.directions_car_outlined),
              label: const Text('Directions'),
            ),
          ),
        ],
        if (alertRangeFor(run) != null && run.stationId != null)
          AlertBell(run: run),
      ],
    );
  }
}

/// A small, still map of the put-in and take-out. Scrolling the page
/// never gets caught by the map.
class _AccessMap extends StatelessWidget {
  const _AccessMap({required this.run});
  final RiverRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = [
      ?_point(run.putInCoordinates),
      ?_point(run.takeOutCoordinates),
    ];
    final camera = points.length == 1
        ? CameraFit.coordinates(
            coordinates: points,
            maxZoom: 13,
            padding: const EdgeInsets.all(40),
          )
        : CameraFit.coordinates(
            coordinates: points,
            maxZoom: 14,
            padding: const EdgeInsets.all(36),
          );

    return ClipRRect(
      borderRadius: Pebble.a,
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                backgroundColor: Riverstone.of(context).map,
                initialCameraFit: camera,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                MapTiles.layer(),
                MapTiles.credit(),
                MarkerLayer(
                  markers: [
                    if (_point(run.putInCoordinates) case final p?)
                      _pin(p, _putInColor, 'Put-in'),
                    if (_point(run.takeOutCoordinates) case final p?)
                      _pin(p, _takeOutColor, 'Take-out'),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 6,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                color: theme.colorScheme.surface.withValues(alpha: 0.8),
                child: Text(
                  '© OpenStreetMap',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _pin(LatLng p, Color color, String label) => Marker(
    point: p,
    width: 28,
    height: 28,
    child: Semantics(
      label: label,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
        ),
      ),
    ),
  );
}

class _AccessPoint extends StatelessWidget {
  const _AccessPoint({
    required this.label,
    required this.color,
    required this.point,
    required this.description,
  });

  final String label;
  final Color color;
  final LatLng? point;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: Pebble.small,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_has(description))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          if (point != null)
            IconButton(
              tooltip: 'Directions to the $label',
              icon: const Icon(Icons.directions_outlined),
              onPressed: () =>
                  _open(directionsUri(point!.latitude, point!.longitude)),
            ),
        ],
      ),
    );
  }
}

class _Hazards extends StatelessWidget {
  const _Hazards({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warn = theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn.withValues(alpha: 0.06),
        borderRadius: Pebble.small,
        border: Border.all(color: warn.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: warn),
                const SizedBox(width: 8),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Conditions change. Scout anything you can’t see the bottom of.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Long text that starts folded, with a "Read more" toggle.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text, {this.lines = 6});
  final String text;
  final int lines;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(height: 1.45);
    return LayoutBuilder(
      builder: (context, c) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.lines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: c.maxWidth);
        final long = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _open || !long ? null : widget.lines,
              overflow: _open || !long ? null : TextOverflow.fade,
            ),
            if (long)
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () => setState(() => _open = !_open),
                child: Text(_open ? 'Show less' : 'Read more'),
              ),
          ],
        );
      },
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.images});
  final List<Map<String, String>> images;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final url = images[i]['url'];
          final caption = images[i]['caption'];
          if (url == null) return const SizedBox.shrink();
          return ClipRRect(
            borderRadius: Pebble.small,
            child: Image.network(
              url,
              width: 210,
              height: 150,
              fit: BoxFit.cover,
              semanticLabel: caption,
              errorBuilder: (_, _, _) => Container(
                width: 210,
                color: theme.colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _YourDescents extends ConsumerWidget {
  const _YourDescents({required this.run});
  final RiverRun run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final descents =
        ref.watch(runDescentsProvider(run.riverId)).valueOrNull ??
        const <Descent>[];
    final text = descents.isEmpty
        ? "You haven't logged this run yet."
        : () {
            final last = descents.reduce(
              (a, b) => a.date.isAfter(b.date) ? a : b,
            );
            final times = descents.length == 1
                ? 'once'
                : '${descents.length} times';
            return 'You’ve run this $times. Last on '
                '${DateFormat.yMMMd().format(last.date)}.';
          }();
    return Row(
      children: [
        Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _Source extends StatelessWidget {
  const _Source({required this.run});
  final RiverRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = run.sourceUrl;
    final name = (run.source ?? '').toLowerCase().contains('bc')
        ? 'BC Whitewater'
        : (url != null && url.contains('bcwhitewater'))
        ? 'BC Whitewater'
        : (run.source ?? 'the original guide');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Guide information from $name, with thanks.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_has(url))
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _open(Uri.parse(url!)),
            child: Text('View on $name'),
          ),
      ],
    );
  }
}

/// Distance between put-in and take-out, as the crow flies, in km.
double? accessDistanceKm(RiverRun run) {
  final a = _point(run.putInCoordinates), b = _point(run.takeOutCoordinates);
  if (a == null || b == null) return null;
  return distanceKm(a.latitude, a.longitude, b.latitude, b.longitude);
}
