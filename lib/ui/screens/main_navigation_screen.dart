import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = [
    HomeScreen(onNavigateTab: _onTabTapped),
    const SearchScreen(),
    const LibraryScreen(),
    const SettingsScreen(),
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    // Dismiss the keyboard when leaving Search, otherwise it stays up over the
    // next tab's content.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // While the keyboard is open the mini player + nav bar would otherwise be
    // pushed up and sit directly on top of it, eating most of the search
    // results area.
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      // The screens handle their own top inset via SafeArea.
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: keyboardVisible
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              left: false,
              right: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Seamlessly attached Mini Player
                  const MiniPlayer(),

                  // Bottom Navigation Bar. The system inset is already applied
                  // by the SafeArea above, so strip it here to avoid doubling.
                  MediaQuery.removePadding(
                    context: context,
                    removeBottom: true,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppTheme.surface,
                        border: Border(
                          top: BorderSide(color: AppTheme.cardBorder, width: 0.8),
                        ),
                      ),
                      child: BottomNavigationBar(
                        currentIndex: _currentIndex,
                        onTap: _onTabTapped,
                        backgroundColor: AppTheme.surface,
                        selectedItemColor: AppTheme.primary,
                        unselectedItemColor: AppTheme.textMuted,
                        selectedFontSize: 12,
                        unselectedFontSize: 11,
                        type: BottomNavigationBarType.fixed,
                        elevation: 0,
                        items: const [
                          BottomNavigationBarItem(
                            icon: Icon(Icons.home_outlined),
                            activeIcon: Icon(Icons.home_rounded),
                            label: "Home",
                            tooltip: "Home",
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.search_outlined),
                            activeIcon: Icon(Icons.search_rounded),
                            label: "Search",
                            tooltip: "Search",
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.library_music_outlined),
                            activeIcon: Icon(Icons.library_music_rounded),
                            label: "Library",
                            tooltip: "Library",
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.settings_outlined),
                            activeIcon: Icon(Icons.settings_rounded),
                            label: "Settings",
                            tooltip: "Settings",
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
