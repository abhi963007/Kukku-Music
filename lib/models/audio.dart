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
    if (json == null) {
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
    
    final codecStr = json["audioCodec"]?.toString() ?? "";
    final codec = codecStr.contains("mp4a") || codecStr.contains("mp") ? Codec.mp4a : Codec.opus;
    
    return Audio(
      itag: json['itag'] ?? 0,
      audioCodec: codec,
      duration: json["approxDurationMs"] ?? 0,
      bitrate: json["bitrate"] ?? 0,
      loudnessDb: (json['loudnessDb'] is num) ? (json['loudnessDb'] as num).toDouble() : 0.0,
      url: json['url'] ?? '',
      size: json["size"] ?? 0,
    );
  }
}
