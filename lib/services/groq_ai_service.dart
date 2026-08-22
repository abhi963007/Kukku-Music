import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;

import '../models/song_model.dart';
import '../utils/helper.dart';
import 'saavn_service.dart';

class GroqAiService extends getx.GetxService {
  static const String defaultApiKey = '';
  static const String defaultModel = 'openai/gpt-oss-120b';

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.groq.com/openai/v1',
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  String get _apiKey {
    final custom = boxGet<String>('AppPrefs', 'groqApiKey', '');
    return custom.trim().isNotEmpty ? custom.trim() : defaultApiKey;
  }

  String get currentModel {
    final model = boxGet<String>('AppPrefs', 'groqModel', defaultModel);
    return model.isNotEmpty ? model : defaultModel;
  }

  /// Sends a structured prompt to Groq and expects a JSON response
  Future<Map<String, dynamic>?> _callGroqJson({
    required String systemPrompt,
    required String userPrompt,
    String? modelOverride,
  }) async {
    try {
      final model = modelOverride ?? currentModel;
      final payload = {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt}
        ],
        'temperature': 0.7,
      };

      final response = await _dio.post(
        '/chat/completions',
        data: jsonEncode(payload),
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }
        final content = data['choices']?[0]?['message']?['content']?.toString() ?? '';
        return _extractJson(content);
      }
    } catch (e) {
      printERROR('Groq API call failed', e);
    }
    return null;
  }

  /// Robust JSON extractor that strips markdown code fences or surrounding text
  Map<String, dynamic>? _extractJson(String content) {
    if (content.isEmpty) return null;
    try {
      // Direct parse
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    try {
      // Find first '{' and last '}'
      final start = content.indexOf('{');
      final end = content.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final jsonStr = content.substring(start, end + 1);
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) return decoded;
      }
    } catch (e) {
      printERROR('Failed to extract JSON from AI response', e);
    }
    return null;
  }

  /// Generates a customized playlist of songs matching the user's vibe/prompt
  Future<Map<String, dynamic>> generatePlaylist({
    required String prompt,
    int count = 12,
  }) async {
    const systemPrompt = '''
You are Kukku AI DJ, an expert music curator with deep knowledge of Indian music (Malayalam, Tamil, Hindi, Telugu, Punjabi, Kannada, Indie) and Global Pop/Rock/R&B/Electronic.
Based on the user's prompt or mood, create a cohesive playlist of authentic real songs.
Output strictly in JSON format without markdown code blocks:
{
  "title": "A short catchy playlist title (with an emoji)",
  "description": "1 sentence describing the vibe",
  "tracks": [
    {"title": "Song Name", "artist": "Primary Singer/Composer", "language": "Language"}
  ]
}
''';

    final userPrompt = 'Generate a playlist of $count songs for this vibe/prompt: "$prompt"';

    final json = await _callGroqJson(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );

    final title = asText(json?['title']).isNotEmpty
        ? asText(json!['title'])
        : 'AI Curated Mix 🎵';
    final description = asText(json?['description']).isNotEmpty
        ? asText(json!['description'])
        : 'Curated by Kukku AI for: $prompt';

    final rawTracks = json?['tracks'] as List? ?? [];
    final List<SongModel> resolvedSongs = [];

    for (final t in rawTracks) {
      final tMap = asStringMap(t);
      final sTitle = asText(tMap['title']);
      final sArtist = asText(tMap['artist']);
      if (sTitle.isEmpty) continue;

      final query = sArtist.isNotEmpty && sArtist != 'Unknown' ? '$sTitle $sArtist' : sTitle;
      final searchResults = await SaavnService.searchSongs(query, limit: 1);
      if (searchResults.isNotEmpty) {
        resolvedSongs.add(searchResults.first);
      } else {
        // Fallback placeholder song model
        resolvedSongs.add(
          SongModel(
            id: sTitle.hashCode.toString(),
            title: sTitle,
            artist: sArtist.isNotEmpty ? sArtist : 'AI Selected',
            album: title,
            artUri: '',
            duration: const Duration(minutes: 3, seconds: 30),
            extras: {'codec': 'MP4A', 'bitrate': 320000},
          ),
        );
      }
    }

    return {
      'title': title,
      'description': description,
      'songs': resolvedSongs,
    };
  }

  /// AI-powered intelligent search that interprets complex requests
  Future<List<SongModel>> smartSearch({
    required String query,
  }) async {
    const systemPrompt = '''
You are an AI Music Search Assistant.
Parse the user's natural language music query (e.g. "rainy Malayalam hits", "Arijit Singh fast songs", "calm acoustic anime vibes").
Extract the best 6-8 matching real song recommendations.
Output strictly in JSON format without markdown code blocks:
{
  "queries": [
    {"title": "Song Title", "artist": "Artist Name"}
  ]
}
''';

    final json = await _callGroqJson(
      systemPrompt: systemPrompt,
      userPrompt: query,
    );

    final rawQueries = json?['queries'] as List? ?? [];
    final List<SongModel> results = [];

    for (final item in rawQueries) {
      final map = asStringMap(item);
      final title = asText(map['title']);
      final artist = asText(map['artist']);
      if (title.isEmpty) continue;

      final q = artist.isNotEmpty ? '$title $artist' : title;
      final found = await SaavnService.searchSongs(q, limit: 1);
      if (found.isNotEmpty) {
        results.add(found.first);
      }
    }

    return results;
  }

  /// Context-aware song recommendations for continuous endless radio with fresh trending priority
  Future<List<SongModel>> getSmartRadioRecommendations({
    required String currentTitle,
    required String currentArtist,
    String currentAlbum = '',
    List<String> excludeTitles = const [],
  }) async {
    const systemPrompt = '''
You are an intelligent music streaming algorithm (like Spotify Radio / YouTube Music).
Recommend 10 modern, trending, and fresh hit songs that seamlessly match the exact emotion, vibe, tempo, and language of the currently playing song.

STRICT REQUIREMENTS:
1. STRICT SAME LANGUAGE: All recommendations MUST be in the EXACT SAME LANGUAGE as the currently playing track.
   - If the current song is Malayalam -> ALL 10 recommendations MUST be popular Malayalam songs.
   - If the current song is Tamil -> ALL 10 recommendations MUST be popular Tamil songs.
   - If the current song is Hindi -> ALL 10 recommendations MUST be popular Hindi songs.
   - NEVER mix languages.
2. DIVERSE SONG TITLES: Recommend DIFFERENT songs. DO NOT recommend covers, remixes, or karaoke of the currently playing track.
3. TRENDING & MODERN: Prioritize recent, popular, and trending contemporary hit songs.
4. DO NOT repeat any excluded songs.
5. Output strictly in JSON format without markdown code blocks:
{
  "language": "Detected Language",
  "recommendations": [
    {"title": "Song Title", "artist": "Primary Singer", "movie": "Movie / Album Name"}
  ]
}
''';

    final excludeStr = excludeTitles.take(20).join(', ');
    final userPrompt =
        'Currently playing: "$currentTitle" by "$currentArtist" (Album/Movie: "$currentAlbum").'
        '${excludeStr.isNotEmpty ? ' Exclude these songs: [$excludeStr].' : ''}'
        ' Recommend 10 fresh, trending songs in the EXACT SAME language.';

    final json = await _callGroqJson(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      modelOverride: 'openai/gpt-oss-20b', // ultra fast for background radio
    );

    final rawList = json?['recommendations'] as List? ?? [];
    final lang = asText(json?['language']);
    final List<SongModel> resolved = [];
    final lowerExcludes = excludeTitles.map((e) => e.toLowerCase().trim()).toSet();
    lowerExcludes.add(currentTitle.toLowerCase().trim());

    for (final item in rawList) {
      final map = asStringMap(item);
      final title = asText(map['title']);
      final artist = asText(map['artist']);
      final movie = asText(map['movie']);
      if (title.isEmpty) continue;

      if (lowerExcludes.contains(title.toLowerCase().trim())) continue;

      // Build specific search query including movie or language
      String q;
      if (movie.isNotEmpty && movie != 'Single') {
        q = '$title $movie';
      } else if (artist.isNotEmpty && artist != 'Unknown') {
        q = '$title $artist';
      } else if (lang.isNotEmpty) {
        q = '$title $lang';
      } else {
        q = title;
      }

      final found = await SaavnService.searchSongs(q, limit: 1);
      if (found.isNotEmpty) {
        final song = found.first;
        final songTitleLower = song.title.toLowerCase().trim();
        if (!lowerExcludes.contains(songTitleLower)) {
          resolved.add(song);
          lowerExcludes.add(songTitleLower);
        }
      }
    }

    return resolved;
  }

  /// Generates authentic song metadata, mood tags, story, and credits for a track
  Future<Map<String, dynamic>> getSongDetails({
    required String title,
    required String artist,
    String album = '',
  }) async {
    const systemPrompt = '''
You are a music encyclopedia and metadata specialist (like Genius, Spotify Credits, and YouTube Music).
Provide authentic song details, credits, mood/genre tags, and background context for the requested song.
Output strictly in JSON format without markdown code blocks:
{
  "tags": ["Tag1", "Tag2", "Tag3"],
  "mood": "1 sentence describing the musical feel, tempo, and atmosphere.",
  "about": "2 concise sentences about this song's composition, vocals, context, and storyline.",
  "composer": "Composer Name",
  "singers": "Singer Name(s)"
}
''';

    final userPrompt = 'Song: "$title" | Artist: "$artist"${album.isNotEmpty ? ' | Album: "$album"' : ''}';

    final json = await _callGroqJson(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      modelOverride: 'openai/gpt-oss-20b',
    );

    if (json != null) {
      final tagsList = (json['tags'] as List? ?? ['Melody', 'Soundtrack'])
          .map((e) => e.toString().replaceAll('#', '').trim())
          .where((e) => e.isNotEmpty)
          .toList();

      return {
        'tags': tagsList.isNotEmpty ? tagsList : ['Soundtrack', 'Melody'],
        'mood': asText(json['mood']).isNotEmpty
            ? asText(json['mood'])
            : 'Melodic acoustic composition with warm harmonies.',
        'about': asText(json['about']).isNotEmpty
            ? asText(json['about'])
            : 'Popular track featuring expressive instrumentation and vocals.',
        'composer': asText(json['composer']),
        'singers': asText(json['singers']),
      };
    }

    return {
      'tags': ['Soundtrack', 'Melody'],
      'mood': 'Melodic arrangement with expressive vocals.',
      'about': 'High quality audio stream from official music catalog.',
      'composer': artist,
      'singers': artist,
    };
  }
}
