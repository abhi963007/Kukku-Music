import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'controllers/download_controller.dart';
import 'controllers/player_controller.dart';
import 'controllers/search_controller.dart';
import 'controllers/settings_controller.dart';
import 'services/audio_handler.dart';
import 'services/downloader.dart';
import 'services/music_service.dart';
import 'ui/screens/main_navigation_screen.dart';
import 'ui/theme/app_theme.dart';
import 'utils/helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system navigation bar & status bar transparent / dark
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Hive and open all storage boxes
  try {
    await Hive.initFlutter();
    await Hive.openBox('AppPrefs');
    await Hive.openBox('SongsUrlCache');
    await Hive.openBox('SongsCache');
    await Hive.openBox('SongDownloads');
    // Clear stale stream URL cache so fresh MP4a URLs are fetched
    await Hive.box('SongsUrlCache').clear();
    printINFO("Hive boxes initialized successfully");
  } catch (e) {
    printERROR("Hive initialization failed", e);
  }

  // Initialize background AudioService
  final audioHandler = await initAudioService();
  final myAudioHandler = audioHandler as MyAudioHandler;

  // Register GetX global services and controllers
  Get.put<MyAudioHandler>(myAudioHandler);
  Get.put<MusicServices>(MusicServices());
  Get.put<DownloaderService>(DownloaderService());
  Get.put<PlayerController>(PlayerController(audioHandler: myAudioHandler));
  Get.put<SearchViewController>(SearchViewController());
  Get.put<DownloadViewController>(DownloadViewController());
  Get.put<SettingsController>(SettingsController());

  runApp(const KukkuApp());
}

class KukkuApp extends StatelessWidget {
  const KukkuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Kukku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}
