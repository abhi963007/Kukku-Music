import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/audio.dart';
import '../utils/helper.dart';
import 'piped_stream_service.dart';

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;

  StreamProvider({
    required this.playable,
    this.audioFormats,
    this.statusMSG = "",
  });

  static Future<StreamProvider> fetch(
    String videoId, {
    String? songTitle,
    String? artistName,
  }) async {
    final yt = YoutubeExplode();
    try {
      StreamManifest? manifest;

      // Tier 1: Try default yt-explode manifest resolution
      try {
        manifest = await yt.videos.streamsClient.getManifest(videoId);
      } catch (e) {
        printERROR("Default yt-explode manifest failed for $videoId", e);
      }

      // Tier 2: Try specific fallback clients if default failed or empty
      if (manifest == null || manifest.audioOnly.isEmpty) {
        final fallbackClients = [
          YoutubeApiClient.androidVr,
          YoutubeApiClient.ios,
          YoutubeApiClient.tv,
          YoutubeApiClient.mweb,
          YoutubeApiClient.safari,
        ];
        for (final client in fallbackClients) {
          try {
            manifest = await yt.videos.streamsClient.getManifest(videoId, ytClients: [client]);
            if (manifest.audioOnly.isNotEmpty) break;
          } catch (_) {
            continue;
          }
        }
      }

      final audioStreams = manifest?.audioOnly.toList() ?? [];

      if (audioStreams.isNotEmpty) {
        final List<Audio> formats = audioStreams.map((e) {
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

        return StreamProvider(
          playable: true,
          statusMSG: "OK",
          audioFormats: formats,
        );
      }
    } catch (e) {
      printERROR("StreamProvider fetch error for $videoId", e);
    } finally {
      yt.close();
    }

    // Tier 3: Fallback via Piped, Invidious, and JioSaavn high-quality CDN
    try {
      final fallbackRes = await PipedStreamService.fetchAudioUrl(
        videoId,
        title: songTitle,
        artist: artistName,
      );
      if (fallbackRes.playable && fallbackRes.audio != null) {
        return StreamProvider(
          playable: true,
          statusMSG: "OK",
          audioFormats: [fallbackRes.audio!],
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
