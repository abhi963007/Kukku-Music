import 'package:get/get.dart';
import 'package:hive/hive.dart';

class SettingsController extends GetxController {
  final box = Hive.box('AppPrefs');

  final RxInt streamingQuality = 1.obs; // 0: Low (48-50kbps), 1: High (128-160kbps)
  final RxString downloadFormat = 'opus'.obs; // 'opus' or 'm4a'
  final RxBool cacheSongs = true.obs;
  final RxString contentLanguage = 'en'.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  void _loadSettings() {
    streamingQuality.value = box.get('streamingQuality', defaultValue: 1);
    downloadFormat.value = box.get('downloadFormat', defaultValue: 'opus');
    cacheSongs.value = box.get('cacheSongs', defaultValue: true);
    contentLanguage.value = box.get('contentLanguage', defaultValue: 'en');
  }

  void setStreamingQuality(int quality) {
    streamingQuality.value = quality;
    box.put('streamingQuality', quality);
  }

  void setDownloadFormat(String format) {
    downloadFormat.value = format;
    box.put('downloadFormat', format);
  }

  void toggleCacheSongs(bool enabled) {
    cacheSongs.value = enabled;
    box.put('cacheSongs', enabled);
  }

  void setContentLanguage(String lang) {
    contentLanguage.value = lang;
    box.put('contentLanguage', lang);
  }
}
