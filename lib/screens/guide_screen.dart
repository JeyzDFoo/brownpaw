import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../domain/flow_status.dart';
import '../domain/gauges.dart' show runLabel;
import '../domain/guide.dart';
import '../providers/gauges_provider.dart';
import '../providers/river_runs_provider.dart';
import '../router.dart';
import '../theme/flow_status_style.dart';
import '../widgets/flow_status_chip.dart';
import '../widgets/map_tiles.dart';

/// Every run in the guide, with how it's running now.
final guideEntriesProvider = Provider<AsyncValue<List<GuideEntry>>>((ref) {
  final stations = ref.watch(stationsProvider).value ?? const {};
  return ref
      .watch(riverRunsStreamProvider)
      .whenData((runs) => guideEntries(runs, stations));
});

enum GuideView { map, list }

/// The Guide tab: a map of runs coloured by how they're running now, and
/// a searchable list. Each opens the run's guide page.
class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  final _search = TextEditingController();
  final _map = MapController();
  String _query = '';
  bool _runningOnly = false;
  GuideView _view = GuideView.map;
  GuideEntry? _selected;

  /// The map's view, kept when switching to the list and back.
  LatLng _center = LatLng(
    lowerMainlandCentre.latitude,
    lowerMainlandCentre.longitude,
  );
  double _zoom = lowerMainlandZoom;
  LatLngBounds? _bounds;

  /// Whether the list shows only the runs in the map's view.
  bool _inMapArea = true;

  @override
  void dispose() {
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onCamera(MapCamera camera) {
    // Kept for the list and for returning to the map; no rebuild needed.
    _center = camera.center;
    _zoom = camera.zoom;
    _bounds = camera.visibleBounds;
  }

  void _zoomBy(double delta) {
    final camera = _map.camera;
    _map.move(
      camera.center,
      (camera.zoom + delta).clamp(_minZoom, _maxZoom).toDouble(),
    );
  }

  void _resetView() {
    _map.move(
      LatLng(lowerMainlandCentre.latitude, lowerMainlandCentre.longitude),
      lowerMainlandZoom,
    );
    setState(() => _selected = null);
  }

  bool _inView(GuideEntry e) {
    final b = _bounds;
    if (b == null) return true;
    return e.onMap && b.contains(LatLng(e.latitude!, e.longitude!));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(guideEntriesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load the guide"),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(riverRunsStreamProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (all) {
        final shown = all
            .where((e) => e.matches(_query))
            .where((e) => !_runningOnly || e.status.isRunnable)
            .toList();
        final running = all.where((e) => e.status.isRunnable).length;
        final inArea = shown.where(_inView).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _SearchField(
                controller: _search,
                onChanged: (v) => setState(() {
                  _query = v;
                  _selected = null;
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: FilterChip(
                        labelStyle: Theme.of(context).textTheme.labelLarge,
                        label: Text('Running now · $running'),
                        selected: _runningOnly,
                        onSelected: (v) => setState(() {
                          _runningOnly = v;
                          _selected = null;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SegmentedButton<GuideView>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      selectedBackgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.14),
                      selectedForegroundColor: Theme.of(
                        context,
                      ).colorScheme.primary,
                    ),
                    segments: const [
                      ButtonSegment(
                        value: GuideView.map,
                        icon: Icon(Icons.map_outlined),
                        tooltip: 'Map',
                      ),
                      ButtonSegment(
                        value: GuideView.list,
                        icon: Icon(Icons.view_list_outlined),
                        tooltip: 'List',
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (s) => setState(() {
                      _view = s.first;
                      _selected = null;
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_view) {
                GuideView.map => _buildMap(context, shown),
                GuideView.list => _GuideList(
                  entries: _inMapArea && _bounds != null ? inArea : shown,
                  areaNote: _bounds == null
                      ? null
                      : _inMapArea
                      ? _AreaNote(
                          text: inArea.length == 1
                              ? '1 run in the map area'
                              : '${inArea.length} runs in the map area',
                          action: 'Show all',
                          onTap: () => setState(() => _inMapArea = false),
                        )
                      : _AreaNote(
                          text: shown.length == 1
                              ? '1 run'
                              : '${shown.length} runs',
                          action: 'Only the map area',
                          onTap: () => setState(() => _inMapArea = true),
                        ),
                ),
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMap(BuildContext context, List<GuideEntry> entries) {
    final theme = Theme.of(context);
    final pins = entries.where((e) => e.onMap).toList();
    final byKey = {for (final e in pins) ValueKey(e.run.riverId): e};
    final selected = _selected;

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: _zoom,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () => _onCamera(_map.camera),
            onPositionChanged: (camera, _) => _onCamera(camera),
            onTap: (_, _) => setState(() => _selected = null),
          ),
          children: [
            MapTiles.layer(),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 56,
                disableClusteringAtZoom: clusterUntilZoom,
                size: const Size(40, 40),
                padding: const EdgeInsets.all(64),
                maxZoom: clusterUntilZoom + 1.0,
                showPolygon: false,
                // Each pin handles its own tap, to open its card.
                markerChildBehavior: true,
                markers: [
                  for (final e in pins)
                    Marker(
                      key: ValueKey(e.run.riverId),
                      point: LatLng(e.latitude!, e.longitude!),
                      width: 48,
                      height: 48,
                      child: _Pin(
                        entry: e,
                        selected: e.run.riverId == selected?.run.riverId,
                        onTap: () => setState(() => _selected = e),
                      ),
                    ),
                ],
                builder: (context, markers) => _ClusterPin(
                  entries: [for (final m in markers) ?byKey[m.key]],
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 6,
          top: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            child: Text('© OpenStreetMap', style: theme.textTheme.labelSmall),
          ),
        ),
        Positioned(
          right: 12,
          top: 32,
          child: _ZoomControls(
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
            onReset: _resetView,
          ),
        ),
        if (pins.isEmpty)
          Positioned(
            left: 20,
            right: 72,
            top: 16,
            child: Material(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'No runs to show here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: GuideRunCard(entry: selected, elevated: true),
          ),
      ],
    );
  }
}

const _minZoom = 5.0;
const _maxZoom = 17.0;

/// Zoom in, zoom out and back to the Lower Mainland, for the web and for
/// one-handed use where pinching is awkward.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget button(IconData icon, String tip, VoidCallback onTap) => IconButton(
      tooltip: tip,
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      color: theme.colorScheme.onSurface,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
    );
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.add, 'Zoom in', onZoomIn),
          Container(width: 28, height: 1, color: theme.dividerColor),
          button(Icons.remove, 'Zoom out', onZoomOut),
          Container(width: 28, height: 1, color: theme.dividerColor),
          button(
            Icons.my_location_outlined,
            'Back to the Lower Mainland',
            onReset,
          ),
        ],
      ),
    );
  }
}

/// Several runs close together: a count in the colour of the best status.
/// Tapping zooms in to split them (or fans them out where they share a
/// put-in).
class _ClusterPin extends StatelessWidget {
  const _ClusterPin({required this.entries});

  final List<GuideEntry> entries;

  @override
  Widget build(BuildContext context) {
    final color = bestStatus(entries).color(context);
    final n = entries.length;
    final running = entries.where((e) => e.status.isRunnable).length;
    return Semantics(
      button: true,
      label: '$n runs here${running > 0 ? ', $running running' : ''}',
      excludeSemantics: true,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
        ),
        child: Text(
          '$n',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

/// A run's map pin: a ring in its status colour, filled when selected.
class _Pin extends StatelessWidget {
  const _Pin({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final GuideEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = entry.status.color(context);
    final size = selected ? 26.0 : 20.0;
    return Semantics(
      button: true,
      label:
          '${entry.run.river}, ${runLabel(entry.run)}, '
          '${entry.status.label}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: selected ? 4 : 3),
              boxShadow: const [
                BoxShadow(blurRadius: 4, color: Colors.black38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AreaNote {
  const _AreaNote({
    required this.text,
    required this.action,
    required this.onTap,
  });
  final String text;
  final String action;
  final VoidCallback onTap;
}

class _GuideList extends StatelessWidget {
  const _GuideList({required this.entries, this.areaNote});
  final List<GuideEntry> entries;

  /// How the list relates to the map's view, with a switch.
  final _AreaNote? areaNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = areaNote;
    final header = note == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    note.text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(onPressed: note.onTap, child: Text(note.action)),
              ],
            ),
          );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        ?header,
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Center(
              child: Text('No runs match', style: theme.textTheme.bodyMedium),
            ),
          ),
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GuideRunCard(entry: e),
          ),
      ],
    );
  }
}

/// A run in the Guide: river, run, class and how it's running now.
/// Tapping it opens the run's guide page.
class GuideRunCard extends StatelessWidget {
  const GuideRunCard({super.key, required this.entry, this.elevated = false});

  final GuideEntry entry;

  /// Floating over the map, so it needs a shadow to separate it.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final run = entry.run;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final details = [
      if (run.difficultyClass.isNotEmpty && run.difficultyClass != 'Unknown')
        'Class ${run.difficultyClass}',
      if (entry.flow != null)
        '${entry.flow!.toStringAsFixed(1)} ${run.flowUnit}',
    ].join(' · ');

    return Material(
      color: theme.colorScheme.surface,
      elevation: elevated ? 3 : 0,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.run(run.riverId)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.river,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(runLabel(run), style: muted),
                    ),
                    if (details.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(details, style: muted),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (entry.status != FlowStatus.unknown)
                FlowStatusChip(status: entry.status),
              Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search rivers and runs',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        isDense: true,
        border: border(theme.colorScheme.outlineVariant),
        enabledBorder: border(theme.colorScheme.outlineVariant),
        focusedBorder: border(theme.colorScheme.primary),
      ),
    );
  }
}
