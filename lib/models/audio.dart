import '../utils/helper.dart';

enum Codec { mp4a, opus }

class Audio {
  final int itag;
  final Codec audioCodec;
  final int bitrate;
  final int duration;
  final int size;
  final double loudnessDb;
  final String url;

  Audio({
    required this.itag,
    required this.audioCodec,
    required this.bitrate,
    required this.duration,
    required this.loudnessDb,
    required this.url,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
        "itag": itag,
        "audioCodec": audioCodec.name,
        "bitrate": bitrate,
        "loudnessDb": loudnessDb,
        "url": url,
        "approxDurationMs": duration,
        "size": size,
      };

  factory Audio.fromJson(dynamic json) {
    final map = asStringMap(json);
    if (map.isEmpty) {
      return Audio(
        itag: 0,
        audioCodec: Codec.mp4a,
        bitrate: 0,
        duration: 0,
        loudnessDb: 0.0,
        url: '',
        size: 0,
      );
    }

    final codecStr = asText(map["audioCodec"]).toLowerCase();
    final codec = codecStr.contains("mp4a") || codecStr.contains("mp") ? Codec.mp4a : Codec.opus;

    return Audio(
      itag: asInt(map['itag']),
      audioCodec: codec,
      duration: asInt(map["approxDurationMs"]),
      bitrate: asInt(map["bitrate"]),
      loudnessDb: asDouble(map['loudnessDb']),
      url: asText(map['url']),
      size: asInt(map["size"]),
    );
  }
}
