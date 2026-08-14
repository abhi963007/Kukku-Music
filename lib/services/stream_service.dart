import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/audio.dart';
import '../utils/helper.dart';

class StreamProvider {
  final bool playable;
  final List<Audio>? audioFormats;
  final String statusMSG;

  StreamProvider({
    required this.playable,
    this.audioFormats,
    this.statusMSG = "",
  });

  static Future<StreamProvider> fetch(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly.toList();

      if (audioStreams.isEmpty) {
        return StreamProvider(
          playable: false,
          statusMSG: "No audio streams found for video",
        );
      }

      final List<Audio> formats = audioStreams.map((e) {
        final isMp4 = e.audioCodec.toLowerCase().contains('mp') ||
            e.container.name.toLowerCase().contains('mp4') ||
            e.container.name.toLowerCase().contains('m4a');

        return Audio(
          itag: e.tag,
          audioCodec: isMp4 ? Codec.mp4a : Codec.opus,
          bitrate: e.bitrate.bitsPerSecond,
          duration: (e.size.totalBytes / (e.bitrate.bitsPerSecond / 8) * 1000).toInt(),
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
    } catch (e) {
      printERROR("StreamProvider fetch error for $videoId", e);
      if (e is SocketException) {
        return StreamProvider(playable: false, statusMSG: "networkError");
      } else if (e is VideoUnplayableException) {
        return StreamProvider(
          playable: false,
          statusMSG: e.message.isNotEmpty ? e.message : "Song is unplayable",
        );
      } else {
        return StreamProvider(
          playable: false,
          statusMSG: "Failed to extract stream: ${e.toString()}",
        );
      }
    } finally {
      yt.close();
    }
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
