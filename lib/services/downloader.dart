import 'dart:io';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/audio.dart';
import '../models/song_model.dart';
import '../utils/helper.dart';
import 'stream_service.dart';

class DownloaderService extends getx.GetxService {
  final Dio _dio = Dio();
  final getx.RxMap<String, int> downloadProgress = <String, int>{}.obs;
  final getx.RxSet<String> activeDownloads = <String>{}.obs;

  bool isDownloading(String songId) => activeDownloads.contains(songId);
  int getProgress(String songId) => downloadProgress[songId] ?? 0;

  bool isDownloaded(String songId) {
    final box = Hive.box('SongDownloads');
    if (!box.containsKey(songId)) return false;
    final data = box.get(songId);
    final path = data['extras']?['url'] as String? ?? '';
    return path.isNotEmpty && File(path).existsSync();
  }

  Future<bool> downloadSong(SongModel song) async {
    if (activeDownloads.contains(song.id)) return false;

    try {
      activeDownloads.add(song.id);
      downloadProgress[song.id] = 0;

      final appPrefs = Hive.box('AppPrefs');
      final downloadingFormat = appPrefs.get('downloadFormat', defaultValue: 'opus') as String;

      final playerResponse = await StreamProvider.fetch(song.id);
      if (!playerResponse.playable) {
        printERROR("Failed to resolve stream for download of ${song.id}");
        activeDownloads.remove(song.id);
        return false;
      }

      final Audio? requiredAudioStream = downloadingFormat == "opus"
          ? (playerResponse.highestBitrateOpusAudio ?? playerResponse.highestQualityAudio)
          : (playerResponse.highestBitrateMp4aAudio ?? playerResponse.highestQualityAudio);

      if (requiredAudioStream == null || requiredAudioStream.url.isEmpty) {
        printERROR("No valid audio format found to download for ${song.id}");
        activeDownloads.remove(song.id);
        return false;
      }

      final docDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory("${docDir.path}/downloads");
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final actualExt = requiredAudioStream.audioCodec == Codec.mp4a ? "m4a" : "opus";
      final safeTitle = cleanFilename("${song.title} - ${song.artist}");
      final filePath = "${downloadsDir.path}/$safeTitle.$actualExt";

      final headers = <String, dynamic>{};
      if (requiredAudioStream.size > 0) {
        headers['Range'] = 'bytes=0-${requiredAudioStream.size - 1}';
      }

      await _dio.download(
        requiredAudioStream.url,
        filePath,
        options: Options(headers: headers),
        onReceiveProgress: (count, total) {
          final totalBytes = total > 0 ? total : requiredAudioStream.size;
          if (totalBytes > 0) {
            final percentage = ((count / totalBytes) * 100).clamp(0, 100).toInt();
            downloadProgress[song.id] = percentage;
          }
        },
      );

      // Save to SongDownloads Hive Box
      final updatedExtras = Map<String, dynamic>.from(song.extras);
      updatedExtras['url'] = filePath;
      updatedExtras['downloadedAt'] = DateTime.now().toIso8601String();
      updatedExtras['codec'] = actualExt;
      updatedExtras['fileSize'] = requiredAudioStream.size;

      final downloadedSong = SongModel(
        id: song.id,
        title: song.title,
        artist: song.artist,
        album: song.album,
        artUri: song.artUri,
        duration: song.duration,
        extras: updatedExtras,
      );

      final downloadsBox = Hive.box("SongDownloads");
      await downloadsBox.put(song.id, downloadedSong.toJson());

      printINFO("Successfully downloaded and registered: $filePath");
      return true;
    } catch (e) {
      printERROR("Download error for song: ${song.id}", e);
      return false;
    } finally {
      activeDownloads.remove(song.id);
      downloadProgress.remove(song.id);
    }
  }

  Future<void> deleteDownloadedSong(String songId) async {
    try {
      final box = Hive.box("SongDownloads");
      if (box.containsKey(songId)) {
        final data = box.get(songId);
        final filePath = data['extras']?['url'] as String? ?? '';
        if (filePath.isNotEmpty) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
        await box.delete(songId);
      }
    } catch (e) {
      printERROR("Error deleting downloaded song $songId", e);
    }
  }
}
