// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;

import '../models/song_model.dart';
import '../utils/helper.dart';
import 'piped_stream_service.dart';
import 'saavn_service.dart';

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
    try {
      final date = DateTime.now();
      _context['context']['client']['clientVersion'] =
          "1.${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}.01.00";
      final signatureTimestamp = getDatestamp() - 1;
      _context['playbackContext'] = {
        'contentPlaybackContext': {'signatureTimestamp': signatureTimestamp},
      };

      hlCode = asText(boxGet<dynamic>('AppPrefs', 'contentLanguage', 'en')).isNotEmpty
          ? asText(boxGet<dynamic>('AppPrefs', 'contentLanguage', 'en'))
          : 'en';

      final visitorData = asStringMap(boxGet<dynamic>('AppPrefs', 'visitorId', null));
      final cachedId = asText(visitorData['id']);
      final exp = asInt(visitorData['exp']);
      if (cachedId.isNotEmpty && exp > 0 && !isExpired(epoch: exp)) {
        _headers['X-Goog-Visitor-Id'] = cachedId;
        printINFO("Loaded cached visitorId");
        return;
      }

      final visitorId = await generateVisitorId();
      if (visitorId != null && visitorId.isNotEmpty) {
        _headers['X-Goog-Visitor-Id'] = visitorId;
        await boxPut('AppPrefs', 'visitorId', {
          'id': visitorId,
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2592000,
        });
        printINFO("Generated and cached visitorId");
      } else {
        _headers['X-Goog-Visitor-Id'] =
            "CgttN24wcmd5UzNSWSi2lvq2BjIKCgJKUBIEGgAgYQ%3D%3D";
      }
    } catch (e) {
      // A failed init must not prevent search from working via the fallbacks.
      printERROR('MusicServices init failed', e);
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

  /// Search tracks with direct 320kbps CDNs using SaavnService as primary
  Future<List<SongModel>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];

    // 1. Direct JioSaavn search with embedded 320kbps CDN stream URLs
    try {
      final saavnResults = await SaavnService.searchSongs(query);
      if (saavnResults.isNotEmpty) return saavnResults;
    } catch (e) {
      printERROR("SaavnService search failed for: $query", e);
    }

    // 2. YouTube Music InnerTube fallback
    try {
      final body = Map.of(_context);
      body['query'] = query;
      body['params'] = 'EgWKAQIIAWoKEAkQChAFEAMQBA%3D%3D';

      final response = await dio.post(
        '$domain/youtubei/v1/search',
        data: jsonEncode(body),
        options: Options(headers: _headers),
      );

      final List<SongModel> songs = _parseInnertubeSearchResponse(response.data, "Search");
      if (songs.isNotEmpty) return songs;
    } catch (e) {
      printERROR("InnerTube search failed for query: $query, attempting fallback", e);
    }

    // 3. Piped fallback search
    try {
      return await _searchPiped(query);
    } catch (e) {
      printERROR("Piped fallback search failed for: $query", e);
      return [];
    }
  }

  Duration _parseDurationText(String text) {
    final clean = text.trim();
    final parts = clean.split(':');
    if (parts.length == 2) {
      final mins = int.tryParse(parts[0]) ?? 0;
      final secs = int.tryParse(parts[1]) ?? 0;
      return Duration(minutes: mins, seconds: secs);
    } else if (parts.length == 3) {
      final hours = int.tryParse(parts[0]) ?? 0;
      final mins = int.tryParse(parts[1]) ?? 0;
      final secs = int.tryParse(parts[2]) ?? 0;
      return Duration(hours: hours, minutes: mins, seconds: secs);
    }
    return const Duration(minutes: 3, seconds: 30);
  }

  /// Parse structured InnerTube search response ensuring exact matching video IDs and song details
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
            String albumName = '';
            String thumbnail = '';
            Duration duration = const Duration(minutes: 3, seconds: 30);

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
                  final subRuns = flexCols[1]?['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'] as List? ?? [];
                  final textParts = <String>[];
                  for (final run in subRuns) {
                    final t = run['text']?.toString();
                    if (t != null && t.trim() != '•' && t.trim().isNotEmpty) {
                      textParts.add(t.trim());
                    }
                  }
                  if (textParts.isNotEmpty) {
                    artist = textParts[0];
                  }
                  if (textParts.length > 1) {
                    if (RegExp(r'^\d+:\d+(:\d+)?$').hasMatch(textParts.last)) {
                      duration = _parseDurationText(textParts.last);
                      if (textParts.length > 2) {
                        albumName = textParts[1];
                      }
                    } else {
                      albumName = textParts[1];
                    }
                  }
                }
              }

              if (videoId.isEmpty) {
                videoId = renderer['playlistItemData']?['videoId'] ??
                    renderer['overlay']?['musicItemThumbnailOverlayRenderer']?['content']?['musicPlayButtonRenderer']?['playNavigationEndpoint']?['watchEndpoint']?['videoId'] ??
                    renderer['navigationEndpoint']?['watchEndpoint']?['videoId'] ??
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

            // Exclude empty IDs, invalid playlists/channels, and DJ mixes > 12 minutes
            if (videoId.isNotEmpty &&
                title.isNotEmpty &&
                !videoId.startsWith('VL') &&
                !videoId.startsWith('MPRE') &&
                !videoId.startsWith('UC') &&
                duration < const Duration(minutes: 12)) {
              if (thumbnail.contains('=w') || thumbnail.contains('=s')) {
                thumbnail = thumbnail.replaceAll(RegExp(r'=w\d+-h\d+.*'), '=w500-h500-l90-rj');
              }
              songs.add(
                SongModel(
                  id: videoId,
                  title: title,
                  artist: artist,
                  album: albumName.isNotEmpty ? albumName : category,
                  artUri: thumbnail,
                  duration: duration,
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

  /// Fetch infinite radio recommendations for a specific track
  Future<List<SongModel>> getRadioTracks(String videoId) async {
    if (videoId.isEmpty) return [];

    try {
      final body = Map.of(_context);
      body['videoId'] = videoId;
      body['playlistId'] = 'RDAMVM$videoId';
      body['isAudioOnly'] = true;

      final response = await dio.post(
        '$domain/youtubei/v1/next',
        data: jsonEncode(body),
        options: Options(headers: _headers),
      );

      final data = response.data;
      final List<SongModel> songs = [];

      final contents = data['contents']?['singleColumnMusicWatchNextResultsRenderer']?['tabbedRenderer']?['watchNextTabbedResultsRenderer']?['tabs']?[0]?['tabRenderer']?['content']?['musicQueueRenderer']?['content']?['playlistPanelRenderer']?['contents'];

      if (contents != null && contents is List) {
        for (final item in contents) {
          final renderer = item['playlistPanelVideoRenderer'];
          if (renderer == null) continue;

          final id = renderer['videoId']?.toString() ?? '';
          final titleRuns = renderer['title']?['runs'] as List?;
          final title = (titleRuns != null && titleRuns.isNotEmpty) ? titleRuns[0]['text']?.toString() ?? '' : '';
          final artistRuns = renderer['shortBylineText']?['runs'] as List?;
          final artist = artistRuns?.map((r) => r['text'] ?? '').join('') ?? 'Unknown';

          final thumbs = renderer['thumbnail']?['thumbnails'] as List?;
          String thumbnail = '';
          if (thumbs != null && thumbs.isNotEmpty) {
            thumbnail = thumbs.last['url'] ?? '';
            if (thumbnail.contains('=w') || thumbnail.contains('=s')) {
              thumbnail = thumbnail.replaceAll(RegExp(r'=w\d+-h\d+.*'), '=w500-h500-l90-rj');
            }
          }

          if (id.isNotEmpty && title.isNotEmpty) {
            songs.add(
              SongModel(
                id: id,
                title: title,
                artist: artist,
                album: "Radio Recommendation",
                artUri: thumbnail,
                duration: const Duration(minutes: 3, seconds: 30),
              ),
            );
          }
        }
      }
      return songs;
    } catch (e) {
      printERROR("getRadioTracks failed for $videoId", e);
      return [];
    }
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
  final Map<String, DateTime> _languageCacheStamp = {};

  /// How long a cached language section stays fresh.
  static const Duration _cacheTtl = Duration(minutes: 30);

  /// Fetch categorized content for a specific language.
  ///
  /// [forceRefresh] bypasses the in-memory cache — without it, pull-to-refresh
  /// on the home screen returned the same cached payload and appeared to do
  /// nothing.
  Future<LanguageHomeData> getLanguageHomeSections(
    String language, {
    bool forceRefresh = false,
  }) async {
    final cached = _languageCache[language];
    final stamp = _languageCacheStamp[language];
    final isFresh = stamp != null && DateTime.now().difference(stamp) < _cacheTtl;
    if (!forceRefresh && cached != null && cached.trending.isNotEmpty && isFresh) {
      return cached;
    }

    try {
      final queries = _getQueriesForLanguage(language);

      // Fetch trending, albums, movie hits, and melodies concurrently from JioSaavn API
      final results = await Future.wait([
        SaavnService.searchSongs(queries.trendingQuery, limit: 30),
        SaavnService.searchAlbums("${language == 'Trending' ? 'Latest' : language} Movie Soundtracks", limit: 20),
        SaavnService.searchSongs(queries.movieHitsQuery, limit: 30),
        SaavnService.searchSongs(queries.melodiesQuery, limit: 40),
      ]);

      final trending = results[0] as List<SongModel>;
      final albums = results[1] as List<AlbumModel>;
      final movieHits = results[2] as List<SongModel>;
      final melodies = results[3] as List<SongModel>;

      final data = LanguageHomeData(
        language: language,
        trending: trending.isNotEmpty ? trending : await searchTracks(queries.trendingQuery),
        albums: albums,
        movieHits: movieHits.isNotEmpty ? movieHits : await searchTracks(queries.movieHitsQuery),
        topPicks: melodies.isNotEmpty ? melodies : (trending.isNotEmpty ? trending : []),
        artists: queries.popularArtists,
      );

      if (trending.isNotEmpty || movieHits.isNotEmpty || albums.isNotEmpty) {
        _languageCache[language] = data;
        _languageCacheStamp[language] = DateTime.now();
      }
      return data;
    } catch (e) {
      printERROR("Error fetching language sections for $language", e);
      // Prefer stale content over an empty screen when the network is down.
      if (cached != null) return cached;
      return LanguageHomeData(
        language: language,
        trending: [],
        albums: [],
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
          trendingQuery: "Malayalam trending hits",
          movieHitsQuery: "Malayalam movie songs",
          melodiesQuery: "Malayalam melody songs",
          popularArtists: ["Sushin Shyam", "Vineeth Sreenivasan", "Anirudh", "K.J. Yesudas", "KS Chithra", "Shaan Rahman"],
        );
      case 'tamil':
        return LanguageQueries(
          trendingQuery: "Tamil trending hits",
          movieHitsQuery: "Tamil movie songs",
          melodiesQuery: "Tamil melody songs",
          popularArtists: ["Anirudh Ravichander", "A.R. Rahman", "Harris Jayaraj", "Yuvan Shankar Raja", "Sid Sriram", "Dhibu Ninan"],
        );
      case 'hindi':
        return LanguageQueries(
          trendingQuery: "Bollywood trending songs",
          movieHitsQuery: "Hindi movie songs",
          melodiesQuery: "Hindi melody songs",
          popularArtists: ["Arijit Singh", "Shreya Ghoshal", "Pritam", "Vishal-Shekhar", "Atif Aslam", "Armaan Malik"],
        );
      case 'telugu':
        return LanguageQueries(
          trendingQuery: "Telugu trending hits",
          movieHitsQuery: "Telugu movie songs",
          melodiesQuery: "Telugu melody songs",
          popularArtists: ["Thaman S", "Devi Sri Prasad", "Sid Sriram", "Anurag Kulkarni", "Armaan Malik", "Ram Miriyala"],
        );
      case 'kannada':
        return LanguageQueries(
          trendingQuery: "Kannada trending hits",
          movieHitsQuery: "Kannada movie songs",
          melodiesQuery: "Kannada melody songs",
          popularArtists: ["Ravi Basrur", "Arjun Janya", "Charan Raj", "Sanjith Hegde", "Vijay Prakash"],
        );
      case 'punjabi':
        return LanguageQueries(
          trendingQuery: "Punjabi trending hits",
          movieHitsQuery: "Top Punjabi pop songs",
          melodiesQuery: "Best Punjabi romantic songs",
          popularArtists: ["Diljit Dosanjh", "Karan Aujla", "AP Dhillon", "Shubh", "Sidhu Moose Wala", "Guru Randhawa"],
        );
      case 'english':
        return LanguageQueries(
          trendingQuery: "Billboard top hits",
          movieHitsQuery: "Popular movie soundtracks",
          melodiesQuery: "Chill pop melodies",
          popularArtists: ["The Weeknd", "Taylor Swift", "Ed Sheeran", "Dua Lipa", "Bruno Mars", "Billie Eilish"],
        );
      case 'trending':
      default:
        return LanguageQueries(
          trendingQuery: "Trending songs 2025",
          movieHitsQuery: "Popular movie songs",
          melodiesQuery: "Popular acoustic melodies",
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
  final List<AlbumModel> albums;
  final List<SongModel> movieHits;
  final List<SongModel> topPicks;
  final List<String> artists;

  LanguageHomeData({
    required this.language,
    required this.trending,
    this.albums = const [],
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
