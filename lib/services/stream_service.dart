import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/audio.dart';
import '../utils/helper.dart';
import 'piped_stream_service.dart';

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;

  /// The YouTube video id the streams were actually taken from.
  ///
  /// Differs from the requested id when the track came from JioSaavn or a radio
  /// recommendation and had to be located by search. Callers can cache this to
  /// skip the search next time.
  final String? resolvedVideoId;

  StreamProvider({
    required this.playable,
    this.audioFormats,
    this.statusMSG = "",
    this.resolvedVideoId,
  });

  /// A YouTube video id is exactly 11 characters of `[A-Za-z0-9_-]`.
  ///
  /// JioSaavn ids (`OqrgPNQd`), album ids and generated hash ids all fail this,
  /// and calling `getManifest` with one wasted six network round-trips before
  /// failing — which is what left recommended tracks unplayable.
  static final RegExp _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

  static bool isValidVideoId(String? id) =>
      id != null && _videoIdPattern.hasMatch(id);

  /// Search results longer than this are almost always mixes or full albums
  /// rather than the requested track.
  static const Duration _maxSearchResultDuration = Duration(minutes: 12);
  static const Duration _minSearchResultDuration = Duration(seconds: 30);
  static Future<StreamProvider> fetch(
    String videoId, {
    String? songTitle,
    String? artistName,
  }) async {
    final yt = YoutubeExplode();
    String? resolvedId;

    try {
      StreamManifest? manifest;

      // ── Tier 1: the id we were given, if it can even be a YouTube id ───────
      if (isValidVideoId(videoId)) {
        resolvedId = videoId;
        manifest = await _manifestFor(yt, videoId);
      } else {
        printINFO('"$videoId" is not a YouTube video id — searching by title');
      }

      // ── Tier 2: locate the track by name ──────────────────────────────────
      // Covers JioSaavn results, radio recommendations and any other external
      // catalogue whose ids mean nothing to YouTube.
      if (manifest == null || manifest.audioOnly.isEmpty) {
        final searchedId = await _searchForVideoId(yt, songTitle, artistName);
        if (searchedId != null && searchedId != videoId) {
          resolvedId = searchedId;
          manifest = await _manifestFor(yt, searchedId);
        }
      }

      final formats = _audioFormatsFrom(manifest);
      if (formats.isNotEmpty) {
        printINFO('YoutubeExplode resolved ${formats.length} streams for $resolvedId');
        return StreamProvider(
          playable: true,
          statusMSG: "OK",
          audioFormats: formats,
          resolvedVideoId: resolvedId,
        );
      }
    } catch (e) {
      printERROR("StreamProvider fetch error for $videoId", e);
    } finally {
      yt.close();
    }

    // ── Tier 3: Piped / Invidious / JioSaavn mirrors ────────────────────────
    // Uses the resolved id when the search found one; the mirrors cannot do
    // anything with a non-YouTube id either.
    try {
      final fallbackRes = await PipedStreamService.fetchAudioUrl(
        resolvedId ?? videoId,
        title: songTitle,
        artist: artistName,
      );
      if (fallbackRes.playable && fallbackRes.audio != null) {
        printINFO("Fallback stream resolved for ${resolvedId ?? videoId}");
        return StreamProvider(
          playable: true,
          statusMSG: "OK",
          audioFormats: [fallbackRes.audio!],
          resolvedVideoId: resolvedId,
        );
      }
    } catch (e) {
      printERROR("Fallback stream error for $videoId", e);
    }

    return StreamProvider(
      playable: false,
      statusMSG: "Unable to retrieve audio stream",
    );
  }
  /// Fetches a manifest for [videoId], retrying across client impersonations.
  ///
  /// Returns `null` rather than throwing so callers can fall through to search.
  static Future<StreamManifest?> _manifestFor(YoutubeExplode yt, String videoId) async {
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      if (manifest.audioOnly.isNotEmpty) return manifest;
    } catch (e) {
      printERROR("Default yt-explode manifest failed for $videoId", e);
    }

    // Not const: YoutubeApiClient instances are runtime values.
    final fallbackClients = <YoutubeApiClient>[
      YoutubeApiClient.androidVr,
      YoutubeApiClient.ios,
      YoutubeApiClient.tv,
      YoutubeApiClient.mweb,
      YoutubeApiClient.safari,
    ];
    for (final client in fallbackClients) {
      try {
        final manifest = await yt.videos.streamsClient
            .getManifest(videoId, ytClients: [client]);
        if (manifest.audioOnly.isNotEmpty) return manifest;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// Finds the most plausible YouTube video id for a track title/artist.
  static Future<String?> _searchForVideoId(
    YoutubeExplode yt,
    String? songTitle,
    String? artistName,
  ) async {
    final query = _searchQuery(songTitle, artistName);
    if (query == null) return null;

    try {
      printINFO('Searching YouTube for "$query"');
      final results = await yt.search.search(query);
      if (results.isEmpty) return null;

      // Prefer a result that looks like a single track; fall back to the first.
      for (final video in results.take(5)) {
        if (video.isLive) continue;
        final duration = video.duration;
        if (duration == null) continue;
        if (duration < _minSearchResultDuration) continue;
        if (duration > _maxSearchResultDuration) continue;
        printINFO('Search matched "${video.title}" (${video.id.value})');
        return video.id.value;
      }

      final first = results.first;
      printINFO('Search falling back to "${first.title}" (${first.id.value})');
      return first.id.value;
    } catch (e) {
      printERROR('YouTube search failed for "$query"', e);
      return null;
    }
  }

  /// Builds a search query, dropping placeholder artist values.
  static String? _searchQuery(String? songTitle, String? artistName) {
    final title = (songTitle ?? '').trim();
    if (title.isEmpty) return null;

    final artist = (artistName ?? '').trim();
    const placeholders = {'unknown', 'unknown artist', 'various artists', ''};
    if (placeholders.contains(artist.toLowerCase())) return title;

    // Only the primary artist: comma-separated lists rarely match anything.
    final primary = artist.split(',').first.split('&').first.trim();
    return primary.isEmpty ? title : '$title $primary';
  }
  static List<Audio> _audioFormatsFrom(StreamManifest? manifest) {
    final audioStreams = manifest?.audioOnly.toList() ?? const [];
    if (audioStreams.isEmpty) return const [];

    return audioStreams.map((e) {
      final isMp4 = e.audioCodec.toLowerCase().contains('mp') ||
          e.container.name.toLowerCase().contains('mp4') ||
          e.container.name.toLowerCase().contains('m4a');

      final durationMs = (e.size.totalBytes > 0 && e.bitrate.bitsPerSecond > 0)
          ? (e.size.totalBytes / (e.bitrate.bitsPerSecond / 8) * 1000).toInt()
          : 0;

      return Audio(
        itag: e.tag,
        audioCodec: isMp4 ? Codec.mp4a : Codec.opus,
        bitrate: e.bitrate.bitsPerSecond,
        duration: durationMs,
        loudnessDb: 0.0,
        url: e.url.toString(),
        size: e.size.totalBytes,
      );
    }).toList();
  }
  Audio? get highestQualityAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    // Prefer MP4a (itag 140 = 128kbps AAC in M4A container)
    // MP4a is universally supported by Android MediaCodec without WebM container issues
    return audioFormats!.lastWhere(
      (item) => item.itag == 140,
      orElse: () => audioFormats!.lastWhere(
        (item) => item.itag == 251,
        orElse: () => audioFormats!.lastWhere(
          (item) => item.audioCodec == Codec.mp4a,
          orElse: () => audioFormats!.reduce(
              (curr, next) => curr.bitrate > next.bitrate ? curr : next),
        ),
      ),
    );
  }

  Audio? get lowQualityAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    return audioFormats!.lastWhere(
      (item) => item.itag == 139,
      orElse: () => audioFormats!.lastWhere(
        (item) => item.itag == 249,
        orElse: () => audioFormats!.reduce(
            (curr, next) => curr.bitrate < next.bitrate ? curr : next),
      ),
    );
  }

  Audio? get highestBitrateOpusAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    final opusList = audioFormats!.where((e) => e.audioCodec == Codec.opus).toList();
    if (opusList.isNotEmpty) {
      return opusList.reduce((curr, next) => curr.bitrate > next.bitrate ? curr : next);
    }
    return highestQualityAudio;
  }

  Audio? get highestBitrateMp4aAudio {
    if (audioFormats == null || audioFormats!.isEmpty) return null;
    final mp4List = audioFormats!.where((e) => e.audioCodec == Codec.mp4a).toList();
    if (mp4List.isNotEmpty) {
      return mp4List.reduce((curr, next) => curr.bitrate > next.bitrate ? curr : next);
    }
    return highestQualityAudio;
  }

  Map<String, dynamic> get hmStreamingData {
    return {
      "playable": playable,
      "statusMSG": statusMSG,
      "lowQualityAudio": lowQualityAudio?.toJson(),
      "highQualityAudio": highestQualityAudio?.toJson(),
    };
  }
}
