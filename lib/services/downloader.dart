import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;

import '../models/audio.dart';
import '../models/song_model.dart';
import '../models/streaming_data.dart';
import '../utils/helper.dart';
import 'saavn_service.dart';
import 'storage_paths.dart';
import 'stream_service.dart';

/// Outcome of a download attempt, so callers can show a specific message
/// instead of a generic "failed".
class DownloadResult {
  final bool success;
  final String message;

  /// The song was already downloading. Not an error — callers should stay quiet
  /// rather than reporting a failure.
  final bool alreadyRunning;

  const DownloadResult._(
    this.success,
    this.message, {
    this.alreadyRunning = false,
  });

  const DownloadResult.success(String message) : this._(true, message);
  const DownloadResult.failure(String message) : this._(false, message);

  static const DownloadResult inProgress = DownloadResult._(
    false,
    'Download already in progress',
    alreadyRunning: true,
  );
}

/// A remote stream chosen for download, plus everything needed to name the
/// file and report progress when the server omits `Content-Length`.
class _ResolvedStream {
  final String url;
  final Codec codec;
  final int sizeBytes;
  final int bitrate;
  final String source;

  const _ResolvedStream({
    required this.url,
    required this.codec,
    required this.source,
    this.sizeBytes = 0,
    this.bitrate = 0,
  });

  String get extension => DownloadFormat.extensionFor(codec);
}

/// Format and progress arithmetic for downloads.
///
/// Public and side-effect free so the container/extension mapping and the
/// missing-`Content-Length` fallback can be unit-tested directly.
class DownloadFormat {
  DownloadFormat._();

  /// Nominal size used only when neither `Content-Length`, the stream metadata
  /// nor the track duration give anything to divide by. Keeps the progress ring
  /// moving instead of pinning it at 0%.
  static const int nominalBytes = 8 * 1024 * 1024;

  /// File extension for [codec]. JioSaavn serves AAC inside an MP4 container,
  /// so those downloads must be named `.m4a`, never `.mp4` or `.opus`.
  static String extensionFor(Codec codec) => codec == Codec.mp4a ? 'm4a' : 'opus';

  /// Codec implied by an explicit codec string, falling back to the URL path.
  static Codec codecFor({required String codecHint, required String url}) {
    final hint = codecHint.toLowerCase();
    if (hint.contains('opus')) return Codec.opus;
    if (hint.contains('mp4') || hint.contains('m4a') || hint.contains('aac')) {
      return Codec.mp4a;
    }
    return codecFromUrl(url);
  }

  /// Codec implied by the file extension in a URL path.
  static Codec codecFromUrl(String url, {Codec fallback = Codec.mp4a}) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.opus') || path.endsWith('.webm')) return Codec.opus;
    if (path.endsWith('.m4a') || path.endsWith('.mp4') || path.endsWith('.aac')) {
      return Codec.mp4a;
    }
    return fallback;
  }

  /// Bytes a track of [duration] is expected to occupy at [bitrate].
  static int estimatedBytes({required Duration duration, required int bitrate}) {
    if (duration <= Duration.zero) return 0;
    final bps = bitrate > 0 ? bitrate : 320000;
    return (duration.inSeconds * bps / 8).round();
  }

  /// Percentage to publish for [received] bytes.
  ///
  /// When the server sends no `Content-Length` ([total] <= 0) the denominator is
  /// an estimate, so the result is held in 1–99: it must never sit at 0% (the
  /// old behaviour) nor claim 100% before the transfer finishes.
  static int progressPercent({
    required int received,
    required int total,
    required int fallbackTotal,
  }) {
    final known = total > 0;
    final expected = known ? total : (fallbackTotal > 0 ? fallbackTotal : nominalBytes);
    if (expected <= 0) return 0;
    final percentage = ((received / expected) * 100).round();
    return known ? percentage.clamp(0, 100) : percentage.clamp(1, 99);
  }
}
class DownloaderService extends getx.GetxService {
  /// Media CDNs (JioSaavn, googlevideo) reject requests without a browser-ish
  /// User-Agent with 403, and both redirect to a regional edge node, so
  /// redirects must be followed.
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      // Applies between chunks, not to the whole transfer, so a large file on a
      // slow connection is fine.
      receiveTimeout: const Duration(seconds: 45),
      followRedirects: true,
      maxRedirects: 5,
      headers: {
        'User-Agent': _userAgent,
        'Accept': '*/*',
        'Accept-Encoding': 'identity',
      },
      // 206 is expected when a CDN answers a ranged request.
      validateStatus: (status) => status != null && status >= 200 && status < 300,
    ),
  );

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
      if (path.isNotEmpty) {
        final file = File(path);
        // Require a non-empty file: a truncated download must not be reported
        // as available offline.
        if (file.existsSync() && file.lengthSync() > 0) {
          ids.add(key.toString());
        }
      }
    }
    downloadedIds
      ..clear()
      ..addAll(ids);
  }

  /// Absolute local path recorded for a download, accepting both the flat
  /// `url` field and the nested `extras.url` written by older builds.
  String _pathFromEntry(Map<String, dynamic> entry) {
    final direct = asText(entry['url']);
    if (direct.isNotEmpty) return _toFilePath(direct);
    final nested = asText(asStringMap(entry['extras'])['url']);
    if (nested.isEmpty) return '';
    return _toFilePath(nested);
  }

  String _toFilePath(String value) {
    if (!value.startsWith('file://')) return value;
    try {
      return Uri.parse(value).toFilePath();
    } catch (_) {
      return '';
    }
  }

  /// Local path recorded for [songId], or empty when not downloaded.
  String localPathFor(String songId) =>
      _pathFromEntry(asStringMap(boxGet<dynamic>('SongDownloads', songId, null)));
  // ── Stream resolution ──────────────────────────────────────────────────────
  //
  // Ordered cheapest-first. The previous implementation went straight to
  // `StreamProvider.fetch` (YouTube Explode + Piped/Invidious mirrors), ignoring
  // the direct 320kbps JioSaavn URL that search results already carry — so a
  // download did a slow round-trip and often failed even though a working link
  // was sitting in `song.extras`.

  Future<_ResolvedStream?> _resolveStream(SongModel song) async {
    // 1. A direct remote URL already attached to the song.
    final attached = _fromAttachedUrl(song);
    if (attached != null) {
      printINFO('Download: using URL attached to ${song.id}');
      return attached;
    }

    // 2. Previously cached stream URL, honouring the quality preference.
    final cached = _fromUrlCache(song.id);
    if (cached != null) {
      printINFO('Download: using SongsUrlCache entry for ${song.id}');
      return cached;
    }

    // 3. Direct 320kbps JioSaavn resolution by title/artist.
    if (song.title.isNotEmpty) {
      try {
        final url = await SaavnService.resolveAudioUrl(song.title, song.artist);
        if (url != null && url.isNotEmpty) {
          printINFO('Download: resolved direct stream for "${song.title}"');
          return _ResolvedStream(
            url: url,
            codec: DownloadFormat.codecFromUrl(url),
            bitrate: 320000,
            source: 'saavn',
          );
        }
      } catch (e) {
        printERROR('Download: SaavnService.resolveAudioUrl failed for ${song.id}', e);
      }
    }

    // 4. Full extractor chain as a last resort.
    return _fromStreamProvider(song);
  }
  _ResolvedStream? _fromAttachedUrl(SongModel song) {
    final url = asText(song.extras['url']);
    // Only remote links qualify: a `file://` value means the track is already
    // local, and an expired signed URL would 403.
    if (!_isRemoteUrl(url) || isExpired(url: url)) return null;

    final bitrate = asInt(song.extras['bitrate']);
    return _ResolvedStream(
      url: url,
      codec: DownloadFormat.codecFor(
        codecHint: asText(song.extras['codec']),
        url: url,
      ),
      bitrate: bitrate > 0 ? bitrate : 320000,
      sizeBytes: asInt(song.extras['fileSize']),
      source: 'extras',
    );
  }

  _ResolvedStream? _fromUrlCache(String songId) {
    if (songId.isEmpty) return null;
    final cached = asStringMap(boxGet<dynamic>('SongsUrlCache', songId, null));
    if (cached.isEmpty) return null;

    final data = HMStreamingData.fromJson(cached);
    if (!data.playable) return null;

    // Downloads should keep the best available copy regardless of the streaming
    // quality preference, which only exists to save mobile data while playing.
    final audio = data.highQualityAudio ?? data.lowQualityAudio;
    if (audio == null || !_isRemoteUrl(audio.url) || isExpired(url: audio.url)) {
      return null;
    }

    return _ResolvedStream(
      url: audio.url,
      codec: audio.audioCodec,
      bitrate: audio.bitrate,
      sizeBytes: audio.size,
      source: 'urlCache',
    );
  }
  Future<_ResolvedStream?> _fromStreamProvider(SongModel song) async {
    try {
      final preferOpus = boxGet<String>('AppPrefs', 'downloadFormat', 'opus') == 'opus';
      final response = await StreamProvider.fetch(
        song.id,
        // Passing these lets the fallback tiers search by name when the video id
        // cannot be resolved; they were omitted before.
        songTitle: song.title,
        artistName: song.artist,
      );
      if (!response.playable) return null;

      final Audio? audio = preferOpus
          ? (response.highestBitrateOpusAudio ?? response.highestQualityAudio)
          : (response.highestBitrateMp4aAudio ?? response.highestQualityAudio);
      if (audio == null || audio.url.isEmpty) return null;

      return _ResolvedStream(
        url: audio.url,
        codec: audio.audioCodec,
        bitrate: audio.bitrate,
        sizeBytes: audio.size,
        source: 'streamProvider',
      );
    } catch (e) {
      printERROR('Download: StreamProvider.fetch failed for ${song.id}', e);
      return null;
    }
  }

  bool _isRemoteUrl(String url) =>
      url.startsWith('http://') || url.startsWith('https://');

  /// Per-host request headers.
  ///
  /// The referer is only sent to JioSaavn edges — googlevideo rejects requests
  /// carrying an unrelated referer, so a blanket header would trade one 403 for
  /// another.
  Map<String, String> _headersFor(String url) {
    final headers = <String, String>{
      'User-Agent': _userAgent,
      'Accept': '*/*',
      // Avoid transfer encoding so Content-Length stays accurate for progress.
      'Accept-Encoding': 'identity',
    };
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    if (host.contains('saavn')) {
      headers['Referer'] = 'https://www.jiosaavn.com/';
      headers['Origin'] = 'https://www.jiosaavn.com';
    }
    return headers;
  }

  // ── Download ───────────────────────────────────────────────────────────────

  Future<DownloadResult> downloadSong(SongModel song) async {
    if (song.id.isEmpty) {
      return const DownloadResult.failure('This track cannot be downloaded');
    }
    if (activeDownloads.contains(song.id)) return DownloadResult.inProgress;

    // Already on disk and valid — report success rather than re-downloading.
    final existingPath = localPathFor(song.id);
    if (existingPath.isNotEmpty) {
      final existing = File(existingPath);
      if (existing.existsSync() && existing.lengthSync() > 0) {
        downloadedIds.add(song.id);
        return const DownloadResult.success('Already available offline');
      }
    }

    String? partialPath;
    try {
      activeDownloads.add(song.id);
      // Seed at 1% so the UI shows a determinate ring immediately.
      _setProgress(song.id, 1);

      final stream = await _resolveStream(song);
      if (stream == null) {
        return const DownloadResult.failure(
          'Could not find a downloadable audio stream',
        );
      }
      printINFO(
        'Download: ${song.id} via ${stream.source} '
        '(${stream.extension}, ${stream.bitrate}bps, ${stream.sizeBytes}B)',
      );

      final downloadsDir = await StoragePaths.downloadsDir();
      final safeTitle = cleanFilename("${song.title} - ${song.artist}");
      // Sanitising can leave an empty string; fall back to the id so the file
      // never lands on a bare ".m4a" name.
      final baseName = safeTitle.isNotEmpty ? safeTitle : song.id;
      // Extension follows the *resolved* codec, not the user's format
      // preference — a JioSaavn link is always AAC even when Opus is preferred,
      // and mislabelling it broke playback of the downloaded file.
      final filePath = '${downloadsDir.path}/$baseName.${stream.extension}';
      partialPath = filePath;

      // Best guess at the total, used when the CDN omits Content-Length.
      final fallbackTotal = stream.sizeBytes > 0
          ? stream.sizeBytes
          : DownloadFormat.estimatedBytes(
              duration: song.duration,
              bitrate: stream.bitrate,
            );

      await _dio.download(
        stream.url,
        filePath,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
          responseType: ResponseType.stream,
          headers: _headersFor(stream.url),
        ),
        onReceiveProgress: (count, total) {
          _setProgress(
            song.id,
            DownloadFormat.progressPercent(
              received: count,
              total: total,
              fallbackTotal: fallbackTotal,
            ),
          );
        },
      );

      // A 0-byte file means the CDN returned an error body or an empty stream.
      final written = File(filePath);
      if (!written.existsSync() || written.lengthSync() <= 0) {
        printERROR('Download produced an empty file for ${song.id}');
        return const DownloadResult.failure('The download came back empty');
      }

      _setProgress(song.id, 100);

      final updatedExtras = Map<String, dynamic>.from(song.extras);
      // Store the absolute local path; playback resolves this back to a file://
      // URI. Keep it in both places so either reader finds it.
      updatedExtras['url'] = filePath;
      updatedExtras['downloadedAt'] = DateTime.now().toIso8601String();
      updatedExtras['codec'] = stream.extension;
      updatedExtras['bitrate'] = stream.bitrate;
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

      final record = downloadedSong.toJson();
      record['url'] = filePath;
      await boxPut('SongDownloads', song.id, record);

      // Verify the write landed before advertising the track as offline.
      if (localPathFor(song.id).isEmpty) {
        printERROR('Download: SongDownloads write did not persist for ${song.id}');
        return const DownloadResult.failure('Could not save the download');
      }

      downloadedIds.add(song.id);
      partialPath = null;

      printINFO('Downloaded ${song.id} -> $filePath (${written.lengthSync()} bytes)');
      return DownloadResult.success('"${song.title}" is available offline');
    } on DioException catch (e) {
      printERROR('Download failed for ${song.id}', e);
      return DownloadResult.failure(_messageForDioError(e));
    } on FileSystemException catch (e) {
      printERROR('Download storage error for ${song.id}', e);
      return const DownloadResult.failure('Not enough storage to save this track');
    } catch (e) {
      printERROR('Download error for song: ${song.id}', e);
      return const DownloadResult.failure('Download failed. Please try again.');
    } finally {
      _cleanUpAfterDownload(song.id, partialPath);
    }
  }
  /// Publishes [percentage] only when it actually changes.
  ///
  /// `onReceiveProgress` fires per chunk; assigning on every callback pushed a
  /// reactive update (and a rebuild of every visible `SongTile`) hundreds of
  /// times per download.
  void _setProgress(String songId, int percentage) {
    if (downloadProgress[songId] == percentage) return;
    downloadProgress[songId] = percentage;
  }

  /// Always runs, on success and failure alike, so the UI can never be left
  /// showing a stuck spinner.
  void _cleanUpAfterDownload(String songId, String? partialPath) {
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
    activeDownloads.remove(songId);
    downloadProgress.remove(songId);
  }

  String _messageForDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The download timed out. Check your connection and retry.';
      case DioExceptionType.connectionError:
        return 'No internet connection';
      case DioExceptionType.cancel:
        return 'Download cancelled';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 403 || code == 401) {
          return 'The audio link expired. Play the track once, then retry.';
        }
        if (code == 404) return 'This audio stream is no longer available';
        return 'Server refused the download${code != null ? ' ($code)' : ''}';
      case DioExceptionType.badCertificate:
        return 'Could not verify the download server';
      case DioExceptionType.unknown:
      case DioExceptionType.transformTimeout:
        return 'Download failed. Please try again.';
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
