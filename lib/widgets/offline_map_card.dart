import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/offline_map_provider.dart';
import '../theme/app_theme.dart';
import 'map_tiles.dart';

/// "Offline map" on Me: download the Lower Mainland map for trips with no
/// signal. Shown only in the phone apps, and only when the map provider
/// allows offline downloads.
class OfflineMapCard extends ConsumerWidget {
  const OfflineMapCard({super.key});

  static bool get available =>
      MapTiles.offlineDownloadAllowed && MapTiles.store.supported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!available) return const SizedBox.shrink();
    final state = ref.watch(offlineMapProvider);
    final notifier = ref.read(offlineMapProvider.notifier);
    final text = Theme.of(context).textTheme;
    final p = Riverstone.of(context);
    final status = state.status;

    final String subtitle;
    if (state.downloading) {
      subtitle = 'Downloading… ${(state.progress! * 100).round()}%';
    } else if (state.error != null) {
      subtitle = state.error!;
    } else if (status.isEmpty) {
      subtitle =
          'The Lower Mainland and Sea to Sky, with close-ups of every run. '
          'About ${_mb(notifier.plan().length * 25000)}. Best on Wi-Fi.';
    } else {
      subtitle =
          'Saved ${DateFormat.MMMd().format(status.savedAt ?? DateTime.now())}'
          ' · ${_mb(status.bytes)}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.map_outlined, color: p.glacier),
                const SizedBox(width: 12),
                Expanded(child: Text('Offline map', style: text.titleSmall)),
                if (state.downloading)
                  TextButton(
                    onPressed: notifier.cancel,
                    child: const Text('Stop'),
                  )
                else if (status.isEmpty)
                  FilledButton(
                    onPressed: notifier.download,
                    child: const Text('Download'),
                  )
                else ...[
                  TextButton(
                    onPressed: notifier.download,
                    child: const Text('Update'),
                  ),
                  IconButton(
                    tooltip: 'Delete offline map',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: notifier.delete,
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 36, right: 8, top: 4),
              child: Text(subtitle, style: text.bodySmall),
            ),
            if (state.downloading)
              Padding(
                padding: const EdgeInsets.only(left: 36, right: 8, top: 10),
                child: LinearProgressIndicator(value: state.progress),
              ),
          ],
        ),
      ),
    );
  }

  static String _mb(int bytes) => '${(bytes / 1e6).ceil()} MB';
}
