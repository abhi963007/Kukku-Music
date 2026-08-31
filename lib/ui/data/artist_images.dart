import 'dart:convert';
import 'package:dio/dio.dart';

import '../../utils/helper.dart';

/// 100% Dynamic Artist Avatar Resolution Service.
/// Automatically queries the JioSaavn web music catalog in real-time.
/// No hardcoded URLs or static mappings.
class ArtistImages {
  ArtistImages._();

  static final Map<String, String> _dynamicCache = {};
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      },
    ),
  );

  /// Synchronously get cached URL or empty string
  static String urlFor(String name) {
    final key = name.trim().toLowerCase();
    if (_dynamicCache.containsKey(key)) {
      return _dynamicCache[key]!;
    }

    // Check persistent box cache
    final stored = boxGet<String>('AppPrefs', 'artist_img_$key', '');
    if (stored.isNotEmpty) {
      _dynamicCache[key] = stored;
      return stored;
    }

    // Trigger async dynamic fetch in background
    fetchDynamically(name);
    return '';
  }

  /// Dynamically search JioSaavn web catalog for the artist's real HD portrait
  static Future<String?> fetchDynamically(String name) async {
    final key = name.trim().toLowerCase();
    if (_dynamicCache.containsKey(key) && _dynamicCache[key]!.isNotEmpty) {
      return _dynamicCache[key];
    }

    // Check persistent box cache
    final stored = boxGet<String>('AppPrefs', 'artist_img_$key', '');
    if (stored.isNotEmpty) {
      _dynamicCache[key] = stored;
      return stored;
    }

    try {
      // 1. Query JioSaavn Artist Catalog directly
      final res = await _dio.get(
        'https://www.jiosaavn.com/api.php',
        queryParameters: {
          '__call': 'search.getArtistResults',
          '_format': 'json',
          '_marker': '0',
          'api_version': '4',
          'ctx': 'web6dot0',
          'q': name.trim(),
          'n': 1,
        },
      );

      final dynamic rawData = res.data is String ? jsonDecode(res.data) : res.data;
      final results = asStringMap(rawData)['results'] as List? ?? const [];
      if (results.isNotEmpty) {
        final first = asStringMap(results.first);
        final rawImg = asText(first['image']);
        if (rawImg.isNotEmpty) {
          final hdImg = rawImg
              .replaceAll('150x150', '500x500')
              .replaceAll('50x50', '500x500');
          _dynamicCache[key] = hdImg;
          boxPut('AppPrefs', 'artist_img_$key', hdImg);
          return hdImg;
        }
      }

      // 2. Secondary dynamic search: query top song by this artist and use track album art
      final songRes = await _dio.get(
        'https://www.jiosaavn.com/api.php',
        queryParameters: {
          '__call': 'search.getResults',
          '_format': 'json',
          '_marker': '0',
          'api_version': '4',
          'ctx': 'web6dot0',
          'q': '$name songs',
          'n': 1,
        },
      );
      final dynamic rawSongData = songRes.data is String ? jsonDecode(songRes.data) : songRes.data;
      final songResults = asStringMap(rawSongData)['results'] as List? ?? const [];
      if (songResults.isNotEmpty) {
        final song = asStringMap(songResults.first);
        final rawImg = asText(song['image']);
        if (rawImg.isNotEmpty) {
          final hdImg = rawImg
              .replaceAll('150x150', '500x500')
              .replaceAll('50x50', '500x500');
          _dynamicCache[key] = hdImg;
          boxPut('AppPrefs', 'artist_img_$key', hdImg);
          return hdImg;
        }
      }
    } catch (e) {
      printINFO("Dynamic artist image lookup error for $name: $e");
    }

    return null;
  }
}
