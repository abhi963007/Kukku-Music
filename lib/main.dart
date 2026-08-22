import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'controllers/download_controller.dart';
import 'controllers/player_controller.dart';
import 'controllers/search_controller.dart';
import 'controllers/settings_controller.dart';
import 'services/audio_handler.dart';
import 'services/downloader.dart';
import 'services/music_service.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme/app_theme.dart';
import 'utils/helper.dart';

/// Names of every Hive box the app relies on.
const List<String> _hiveBoxes = [
  'AppPrefs',
  'SongsUrlCache',
  'SongsCache',
  'SongDownloads',
];

void main() {
  // Any error thrown during startup used to take down the whole app with a bare
  // red screen. Route framework + isolate errors into the logger instead, and
  // still bring up a usable UI.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      printERROR('FlutterError: ${details.exceptionAsString()}', details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      printERROR('Uncaught platform error', error);
      return true;
    };

    await _configureSystemChrome();
    await _initStorage();

    // Initialize background AudioService. If this fails the app must still run,
    // so fall back to an un-backgrounded handler rather than crashing.
    MyAudioHandler? myAudioHandler;
    try {
      final audioHandler = await initAudioService();
      myAudioHandler = audioHandler as MyAudioHandler;
    } catch (e) {
      printERROR('AudioService init failed, falling back to local handler', e);
      myAudioHandler = MyAudioHandler();
    }

    // Register GetX global services and controllers
    Get.put<MyAudioHandler>(myAudioHandler, permanent: true);
    Get.put<MusicServices>(MusicServices(), permanent: true);
    Get.put<DownloaderService>(DownloaderService(), permanent: true);
    Get.put<PlayerController>(
      PlayerController(audioHandler: myAudioHandler),
      permanent: true,
    );
    Get.put<SearchViewController>(SearchViewController(), permanent: true);
    Get.put<DownloadViewController>(DownloadViewController(), permanent: true);
    Get.put<SettingsController>(SettingsController(), permanent: true);

    runApp(const KukkuApp());

    // Ask for the Android 13+ notification permission after the first frame so
    // the system dialog does not race the splash screen.
    _requestNotificationPermission();
  }, (error, stack) {
    printERROR('Uncaught zone error', error);
  });
}

/// Enables edge-to-edge rendering so content flows behind the status bar and
/// gesture navigation bar. Punch-hole cameras, notches and the nav bar are then
/// handled by `SafeArea` / `MediaQuery.viewPadding` in each screen.
Future<void> _configureSystemChrome() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      // Transparent nav bar; Android 15+ ignores a solid colour here anyway.
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  // Portrait-first, but landscape stays available and the layouts now adapt.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

/// Opens every Hive box, tolerating individual corrupt boxes by deleting and
/// recreating them instead of aborting startup.
Future<void> _initStorage() async {
  try {
    await Hive.initFlutter();
  } catch (e) {
    printERROR('Hive.initFlutter failed — storage will be in-memory only', e);
    return;
  }

  for (final name in _hiveBoxes) {
    try {
      await Hive.openBox(name);
    } catch (e) {
      printERROR('Hive box "$name" failed to open, recreating', e);
      try {
        await Hive.deleteBoxFromDisk(name);
        await Hive.openBox(name);
      } catch (e2) {
        printERROR('Hive box "$name" is unusable', e2);
      }
    }
  }

  // Drop only the stream URLs that have actually expired. The previous code
  // wiped the whole box on every launch, which disabled URL caching entirely.
  await _pruneExpiredStreamUrls();
  printINFO('Hive boxes initialized');
}

Future<void> _pruneExpiredStreamUrls() async {
  final box = safeBox('SongsUrlCache');
  if (box == null) return;
  try {
    final staleKeys = <dynamic>[];
    for (final key in box.keys) {
      final entry = asStringMap(box.get(key));
      final url = asText(asStringMap(entry['highQualityAudio'])['url']).isNotEmpty
          ? asText(asStringMap(entry['highQualityAudio'])['url'])
          : asText(asStringMap(entry['lowQualityAudio'])['url']);
      if (url.isEmpty || isExpired(url: url)) staleKeys.add(key);
    }
    if (staleKeys.isNotEmpty) {
      await box.deleteAll(staleKeys);
      printINFO('Pruned ${staleKeys.length} expired stream URL(s)');
    }
  } catch (e) {
    printERROR('Failed to prune SongsUrlCache', e);
  }
}

Future<void> _requestNotificationPermission() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  } catch (e) {
    printERROR('Notification permission request failed', e);
  }
}

class KukkuApp extends StatelessWidget {
  const KukkuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Kukku',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Prevents an extreme system font scale from tearing fixed-height rows.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: AppTheme.clampTextScaler(context),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const SplashScreen(),
    );
  }
}
