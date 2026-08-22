import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;

import '../models/audio.dart';
import '../models/song_model.dart';
import '../utils/helper.dart';
import 'storage_paths.dart';
import 'stream_service.dart';

class DownloaderService extends getx.GetxService {
  final Dio _dio = Dio();
  final getx.RxMap<String, int> downloadProgress = <String, int>{}.obs;
  final getx.RxSet<String> activeDownloads = <String>{}.obs;

  /// Ids known to have a valid file on disk.
  ///
  /// This used to be answered by a synchronous `File.existsSync()` inside every
  /// `SongTile`'s `Obx`, which hit the filesystem on every scroll frame and,
  /// because it was not observable, never refreshed when a download finished.
  final getx.RxSet<String> downloadedIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    refreshDownloadedIds();
  }

  bool isDownloading(String songId) => activeDownloads.contains(songId);

  int getProgress(String songId) => downloadProgress[songId] ?? 0;

  bool isDownloaded(String songId) => downloadedIds.contains(songId);

  /// Rebuilds [downloadedIds] from Hive + disk. Cheap enough to call after a
  /// download or delete, but never during a build.
  void refreshDownloadedIds() {
    final box = safeBox('SongDownloads');
    if (box == null) {
      downloadedIds.clear();
      return;
    }
    final ids = <String>{};
    for (final key in box.keys) {
      final entry = asStringMap(box.get(key));
      final path = _pathFromEntry(entry);
      if (path.isNotEmpty && File(path).existsSync()) {
        ids.add(key.toString());
      }
    }
    downloadedIds
      ..clear()
      ..addAll(ids);
  }

  String _pathFromEntry(Map<String, dynamic> entry) {
    final direct = asText(entry['url']);
    if (direct.isNotEmpty) {
      return direct.startsWith('file://') ? Uri.parse(direct).toFilePath() : direct;
    }
    final nested = asText(asStringMap(entry['extras'])['url']);
    if (nested.isEmpty) return '';
    return nested.startsWith('file://') ? Uri.parse(nested).toFilePath() : nested;
  }

  Future<bool> downloadSong(SongModel song) async {
    if (song.id.isEmpty) return false;
    if (activeDownloads.contains(song.id)) return false;

    String? partialPath;
    try {
      activeDownloads.add(song.id);
      downloadProgress[song.id] = 0;

      final downloadingFormat = boxGet<String>('AppPrefs', 'downloadFormat', 'opus');

      final playerResponse = await StreamProvider.fetch(
        song.id,
        songTitle: song.title,
        artistName: song.artist,
      );
      if (!playerResponse.playable) {
        printERROR("Failed to resolve stream for download of ${song.id}");
        return false;
      }

      final Audio? requiredAudioStream = downloadingFormat == "opus"
          ? (playerResponse.highestBitrateOpusAudio ?? playerResponse.highestQualityAudio)
          : (playerResponse.highestBitrateMp4aAudio ?? playerResponse.highestQualityAudio);

      if (requiredAudioStream == null || requiredAudioStream.url.isEmpty) {
        printERROR("No valid audio format found to download for ${song.id}");
        return false;
      }

      final downloadsDir = await StoragePaths.downloadsDir();
      final actualExt = requiredAudioStream.audioCodec == Codec.mp4a ? "m4a" : "opus";
      final safeTitle = cleanFilename("${song.title} - ${song.artist}");
      // Guard against an empty/duplicate filename after sanitising.
      final baseName = safeTitle.isNotEmpty ? safeTitle : song.id;
      final filePath = "${downloadsDir.path}/$baseName.$actualExt";
      partialPath = filePath;

      await _dio.download(
        requiredAudioStream.url,
        filePath,
        onReceiveProgress: (count, total) {
          final totalBytes = total > 0 ? total : requiredAudioStream.size;
          if (totalBytes > 0) {
            downloadProgress[song.id] =
                ((count / totalBytes) * 100).clamp(0, 100).toInt();
          }
        },
      );

      // A 0-byte file means the CDN returned an error body; treat it as failure.
      final written = File(filePath);
      if (!written.existsSync() || written.lengthSync() <= 0) {
        printERROR("Download produced an empty file for ${song.id}");
        return false;
      }

      final updatedExtras = Map<String, dynamic>.from(song.extras);
      updatedExtras['url'] = filePath;
      updatedExtras['downloadedAt'] = DateTime.now().toIso8601String();
      updatedExtras['codec'] = actualExt;
      updatedExtras['fileSize'] = written.lengthSync();

      final downloadedSong = SongModel(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        artUri: song.artUri,
        duration: song.duration,
        extras: updatedExtras,
      );

      await boxPut('SongDownloads', song.id, downloadedSong.toJson());
      downloadedIds.add(song.id);
      partialPath = null;

      printINFO("Successfully downloaded and registered: $filePath");
      return true;
    } catch (e) {
      printERROR("Download error for song: ${song.id}", e);
      return false;
    } finally {
      // Never leave a half-written file behind: it would be reported as a valid
      // download and then fail to play.
      if (partialPath != null) {
        try {
          final partial = File(partialPath);
          if (partial.existsSync()) partial.deleteSync();
        } catch (e) {
          printERROR('Failed to clean up partial download', e);
        }
      }
      activeDownloads.remove(song.id);
      downloadProgress.remove(song.id);
    }
  }

  Future<void> deleteDownloadedSong(String songId) async {
    try {
      final box = safeBox('SongDownloads');
      if (box == null) return;
      if (box.containsKey(songId)) {
        final path = _pathFromEntry(asStringMap(box.get(songId)));
        if (path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
        await box.delete(songId);
      }
      downloadedIds.remove(songId);
    } catch (e) {
      printERROR("Error deleting downloaded song $songId", e);
    }
  }
}
