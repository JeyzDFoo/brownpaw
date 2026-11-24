import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:brownpaw/router.dart';

import 'package:brownpaw/screens/community_home_screen.dart';
import 'package:brownpaw/screens/favourites_screen.dart';
import 'package:brownpaw/screens/logbook_screen.dart';
// import 'package:brownpaw/screens/map_screen.dart';
import 'package:brownpaw/screens/settings_screen.dart';

/// The tabbed home shell. Each tab has its own URL (see [AppRoutes.tabs]),
/// so the browser's back button and shared links work on the web.
class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, this.tabIndex = 0});

  final int tabIndex;

  static const List<Widget> _screens = [
    CommunityHomeScreen(),
    LogbookScreen(),
    FavouritesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: tabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.logDescent),
              icon: const Icon(Icons.add),
              label: const Text('Log Descent'),
            )
          : null,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Brown Paw'),
      ),
      body: _screens[tabIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: tabIndex,
        onTap: (index) => context.go(AppRoutes.tabs[index]),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Logbook'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favourites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
