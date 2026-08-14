// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:hive/hive.dart';

import '../models/song_model.dart';
import '../utils/helper.dart';
import 'piped_stream_service.dart';

enum AudioQuality {
  Low,
  High,
}

class MusicServices extends getx.GetxService {
  static const String domain = "https://music.youtube.com";
  static const String userAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

  final Map<String, String> _headers = {
    'user-agent': userAgent,
    'accept': '*/*',
    'accept-encoding': 'gzip, deflate',
    'content-type': 'application/json',
    'origin': domain,
  };

  final Map<String, dynamic> _context = {
    'context': {
      'client': {
        "clientName": "WEB_REMIX",
        "clientVersion": "1.20240101.01.00",
        "hl": "en",
      },
      'user': {}
    }
  };

  final dio = Dio();

  @override
  void onInit() {
    init();
    super.onInit();
  }

  Future<void> init() async {
    final date = DateTime.now();
    _context['context']['client']['clientVersion'] =
        "1.${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}.01.00";
    final signatureTimestamp = getDatestamp() - 1;
    _context['playbackContext'] = {
      'contentPlaybackContext': {'signatureTimestamp': signatureTimestamp},
    };

    final appPrefsBox = Hive.box('AppPrefs');
    hlCode = appPrefsBox.get('contentLanguage') ?? "en";

    if (appPrefsBox.containsKey('visitorId')) {
      final visitorData = appPrefsBox.get("visitorId");
      if (visitorData != null &&
          visitorData['exp'] != null &&
          !isExpired(epoch: visitorData['exp'])) {
        _headers['X-Goog-Visitor-Id'] = visitorData['id'];
        printINFO("Loaded cached visitorId: ${visitorData['id']}");
        return;
      }
    }

    final visitorId = await generateVisitorId();
    if (visitorId != null) {
      _headers['X-Goog-Visitor-Id'] = visitorId;
      appPrefsBox.put("visitorId", {
        'id': visitorId,
        'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2592000
      });
      printINFO("Generated and cached visitorId: $visitorId");
    } else {
      _headers['X-Goog-Visitor-Id'] =
          "CgttN24wcmd5UzNSWSi2lvq2BjIKCgJKUBIEGgAgYQ%3D%3D";
    }
  }

  set hlCode(String code) {
    _context['context']['client']['hl'] = code;
  }

  Future<String?> generateVisitorId() async {
    try {
      final response =
          await dio.get(domain, options: Options(headers: _headers));
      final reg = RegExp(r'ytcfg\.set\s*\(\s*({.+?})\s*\)\s*;');
      final matches = reg.firstMatch(response.data.toString());
      if (matches != null) {
        final data = jsonDecode(matches.group(1)!);
        return data['VISITOR_DATA'];
      }
    } catch (e) {
      printERROR("Failed to generate visitor ID", e);
    }
    return null;
  }

  /// Search tracks using direct YouTube Music InnerTube endpoint with Piped fallback
  Future<List<SongModel>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final body = Map.of(_context);
      body['query'] = query;

      final response = await dio.post(
        '$domain/youtubei/v1/search',
        data: jsonEncode(body),
        options: Options(headers: _headers),
      );

      final List<SongModel> songs = _parseInnertubeSearchResponse(response.data, "Search");
      if (songs.isNotEmpty) return songs;
    } catch (e) {
      printERROR("InnerTube search failed for query: $query, attempting Piped fallback", e);
    }

    // Piped fallback search
    try {
      return await _searchPiped(query);
    } catch (e) {
      printERROR("Piped fallback search failed for: $query", e);
      return [];
    }
  }

  /// Parse structured InnerTube search response
  List<SongModel> _parseInnertubeSearchResponse(dynamic data, String category) {
    final List<SongModel> songs = [];
    if (data == null || data is! Map) return songs;

    final tab = data['contents']?['tabbedSearchResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['sectionListRenderer']?['contents'];
    if (tab != null && tab is List) {
      for (final section in tab) {
        final itemSection = section['itemSectionRenderer'];
        final shelf = section['musicShelfRenderer'] ?? section['musicCardShelfRenderer'] ?? itemSection;

        final contents = shelf?['contents'] ?? itemSection?['contents'];
        if (contents != null && contents is List) {
          for (final item in contents) {
            String title = '';
            String videoId = '';
            String artist = 'Unknown';
            String thumbnail = '';

            if (item.containsKey('musicResponsiveListItemRenderer')) {
              final renderer = item['musicResponsiveListItemRenderer'];
              final flexCols = renderer['flexColumns'] as List?;
              if (flexCols != null && flexCols.isNotEmpty) {
                final titleRuns = flexCols[0]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
                if (titleRuns != null && titleRuns.isNotEmpty) {
                  title = titleRuns[0]['text'] ?? '';
                  videoId = titleRuns[0]['navigationEndpoint']?['watchEndpoint']?['videoId'] ?? '';
                }

                if (flexCols.length > 1) {
                  final subRuns = flexCols[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List?;
                  if (subRuns != null && subRuns.isNotEmpty) {
                    artist = subRuns.map((r) => r['text'] ?? '').join('');
                  }
                }
              }

              if (videoId.isEmpty) {
                videoId = renderer['playlistItemData']?['videoId'] ??
                    renderer['navigationEndpoint']?['watchEndpoint']?['videoId'] ??
                    renderer['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'] ??
                    '';
              }

              final thumbs = renderer['thumbnail']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
              if (thumbs != null && thumbs.isNotEmpty) {
                thumbnail = thumbs.last['url'] ?? '';
              }
            } else if (item.containsKey('musicTwoRowItemRenderer')) {
              final renderer = item['musicTwoRowItemRenderer'];
              final titleRuns = renderer['title']?['runs'] as List?;
              if (titleRuns != null && titleRuns.isNotEmpty) {
                title = titleRuns[0]['text'] ?? '';
                videoId = renderer['navigationEndpoint']?['watchEndpoint']?['videoId'] ?? '';
              }
              final subRuns = renderer['subtitle']?['runs'] as List?;
              if (subRuns != null && subRuns.isNotEmpty) {
                artist = subRuns.map((r) => r['text'] ?? '').join('');
              }
              final thumbs = renderer['thumbnailRenderer']?['musicThumbnailRenderer']?['thumbnail']?['thumbnails'] as List?;
              if (thumbs != null && thumbs.isNotEmpty) {
                thumbnail = thumbs.last['url'] ?? '';
              }
            }

            if (videoId.isNotEmpty && title.isNotEmpty) {
              if (thumbnail.contains('=w') || thumbnail.contains('=s')) {
                thumbnail = thumbnail.replaceAll(RegExp(r'=w\d+-h\d+.*'), '=w500-h500-l90-rj');
              }
              songs.add(
                SongModel(
                  id: videoId,
                  title: title,
                  artist: artist,
                  album: category,
                  artUri: thumbnail,
                  duration: const Duration(minutes: 3, seconds: 30),
                  extras: {
                    'uploadDate': DateTime.now().toIso8601String(),
                  },
                ),
              );
            }
          }
        }
      }
    }
    return songs;
  }

  /// Piped fallback search
  Future<List<SongModel>> _searchPiped(String query) async {
    for (final instance in PipedStreamService.pipedInstances) {
      try {
        final uri = Uri.parse("$instance/search?q=${Uri.encodeComponent(query)}&filter=music_songs");
        final response = await dio.getUri(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200 && response.data != null) {
          final items = response.data['items'] as List<dynamic>? ?? [];
          final songs = <SongModel>[];
          for (final item in items) {
            final url = item['url']?.toString() ?? '';
            final videoId = url.replaceFirst('/watch?v=', '');
            if (videoId.isNotEmpty) {
              songs.add(
                SongModel(
                  id: videoId,
                  title: item['title'] ?? 'Unknown Track',
                  artist: item['uploaderName'] ?? 'Unknown Artist',
                  album: "Piped Search",
                  artUri: item['thumbnail'] ?? '',
                  duration: Duration(seconds: item['duration'] is int ? item['duration'] : 200),
                ),
              );
            }
          }
          if (songs.isNotEmpty) return songs;
        }
      } catch (_) {
        continue;
      }
    }
    return [];
  }

  /// Cache for language sections to make tab switching instantaneous
  final Map<String, LanguageHomeData> _languageCache = {};

  /// Fetch categorized content for a specific language
  Future<LanguageHomeData> getLanguageHomeSections(String language) async {
    if (_languageCache.containsKey(language) && _languageCache[language]!.trending.isNotEmpty) {
      return _languageCache[language]!;
    }

    try {
      final queries = _getQueriesForLanguage(language);

      // Fetch all three sections concurrently
      final results = await Future.wait([
        searchTracks(queries.trendingQuery),
        searchTracks(queries.movieHitsQuery),
        searchTracks(queries.melodiesQuery),
      ]);

      final trending = results[0];
      final movieHits = results[1];
      final melodies = results[2];

      final data = LanguageHomeData(
        language: language,
        trending: trending,
        movieHits: movieHits,
        topPicks: melodies.isNotEmpty ? melodies : trending,
        artists: queries.popularArtists,
      );

      if (trending.isNotEmpty || movieHits.isNotEmpty || melodies.isNotEmpty) {
        _languageCache[language] = data;
      }
      return data;
    } catch (e) {
      printERROR("Error fetching language sections for $language", e);
      return LanguageHomeData(
        language: language,
        trending: [],
        movieHits: [],
        topPicks: [],
        artists: _getQueriesForLanguage(language).popularArtists,
      );
    }
  }

  LanguageQueries _getQueriesForLanguage(String language) {
    switch (language.toLowerCase()) {
      case 'malayalam':
        return LanguageQueries(
          trendingQuery: "Latest Malayalam trending songs 2025 hits",
          movieHitsQuery: "New Malayalam movie songs audio hits",
          melodiesQuery: "Best Malayalam melody songs playlist hits",
          popularArtists: ["Sushin Shyam", "Vineeth Sreenivasan", "Anirudh", "K.J. Yesudas", "KS Chithra", "Shaan Rahman"],
        );
      case 'tamil':
        return LanguageQueries(
          trendingQuery: "Latest Tamil trending songs 2025 hits",
          movieHitsQuery: "New Tamil movie songs audio jukebox",
          melodiesQuery: "Best Tamil melody songs playlist hits",
          popularArtists: ["Anirudh Ravichander", "A.R. Rahman", "Harris Jayaraj", "Yuvan Shankar Raja", "Sid Sriram", "Dhibu Ninan"],
        );
      case 'hindi':
        return LanguageQueries(
          trendingQuery: "Latest Bollywood trending songs 2025 hits",
          movieHitsQuery: "New Hindi movie songs audio hits",
          melodiesQuery: "Best Hindi romantic melody songs playlist",
          popularArtists: ["Arijit Singh", "Shreya Ghoshal", "Pritam", "Vishal-Shekhar", "Atif Aslam", "Armaan Malik"],
        );
      case 'telugu':
        return LanguageQueries(
          trendingQuery: "Latest Telugu trending songs 2025 hits",
          movieHitsQuery: "New Telugu movie songs audio hits",
          melodiesQuery: "Best Telugu melody songs playlist hits",
          popularArtists: ["Thaman S", "Devi Sri Prasad", "Sid Sriram", "Anurag Kulkarni", "Armaan Malik", "Ram Miriyala"],
        );
      case 'kannada':
        return LanguageQueries(
          trendingQuery: "Latest Kannada trending songs 2025 hits",
          movieHitsQuery: "New Kannada movie songs audio hits",
          melodiesQuery: "Best Kannada melody songs playlist",
          popularArtists: ["Ravi Basrur", "Arjun Janya", "Charan Raj", "Sanjith Hegde", "Vijay Prakash"],
        );
      case 'punjabi':
        return LanguageQueries(
          trendingQuery: "Latest Punjabi trending songs 2025 hits",
          movieHitsQuery: "Top Punjabi pop music hits",
          melodiesQuery: "Best Punjabi romantic songs",
          popularArtists: ["Diljit Dosanjh", "Karan Aujla", "AP Dhillon", "Shubh", "Sidhu Moose Wala", "Guru Randhawa"],
        );
      case 'english':
        return LanguageQueries(
          trendingQuery: "Top trending songs Billboard global hits 2025",
          movieHitsQuery: "Top soundtrack songs popular hits",
          melodiesQuery: "Chill acoustic pop melodies playlist hits",
          popularArtists: ["The Weeknd", "Taylor Swift", "Ed Sheeran", "Dua Lipa", "Bruno Mars", "Billie Eilish"],
        );
      case 'trending':
      default:
        return LanguageQueries(
          trendingQuery: "Trending global songs top music hits 2025",
          movieHitsQuery: "Popular movie soundtrack songs 2025",
          melodiesQuery: "Top global chill acoustic melody songs",
          popularArtists: ["The Weeknd", "Taylor Swift", "Anirudh", "Arijit Singh", "Ed Sheeran", "Dua Lipa"],
        );
    }
  }

  /// Fetch trending / popular songs for explore / home screen
  Future<List<SongModel>> getTrendingTracks() async {
    final res = await getLanguageHomeSections("Trending");
    return res.trending.isNotEmpty ? res.trending : [];
  }
}

class LanguageHomeData {
  final String language;
  final List<SongModel> trending;
  final List<SongModel> movieHits;
  final List<SongModel> topPicks;
  final List<String> artists;

  LanguageHomeData({
    required this.language,
    required this.trending,
    required this.movieHits,
    required this.topPicks,
    required this.artists,
  });
}

class LanguageQueries {
  final String trendingQuery;
  final String movieHitsQuery;
  final String melodiesQuery;
  final List<String> popularArtists;

  LanguageQueries({
    required this.trendingQuery,
    required this.movieHitsQuery,
    required this.melodiesQuery,
    required this.popularArtists,
  });
}
