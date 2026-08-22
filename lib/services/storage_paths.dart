import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../utils/helper.dart';

/// Single source of truth for on-disk locations.
///
/// The audio handler and the library screen previously resolved the streaming
/// cache from two different roots (`getTemporaryDirectory()` vs
/// `getApplicationSupportDirectory()`), so the cache stats and the "Cached
/// Songs" tab never saw what playback had written. Everything now goes through
/// here.
class StoragePaths {
  StoragePaths._();

  static Directory? _cachedSongsDir;
  static Directory? _downloadsDir;

  /// Directory holding progressively-cached stream files.
  ///
  /// Uses application support (not the OS temp dir) so the files survive
  /// system cache eviction, matching the "offline replay" promise in Settings.
  static Future<Directory> cachedSongsDir() async {
    final existing = _cachedSongsDir;
    if (existing != null && existing.existsSync()) return existing;

    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/cachedSongs');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _cachedSongsDir = dir;
    return dir;
  }

  /// Directory holding user-initiated downloads.
  static Future<Directory> downloadsDir() async {
    final existing = _downloadsDir;
    if (existing != null && existing.existsSync()) return existing;

    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/downloads');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    _downloadsDir = dir;
    return dir;
  }

  /// Extensions written by the stream cache. `.mp3` is accepted for backwards
  /// compatibility with files written by earlier builds.
  static const List<String> cacheExtensions = ['.m4a', '.mp3'];

  /// Path the stream cache uses for [songId].
  static Future<String> cacheFilePathFor(String songId) async {
    final dir = await cachedSongsDir();
    return '${dir.path}/$songId.m4a';
  }

  /// Returns the existing cache file for [songId], or `null` when absent or
  /// zero-length (a truncated download must not be handed to the player).
  static Future<File?> existingCacheFile(String songId) async {
    try {
      final dir = await cachedSongsDir();
      for (final ext in cacheExtensions) {
        final file = File('${dir.path}/$songId$ext');
        if (file.existsSync() && file.lengthSync() > 0) return file;
      }
    } catch (e) {
      printERROR('existingCacheFile($songId) failed', e);
    }
    return null;
  }
}
