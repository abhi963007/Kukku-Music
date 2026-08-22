import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Long enough to read as intentional branding, short enough not to feel like
  /// a stall. The previous 2s was pure dead time.
  static const Duration _minimumDisplay = Duration(milliseconds: 1100);

  Timer? _timer;

  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    _timer = Timer(_minimumDisplay, _goToApp);
  }

  void _goToApp() {
    if (!mounted) return;
    Get.off(
      () => const MainNavigationScreen(),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Matches AppTheme.background and the native splash colour, so there is no
      // colour flash between the launch screen, this screen and the app.
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: FadeTransition(
                opacity: _fade,
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.music_note_rounded,
                      size: 80,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 48,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
