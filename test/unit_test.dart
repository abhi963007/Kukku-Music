import 'package:flutter_test/flutter_test.dart';
import 'package:kukku/models/audio.dart';
import 'package:kukku/models/song_model.dart';
import 'package:kukku/models/streaming_data.dart';
import 'package:kukku/utils/helper.dart';

void main() {
  group('Helper Utilities Tests', () {
    test('cleanFilename strips forbidden characters', () {
      const dirty = 'My Song / Track: "Remix" <Official>? * [HD] |';
      final clean = cleanFilename(dirty);
      expect(clean.contains('/'), isFalse);
      expect(clean.contains(':'), isFalse);
      expect(clean.contains('"'), isFalse);
      expect(clean.contains('<'), isFalse);
      expect(clean.contains('>'), isFalse);
      expect(clean.contains('?'), isFalse);
      expect(clean.contains('*'), isFalse);
      expect(clean.contains('['), isFalse);
      expect(clean.contains(']'), isFalse);
      expect(clean.contains('|'), isFalse);
    });

    test('formatDuration formats mm:ss properly', () {
      expect(formatDuration(const Duration(minutes: 3, seconds: 45)), "3:45");
      expect(formatDuration(const Duration(minutes: 0, seconds: 5)), "0:05");
      expect(formatDuration(null), "0:00");
    });

    test('formatBytes formats bytes into human readable units', () {
      expect(formatBytes(500), "500.0 B");
      expect(formatBytes(1024), "1.0 KB");
      expect(formatBytes(1024 * 1024 * 5), "5.0 MB");
    });

    test('isExpired detects future and past epochs correctly', () {
      final pastEpoch = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 500;
      final futureEpoch = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 10000;
      expect(isExpired(epoch: pastEpoch), isTrue);
      expect(isExpired(epoch: futureEpoch), isFalse);
    });
  });

  group('Data Models Tests', () {
    test('Audio model JSON serialization and deserialization', () {
      final audio = Audio(
        itag: 251,
        audioCodec: Codec.opus,
        bitrate: 160000,
        duration: 210000,
        loudnessDb: -1.5,
        url: 'https://rr5---sn.googlevideo.com/videoplayback?expire=1800000000',
        size: 4200000,
      );

      final json = audio.toJson();
      final restored = Audio.fromJson(json);

      expect(restored.itag, 251);
      expect(restored.audioCodec, Codec.opus);
      expect(restored.bitrate, 160000);
      expect(restored.url, audio.url);
      expect(restored.size, 4200000);
    });

    test('HMStreamingData quality selection works correctly', () {
      final lowAudio = Audio(
        itag: 249,
        audioCodec: Codec.opus,
        bitrate: 50000,
        duration: 200000,
        loudnessDb: 0.0,
        url: 'https://stream.low',
        size: 1000000,
      );

      final highAudio = Audio(
        itag: 251,
        audioCodec: Codec.opus,
        bitrate: 160000,
        duration: 200000,
        loudnessDb: 0.0,
        url: 'https://stream.high',
        size: 3500000,
      );

      final streamingData = HMStreamingData(
        playable: true,
        statusMSG: 'OK',
        lowQualityAudio: lowAudio,
        highQualityAudio: highAudio,
      );

      streamingData.setQualityIndex(0);
      expect(streamingData.activeAudio?.bitrate, 50000);

      streamingData.setQualityIndex(1);
      expect(streamingData.activeAudio?.bitrate, 160000);
    });

    test('SongModel conversions to/from MediaItem', () {
      final song = SongModel(
        id: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        album: 'Whenever You Need Somebody',
        artUri: 'https://img.youtube.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
        duration: const Duration(minutes: 3, seconds: 33),
        extras: {'views': 1500000000},
      );

      final mediaItem = song.toMediaItem();
      expect(mediaItem.id, 'dQw4w9WgXcQ');
      expect(mediaItem.title, 'Never Gonna Give You Up');

      final reconstructedSong = SongModel.fromMediaItem(mediaItem);
      expect(reconstructedSong.id, song.id);
      expect(reconstructedSong.title, song.title);
      expect(reconstructedSong.artist, song.artist);
    });
  });
}
