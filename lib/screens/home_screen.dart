import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:brownpaw/providers/offline_cache_provider.dart';
import 'package:brownpaw/router.dart';
import 'package:brownpaw/screens/gauges_screen.dart';
import 'package:brownpaw/screens/guide_screen.dart';
import 'package:brownpaw/screens/logbook_screen.dart';
import 'package:brownpaw/screens/settings_screen.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:brownpaw/widgets/nav_icons.dart';
import 'package:brownpaw/widgets/pebble.dart';
import 'package:brownpaw/widgets/quick_log_sheet.dart';

/// The tabbed home shell: Logbook · Gauges · [Log] · Guide · Me.
///
/// Each tab has its own URL (see [AppRoutes.tabs]). The centre Log button
/// sits in the bar rather than floating over content, and opens the
/// quick-log sheet from any tab.
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, this.tabIndex = 0});

  /// Index into [AppRoutes.tabs].
  final int tabIndex;

  static const _tabs = [
    (title: 'Logbook', screen: LogbookScreen()),
    (title: 'Gauges', screen: GaugesScreen()),
    (title: 'Guide', screen: GuideScreen()),
    (title: 'Me', screen: SettingsScreen()),
  ];

  /// The Log button's slot in the bar.
  static const _logSlot = 2;

  int get _barIndex => tabIndex < _logSlot ? tabIndex : tabIndex + 1;

  void _onBarTap(BuildContext context, int barIndex) {
    if (barIndex == _logSlot) {
      showQuickLog(context);
      return;
    }
    final tab = barIndex < _logSlot ? barIndex : barIndex - 1;
    context.go(AppRoutes.tabs[tab]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tab = _tabs[tabIndex];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const BrownpawMark(size: 38),
            const SizedBox(width: 10),
            Flexible(
              child: Text(tab.title, style: theme.textTheme.headlineSmall),
            ),
          ],
        ),
        centerTitle: false,
      ),
      // Keeps starred and logged gauges cached for when there's no signal.
      body: Consumer(
        builder: (context, ref, child) {
          ref.watch(offlineCacheProvider);
          return child!;
        },
        child: tab.screen,
      ),
      // A pebble-topped bar that sits on the silt-green page.
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: NavigationBar(
          selectedIndex: _barIndex,
          onDestinationSelected: (i) => _onBarTap(context, i),
          destinations: [
            NavigationDestination(
              icon: const NavIcon(NavGlyph.logbook),
              selectedIcon: NavIcon(
                NavGlyph.logbook,
                filled: true,
                color: theme.colorScheme.primary,
              ),
              label: 'Logbook',
            ),
            NavigationDestination(
              icon: const NavIcon(NavGlyph.gauges),
              selectedIcon: NavIcon(
                NavGlyph.gauges,
                filled: true,
                color: theme.colorScheme.primary,
              ),
              label: 'Gauges',
            ),
            NavigationDestination(
              icon: _LogButtonIcon(color: theme.colorScheme.primary),
              label: 'Log',
              tooltip: 'Log a run',
            ),
            NavigationDestination(
              icon: const NavIcon(NavGlyph.guide),
              selectedIcon: NavIcon(
                NavGlyph.guide,
                filled: true,
                color: theme.colorScheme.primary,
              ),
              label: 'Guide',
            ),
            NavigationDestination(
              icon: const NavIcon(NavGlyph.me),
              selectedIcon: NavIcon(
                NavGlyph.me,
                filled: true,
                color: theme.colorScheme.primary,
              ),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}

/// A filled orange pebble with a plus: the bar's one primary action.
class _LogButtonIcon extends StatelessWidget {
  const _LogButtonIcon({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 40,
      decoration: BoxDecoration(color: color, borderRadius: Pebble.small),
      child: Center(
        child: NavIcon(NavGlyph.add, color: Riverstone.of(context).card),
      ),
    );
  }
}
