import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Navigate to MainNavigationScreen after clean splash presentation
    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        Get.off(
          () => const MainNavigationScreen(),
          transition: Transition.fadeIn,
          duration: const Duration(milliseconds: 400),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D14),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Centered Transparent App Icon (Large & Clean)
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: Image.asset(
                'assets/images/app_icon.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.music_note_rounded,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Bottom White Loading Spinner
          const Positioned(
            bottom: 60,
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
