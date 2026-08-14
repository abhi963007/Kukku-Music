import 'dart:io';
import 'package:dio/dio.dart';

import '../models/audio.dart';
import '../utils/helper.dart';

/// Fetches audio stream URLs via Piped API (open-source YouTube proxy)
/// Piped proxies requests through their servers, so the URLs work from any IP.
/// Public instances: https://piped-instances.kavin.rocks/
class PipedStreamService {
  static const List<String> _instances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.adminforge.de',
    'https://piped-api.garudalinux.org',
    'https://pipedapi.tokhmi.xyz',
    'https://api.piped.projectsegfau.lt',
  ];

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Fetches the best audio stream URL for a given YouTube video ID via Piped
  static Future<PipedStreamResult> fetchAudioUrl(String videoId) async {
    for (final instance in _instances) {
      try {
        printINFO('Trying Piped instance: $instance for $videoId');
        final response = await _dio.get('$instance/streams/$videoId');

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data as Map<String, dynamic>;
          final audioStreams = data['audioStreams'] as List? ?? [];

          if (audioStreams.isEmpty) continue;

          // Find best MP4a stream (itag 140 = 128kbps AAC, most compatible)
          Map<String, dynamic>? best;
          Map<String, dynamic>? mp4a;
          Map<String, dynamic>? fallback;

          for (final stream in audioStreams) {
            final itag = stream['itag'] ?? 0;
            final codec = (stream['codec'] ?? '').toString().toLowerCase();
            final isMp4 = codec.contains('mp4a') || codec.contains('aac');

            if (itag == 140) {
              best = stream as Map<String, dynamic>;
              break;
            } else if (isMp4 && mp4a == null) {
              mp4a = stream as Map<String, dynamic>;
            } else {
              fallback ??= stream as Map<String, dynamic>;
            }
          }

          final selected = best ?? mp4a ?? fallback;
          if (selected == null) continue;

          final url = selected['url'] as String? ?? '';
          if (url.isEmpty) continue;

          final bitrate = selected['bitrate'] as int? ?? 0;
          final codec = (selected['codec'] ?? '').toString();
          final isMp4 = codec.toLowerCase().contains('mp4a') || 
                        codec.toLowerCase().contains('aac');
          final duration = selected['duration'] as int? ?? 0;

          printINFO('Piped stream resolved: itag=${selected['itag']} codec=$codec bitrate=$bitrate');

          return PipedStreamResult(
            playable: true,
            url: url,
            audio: Audio(
              itag: selected['itag'] as int? ?? 0,
              audioCodec: isMp4 ? Codec.mp4a : Codec.opus,
              bitrate: bitrate,
              duration: duration * 1000, // convert to ms
              loudnessDb: 0.0,
              url: url,
              size: selected['contentLength'] as int? ?? 0,
            ),
          );
        }
      } on SocketException catch (e) {
        printERROR('Piped instance $instance - network error: $e');
        continue;
      } on DioException catch (e) {
        printERROR('Piped instance $instance - DioError: ${e.message}');
        continue;
      } catch (e) {
        printERROR('Piped instance $instance - error: $e');
        continue;
      }
    }

    return PipedStreamResult(playable: false, url: '', audio: null);
  }
}

class PipedStreamResult {
  final bool playable;
  final String url;
  final Audio? audio;

  PipedStreamResult({
    required this.playable,
    required this.url,
    required this.audio,
  });
}
