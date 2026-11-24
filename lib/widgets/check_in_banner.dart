import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_service.dart';
import '../models/river_run.dart';
import '../providers/check_in_provider.dart';
import 'quick_log_sheet.dart';

/// The run's name as people say it: "Chilliwack · Tamihi to Vedder".
String runTitle(RiverRun run) =>
    run.name == run.river ? run.river : '${run.river} · ${run.name}';

/// "You're at the put-in" card: one tap opens the quick log on that run.
class CheckInBanner extends ConsumerWidget {
  const CheckInBanner({super.key, required this.checkIn});
  final PutInCheckIn checkIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final run = checkIn.run;
    final flow = checkIn.flow;
    final detail = flow != null
        ? '${run.river} is at ${flow.toStringAsFixed(1)} m³/s. '
              "Log today's run?"
        : "Log today's run?";

    return _BannerCard(
      icon: Icons.place_outlined,
      eyebrow: "You're at the put-in",
      title: runTitle(run),
      body: detail,
      primaryLabel: 'Log it',
      onPrimary: () => showQuickLog(context, run: run),
      onDismiss: () {
        final dismissed = ref.read(dismissedCheckInsProvider);
        ref.read(dismissedCheckInsProvider.notifier).state = {
          ...dismissed,
          run.riverId,
        };
      },
      foreground: onPrimary,
      background: theme.colorScheme.primary,
    );
  }
}

/// Asks once, in context, before Brownpaw ever shows a location prompt.
class LocationPromptCard extends ConsumerWidget {
  const LocationPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return _BannerCard(
      icon: Icons.place_outlined,
      title: 'Know when you’re at a put-in',
      body:
          'Brownpaw can spot the run you’re about to paddle, so logging it '
          'takes one tap.',
      primaryLabel: 'Turn on location',
      onPrimary: () async {
        await ref.read(locationServiceProvider).ask();
        ref.invalidate(locationAccessProvider);
      },
      onDismiss: () => dismissLocationPrompt(ref),
      foreground: theme.colorScheme.onSurface,
      background: theme.colorScheme.surface,
      border: theme.colorScheme.outlineVariant,
      accent: theme.colorScheme.primary,
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.icon,
    this.eyebrow,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onDismiss,
    required this.foreground,
    required this.background,
    this.border,
    this.accent,
  });

  final IconData icon;
  final String? eyebrow;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onDismiss;
  final Color foreground;
  final Color background;
  final Color? border;

  /// Fill for the primary button; defaults to [foreground] (inverted card).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonFill = accent ?? foreground;
    final buttonText = accent != null
        ? theme.colorScheme.onPrimary
        : background;
    final soft = foreground.withValues(alpha: 0.85);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: border != null ? Border.all(color: border!) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: accent ?? foreground, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null)
                      Text(
                        eyebrow!,
                        style: theme.textTheme.bodySmall?.copyWith(color: soft),
                      ),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(color: soft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: buttonFill,
                    foregroundColor: buttonText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: onPrimary,
                  child: Text(primaryLabel),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: foreground,
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: foreground.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onDismiss,
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
