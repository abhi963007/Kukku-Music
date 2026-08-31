import 'dart:convert';
import 'package:dio/dio.dart';

import '../../utils/helper.dart';

/// Dynamic and cached artist avatar resolution service.
/// Automatically searches JioSaavn & web catalog for real-time HD artist portraits.
class ArtistImages {
  ArtistImages._();

  static final Map<String, String> _dynamicCache = {};
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      },
    ),
  );

  /// Synchronous cached or curated URL lookup
  static String urlFor(String name) {
    final key = name.trim().toLowerCase();
    if (_dynamicCache.containsKey(key)) {
      return _dynamicCache[key]!;
    }
    final match = _curatedMap[key];
    if (match != null) return match;

    // Trigger async fetch in background
    fetchDynamically(name);

    return _curatedMap[key] ?? '';
  }

  /// Asynchronously fetch real HD artist portrait from JioSaavn web search
  static Future<String?> fetchDynamically(String name) async {
    final key = name.trim().toLowerCase();
    if (_dynamicCache.containsKey(key)) return _dynamicCache[key];

    try {
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
          return hdImg;
        }
      }

      // Secondary fallback: search top song and use track artwork
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
          return hdImg;
        }
      }
    } catch (e) {
      printINFO("Could not dynamically resolve image for $name: $e");
    }

    return null;
  }

  static const Map<String, String> _curatedMap = {
    // English & Global
    "the weeknd": "https://lh3.googleusercontent.com/U-SAmNOu4TynE818gLCfKsuHZ0U5YNEtO9mrjSI9WCCKERs98LzrCal5kajBBTQNwdcisoB2Bn-pHp4=w300-h300-l90-rj",
    "taylor swift": "https://yt3.googleusercontent.com/RCpTA6EXJQyjVFDosWOKa2SMmqkua_lA9mHPDWWciLwgqpZLz-k8rXWRF_367trrQ7up9BUwCbk6kRk=w300-h300-l90-rj",
    "ed sheeran": "https://lh3.googleusercontent.com/jQoBIAS6JjFGpcqQY1M_Mh3AasOvFENCdVRxkgax1a0K6qiq7AgE3MbJ6Jtt-Jndcarvoawmrg66KTny=w300-h300-l90-rj",
    "dua lipa": "https://lh3.googleusercontent.com/aFx8s1fTuelgxONGbezmTG0EKR8r82uB5H-Q6ZJtssyCWLJWF8GfZNr4tHo84sXdFCPBKrA4R6zXOss=w300-h300-l90-rj",
    "bruno mars": "https://lh3.googleusercontent.com/hnefGBrazRhn4Z92bdSZBUENl40ONjRiVDsmZKZh-WZ2iCKE-2c7KKR7SNcZfzLHoRyB3E6as8L87YA=w300-h300-l90-rj",
    "billie eilish": "https://lh3.googleusercontent.com/tQC4rOL6xz6FhmFr0ggQExxyGbYSOsyveXVSnPBh2WjEyIzQ9pMHablLJ-0GlMBrLBlBrbWQGmzrV6KN=w300-h300-l90-rj",

    // Malayalam
    "sushin shyam": "https://c.saavncdn.com/artists/Sushin_Shyam_001_20240306085527_500x500.jpg",
    "hesham abdul wahab": "https://c.saavncdn.com/artists/Hesham_Abdul_Wahab_001_20230713095037_500x500.jpg",
    "jakes bejoy": "https://c.saavncdn.com/artists/Jakes_Bejoy_001_20231122115312_500x500.jpg",
    "vineeth sreenivasan": "https://c.saavncdn.com/artists/Vineeth_Sreenivasan_500x500.jpg",
    "k.j. yesudas": "https://c.saavncdn.com/artists/K_J_Yesudas_500x500.jpg",
    "ks chithra": "https://c.saavncdn.com/artists/K_S_Chithra_500x500.jpg",
    "shaan rahman": "https://c.saavncdn.com/artists/Shaan_Rahman_500x500.jpg",
    "deepak dev": "https://c.saavncdn.com/artists/Deepak_Dev_500x500.jpg",
    "gopi sundar": "https://c.saavncdn.com/artists/Gopi_Sundar_500x500.jpg",

    // Tamil
    "anirudh": "https://c.saavncdn.com/artists/Anirudh_Ravichander_004_20231018114631_500x500.jpg",
    "anirudh ravichander": "https://c.saavncdn.com/artists/Anirudh_Ravichander_004_20231018114631_500x500.jpg",
    "a.r. rahman": "https://c.saavncdn.com/artists/A_R_Rahman_004_20231110074218_500x500.jpg",
    "harris jayaraj": "https://c.saavncdn.com/artists/Harris_Jayaraj_500x500.jpg",
    "yuvan shankar raja": "https://c.saavncdn.com/artists/Yuvan_Shankar_Raja_002_20231019095655_500x500.jpg",
    "sid sriram": "https://c.saavncdn.com/artists/Sid_Sriram_003_20231019104033_500x500.jpg",
    "dhibu ninan": "https://c.saavncdn.com/artists/Dhibu_Ninan_Thomas_500x500.jpg",
    "santhosh narayanan": "https://c.saavncdn.com/artists/Santhosh_Narayanan_500x500.jpg",

    // Hindi
    "arijit singh": "https://c.saavncdn.com/artists/Arijit_Singh_002_20230323062147_500x500.jpg",
    "shreya ghoshal": "https://c.saavncdn.com/artists/Shreya_Ghoshal_004_20231110074034_500x500.jpg",
    "pritam": "https://c.saavncdn.com/artists/Pritam_003_20231110074148_500x500.jpg",
    "atif aslam": "https://c.saavncdn.com/artists/Atif_Aslam_500x500.jpg",
    "armaan malik": "https://c.saavncdn.com/artists/Armaan_Malik_500x500.jpg",
    "vishal-shekhar": "https://c.saavncdn.com/artists/Vishal-Shekhar_500x500.jpg",

    // Telugu
    "thaman s": "https://c.saavncdn.com/artists/Thaman_S_500x500.jpg",
    "devi sri prasad": "https://c.saavncdn.com/artists/Devi_Sri_Prasad_500x500.jpg",
    "anurag kulkarni": "https://c.saavncdn.com/artists/Anurag_Kulkarni_500x500.jpg",
    "ram miriyala": "https://c.saavncdn.com/artists/Ram_Miriyala_500x500.jpg",

    // Kannada
    "ravi basrur": "https://c.saavncdn.com/artists/Ravi_Basrur_500x500.jpg",
    "arjun janya": "https://c.saavncdn.com/artists/Arjun_Janya_500x500.jpg",
    "charan raj": "https://c.saavncdn.com/artists/Charan_Raj_500x500.jpg",
    "sanjith hegde": "https://c.saavncdn.com/artists/Sanjith_Hegde_500x500.jpg",
    "vijay prakash": "https://c.saavncdn.com/artists/Vijay_Prakash_500x500.jpg",

    // Punjabi
    "diljit dosanjh": "https://c.saavncdn.com/artists/Diljit_Dosanjh_003_20231025073105_500x500.jpg",
    "karan aujla": "https://c.saavncdn.com/artists/Karan_Aujla_003_20231019114757_500x500.jpg",
    "ap dhillon": "https://c.saavncdn.com/artists/AP_Dhillon_500x500.jpg",
    "shubh": "https://c.saavncdn.com/artists/Shubh_002_20230526053805_500x500.jpg",
    "sidhu moose wala": "https://c.saavncdn.com/artists/Sidhu_Moose_Wala_500x500.jpg",
    "badshah": "https://c.saavncdn.com/artists/Badshah_005_20231109074052_500x500.jpg",
  };
}
