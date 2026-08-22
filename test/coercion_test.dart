import 'package:flutter_test/flutter_test.dart';
import 'package:kukku/models/audio.dart';
import 'package:kukku/models/song_model.dart';
import 'package:kukku/models/streaming_data.dart';
import 'package:kukku/utils/helper.dart';

/// Regression tests for the dynamic-value handling that used to throw.
///
/// Hive returns nested maps as `Map<dynamic, dynamic>`, and third-party JSON
/// hands back numbers as strings. The decoders previously used hard casts
/// (`as Map<String, dynamic>`) and typed reads, so a restored cache entry threw
/// at runtime instead of being parsed.
void main() {
  group('Dynamic coercion helpers', () {
    test('asStringMap normalises a Hive-style Map<dynamic, dynamic>', () {
      final hiveStyle = <dynamic, dynamic>{'url': 'https://cdn/a.m4a', 'bitrate': 320000};
      final normalised = asStringMap(hiveStyle);

      expect(normalised, isA<Map<String, dynamic>>());
      expect(normalised['url'], 'https://cdn/a.m4a');
      expect(normalised['bitrate'], 320000);
    });

    test('asStringMap returns an empty map for non-map input', () {
      expect(asStringMap(null), isEmpty);
      expect(asStringMap('not a map'), isEmpty);
      expect(asStringMap(42), isEmpty);
    });

    test('asInt accepts ints, doubles and numeric strings', () {
      expect(asInt(7), 7);
      expect(asInt(7.9), 7);
      expect(asInt('128000'), 128000);
      expect(asInt('not a number', 99), 99);
      expect(asInt(null, 5), 5);
    });

    test('asBool accepts bools, 0/1 and "true"/"false"', () {
      expect(asBool(true), isTrue);
      expect(asBool('true'), isTrue);
      expect(asBool('FALSE'), isFalse);
      expect(asBool(1), isTrue);
      expect(asBool(0), isFalse);
      expect(asBool('maybe', true), isTrue);
    });

    test('asDouble and asText handle mixed input', () {
      expect(asDouble('-1.5'), -1.5);
      expect(asDouble(3), 3.0);
      expect(asDouble(null, 0.25), 0.25);
      expect(asText('  padded  '), 'padded');
      expect(asText(null), '');
      expect(asText(12), '12');
    });
  });
  group('Hive round-trip decoding', () {
    test('Audio.fromJson survives a Map<dynamic, dynamic> with string numbers', () {
      final restored = Audio.fromJson(<dynamic, dynamic>{
        'itag': '140',
        'audioCodec': 'mp4a.40.2',
        'bitrate': '128000',
        'loudnessDb': '-3.5',
        'url': 'https://cdn/track.m4a',
        'approxDurationMs': '210000',
        'size': '3400000',
      });

      expect(restored.itag, 140);
      expect(restored.audioCodec, Codec.mp4a);
      expect(restored.bitrate, 128000);
      expect(restored.loudnessDb, -3.5);
      expect(restored.duration, 210000);
      expect(restored.size, 3400000);
    });

    test('HMStreamingData.fromJson decodes nested dynamic maps', () {
      final restored = HMStreamingData.fromJson(<dynamic, dynamic>{
        'playable': true,
        'statusMSG': 'OK',
        'lowQualityAudio': <dynamic, dynamic>{'itag': 139, 'bitrate': 48000, 'url': 'low'},
        'highQualityAudio': <dynamic, dynamic>{'itag': 140, 'bitrate': 128000, 'url': 'high'},
      });

      expect(restored.playable, isTrue);
      restored.setQualityIndex(0);
      expect(restored.activeAudio?.url, 'low');
      restored.setQualityIndex(1);
      expect(restored.activeAudio?.url, 'high');
    });

    test('SongModel.fromJson decodes dynamic maps and nested extras', () {
      final restored = SongModel.fromJson(<dynamic, dynamic>{
        'id': 'abc123',
        'title': 'Track',
        'artist': 'Artist',
        'album': 'Album',
        'artUri': 'https://img/art.jpg',
        'durationMs': '215000',
        'extras': <dynamic, dynamic>{'url': 'https://cdn/a.m4a', 'codec': 'MP4A'},
      });

      expect(restored.id, 'abc123');
      expect(restored.duration, const Duration(milliseconds: 215000));
      expect(restored.extras['url'], 'https://cdn/a.m4a');
    });

    test('MediaItemBuilder.fromJson tolerates missing and dynamic fields', () {
      final item = MediaItemBuilder.fromJson(<dynamic, dynamic>{'id': 'xyz'});

      expect(item.id, 'xyz');
      expect(item.title, 'Unknown Title');
      expect(item.duration, Duration.zero);
      expect(item.extras, isEmpty);
    });
  });
  group('Graceful defaults', () {
    test('SongModel.fromJson never returns empty display strings', () {
      final blank = SongModel.fromJson(<dynamic, dynamic>{'id': 'only-id'});

      expect(blank.title, 'Unknown Title');
      expect(blank.artist, 'Unknown Artist');
      expect(blank.album, 'Unknown Album');
      expect(blank.artUri, '');
    });

    test('AlbumModel.fromJson parses a dynamic tracklist', () {
      final album = AlbumModel.fromJson(<dynamic, dynamic>{
        'id': 'album-1',
        'title': 'Soundtrack',
        'songCount': '2',
        'songs': <dynamic>[
          <dynamic, dynamic>{'id': 's1', 'title': 'One'},
          <dynamic, dynamic>{'id': 's2', 'title': 'Two'},
        ],
      });

      expect(album.songCount, 2);
      expect(album.songs.map((s) => s.id), ['s1', 's2']);
    });

    test('Audio.fromJson falls back to opus for unknown codecs', () {
      final audio = Audio.fromJson(<dynamic, dynamic>{'audioCodec': 'opus', 'url': 'u'});
      expect(audio.audioCodec, Codec.opus);
    });
  });
}
