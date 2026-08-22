import 'package:flutter_test/flutter_test.dart';
import 'package:kukku/models/audio.dart';
import 'package:kukku/services/downloader.dart';

/// Regression tests for offline-download format selection and progress
/// reporting.
///
/// Two bugs these pin down:
///  * the file extension came from the user's *preference* rather than the
///    resolved codec, so a JioSaavn AAC stream could be saved as `.opus` and
///    then fail to play;
///  * when a CDN omitted `Content-Length`, `total` was 0 and the progress ring
///    sat at 0% for the whole download.
void main() {
  group('DownloadFormat.extensionFor', () {
    test('maps codecs to the container extension actually written', () {
      expect(DownloadFormat.extensionFor(Codec.mp4a), 'm4a');
      expect(DownloadFormat.extensionFor(Codec.opus), 'opus');
    });
  });

  group('DownloadFormat.codecFromUrl', () {
    test('treats JioSaavn _320.mp4 links as AAC/m4a, never mp4', () {
      final codec = DownloadFormat.codecFromUrl(
        'https://aac.saavncdn.com/123/abcdef_320.mp4',
      );
      expect(codec, Codec.mp4a);
      expect(DownloadFormat.extensionFor(codec), 'm4a');
    });

    test('recognises opus and webm as Opus', () {
      expect(DownloadFormat.codecFromUrl('https://cdn/a.opus'), Codec.opus);
      expect(DownloadFormat.codecFromUrl('https://cdn/a.webm'), Codec.opus);
    });

    test('recognises m4a and aac as AAC', () {
      expect(DownloadFormat.codecFromUrl('https://cdn/a.m4a'), Codec.mp4a);
      expect(DownloadFormat.codecFromUrl('https://cdn/a.aac'), Codec.mp4a);
    });

    test('ignores the query string when reading the extension', () {
      expect(
        DownloadFormat.codecFromUrl('https://cdn/a.opus?expire=1800000000&sig=x'),
        Codec.opus,
      );
    });

    test('falls back for extensionless googlevideo URLs', () {
      const url = 'https://rr5---sn.googlevideo.com/videoplayback?itag=140';
      expect(DownloadFormat.codecFromUrl(url), Codec.mp4a);
      expect(DownloadFormat.codecFromUrl(url, fallback: Codec.opus), Codec.opus);
    });
  });
  group('DownloadFormat.codecFor', () {
    test('an explicit codec hint wins over the URL', () {
      expect(
        DownloadFormat.codecFor(codecHint: 'opus', url: 'https://cdn/a.m4a'),
        Codec.opus,
      );
      expect(
        DownloadFormat.codecFor(codecHint: 'MP4A', url: 'https://cdn/a.opus'),
        Codec.mp4a,
      );
    });

    test('an unusable hint falls through to the URL', () {
      expect(
        DownloadFormat.codecFor(codecHint: '', url: 'https://cdn/a.opus'),
        Codec.opus,
      );
      expect(
        DownloadFormat.codecFor(codecHint: 'unknown', url: 'https://cdn/a.m4a'),
        Codec.mp4a,
      );
    });

    test('handles the codec strings the app actually stores in extras', () {
      // Written by SaavnService and the audio handler.
      expect(DownloadFormat.codecFor(codecHint: 'MP4A', url: ''), Codec.mp4a);
      // Written by StreamProvider from youtube_explode.
      expect(
        DownloadFormat.codecFor(codecHint: 'mp4a.40.2', url: ''),
        Codec.mp4a,
      );
      expect(DownloadFormat.codecFor(codecHint: 'aac', url: ''), Codec.mp4a);
    });
  });

  group('DownloadFormat.estimatedBytes', () {
    test('estimates from duration and bitrate', () {
      // 4 minutes at 320 kbps ≈ 9.6 MB.
      final bytes = DownloadFormat.estimatedBytes(
        duration: const Duration(minutes: 4),
        bitrate: 320000,
      );
      expect(bytes, 240 * 320000 ~/ 8);
    });

    test('assumes 320 kbps when the bitrate is unknown', () {
      expect(
        DownloadFormat.estimatedBytes(duration: const Duration(seconds: 8), bitrate: 0),
        8 * 320000 ~/ 8,
      );
    });

    test('returns 0 for an unknown duration', () {
      expect(
        DownloadFormat.estimatedBytes(duration: Duration.zero, bitrate: 320000),
        0,
      );
    });
  });
  group('DownloadFormat.progressPercent', () {
    test('uses Content-Length when the server provides it', () {
      expect(
        DownloadFormat.progressPercent(received: 500, total: 1000, fallbackTotal: 0),
        50,
      );
      expect(
        DownloadFormat.progressPercent(received: 1000, total: 1000, fallbackTotal: 0),
        100,
      );
    });

    test('never reports 0% once bytes are arriving without Content-Length', () {
      // The old code divided by `total` and published 0 for the whole download.
      final early = DownloadFormat.progressPercent(
        received: 1024,
        total: 0,
        fallbackTotal: 10 * 1024 * 1024,
      );
      expect(early, greaterThanOrEqualTo(1));

      final midway = DownloadFormat.progressPercent(
        received: 5 * 1024 * 1024,
        total: 0,
        fallbackTotal: 10 * 1024 * 1024,
      );
      expect(midway, 50);
    });

    test('holds below 100% while the total is only an estimate', () {
      // A real file larger than the estimate must not claim completion early.
      expect(
        DownloadFormat.progressPercent(
          received: 20 * 1024 * 1024,
          total: 0,
          fallbackTotal: 10 * 1024 * 1024,
        ),
        99,
      );
    });

    test('falls back to a nominal size when nothing else is known', () {
      final percent = DownloadFormat.progressPercent(
        received: DownloadFormat.nominalBytes ~/ 4,
        total: 0,
        fallbackTotal: 0,
      );
      expect(percent, 25);
    });

    test('progress is monotonic as bytes accumulate', () {
      var previous = 0;
      for (var received = 0; received <= 8 * 1024 * 1024; received += 512 * 1024) {
        final percent = DownloadFormat.progressPercent(
          received: received,
          total: 0,
          fallbackTotal: 8 * 1024 * 1024,
        );
        expect(percent, greaterThanOrEqualTo(previous));
        expect(percent, inInclusiveRange(1, 99));
        previous = percent;
      }
    });
  });
}
