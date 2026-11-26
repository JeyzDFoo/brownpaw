import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/repositories.dart';
import '../domain/flow_status.dart';
import '../domain/run_suggestion.dart';
import '../models/descent.dart';
import '../models/river_run.dart';
import '../providers/descents_provider.dart';
import '../providers/recent_runs_provider.dart';
import '../providers/river_runs_provider.dart';
import '../router.dart';
import '../screens/log_descent_screen.dart' show RiverRunSelector;
import 'flow_status_chip.dart';
import '../theme/app_theme.dart';

/// Opens the quick-log sheet. Everything the app can know is filled in
/// (run, date, gauge flow, crew), so logging is usually one tap on Save.
///
/// Pass [run] to log a specific run, e.g. from its page.
Future<void> showQuickLog(BuildContext context, {RiverRun? run}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => QuickLogSheet(initialRun: run),
  );
}

class QuickLogSheet extends ConsumerStatefulWidget {
  const QuickLogSheet({super.key, this.initialRun});

  final RiverRun? initialRun;

  @override
  ConsumerState<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends ConsumerState<QuickLogSheet> {
  final _noteController = TextEditingController();

  RiverRun? _run;
  SuggestionReason? _reason;
  bool _loadingRun = true;

  DateTime _date = DateUtils.dateOnly(DateTime.now());

  double? _flow;
  bool _flowFromGauge = false;
  bool _loadingFlow = false;
  int _flowRequest = 0;

  List<String> _crewOptions = [];
  final Set<String> _crew = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pickInitialRun();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickInitialRun() async {
    List<Descent> descents = const [];
    try {
      descents = await ref.read(allDescentsProvider.future);
    } catch (_) {}
    if (!mounted) return;

    // Crew: everyone you've paddled with, last trip's crew pre-selected.
    _crewOptions = crewSuggestions(descents);
    if (descents.isNotEmpty) {
      final latest = descents.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
      _crew.addAll(latest.crew ?? const []);
    }

    RiverRun? run = widget.initialRun;
    SuggestionReason? reason;
    if (run == null) {
      try {
        final runs = await ref.read(riverRunsStreamProvider.future);
        final suggestion = suggestRun(
          runs: runs,
          descents: descents,
          recentRunIds: ref.read(recentRunsProvider),
        );
        run = suggestion?.run;
        reason = suggestion?.reason;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _run = run;
      _reason = reason;
      _loadingRun = false;
    });
    _refreshFlow();
  }

  Future<void> _refreshFlow() async {
    final stationId = _run?.stationId;
    final request = ++_flowRequest;
    if (stationId == null || stationId.isEmpty) {
      setState(() {
        _flow = null;
        _flowFromGauge = false;
      });
      return;
    }
    setState(() => _loadingFlow = true);
    final flow = await ref
        .read(gaugeRepositoryProvider)
        .flowOn(stationId, _date);
    if (!mounted || request != _flowRequest) return;
    setState(() {
      _flow = flow;
      _flowFromGauge = flow != null;
      _loadingFlow = false;
    });
  }

  Future<void> _changeRun() async {
    final run = await showModalBottomSheet<RiverRun>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RiverRunSelector(),
    );
    if (run == null || !mounted) return;
    setState(() {
      _run = run;
      _reason = null;
    });
    _refreshFlow();
  }

  Future<void> _changeDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = DateUtils.dateOnly(picked));
    _refreshFlow();
  }

  Future<void> _editFlow() async {
    final controller = TextEditingController(
      text: _flow?.toStringAsFixed(1) ?? '',
    );
    final result = await showDialog<double?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flow'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'm³/s'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _flow = result;
      _flowFromGauge = false;
    });
  }

  Future<void> _addCrew() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to crew'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    setState(() {
      if (!_crewOptions.contains(trimmed)) _crewOptions.add(trimmed);
      _crew.add(trimmed);
    });
  }

  Future<void> _save() async {
    final run = _run;
    if (run == null || _saving) return;
    setState(() => _saving = true);

    final runName = run.river == run.name
        ? run.name
        : '${run.river} - ${run.name}';
    final note = _noteController.text.trim();
    final notifier = ref.read(descentsProvider.notifier);
    final id = await notifier.addDescent(
      runId: run.riverId,
      runName: runName,
      date: _date,
      flow: _flow,
      flowUnit: _flow != null ? 'm³/s' : null,
      notes: note.isEmpty ? null : note,
      difficulty: run.difficultyClass,
      crew: _crew.isEmpty ? null : _crew.toList(),
    );
    ref.read(recentRunsProvider.notifier).addRecentRun(run.riverId);

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (id == null) {
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ref.read(descentsProvider).errorMessage ??
                "Couldn't save. Check your connection and try again.",
          ),
        ),
      );
      return;
    }
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Saved ${run.name} to your logbook.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.deleteDescent(id),
        ),
      ),
    );
  }

  void _openFullForm() {
    final run = _run;
    Navigator.pop(context);
    context.push(AppRoutes.logDescent, extra: run);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Log a run',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),

            // Run
            Text('RUN', style: labelStyle),
            const SizedBox(height: 6),
            _Tile(
              onTap: _changeRun,
              semanticsLabel: 'Run: ${_run?.name ?? 'none'}. Change run',
              child: Row(
                children: [
                  Expanded(
                    child: _loadingRun
                        ? const LinearProgressIndicator()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _run?.name ?? 'Choose a run',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (_run != null)
                                Text(
                                  [
                                    if (_run!.river != _run!.name) _run!.river,
                                    if (_reason != null) _reason!.label,
                                  ].join(' · '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Text(
                    'Change',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Date and flow
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('DATE', style: labelStyle),
                      const SizedBox(height: 6),
                      _Tile(
                        onTap: _changeDate,
                        semanticsLabel: 'Date: ${_dateLabel()}. Change date',
                        child: Text(
                          _dateLabel(),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('FLOW', style: labelStyle),
                      const SizedBox(height: 6),
                      _Tile(
                        onTap: _editFlow,
                        semanticsLabel: _flow == null
                            ? 'Flow: not set. Add flow'
                            : 'Flow: ${_flow!.toStringAsFixed(1)} cubic metres '
                                  'per second. Edit flow',
                        child: _loadingFlow
                            ? const LinearProgressIndicator()
                            : Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    _flow == null
                                        ? 'Add'
                                        : '${_flow!.toStringAsFixed(1)} m³/s',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if ((_run?.flowStatus(_flow) ??
                                          FlowStatus.unknown)
                                      case final status
                                      when status != FlowStatus.unknown)
                                    FlowStatusChip(status: status),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _flowCaption(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Crew
            Text('CREW', style: labelStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final name in _crewOptions)
                  FilterChip(
                    label: Text(name),
                    selected: _crew.contains(name),
                    onSelected: (on) => setState(
                      () => on ? _crew.add(name) : _crew.remove(name),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  onPressed: _addCrew,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Note
            TextField(
              controller: _noteController,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Anything worth remembering?',
              ),
            ),
            const SizedBox(height: 8),

            FilledButton(
              onPressed: _run == null || _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Save to logbook'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _openFullForm,
              child: const Text('Add rating, difficulty or photos'),
            ),
          ],
        ),
      ),
    );
  }

  String _dateLabel() {
    final today = DateUtils.dateOnly(DateTime.now());
    if (_date == today) return 'Today, ${DateFormat.MMMd().format(_date)}';
    if (_date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat.MMMd().format(_date)}';
    }
    return DateFormat.yMMMd().format(_date);
  }

  String _flowCaption() {
    if (_loadingFlow) return 'Checking the gauge…';
    if (_run?.stationId == null)
      return "This run has no gauge. Add flow if you know it.";
    if (_flow == null)
      return 'No gauge reading for this day. Add flow if you know it.';
    if (!_flowFromGauge) return 'Entered by you.';
    final gauge = _run?.gaugeStation?['name'];
    return gauge == null
        ? 'Filled in from the gauge.'
        : 'Filled in from $gauge.';
  }
}

/// A large, tappable field with a visible outline: easy to hit with wet
/// hands and clearly editable.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.child,
    required this.onTap,
    required this.semanticsLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: Pebble.small),
        child: InkWell(
          onTap: onTap,
          borderRadius: Pebble.small,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
