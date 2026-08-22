import 'dart:convert';
import 'package:dart_des/dart_des.dart';
import 'package:dio/dio.dart';

import '../models/song_model.dart';
import '../utils/helper.dart';

class SaavnService {
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      },
    ),
  );

  static const String _key = '38346591';

  /// Decrypt JioSaavn DES-ECB encrypted media URL to direct 320kbps audio link
  static String? decryptMediaUrl(String? encryptedUrl) {
    if (encryptedUrl == null || encryptedUrl.isEmpty) return null;
    try {
      final desECB = DES(
        key: _key.codeUnits,
        mode: DESMode.ECB,
        paddingType: DESPaddingType.PKCS7,
      );
      final encryptedBytes = base64Decode(encryptedUrl);
      final decryptedBytes = desECB.decrypt(encryptedBytes);
      final decryptedUrl = utf8.decode(decryptedBytes);
      return decryptedUrl
          .replaceAll('_96.mp4', '_320.mp4')
          .replaceAll('_160.mp4', '_320.mp4');
    } catch (e) {
      printERROR("Failed to decrypt media URL", e);
      return null;
    }
  }

  /// Clean title and image URLs
  static String _cleanString(String? str) {
    if (str == null || str.isEmpty) return '';
    return str
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&copy;', '')
        .trim();
  }

  /// First non-empty scalar in [candidates], or [fallback].
  ///
  /// Written as an explicit loop because `??` chains on `?.toString()` never
  /// short-circuit on the empty string, and would happily stringify a nested
  /// map (which is how "Release Year" used to render a whole JSON object).
  static String _firstNonEmpty(List<dynamic> candidates, String fallback) {
    for (final candidate in candidates) {
      if (candidate == null || candidate is Map || candidate is List) continue;
      final text = asText(candidate);
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  /// Track length in seconds, defaulting to 3:30 when the API omits it.
  static int _durationSeconds(dynamic raw) {
    final parsed = asInt(raw, 0);
    return parsed > 0 ? parsed : 210;
  }

  static String _cleanImage(String? url) {
    if (url == null || url.isEmpty) return '';
    return url.replaceAll('150x150', '500x500').replaceAll('50x50', '500x500');
  }

  /// Search songs with direct 320kbps streams (supports high limits and pagination)
  static Future<List<SongModel>> searchSongs(
    String query, {
    int limit = 30,
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final res = await _dio.get(
        'https://www.jiosaavn.com/api.php',
        queryParameters: {
          '__call': 'search.getResults',
          '_format': 'json',
          '_marker': '0',
          'api_version': '4',
          'ctx': 'web6dot0',
          'q': query,
          'n': limit,
          'p': page,
        },
      );

      final dynamic rawData = res.data is String ? jsonDecode(res.data) : res.data;
      final results = asStringMap(rawData)['results'] as List? ?? const [];
      final List<SongModel> songs = [];

      for (final item in results) {
        final map = asStringMap(item);
        if (map.isEmpty) continue;
        final moreInfo = asStringMap(map['more_info']);

        final encryptedUrl = asText(moreInfo['encrypted_media_url']);
        final directAudioUrl = decryptMediaUrl(encryptedUrl);

        final title = _cleanString(asText(map['title']));
        final artist = _cleanString(
          _firstNonEmpty([
            moreInfo['primary_artists'],
            moreInfo['singers'],
            map['subtitle'],
          ], 'Unknown Artist'),
        );
        final album = _cleanString(
          _firstNonEmpty([moreInfo['album'], map['album']], 'Single'),
        );
        final artUri = _cleanImage(asText(map['image']));
        final durationSec = _durationSeconds(moreInfo['duration']);

        if (title.isNotEmpty) {
          songs.add(
            SongModel(
              id: asText(map['id']).isNotEmpty ? asText(map['id']) : title.hashCode.toString(),
              title: title,
              artist: artist,
              album: album,
              artUri: artUri,
              duration: Duration(seconds: durationSec),
              extras: {
                'url': directAudioUrl ?? '',
                'bitrate': 320000,
                'codec': 'MP4A',
              },
            ),
          );
        }
      }

      printINFO("SaavnService search found ${songs.length} tracks for '$query'");
      return songs;
    } catch (e) {
      printERROR("SaavnService search error for '$query'", e);
      return [];
    }
  }

  /// Search albums for soundtracks and film hits
  static Future<List<AlbumModel>> searchAlbums(
    String query, {
    int limit = 20,
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final res = await _dio.get(
        'https://www.jiosaavn.com/api.php',
        queryParameters: {
          '__call': 'search.getAlbumResults',
          '_format': 'json',
          '_marker': '0',
          'api_version': '4',
          'ctx': 'web6dot0',
          'q': query,
          'n': limit,
          'p': page,
        },
      );

      final dynamic rawData = res.data is String ? jsonDecode(res.data) : res.data;
      final results = asStringMap(rawData)['results'] as List? ?? const [];
      final List<AlbumModel> albums = [];

      for (final item in results) {
        final map = asStringMap(item);
        if (map.isEmpty) continue;
        final moreInfo = asStringMap(map['more_info']);

        final title = _cleanString(asText(map['title']));
        final artist = _cleanString(
          _firstNonEmpty([
            moreInfo['primary_artists'],
            map['music'],
            map['subtitle'],
          ], 'Soundtrack'),
        );
        final artUri = _cleanImage(asText(map['image']));
        // `more_info` is a map; the old fallback stringified the whole thing and
        // rendered "{song_pids: ..., ...}" as the release year.
        final year = _firstNonEmpty([map['year'], moreInfo['year']], '');
        final language = asText(map['language']);
        final pids = asText(moreInfo['song_pids']);
        final songCount = pids.isEmpty ? 0 : pids.split(',').where((e) => e.trim().isNotEmpty).length;

        if (title.isNotEmpty) {
          albums.add(
            AlbumModel(
              id: asText(map['id']).isNotEmpty ? asText(map['id']) : title.hashCode.toString(),
              title: title,
              artist: artist,
              artUri: artUri,
              year: year,
              language: language,
              songCount: songCount,
            ),
          );
        }
      }

      printINFO("SaavnService found ${albums.length} albums for '$query'");
      return albums;
    } catch (e) {
      printERROR("SaavnService searchAlbums error for '$query'", e);
      return [];
    }
  }

  /// Fetch full album details and its tracklist with direct 320kbps streams
  static Future<AlbumModel?> getAlbumDetails(String albumId) async {
    if (albumId.isEmpty) return null;

    try {
      final res = await _dio.get(
        'https://www.jiosaavn.com/api.php',
        queryParameters: {
          '__call': 'content.getAlbumDetails',
          '_format': 'json',
          '_marker': '0',
          'api_version': '4',
          'ctx': 'web6dot0',
          'albumid': albumId,
        },
      );

      final dynamic rawData = res.data is String ? jsonDecode(res.data) : res.data;
      final map = asStringMap(rawData);
      if (map.isEmpty) return null;

      final title = _cleanString(asText(map['title']));
      final artist = _cleanString(
        _firstNonEmpty([map['primary_artists'], map['header_desc']], 'Soundtrack'),
      );
      final artUri = _cleanImage(asText(map['image']));
      final year = asText(map['year']);
      final language = asText(map['language']);

      final rawList = map['list'] as List? ?? const [];
      final List<SongModel> albumSongs = [];

      for (final item in rawList) {
        final songMap = asStringMap(item);
        if (songMap.isEmpty) continue;
        final moreInfo = asStringMap(songMap['more_info']);

        final encryptedUrl = asText(moreInfo['encrypted_media_url']);
        final directAudioUrl = decryptMediaUrl(encryptedUrl);

        final songTitle = _cleanString(asText(songMap['title']));
        final songArtist = _cleanString(
          _firstNonEmpty([
            moreInfo['primary_artists'],
            moreInfo['singers'],
            songMap['subtitle'],
          ], artist),
        );
        final songArt = _cleanImage(asText(songMap['image']));
        final durationSec = _durationSeconds(moreInfo['duration']);

        if (songTitle.isNotEmpty) {
          albumSongs.add(
            SongModel(
              id: asText(songMap['id']).isNotEmpty
                  ? asText(songMap['id'])
                  : songTitle.hashCode.toString(),
              title: songTitle,
              artist: songArtist,
              album: title,
              artUri: songArt.isNotEmpty ? songArt : artUri,
              duration: Duration(seconds: durationSec),
              extras: {
                'url': directAudioUrl ?? '',
                'bitrate': 320000,
                'codec': 'MP4A',
              },
            ),
          );
        }
      }

      return AlbumModel(
        id: albumId,
        title: title,
        artist: artist,
        artUri: artUri,
        year: year,
        language: language,
        songCount: albumSongs.length,
        songs: albumSongs,
      );
    } catch (e) {
      printERROR("SaavnService getAlbumDetails error for $albumId", e);
      return null;
    }
  }

  /// Get endless related song recommendations for auto-playing continuous music
  static Future<List<SongModel>> getRelatedSongs(
    String title,
    String artist, [
    String album = '',
  ]) async {
    final cleanArtist = (artist.isNotEmpty && artist != 'Unknown' && artist != 'Unknown Artist')
        ? artist.split(',')[0].split('&')[0].trim()
        : '';

    final queries = <String>[];
    if (cleanArtist.isNotEmpty) {
      queries.add('$cleanArtist top hits');
      queries.add('$cleanArtist latest songs');
    }
    if (album.isNotEmpty && album != 'Single' && album != 'Search') {
      queries.add(album);
    }
    queries.add('$title similar songs');

    for (final q in queries) {
      final results = await searchSongs(q, limit: 15);
      if (results.isNotEmpty) {
        return results;
      }
    }
    return [];
  }

  /// Resolve direct 320kbps audio URL by song title & artist
  static Future<String?> resolveAudioUrl(String title, [String? artist]) async {
    if (title.trim().isEmpty) return null;
    final query = (artist != null && artist.isNotEmpty && artist != 'Unknown')
        ? '$title $artist'
        : title;
    final results = await searchSongs(query, limit: 3);
    for (final result in results) {
      final url = asText(result.extras['url']);
      if (url.isNotEmpty) return url;
    }
    return null;
  }

  /// Get top trending songs for a specific language without strict limits
  static Future<List<SongModel>> getTopSongsForLanguage(String language, {int limit = 30}) async {
    final query = _getLanguageQuery(language);
    return await searchSongs(query, limit: limit);
  }

  static String _getLanguageQuery(String language) {
    switch (language.toLowerCase()) {
      case 'malayalam':
        return 'Latest Malayalam Hits';
      case 'tamil':
        return 'Latest Tamil Hits';
      case 'hindi':
        return 'Latest Bollywood Hits';
      case 'telugu':
        return 'Latest Telugu Hits';
      case 'punjabi':
        return 'Latest Punjabi Hits';
      case 'kannada':
        return 'Latest Kannada Hits';
      case 'english':
        return 'Top English Pop Hits';
      case 'trending':
      default:
        return 'Trending Hindi English Hits';
    }
  }
}
