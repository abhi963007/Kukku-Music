import '../utils/helper.dart';
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
    final map = asStringMap(json);
    if (map.isEmpty) {
      return HMStreamingData(playable: false, statusMSG: "Empty data");
    }
    return HMStreamingData(
      playable: asBool(map['playable']),
      statusMSG: asText(map['statusMSG']),
      lowQualityAudio:
          map['lowQualityAudio'] != null ? Audio.fromJson(map['lowQualityAudio']) : null,
      highQualityAudio:
          map['highQualityAudio'] != null ? Audio.fromJson(map['highQualityAudio']) : null,
    );
  }
}
