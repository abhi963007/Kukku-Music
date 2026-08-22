import 'dart:io';

import 'package:get/get.dart';

import '../models/song_model.dart';
import '../services/downloader.dart';
import '../services/storage_paths.dart';
import '../utils/helper.dart';

class DownloadViewController extends GetxController {
  final DownloaderService downloader = Get.find<DownloaderService>();

  final RxList<SongModel> downloadedSongs = <SongModel>[].obs;
  final RxList<SongModel> cachedSongs = <SongModel>[].obs;
  final RxInt totalCacheSizeBytes = 0.obs;
  final RxInt totalDownloadSizeBytes = 0.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadOfflineData();
  }

  Future<void> loadOfflineData() async {
    isLoading.value = true;
    try {
      await _loadDownloads();
      await _loadStreamCache();
    } catch (e) {
      printERROR('Failed to load offline data', e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadDownloads() async {
    final box = safeBox('SongDownloads');
    if (box == null) {
      downloadedSongs.clear();
      totalDownloadSizeBytes.value = 0;
      return;
    }

    final List<SongModel> list = [];
    int bytes = 0;
    for (final key in box.keys) {
      final song = SongModel.fromJson(box.get(key));
      if (song.id.isEmpty) continue;
      final rawPath = asText(song.extras['url']);
      if (rawPath.isEmpty) continue;
      final path = rawPath.startsWith('file://') ? Uri.parse(rawPath).toFilePath() : rawPath;
      final file = File(path);
      if (file.existsSync() && file.lengthSync() > 0) {
        bytes += file.lengthSync();
        list.add(song);
      }
    }
    downloadedSongs.value = list;
    totalDownloadSizeBytes.value = bytes;
    downloader.refreshDownloadedIds();
  }

  Future<void> _loadStreamCache() async {
    // The scan root used to be `getApplicationSupportDirectory()` while the
    // audio handler wrote to `getTemporaryDirectory()`, so this tab was always
    // empty and "Disk Space" always read 0 B. Both now go through StoragePaths.
    final cacheFolder = await StoragePaths.cachedSongsDir();
    if (!cacheFolder.existsSync()) {
      cachedSongs.clear();
      totalCacheSizeBytes.value = 0;
      return;
    }

    // Metadata for cached ids, preferring the SongsCache box and falling back
    // to recently-played history.
    final Map<String, dynamic> metadata = {};
    final recents = boxGet<List<dynamic>>('AppPrefs', 'recentSongs', const []);
    for (final item in recents) {
      final map = asStringMap(item);
      final id = asText(map['id']);
      if (id.isNotEmpty) metadata[id] = map;
    }
    final cacheBox = safeBox('SongsCache');
    if (cacheBox != null) {
      for (final key in cacheBox.keys) {
        final map = asStringMap(cacheBox.get(key));
        if (map.isNotEmpty) metadata[key.toString()] = map;
      }
    }

    int totalBytes = 0;
    final List<SongModel> cachedList = [];

    for (final entity in cacheFolder.listSync()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      // LockCachingAudioSource also writes `.part` and `.mime` sidecar files;
      // only count finished audio.
      final ext = StoragePaths.cacheExtensions.firstWhere(
        (e) => name.endsWith(e),
        orElse: () => '',
      );
      if (ext.isEmpty) continue;

      final size = entity.lengthSync();
      if (size <= 0) continue;
      totalBytes += size;

      final songId = name.substring(0, name.length - ext.length);
      final meta = metadata[songId];
      if (meta != null) {
        final song = SongModel.fromJson(meta);
        cachedList.add(SongModel(
          id: song.id.isNotEmpty ? song.id : songId,
          title: song.title,
          artist: song.artist,
          album: song.album,
          artUri: song.artUri,
          duration: song.duration,
          extras: {...song.extras, 'url': entity.uri.toString(), 'size': size},
        ));
      } else {
        cachedList.add(SongModel(
          id: songId,
          title: 'Cached Track',
          artist: 'Offline audio',
          album: 'Local Storage',
          artUri: '',
          duration: Duration.zero,
          extras: {'url': entity.uri.toString(), 'size': size},
        ));
      }
    }

    totalCacheSizeBytes.value = totalBytes;
    cachedSongs.value = cachedList;
  }

  Future<bool> download(SongModel song) async {
    final success = await downloader.downloadSong(song);
    if (success) {
      await loadOfflineData();
    }
    return success;
  }

  Future<void> removeDownload(String songId) async {
    await downloader.deleteDownloadedSong(songId);
    downloadedSongs.removeWhere((element) => element.id == songId);
    // Keeps the "Disk Space" figure honest after a delete.
    await _loadDownloads();
  }

  Future<void> clearAllCache() async {
    try {
      final cacheFolder = await StoragePaths.cachedSongsDir();
      if (cacheFolder.existsSync()) {
        for (final entity in cacheFolder.listSync()) {
          try {
            entity.deleteSync(recursive: true);
          } catch (e) {
            printERROR('Could not delete ${entity.path}', e);
          }
        }
      }
      cachedSongs.clear();
      totalCacheSizeBytes.value = 0;

      final cacheBox = safeBox('SongsCache');
      await cacheBox?.clear();
      final urlCacheBox = safeBox('SongsUrlCache');
      await urlCacheBox?.clear();
    } catch (e) {
      printERROR("Failed to clear cache", e);
    }
  }
}
