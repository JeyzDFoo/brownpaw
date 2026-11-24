import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  String _query = '';
  bool _runningOnly = false;
  GuideView _view = GuideView.map;
  GuideEntry? _selected;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
                GuideView.map => _GuideMap(
                  entries: shown,
                  selected: _selected,
                  onSelect: (e) => setState(() => _selected = e),
                ),
                GuideView.list => _GuideList(entries: shown),
              },
            ),
          ],
        );
      },
    );
  }
}

class _GuideMap extends StatelessWidget {
  const _GuideMap({
    required this.entries,
    required this.selected,
    required this.onSelect,
  });

  final List<GuideEntry> entries;
  final GuideEntry? selected;
  final ValueChanged<GuideEntry?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pins = entries.where((e) => e.onMap).toList()
      // Running runs drawn last, so they sit on top where pins overlap.
      ..sort(
        (a, b) => (a.status.isRunnable ? 1 : 0).compareTo(
          b.status.isRunnable ? 1 : 0,
        ),
      );

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(
              lowerMainlandCentre.latitude,
              lowerMainlandCentre.longitude,
            ),
            initialZoom: lowerMainlandZoom,
            minZoom: 5,
            maxZoom: 17,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, _) => onSelect(null),
          ),
          children: [
            MapTiles.layer(),
            MarkerLayer(
              markers: [
                for (final e in pins)
                  Marker(
                    point: LatLng(e.latitude!, e.longitude!),
                    width: 44,
                    height: 44,
                    child: _Pin(
                      entry: e,
                      selected: e.run.riverId == selected?.run.riverId,
                      onTap: () => onSelect(e),
                    ),
                  ),
              ],
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
        if (pins.isEmpty)
          Positioned(
            left: 20,
            right: 20,
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
        if (selected case final e?)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: GuideRunCard(entry: e, elevated: true),
          ),
      ],
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

class _GuideList extends StatelessWidget {
  const _GuideList({required this.entries});
  final List<GuideEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No runs match',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => GuideRunCard(entry: entries[i]),
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
