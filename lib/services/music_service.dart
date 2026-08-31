// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;

import '../models/song_model.dart';
import '../utils/helper.dart';
import 'ai_discovery_service.dart';
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

  /// How long a cached language section stays fresh (5 minutes for freshness).
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Fetch categorized content for a specific language with AI-driven latest movie discovery and seed rotation.
  Future<LanguageHomeData> getLanguageHomeSections(
    String language, {
    bool forceRefresh = false,
    List<SongModel> userSeeds = const [],
  }) async {
    final cached = _languageCache[language];
    final stamp = _languageCacheStamp[language];
    final isFresh = stamp != null && DateTime.now().difference(stamp) < _cacheTtl;
    if (!forceRefresh && cached != null && cached.trending.isNotEmpty && isFresh) {
      return cached;
    }

    try {
      final queries = _getQueriesForLanguage(language);

      // 1. Fetch real-time AI movie & track recommendations for this language
      final aiMovieQueries = await AiDiscoveryService.getLatestMovieQueries(language);

      // Concurrent fetch for AI movie songs, trending, albums, movie hits, and melodies
      final futures = <Future<dynamic>>[
        // 0. AI latest movie tracks
        Future.wait(
          aiMovieQueries.take(4).map((q) => SaavnService.searchSongs(q, limit: 6)),
        ),
        // 1. General trending
        SaavnService.searchSongs(queries.trendingQuery, limit: 25),
        // 2. Soundtracks & Albums
        SaavnService.searchAlbums(
          aiMovieQueries.isNotEmpty ? aiMovieQueries.first.split(' ').first : "${language == 'Trending' ? 'Latest' : language} Soundtracks",
          limit: 20,
        ),
        // 3. Movie hits
        SaavnService.searchSongs(queries.movieHitsQuery, limit: 25),
        // 4. Melodies
        SaavnService.searchSongs(queries.melodiesQuery, limit: 25),
      ];

      // Personalized Daily Mix generation based on user seeds
      if (userSeeds.isNotEmpty) {
        final topArtist = _extractTopArtist(userSeeds);
        if (topArtist.isNotEmpty) {
          futures.add(SaavnService.searchSongs("$topArtist hits", limit: 20));
        } else {
          futures.add(SaavnService.searchSongs("Weekly top chartbusters", limit: 20));
        }
      } else {
        futures.add(SaavnService.searchSongs("Top viral songs", limit: 20));
      }

      final results = await Future.wait(futures);

      final rawAiSongsLists = results[0] as List<List<SongModel>>;
      final List<SongModel> aiMovieSongs = [];
      for (final list in rawAiSongsLists) {
        aiMovieSongs.addAll(list);
      }

      final generalTrending = results[1] as List<SongModel>;
      final albums = results[2] as List<AlbumModel>;
      final movieHits = results[3] as List<SongModel>;
      final melodies = results[4] as List<SongModel>;
      final dailyMix = results.length > 5 ? results[5] as List<SongModel> : <SongModel>[];

      final isTrending = language.toLowerCase() == 'trending';

      bool isAllowedLanguage(SongModel s) {
        if (isTrending) return true; // Trending tab allows all languages
        final songLang = asText(s.extras['language']).toLowerCase().trim();
        if (songLang.isEmpty) return true;
        return SaavnService.isExactLanguageMatch(songLang, language);
      }

      bool isAllowedAlbum(AlbumModel a) {
        if (isTrending) return true;
        if (a.language.isEmpty) return true;
        return SaavnService.isExactLanguageMatch(a.language, language);
      }

      // Merge AI movie tracks with general trending (deduplicating by ID and strictly enforcing language)
      final Set<String> seenIds = {};
      final List<SongModel> mergedTrending = [];

      for (final s in [...aiMovieSongs, ...generalTrending]) {
        if (s.id.isNotEmpty && !seenIds.contains(s.id) && isAllowedLanguage(s)) {
          seenIds.add(s.id);
          mergedTrending.add(s);
        }
      }

      final List<SongModel> mergedMovieHits = [];
      for (final s in [...movieHits, ...aiMovieSongs]) {
        if (s.id.isNotEmpty && !seenIds.contains(s.id) && isAllowedLanguage(s)) {
          seenIds.add(s.id);
          mergedMovieHits.add(s);
        }
      }

      final filteredMelodies = melodies.where(isAllowedLanguage).toList();
      final filteredDailyMix = dailyMix.where(isAllowedLanguage).toList();
      final filteredAlbums = albums.where(isAllowedAlbum).toList();

      final data = LanguageHomeData(
        language: language,
        trending: mergedTrending.isNotEmpty ? mergedTrending : await searchTracks(queries.trendingQuery),
        albums: filteredAlbums,
        movieHits: mergedMovieHits.isNotEmpty ? mergedMovieHits : movieHits,
        topPicks: filteredMelodies.isNotEmpty ? filteredMelodies : (mergedTrending.isNotEmpty ? mergedTrending : []),
        dailyMix: filteredDailyMix,
        artists: queries.popularArtists,
      );

      if (mergedTrending.isNotEmpty || filteredAlbums.isNotEmpty) {
        _languageCache[language] = data;
        _languageCacheStamp[language] = DateTime.now();
      }
      return data;
    } catch (e) {
      printERROR("Error fetching language sections for $language", e);
      if (cached != null) return cached;
      return LanguageHomeData(
        language: language,
        trending: [],
        albums: [],
        movieHits: [],
        topPicks: [],
        dailyMix: [],
        artists: _getQueriesForLanguage(language).popularArtists,
      );
    }
  }

  String _extractTopArtist(List<SongModel> songs) {
    final Map<String, int> counts = {};
    for (final s in songs) {
      final clean = s.artist.split(',').first.split('&').first.split('-').first.trim();
      if (clean.isNotEmpty && clean != 'Various' && clean != 'Unknown Artist') {
        counts[clean] = (counts[clean] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return '';
    var best = '';
    var max = 0;
    counts.forEach((k, v) {
      if (v > max) {
        max = v;
        best = k;
      }
    });
    return best;
  }

  LanguageQueries _getQueriesForLanguage(String language) {
    final rnd = Random();
    switch (language.toLowerCase()) {
      case 'malayalam':
        const trendingPool = [
          "Latest Malayalam songs 2024",
          "Malayalam trending chartbusters",
          "Top Malayalam viral hits",
          "New Malayalam cinema hits",
          "Malayalam feel good playlist",
        ];
        const moviePool = [
          "Malayalam movie songs",
          "Malayalam new film hits",
          "Mollywood blockbusters",
        ];
        const melodyPool = [
          "Malayalam melody evergreen",
          "Malayalam acoustic love songs",
          "Malayalam chill beats",
        ];
        return LanguageQueries(
          trendingQuery: trendingPool[rnd.nextInt(trendingPool.length)],
          movieHitsQuery: moviePool[rnd.nextInt(moviePool.length)],
          melodiesQuery: melodyPool[rnd.nextInt(melodyPool.length)],
          popularArtists: ["Sushin Shyam", "Vineeth Sreenivasan", "Anirudh", "K.J. Yesudas", "KS Chithra", "Shaan Rahman", "Hesham Abdul Wahab", "Jakes Bejoy"],
        );
      case 'tamil':
        const trendingPool = [
          "Tamil trending hits 2024",
          "Latest Tamil chartbusters",
          "Top Tamil viral songs",
          "New Tamil movie hits",
        ];
        const moviePool = [
          "Tamil movie songs",
          "Tamil blockbuster soundtracks",
          "Kollywood hits",
        ];
        const melodyPool = [
          "Tamil melody songs",
          "Tamil acoustic melodies",
          "Tamil romantic hits",
        ];
        return LanguageQueries(
          trendingQuery: trendingPool[rnd.nextInt(trendingPool.length)],
          movieHitsQuery: moviePool[rnd.nextInt(moviePool.length)],
          melodiesQuery: melodyPool[rnd.nextInt(melodyPool.length)],
          popularArtists: ["Anirudh Ravichander", "A.R. Rahman", "Harris Jayaraj", "Yuvan Shankar Raja", "Sid Sriram", "Dhibu Ninan", "Santhosh Narayanan"],
        );
      case 'hindi':
        const trendingPool = [
          "Bollywood trending hits 2024",
          "Latest Hindi chartbusters",
          "Top 50 Hindi songs",
          "New Bollywood viral songs",
        ];
        const moviePool = [
          "Hindi movie soundtracks",
          "Bollywood blockbuster songs",
        ];
        const melodyPool = [
          "Hindi acoustic melodies",
          "Arijit Singh soulful melodies",
          "Hindi chill romantic songs",
        ];
        return LanguageQueries(
          trendingQuery: trendingPool[rnd.nextInt(trendingPool.length)],
          movieHitsQuery: moviePool[rnd.nextInt(moviePool.length)],
          melodiesQuery: melodyPool[rnd.nextInt(melodyPool.length)],
          popularArtists: ["Arijit Singh", "Shreya Ghoshal", "Pritam", "Vishal-Shekhar", "Atif Aslam", "Armaan Malik", "Sachin-Jigar", "B Praak"],
        );
      case 'telugu':
        const trendingPool = [
          "Telugu trending hits 2024",
          "Latest Tollywood chartbusters",
          "Top Telugu viral songs",
        ];
        const moviePool = ["Telugu movie songs", "Tollywood blockbuster songs"];
        const melodyPool = ["Telugu melody songs", "Telugu acoustic melodies"];
        return LanguageQueries(
          trendingQuery: trendingPool[rnd.nextInt(trendingPool.length)],
          movieHitsQuery: moviePool[rnd.nextInt(moviePool.length)],
          melodiesQuery: melodyPool[rnd.nextInt(melodyPool.length)],
          popularArtists: ["Thaman S", "Devi Sri Prasad", "Sid Sriram", "Anurag Kulkarni", "Armaan Malik", "Ram Miriyala"],
        );
      case 'kannada':
        const trendingPool = ["Kannada trending hits 2024", "Latest Sandalwood hits", "Top Kannada songs"];
        const moviePool = ["Kannada movie songs", "Kannada blockbuster tracks"];
        const melodyPool = ["Kannada melody songs", "Kannada acoustic songs"];
        return LanguageQueries(
          trendingQuery: trendingPool[rnd.nextInt(trendingPool.length)],
          movieHitsQuery: moviePool[rnd.nextInt(moviePool.length)],
          melodiesQuery: melodyPool[rnd.nextInt(melodyPool.length)],
          popularArtists: ["Ravi Basrur", "Arjun Janya", "Charan Raj", "Sanjith Hegde", "Vijay Prakash"],
        );
      case 'punjabi':
        const trendingPool = ["Punjabi trending hits 2024", "Top Punjabi pop songs", "Viral Punjabi tracks"];
        const moviePool = ["Top Punjabi hits", "Punjabi dance tracks"];
        const melodyPool = ["Best Punjabi romantic songs", "Punjabi acoustic songs"];
        return LanguageQueries(
          trendingQuery: trendingPool[rnd.nextInt(trendingPool.length)],
          movieHitsQuery: moviePool[rnd.nextInt(moviePool.length)],
          melodiesQuery: melodyPool[rnd.nextInt(melodyPool.length)],
          popularArtists: ["Diljit Dosanjh", "Karan Aujla", "AP Dhillon", "Shubh", "Sidhu Moose Wala", "Guru Randhawa"],
        );
      case 'english':
        const trendingPool = ["Billboard top hits 2024", "Global viral pop", "Top English chartbusters"];
        const moviePool = ["Popular movie soundtracks", "Global cinema hits"];
        const melodyPool = ["Chill pop melodies", "Acoustic pop favorites"];
        return LanguageQueries(
          trendingQuery: trendingPool[rnd.nextInt(trendingPool.length)],
          movieHitsQuery: moviePool[rnd.nextInt(moviePool.length)],
          melodiesQuery: melodyPool[rnd.nextInt(melodyPool.length)],
          popularArtists: ["The Weeknd", "Taylor Swift", "Ed Sheeran", "Dua Lipa", "Bruno Mars", "Billie Eilish"],
        );
      case 'trending':
      default:
        const trendingPool = [
          "Top 50 India viral hits",
          "Trending chartbusters 2024",
          "Global top hits India",
          "Latest viral trending songs",
          "Weekly top Indian music",
          "Hot new releases India",
        ];
        const moviePool = [
          "Blockbuster movie songs",
          "Cinema soundtrack hits",
          "All time popular Indian songs",
        ];
        const melodyPool = [
          "Acoustic chill melodies",
          "Soulful melodies & pop",
          "Feel good acoustic vibes",
        ];
        return LanguageQueries(
          trendingQuery: trendingPool[rnd.nextInt(trendingPool.length)],
          movieHitsQuery: moviePool[rnd.nextInt(moviePool.length)],
          melodiesQuery: melodyPool[rnd.nextInt(melodyPool.length)],
          popularArtists: ["Anirudh", "Arijit Singh", "Sushin Shyam", "The Weeknd", "Taylor Swift", "Ed Sheeran", "Shreya Ghoshal", "Dua Lipa"],
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
  final List<SongModel> dailyMix;
  final List<String> artists;

  LanguageHomeData({
    required this.language,
    required this.trending,
    this.albums = const [],
    required this.movieHits,
    required this.topPicks,
    this.dailyMix = const [],
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
