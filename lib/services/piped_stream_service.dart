import 'dart:convert';
import 'package:dio/dio.dart';

import '../models/audio.dart';
import '../utils/helper.dart';

/// Fetches audio stream URLs via Piped API, Invidious API, and JioSaavn fallback
class PipedStreamService {
  static const List<String> pipedInstances = [
    'https://api.piped.projectsegfau.lt',
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.drgns.space',
    'https://pipedapi.rivo.cc',
    'https://pa.il.ax',
    'https://piped-api.lunar.icu',
    'https://api.piped.privacydev.net',
    'https://pipedapi.leptons.xyz',
  ];

  static const List<String> invidiousInstances = [
    'https://inv.nadeko.net',
    'https://invidious.nerdvpn.de',
    'https://yewtu.be',
    'https://invidious.jing.rocks',
    'https://iv.ggtyler.dev',
    'https://invidious.drgns.space',
    'https://invidious.projectsegfau.lt',
  ];

  static const List<String> saavnApiInstances = [
    'https://saavn.sumit.co/api',
    'https://saavn.dev/api',
    'https://saavn.me',
    'https://jiosaavn-api-privateindexer.vercel.app',
  ];

  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  /// Fetches audio stream URL with multi-tiered failover:
  /// 1. JioSaavn high-quality CDN (instant 320kbps direct audio)
  /// 2. Piped API instances
  /// 3. Invidious API instances
  static Future<PipedStreamResult> fetchAudioUrl(
    String videoId, {
    String? title,
    String? artist,
  }) async {
    // ── Tier 1: JioSaavn high-quality direct CDN stream (Fastest & 320kbps) ──
    if (title != null && title.trim().isNotEmpty) {
      final query = (artist != null && artist.isNotEmpty && artist != 'Unknown')
          ? '$title $artist'
          : title;

      printINFO('Trying JioSaavn direct CDN search for: $query');
      for (final sApi in saavnApiInstances) {
        try {
          final res = await _dio.get(
            '$sApi/search/songs',
            queryParameters: {'query': query},
          );

          if (res.statusCode == 200 && res.data != null) {
            dynamic rawData = res.data;
            if (rawData is String) {
              try {
                rawData = jsonDecode(rawData);
              } catch (_) {}
            }

            if (rawData is! Map) continue;
            final data = rawData as Map<String, dynamic>;
            final results = data['data']?['results'] as List? ?? data['results'] as List? ?? [];

            if (results.isNotEmpty) {
              final song = results[0] as Map<String, dynamic>;
              final downloadUrls = song['downloadUrl'] as List? ?? [];

              String? streamUrl;
              int bitrate = 320000;

              // Find best 320kbps or 160kbps link
              for (final d in downloadUrls) {
                if (d is! Map) continue;
                final quality = (d['quality'] ?? '').toString();
                final link = d['url']?.toString() ?? d['link']?.toString() ?? '';
                if (quality == '320kbps' && link.isNotEmpty) {
                  streamUrl = link;
                  bitrate = 320000;
                  break;
                } else if (quality == '160kbps' && link.isNotEmpty && streamUrl == null) {
                  streamUrl = link;
                  bitrate = 160000;
                } else if (streamUrl == null && link.isNotEmpty) {
                  streamUrl = link;
                }
              }

              if (streamUrl != null && streamUrl.isNotEmpty) {
                final durationSec = int.tryParse(song['duration']?.toString() ?? '0') ?? 240;
                printINFO('JioSaavn CDN stream resolved: bitrate=$bitrate url=$streamUrl');

                return PipedStreamResult(
                  playable: true,
                  url: streamUrl,
                  audio: Audio(
                    itag: 140,
                    audioCodec: Codec.mp4a,
                    bitrate: bitrate,
                    duration: durationSec * 1000,
                    loudnessDb: 0.0,
                    url: streamUrl,
                    size: 0,
                  ),
                );
              }
            }
          }
        } catch (e) {
          printERROR('JioSaavn API $sApi failed for $query', e);
          continue;
        }
      }
    }

    // ── Tier 2: Piped API instances ──────────────────────────────────────────
    for (final instance in pipedInstances) {
      try {
        printINFO('Trying Piped instance: $instance for $videoId');
        final response = await _dio.get('$instance/streams/$videoId');

        if (response.statusCode == 200 && response.data != null) {
          dynamic rawData = response.data;
          if (rawData is String) {
            try {
              rawData = jsonDecode(rawData);
            } catch (_) {}
          }

          if (rawData is! Map) continue;
          final data = rawData as Map<String, dynamic>;
          final audioStreams = data['audioStreams'] as List? ?? [];

          if (audioStreams.isEmpty) continue;

          // Find best MP4a stream (itag 140 = 128kbps AAC, most compatible)
          Map<String, dynamic>? best;
          Map<String, dynamic>? mp4a;
          Map<String, dynamic>? fallback;

          for (final stream in audioStreams) {
            if (stream is! Map) continue;
            final mapStream = stream as Map<String, dynamic>;
            final itag = mapStream['itag'] ?? 0;
            final codec = (mapStream['codec'] ?? '').toString().toLowerCase();
            final isMp4 = codec.contains('mp4a') || codec.contains('aac');

            if (itag == 140) {
              best = mapStream;
              break;
            } else if (isMp4 && mp4a == null) {
              mp4a = mapStream;
            } else {
              fallback ??= mapStream;
            }
          }

          final selected = best ?? mp4a ?? fallback;
          if (selected == null) continue;

          final url = selected['url'] as String? ?? '';
          if (url.isEmpty) continue;

          final bitrate = selected['bitrate'] as int? ?? 128000;
          final codec = (selected['codec'] ?? '').toString();
          final isMp4 = codec.toLowerCase().contains('mp4a') ||
              codec.toLowerCase().contains('aac');
          final duration = selected['duration'] as int? ?? 0;

          printINFO('Piped stream resolved: itag=${selected['itag']} codec=$codec bitrate=$bitrate');

          return PipedStreamResult(
            playable: true,
            url: url,
            audio: Audio(
              itag: selected['itag'] as int? ?? 140,
              audioCodec: isMp4 ? Codec.mp4a : Codec.opus,
              bitrate: bitrate,
              duration: duration * 1000,
              loudnessDb: 0.0,
              url: url,
              size: selected['contentLength'] as int? ?? 0,
            ),
          );
        }
      } catch (e) {
        printERROR('Piped instance $instance failed for $videoId', e);
        continue;
      }
    }

    // ── Tier 3: Invidious API instances ──────────────────────────────────────
    for (final instance in invidiousInstances) {
      try {
        printINFO('Trying Invidious instance: $instance for $videoId');
        final response = await _dio.get('$instance/api/v1/videos/$videoId');

        if (response.statusCode == 200 && response.data != null) {
          dynamic rawData = response.data;
          if (rawData is String) {
            try {
              rawData = jsonDecode(rawData);
            } catch (_) {}
          }

          if (rawData is! Map) continue;
          final data = rawData as Map<String, dynamic>;
          final adaptiveFormats = data['adaptiveFormats'] as List? ?? [];
          final audioStreams = adaptiveFormats.where((f) {
            if (f is! Map) return false;
            final type = (f['type'] ?? '').toString();
            return type.startsWith('audio/');
          }).toList();

          if (audioStreams.isEmpty) continue;

          Map<String, dynamic>? best;
          for (final stream in audioStreams) {
            final mapStream = stream as Map<String, dynamic>;
            final itag = int.tryParse(mapStream['itag']?.toString() ?? '0') ?? 0;
            final type = (mapStream['type'] ?? '').toString().toLowerCase();
            final isMp4 = type.contains('mp4a') || type.contains('aac') || type.contains('m4a');

            if (itag == 140) {
              best = mapStream;
              break;
            } else if (isMp4 && best == null) {
              best = mapStream;
            }
          }

          final selected = best ?? (audioStreams.first as Map<String, dynamic>);
          final url = selected['url'] as String? ?? '';
          if (url.isEmpty) continue;

          final bitrate = int.tryParse(selected['bitrate']?.toString() ?? '128000') ?? 128000;
          final type = (selected['type'] ?? '').toString().toLowerCase();
          final isMp4 = type.contains('mp4a') || type.contains('aac') || type.contains('m4a');
          final lengthSeconds = int.tryParse(data['lengthSeconds']?.toString() ?? '0') ?? 0;

          printINFO('Invidious stream resolved: instance=$instance bitrate=$bitrate');

          return PipedStreamResult(
            playable: true,
            url: url,
            audio: Audio(
              itag: int.tryParse(selected['itag']?.toString() ?? '140') ?? 140,
              audioCodec: isMp4 ? Codec.mp4a : Codec.opus,
              bitrate: bitrate,
              duration: lengthSeconds * 1000,
              loudnessDb: 0.0,
              url: url,
              size: int.tryParse(selected['clen']?.toString() ?? '0') ?? 0,
            ),
          );
        }
      } catch (e) {
        printERROR('Invidious instance $instance failed for $videoId', e);
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

