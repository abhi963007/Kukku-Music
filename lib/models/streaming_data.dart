import 'audio.dart';

class HMStreamingData {
  final bool playable;
  final String statusMSG;
  final Audio? lowQualityAudio;
  final Audio? highQualityAudio;
  Audio? activeAudio;

  HMStreamingData({
    required this.playable,
    required this.statusMSG,
    this.lowQualityAudio,
    this.highQualityAudio,
    this.activeAudio,
  }) {
    activeAudio ??= highQualityAudio ?? lowQualityAudio;
  }

  void setQualityIndex(int qualityIndex) {
    if (qualityIndex == 0) {
      activeAudio = lowQualityAudio ?? highQualityAudio;
    } else {
      activeAudio = highQualityAudio ?? lowQualityAudio;
    }
  }

  /// Alias for activeAudio — matches Harmony Music API pattern
  Audio? get audio => activeAudio;

  Map<String, dynamic> toJson() => {
        "playable": playable,
        "statusMSG": statusMSG,
        "lowQualityAudio": lowQualityAudio?.toJson(),
        "highQualityAudio": highQualityAudio?.toJson(),
      };

  factory HMStreamingData.fromJson(dynamic json) {
    if (json == null) {
      return HMStreamingData(playable: false, statusMSG: "Empty data");
    }
    return HMStreamingData(
      playable: json['playable'] ?? false,
      statusMSG: json['statusMSG'] ?? '',
      lowQualityAudio: json['lowQualityAudio'] != null
          ? Audio.fromJson(json['lowQualityAudio'])
          : null,
      highQualityAudio: json['highQualityAudio'] != null
          ? Audio.fromJson(json['highQualityAudio'])
          : null,
    );
  }
}
