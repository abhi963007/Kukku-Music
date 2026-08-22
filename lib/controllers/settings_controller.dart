import 'package:get/get.dart';

import '../services/audio_handler.dart';
import '../utils/helper.dart';

class SettingsController extends GetxController {
  final RxInt streamingQuality = 1.obs; // 0: Low (48-50kbps), 1: High (128-160kbps)
  final RxString downloadFormat = 'opus'.obs; // 'opus' or 'm4a'
  final RxBool cacheSongs = true.obs;
  final RxString contentLanguage = 'en'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  /// Reads with type coercion: a value written by an older build (or a corrupt
  /// box) could be a `String` where an `int`/`bool` is expected, which used to
  /// throw while assigning to the typed `Rx`.
  void _loadSettings() {
    streamingQuality.value = asInt(boxGet<dynamic>('AppPrefs', 'streamingQuality', 1), 1)
        .clamp(0, 1);
    final format = asText(boxGet<dynamic>('AppPrefs', 'downloadFormat', 'opus'));
    downloadFormat.value = (format == 'm4a' || format == 'opus') ? format : 'opus';
    cacheSongs.value = asBool(boxGet<dynamic>('AppPrefs', 'cacheSongs', true), true);
    final lang = asText(boxGet<dynamic>('AppPrefs', 'contentLanguage', 'en'));
    contentLanguage.value = lang.isNotEmpty ? lang : 'en';
  }

  Future<void> setStreamingQuality(int quality) async {
    final clamped = quality.clamp(0, 1);
    streamingQuality.value = clamped;
    await boxPut('AppPrefs', 'streamingQuality', clamped);
  }

  Future<void> setDownloadFormat(String format) async {
    if (format != 'opus' && format != 'm4a') return;
    downloadFormat.value = format;
    await boxPut('AppPrefs', 'downloadFormat', format);
  }

  Future<void> toggleCacheSongs(bool enabled) async {
    cacheSongs.value = enabled;
    await boxPut('AppPrefs', 'cacheSongs', enabled);
    // Push the change to the running handler so it applies to the next track
    // without an app restart.
    if (Get.isRegistered<MyAudioHandler>()) {
      await Get.find<MyAudioHandler>()
          .customAction('setCacheEnabled', {'enabled': enabled});
    }
  }

  Future<void> setContentLanguage(String lang) async {
    if (lang.isEmpty) return;
    contentLanguage.value = lang;
    await boxPut('AppPrefs', 'contentLanguage', lang);
  }
}
