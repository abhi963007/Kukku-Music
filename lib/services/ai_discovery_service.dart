import '../services/supabase_service.dart';
import '../utils/helper.dart';

/// Secure AI Music Discovery Service.
/// Communicates securely via Supabase Cloud Backend without exposing any API keys in client code.
class AiDiscoveryService {
  // In-memory cache for AI results per language
  static final Map<String, List<String>> _aiQueriesCache = {};
  static final Map<String, DateTime> _cacheStamp = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

  /// Fetch real-time discovery queries securely via Supabase Cloud / Dynamic JioSaavn Catalog
  static Future<List<String>> getLatestMovieQueries(String language) async {
    final key = language.toLowerCase();
    final cached = _aiQueriesCache[key];
    final stamp = _cacheStamp[key];

    if (cached != null &&
        cached.isNotEmpty &&
        stamp != null &&
        DateTime.now().difference(stamp) < _cacheDuration) {
      return cached;
    }

    // 1. Securely fetch from Supabase Cloud Edge Function (API keys kept safely on server)
    try {
      final res = await SupabaseService.client.functions.invoke(
        'ai-discovery',
        body: {'language': language},
      );
      if (res.data != null) {
        final List<dynamic> parsed = res.data is List
            ? res.data as List<dynamic>
            : (res.data['queries'] as List<dynamic>? ?? []);
        final List<String> result =
            parsed.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        if (result.isNotEmpty) {
          _aiQueriesCache[key] = result;
          _cacheStamp[key] = DateTime.now();
          printINFO("Supabase Cloud AI returned ${result.length} queries for $language: $result");
          return result;
        }
      }
    } catch (e) {
      printINFO("Supabase cloud function offline/fallback for $language: $e");
    }

    // 2. Dynamic, evergreen, real-time query pool for JioSaavn
    final dynamicQueries = _getDynamicGeneralQueries(language);
    _aiQueriesCache[key] = dynamicQueries;
    _cacheStamp[key] = DateTime.now();
    return dynamicQueries;
  }

  /// 100% General, dynamic search queries that always return current new releases from JioSaavn
  static List<String> _getDynamicGeneralQueries(String language) {
    final lang = language.toLowerCase();
    if (lang == 'trending') {
      return [
        "Top 50 India viral hits",
        "Latest trending songs India",
        "New release radar India",
        "Weekly top chartbusters",
        "Viral reels hits India",
        "Latest blockbuster movie songs",
      ];
    }

    final capLang = language[0].toUpperCase() + language.substring(1);
    return [
      "Latest $capLang songs",
      "New $capLang movie songs",
      "$capLang top chartbusters",
      "$capLang new releases",
      "Top $capLang viral hits",
      "$capLang latest soundtracks",
      "$capLang weekly top 50",
      "$capLang new film hits",
    ];
  }
}
