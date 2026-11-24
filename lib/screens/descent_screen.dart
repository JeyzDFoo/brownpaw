import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/flow_status.dart';
import '../models/descent.dart';
import '../models/river_run.dart';
import '../providers/descents_provider.dart';
import '../providers/river_runs_provider.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import '../widgets/flow_status_chip.dart';
import '../widgets/pebble.dart';

/// Difficulty grades a paddler can record for their own run.
const difficultyGrades = [
  'I',
  'II',
  'II+',
  'III-',
  'III',
  'III+',
  'IV-',
  'IV',
  'IV+',
  'V-',
  'V',
  'V+',
];

/// One logged run, at its own URL (see [AppRoutes.descent]) so the browser
/// back button and shared links work. Everything on it edits in place and
/// saves as you go.
class DescentScreen extends ConsumerWidget {
  const DescentScreen({super.key, required this.descentId});
  final String descentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final descents = ref.watch(allDescentsProvider);
    final runs = ref.watch(riverRunsStreamProvider).valueOrNull ?? const [];

    Widget message(String text) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(text)),
    );

    return descents.when(
      loading: () =>
          Scaffold(appBar: AppBar(), body: const LoadingPebbles(count: 4)),
      error: (_, _) => message("Couldn't load this run"),
      data: (all) {
        final descent = all.where((d) => d.id == descentId).firstOrNull;
        if (descent == null)
          return message('This run is no longer in your logbook');
        final run = runs.where((r) => r.riverId == descent.runId).firstOrNull;
        // Keyed so the editor keeps what you're typing while saves stream
        // back in.
        return _DescentEditor(
          key: ValueKey(descent.id),
          descent: descent,
          run: run,
        );
      },
    );
  }
}

class _DescentEditor extends ConsumerStatefulWidget {
  const _DescentEditor({super.key, required this.descent, this.run});
  final Descent descent;
  final RiverRun? run;

  @override
  ConsumerState<_DescentEditor> createState() => _DescentEditorState();
}

class _DescentEditorState extends ConsumerState<_DescentEditor> {
  late DateTime _date = widget.descent.date;
  late int? _rating = widget.descent.rating;
  late String? _difficulty = widget.descent.difficulty;
  late final _flow = TextEditingController(
    text: widget.descent.flow?.toStringAsFixed(1) ?? '',
  );
  late final _notes = TextEditingController(text: widget.descent.notes ?? '');
  late final DescentsNotifier _store = ref.read(descentsProvider.notifier);

  Timer? _debounce;
  bool _dirty = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _flow.addListener(_typed);
    _notes.addListener(_typed);
  }

  @override
  void dispose() {
    // Leaving mid-sentence still keeps what was typed.
    _debounce?.cancel();
    if (_dirty) _save();
    _flow.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _typed() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _saveAndShow);
  }

  void _changedNow() {
    _dirty = true;
    _debounce?.cancel();
    _saveAndShow();
  }

  void _saveAndShow() {
    _save();
    if (mounted) setState(() => _saved = true);
  }

  void _save() {
    _dirty = false;
    final flow = double.tryParse(_flow.text.trim());
    _store.updateDescent(
      descentId: widget.descent.id,
      date: _date,
      flow: flow,
      flowUnit: flow == null ? null : (widget.descent.flowUnit ?? 'cms'),
      notes: _notes.text.trim(),
      rating: _rating,
      difficulty: _difficulty,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || picked == _date) return;
    setState(() => _date = picked);
    _changedNow();
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this run?'),
        content: const Text(
          'It comes out of your logbook and your season stats. '
          "This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    _debounce?.cancel();
    _dirty = false;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _store.deleteDescent(widget.descent.id);
    if (!mounted) return;
    context.go(AppRoutes.home);
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? 'Run deleted' : "Couldn't delete that run")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final d = widget.descent;
    final run = widget.run;
    final crew = d.crew ?? const <String>[];
    final flow = double.tryParse(_flow.text.trim());
    final unit = switch (d.flowUnit) {
      null || 'cms' || 'm3/s' => 'm³/s',
      final u => u,
    };

    return Scaffold(
      appBar: AppBar(
        actions: [
          AnimatedOpacity(
            opacity: _saved ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Text('Saved', style: theme.textTheme.bodySmall),
          ),
          IconButton(
            tooltip: 'Delete this run',
            icon: const Icon(Icons.delete_outline_rounded),
            color: p.muted,
            onPressed: _delete,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(d.displayName, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionChip(
                avatar: Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: p.accent,
                ),
                label: Text(DateFormat('EEE, MMM d, y').format(_date)),
                tooltip: 'Change the date',
                onPressed: _pickDate,
              ),
              if (run != null)
                ActionChip(
                  avatar: Icon(
                    Icons.menu_book_rounded,
                    size: 16,
                    color: p.glacier,
                  ),
                  label: Text(
                    run.difficultyClass.isEmpty
                        ? 'Run guide'
                        : 'Class ${run.difficultyClass} · guide',
                  ),
                  onPressed: () => context.push(AppRoutes.run(run.riverId)),
                ),
            ],
          ),
          if (crew.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'with ${crew.join(', ')}',
              style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
            ),
          ],
          const SizedBox(height: 22),

          // Flow: the number that matters most, edited in place.
          PebbleCard(
            seed: 0,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Flow'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _flow,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          hintText: '–',
                          suffixText: unit,
                          suffixStyle: theme.textTheme.titleMedium?.copyWith(
                            color: p.muted,
                          ),
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (flow != null && (run?.hasFlowRanges ?? false))
                      FlowStatusChip(status: run!.flowStatus(flow)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // How it went.
          PebbleCard(
            seed: 1,
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
            child: Row(
              children: [
                const Expanded(child: SectionLabel('How was it?')),
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i out of 5',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      (_rating ?? 0) >= i
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 30,
                      color: (_rating ?? 0) >= i ? p.accent : p.muted,
                    ),
                    onPressed: () {
                      setState(() => _rating = i);
                      _changedNow();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // The grade it felt like on the day.
          PebbleCard(
            seed: 0,
            padding: const EdgeInsets.fromLTRB(18, 12, 0, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Felt like'),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 18),
                  child: Row(
                    children: [
                      for (final g in difficultyGrades)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(g),
                            selected: _difficulty == g,
                            showCheckmark: false,
                            backgroundColor: p.paper,
                            selectedColor: p.accentSoft,
                            onSelected: (on) {
                              setState(() => _difficulty = on ? g : null);
                              if (on) _changedNow();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          PebbleCard(
            seed: 1,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Notes'),
                TextField(
                  controller: _notes,
                  minLines: 3,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Lines, levels, wood, who swam…',
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
