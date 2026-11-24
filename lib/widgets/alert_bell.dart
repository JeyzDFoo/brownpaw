import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/push_service.dart';
import '../domain/flow_alert.dart';
import '../models/river_run.dart';
import '../providers/flow_alerts_provider.dart';

/// A bell that turns a run's flow alert on or off.
class AlertBell extends ConsumerStatefulWidget {
  const AlertBell({super.key, required this.run});
  final RiverRun run;

  @override
  ConsumerState<AlertBell> createState() => _AlertBellState();
}

class _AlertBellState extends ConsumerState<AlertBell> {
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    final run = widget.run;
    final range = alertRangeFor(run)!;
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(flowAlertsControllerProvider);
    setState(() => _busy = true);
    String message;
    try {
      if (on) {
        await controller.turnOff(run);
        message = 'Alert off for ${run.name}';
      } else {
        message = switch (await controller.turnOn(run)) {
          PushResult.enabled =>
            "We'll tell you when ${run.name} is ${range.word} "
                '(${range.text}).',
          PushResult.denied =>
            'Notifications are off for Brownpaw. Turn them on in your '
                'settings to get flow alerts.',
          PushResult.unavailable =>
            "Flow alerts aren't available on this device yet.",
        };
      }
    } catch (_) {
      message = "Couldn't change the alert. Try again.";
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on =
        ref
            .watch(alertedRunIdsProvider)
            .valueOrNull
            ?.contains(widget.run.riverId) ??
        false;
    final range = alertRangeFor(widget.run)!;
    return IconButton(
      tooltip: on
          ? 'Turn off alert for ${widget.run.name}'
          : 'Alert me when ${widget.run.name} is ${range.word}',
      isSelected: on,
      onPressed: _busy ? null : () => _toggle(on),
      icon: const Icon(Icons.notifications_none),
      selectedIcon: Icon(
        Icons.notifications_active,
        color: theme.colorScheme.primary,
      ),
    );
  }
}
