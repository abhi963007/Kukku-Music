import 'dart:io';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song_model.dart';
import '../services/downloader.dart';
import '../utils/helper.dart';

class DownloadViewController extends GetxController {
  final DownloaderService downloader = Get.find<DownloaderService>();

  final RxList<SongModel> downloadedSongs = <SongModel>[].obs;
  final RxList<SongModel> cachedSongs = <SongModel>[].obs;
  final RxInt totalCacheSizeBytes = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadOfflineData();
  }

  Future<void> loadOfflineData() async {
    // 1. Load Downloaded Songs from Hive box
    final box = Hive.box("SongDownloads");
    final List<SongModel> list = [];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final song = SongModel.fromJson(data);
        final filePath = song.extras['url'] as String? ?? '';
        if (filePath.isNotEmpty && File(filePath).existsSync()) {
          list.add(song);
        }
      }
    }
    downloadedSongs.value = list;

    // 2. Scan Disk Cache Directory
    try {
      final docDir = await getApplicationSupportDirectory();
      final cacheFolder = Directory("${docDir.path}/cachedSongs");
      if (await cacheFolder.exists()) {
        final files = cacheFolder.listSync();
        int totalBytes = 0;
        final List<SongModel> cachedList = [];

        // Check recent songs from AppPrefs for metadata
        final recentJsonList = Hive.box('AppPrefs').get('recentSongs', defaultValue: []);
        final Map<String, dynamic> metadataMap = {};
        for (final item in recentJsonList) {
          if (item != null && item['id'] != null) {
            metadataMap[item['id']] = item;
          }
        }

        for (final entity in files) {
          if (entity is File && entity.path.endsWith('.mp3')) {
            final size = entity.lengthSync();
            totalBytes += size;
            final fileName = entity.uri.pathSegments.last;
            final songId = fileName.replaceAll('.mp3', '');

            if (metadataMap.containsKey(songId)) {
              cachedList.add(SongModel.fromJson(metadataMap[songId]));
            } else {
              cachedList.add(
                SongModel(
                  id: songId,
                  title: "Cached Track ($songId)",
                  artist: "Cached Audio",
                  album: "Local Storage",
                  artUri: "",
                  duration: Duration.zero,
                  extras: {'url': "file://${entity.path}", 'size': size},
                ),
              );
            }
          }
        }
        totalCacheSizeBytes.value = totalBytes;
        cachedSongs.value = cachedList;
      }
    } catch (e) {
      printERROR("Failed to scan cache directory", e);
    }
  }

  Future<void> download(SongModel song) async {
    final success = await downloader.downloadSong(song);
    if (success) {
      await loadOfflineData();
    }
  }

  Future<void> removeDownload(String songId) async {
    await downloader.deleteDownloadedSong(songId);
    downloadedSongs.removeWhere((element) => element.id == songId);
  }

  Future<void> clearAllCache() async {
    try {
      final docDir = await getApplicationSupportDirectory();
      final cacheFolder = Directory("${docDir.path}/cachedSongs");
      if (await cacheFolder.exists()) {
        await cacheFolder.delete(recursive: true);
        await cacheFolder.create();
      }
      cachedSongs.clear();
      totalCacheSizeBytes.value = 0;
      final urlCacheBox = Hive.box('SongsUrlCache');
      await urlCacheBox.clear();
    } catch (e) {
      printERROR("Failed to clear cache", e);
    }
  }
}
