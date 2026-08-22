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
      final results = rawData['results'] as List? ?? [];
      final List<SongModel> songs = [];

      for (final item in results) {
        if (item is! Map) continue;
        final map = item as Map<String, dynamic>;
        final moreInfo = map['more_info'] as Map<String, dynamic>? ?? {};

        final encryptedUrl = moreInfo['encrypted_media_url']?.toString();
        final directAudioUrl = decryptMediaUrl(encryptedUrl);

        final title = _cleanString(map['title']?.toString());
        final artist = _cleanString(
          moreInfo['primary_artists']?.toString() ??
              moreInfo['singers']?.toString() ??
              map['subtitle']?.toString() ??
              'Unknown Artist',
        );
        final album = _cleanString(moreInfo['album']?.toString() ?? map['album']?.toString() ?? 'Single');
        final artUri = _cleanImage(map['image']?.toString());
        final durationSec = int.tryParse(moreInfo['duration']?.toString() ?? '0') ?? 210;

        if (title.isNotEmpty) {
          songs.add(
            SongModel(
              id: map['id']?.toString() ?? title.hashCode.toString(),
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
      final results = rawData['results'] as List? ?? [];
      final List<AlbumModel> albums = [];

      for (final item in results) {
        if (item is! Map) continue;
        final map = item as Map<String, dynamic>;
        final title = _cleanString(map['title']?.toString());
        final artist = _cleanString(
          map['more_info']?['primary_artists']?.toString() ??
              map['music']?.toString() ??
              map['subtitle']?.toString() ??
              'Soundtrack',
        );
        final artUri = _cleanImage(map['image']?.toString());
        final year = map['year']?.toString() ?? map['more_info']?.toString() ?? '';
        final language = map['language']?.toString() ?? '';
        final songCount = int.tryParse(map['more_info']?['song_pids']?.toString().split(',').length.toString() ?? '0') ?? 0;

        if (title.isNotEmpty) {
          albums.add(
            AlbumModel(
              id: map['id']?.toString() ?? title.hashCode.toString(),
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
      if (rawData is! Map) return null;
      final map = rawData as Map<String, dynamic>;

      final title = _cleanString(map['title']?.toString());
      final artist = _cleanString(map['primary_artists']?.toString() ?? map['header_desc']?.toString() ?? 'Soundtrack');
      final artUri = _cleanImage(map['image']?.toString());
      final year = map['year']?.toString() ?? '';
      final language = map['language']?.toString() ?? '';

      final rawList = map['list'] as List? ?? [];
      final List<SongModel> albumSongs = [];

      for (final item in rawList) {
        if (item is! Map) continue;
        final songMap = item as Map<String, dynamic>;
        final moreInfo = songMap['more_info'] as Map<String, dynamic>? ?? {};

        final encryptedUrl = moreInfo['encrypted_media_url']?.toString();
        final directAudioUrl = decryptMediaUrl(encryptedUrl);

        final songTitle = _cleanString(songMap['title']?.toString());
        final songArtist = _cleanString(
          moreInfo['primary_artists']?.toString() ??
              moreInfo['singers']?.toString() ??
              songMap['subtitle']?.toString() ??
              artist,
        );
        final songArt = _cleanImage(songMap['image']?.toString());
        final durationSec = int.tryParse(moreInfo['duration']?.toString() ?? '0') ?? 210;

        if (songTitle.isNotEmpty) {
          albumSongs.add(
            SongModel(
              id: songMap['id']?.toString() ?? songTitle.hashCode.toString(),
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
    final query = (artist != null && artist.isNotEmpty && artist != 'Unknown')
        ? '$title $artist'
        : title;
    final results = await searchSongs(query, limit: 3);
    if (results.isNotEmpty && results.first.extras['url'] != null && results.first.extras['url'].toString().isNotEmpty) {
      return results.first.extras['url'].toString();
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
