// ignore_for_file: constant_identifier_names

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:hive/hive.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/song_model.dart';
import '../utils/helper.dart';

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
    'content-encoding': 'gzip',
    'origin': domain,
    'cookie': 'CONSENT=YES+1',
  };

  final Map<String, dynamic> _context = {
    'context': {
      'client': {
        "clientName": "WEB_REMIX",
        "clientVersion": "1.20240101.01.00",
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

  /// Search tracks using pure YoutubeExplode with metadata mapping
  Future<List<SongModel>> searchTracks(String query) async {
    final yt = YoutubeExplode();
    try {
      final searchResults = await yt.search.search(query);
      final List<SongModel> songs = [];

      for (final video in searchResults) {
        // Filter out live streams or unplayable entries
        if (video.isLive) continue;

        songs.add(
          SongModel(
            id: video.id.value,
            title: video.title,
            artist: video.author,
            album: video.channelId.value,
            artUri: video.thumbnails.highResUrl,
            duration: video.duration ?? const Duration(minutes: 3),
            extras: {
              'views': video.engagement.viewCount,
              'uploadDate': video.uploadDate?.toIso8601String(),
            },
          ),
        );
      }
      return songs;
    } catch (e) {
      printERROR("Search error for query: $query", e);
      return [];
    } finally {
      yt.close();
    }
  }

  /// Cache for language sections to make tab switching instantaneous
  final Map<String, LanguageHomeData> _languageCache = {};

  /// Fetch categorized content for a specific language
  Future<LanguageHomeData> getLanguageHomeSections(String language) async {
    if (_languageCache.containsKey(language)) {
      return _languageCache[language]!;
    }

    final yt = YoutubeExplode();
    try {
      final queries = _getQueriesForLanguage(language);

      // Fetch trending and movie hits in parallel for maximum speed
      final results = await Future.wait([
        yt.search.search(queries.trendingQuery),
        yt.search.search(queries.movieHitsQuery),
        yt.search.search(queries.melodiesQuery),
      ]);

      final List<SongModel> trending = _mapVideosToSongs(results[0], "Trending");
      final List<SongModel> movieHits = _mapVideosToSongs(results[1], "Soundtracks");
      final List<SongModel> melodies = _mapVideosToSongs(results[2], "Hits");

      final data = LanguageHomeData(
        language: language,
        trending: trending,
        movieHits: movieHits,
        topPicks: melodies,
        artists: queries.popularArtists,
      );

      _languageCache[language] = data;
      return data;
    } catch (e) {
      printERROR("Error fetching language sections for $language", e);
      return LanguageHomeData(
        language: language,
        trending: [],
        movieHits: [],
        topPicks: [],
        artists: [],
      );
    } finally {
      yt.close();
    }
  }

  List<SongModel> _mapVideosToSongs(Iterable<Video> searchList, String category) {
    final List<SongModel> songs = [];
    for (final video in searchList) {
      if (video.isLive) continue;
      songs.add(
        SongModel(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          album: category,
          artUri: video.thumbnails.highResUrl,
          duration: video.duration ?? const Duration(minutes: 3, seconds: 30),
          extras: {
            'views': video.engagement.viewCount,
            'uploadDate': video.uploadDate?.toIso8601String(),
          },
        ),
      );
    }
    return songs;
  }

  LanguageQueries _getQueriesForLanguage(String language) {
    switch (language.toLowerCase()) {
      case 'malayalam':
        return LanguageQueries(
          trendingQuery: "Latest Malayalam trending songs 2025 2026 hits",
          movieHitsQuery: "New Malayalam movie songs audio hits",
          melodiesQuery: "Best Malayalam melody songs playlist hits",
          popularArtists: ["Sushin Shyam", "Anirudh", "Vineeth Sreenivasan", "K.J. Yesudas", "KS Chithra", "Shaan Rahman"],
        );
      case 'tamil':
        return LanguageQueries(
          trendingQuery: "Latest Tamil trending songs 2025 2026 hits",
          movieHitsQuery: "New Tamil movie songs audio jukebox",
          melodiesQuery: "Best Tamil melody songs playlist hits",
          popularArtists: ["Anirudh Ravichander", "A.R. Rahman", "Harris Jayaraj", "Yuvan Shankar Raja", "Sid Sriram", "Dhibu Ninan"],
        );
      case 'hindi':
        return LanguageQueries(
          trendingQuery: "Latest Bollywood trending songs 2025 2026 hits",
          movieHitsQuery: "New Hindi movie songs audio hits",
          melodiesQuery: "Best Hindi romantic melody songs playlist",
          popularArtists: ["Arijit Singh", "Shreya Ghoshal", "Pritam", "Vishal-Shekhar", "Atif Aslam", "Armaan Malik"],
        );
      case 'telugu':
        return LanguageQueries(
          trendingQuery: "Latest Telugu trending songs 2025 2026 hits",
          movieHitsQuery: "New Telugu movie songs audio hits",
          melodiesQuery: "Best Telugu melody songs playlist hits",
          popularArtists: ["Thaman S", "Devi Sri Prasad", "Sid Sriram", "Anurag Kulkarni", "Armaan Malik", "Ram Miriyala"],
        );
      case 'kannada':
        return LanguageQueries(
          trendingQuery: "Latest Kannada trending songs 2025 2026 hits",
          movieHitsQuery: "New Kannada movie songs audio hits",
          melodiesQuery: "Best Kannada melody songs playlist",
          popularArtists: ["Ravi Basrur", "Arjun Janya", "Charan Raj", "Sanjith Hegde", "Vijay Prakash"],
        );
      case 'punjabi':
        return LanguageQueries(
          trendingQuery: "Latest Punjabi trending songs 2025 2026 hits",
          movieHitsQuery: "Top Punjabi pop music hits",
          melodiesQuery: "Best Punjabi romantic songs",
          popularArtists: ["Diljit Dosanjh", "Karan Aujla", "AP Dhillon", "Shubh", "Sidhu Moose Wala", "Guru Randhawa"],
        );
      case 'english':
      case 'global':
      default:
        return LanguageQueries(
          trendingQuery: "Top trending songs Billboard global hits 2026",
          movieHitsQuery: "Top soundtrack songs popular hits",
          melodiesQuery: "Chill acoustic pop melodies playlist hits",
          popularArtists: ["The Weeknd", "Taylor Swift", "Ed Sheeran", "Dua Lipa", "Bruno Mars", "Billie Eilish"],
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

