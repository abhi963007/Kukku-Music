import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../utils/helper.dart';
import 'supabase_service.dart';

class SupabaseSyncService {
  static SupabaseClient get _client => SupabaseService.client;
  static String? get _userId => SupabaseService.currentUser?.id;
  static bool get isReady => SupabaseService.isAuthenticated && _userId != null;

  // ==========================================
  // 1. FAVORITES SYNC
  // ==========================================

  /// Fetch all favorite songs for the authenticated user from Supabase
  static Future<List<SongModel>> fetchFavorites() async {
    if (!isReady) return [];

    try {
      final data = await _client
          .from('user_favorites')
          .select()
          .order('created_at', ascending: false);

      final List<SongModel> songs = [];
      for (final row in data) {
        final map = asStringMap(row);
        songs.add(
          SongModel(
            id: asText(map['song_id']),
            title: asText(map['title']),
            artist: asText(map['artist']),
            album: asText(map['album']),
            artUri: asText(map['art_uri']),
            duration: Duration(milliseconds: asInt(map['duration_ms'])),
            extras: asStringMap(map['extras']),
          ),
        );
      }
      return songs;
    } catch (e) {
      printERROR('Failed to fetch favorites from Supabase', e);
      return [];
    }
  }

  /// Save a favorite song to Supabase
  static Future<bool> addFavorite(SongModel song) async {
    if (!isReady) return false;

    try {
      await _client.from('user_favorites').upsert({
        'user_id': _userId,
        'song_id': song.id,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'art_uri': song.artUri,
        'duration_ms': song.duration.inMilliseconds,
        'extras': song.extras,
      }, onConflict: 'user_id,song_id');
      return true;
    } catch (e) {
      printERROR('Failed to add favorite to Supabase', e);
      return false;
    }
  }

  /// Remove a favorite song from Supabase
  static Future<bool> removeFavorite(String songId) async {
    if (!isReady) return false;

    try {
      await _client
          .from('user_favorites')
          .delete()
          .eq('user_id', _userId!)
          .eq('song_id', songId);
      return true;
    } catch (e) {
      printERROR('Failed to remove favorite from Supabase', e);
      return false;
    }
  }

  // ==========================================
  // 2. CUSTOM PLAYLISTS SYNC
  // ==========================================

  /// Fetch all user playlists including their track counts
  static Future<List<CustomPlaylistModel>> fetchPlaylists() async {
    if (!isReady) return [];

    try {
      final playlistsData = await _client
          .from('user_playlists')
          .select('*, playlist_tracks(*)')
          .order('updated_at', ascending: false);

      final List<CustomPlaylistModel> playlists = [];
      for (final row in playlistsData) {
        final pMap = asStringMap(row);
        final tracksList = pMap['playlist_tracks'] as List? ?? [];
        final List<SongModel> songs = [];

        for (final t in tracksList) {
          final tMap = asStringMap(t);
          songs.add(
            SongModel(
              id: asText(tMap['song_id']),
              title: asText(tMap['title']),
              artist: asText(tMap['artist']),
              album: asText(tMap['album']),
              artUri: asText(tMap['art_uri']),
              duration: Duration(milliseconds: asInt(tMap['duration_ms'])),
              extras: asStringMap(tMap['extras']),
            ),
          );
        }

        playlists.add(
          CustomPlaylistModel(
            id: asText(pMap['id']),
            name: asText(pMap['name']),
            description: asText(pMap['description']),
            coverArt: asText(pMap['cover_art']),
            createdAt: DateTime.tryParse(asText(pMap['created_at'])) ?? DateTime.now(),
            updatedAt: DateTime.tryParse(asText(pMap['updated_at'])) ?? DateTime.now(),
            songCount: songs.length,
            songs: songs,
          ),
        );
      }
      return playlists;
    } catch (e) {
      printERROR('Failed to fetch playlists from Supabase', e);
      return [];
    }
  }

  /// Create a new playlist
  static Future<CustomPlaylistModel?> createPlaylist({
    required String name,
    String description = '',
    String coverArt = '',
  }) async {
    if (!isReady) return null;

    try {
      final res = await _client
          .from('user_playlists')
          .insert({
            'user_id': _userId,
            'name': name.trim(),
            'description': description.trim(),
            'cover_art': coverArt.trim(),
          })
          .select()
          .single();

      final map = asStringMap(res);
      return CustomPlaylistModel(
        id: asText(map['id']),
        name: asText(map['name']),
        description: asText(map['description']),
        coverArt: asText(map['cover_art']),
        createdAt: DateTime.tryParse(asText(map['created_at'])) ?? DateTime.now(),
        updatedAt: DateTime.tryParse(asText(map['updated_at'])) ?? DateTime.now(),
        songCount: 0,
        songs: const [],
      );
    } catch (e) {
      printERROR('Failed to create playlist in Supabase', e);
      return null;
    }
  }

  /// Delete a playlist
  static Future<bool> deletePlaylist(String playlistId) async {
    if (!isReady) return false;

    try {
      await _client
          .from('user_playlists')
          .delete()
          .eq('id', playlistId)
          .eq('user_id', _userId!);
      return true;
    } catch (e) {
      printERROR('Failed to delete playlist from Supabase', e);
      return false;
    }
  }

  /// Add a song to a playlist
  static Future<bool> addSongToPlaylist(String playlistId, SongModel song) async {
    if (!isReady) return false;

    try {
      await _client.from('playlist_tracks').upsert({
        'playlist_id': playlistId,
        'user_id': _userId,
        'song_id': song.id,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'art_uri': song.artUri,
        'duration_ms': song.duration.inMilliseconds,
        'extras': song.extras,
      }, onConflict: 'playlist_id,song_id');

      // Touch the updated_at timestamp on the parent playlist
      await _client.from('user_playlists').update({
        'updated_at': DateTime.now().toIso8601String(),
        if (song.artUri.isNotEmpty) 'cover_art': song.artUri,
      }).eq('id', playlistId);

      return true;
    } catch (e) {
      printERROR('Failed to add song to playlist in Supabase', e);
      return false;
    }
  }

  /// Remove a song from a playlist
  static Future<bool> removeSongFromPlaylist(String playlistId, String songId) async {
    if (!isReady) return false;

    try {
      await _client
          .from('playlist_tracks')
          .delete()
          .eq('playlist_id', playlistId)
          .eq('song_id', songId)
          .eq('user_id', _userId!);

      await _client.from('user_playlists').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', playlistId);

      return true;
    } catch (e) {
      printERROR('Failed to remove song from playlist in Supabase', e);
      return false;
    }
  }

  // ==========================================
  // 3. LISTENING HISTORY & "ON REPEAT"
  // ==========================================

  /// Records that a user played a track (upserts and increments play_count)
  static Future<void> recordPlayHistory(SongModel song) async {
    if (!isReady || song.id.isEmpty || song.title.isEmpty) return;

    try {
      // Check if existing history row exists to increment play count
      final existing = await _client
          .from('user_history')
          .select('play_count')
          .eq('user_id', _userId!)
          .eq('song_id', song.id)
          .maybeSingle();

      final currentCount = existing != null ? asInt(existing['play_count'], 1) : 0;

      await _client.from('user_history').upsert({
        'user_id': _userId,
        'song_id': song.id,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'art_uri': song.artUri,
        'duration_ms': song.duration.inMilliseconds,
        'extras': song.extras,
        'play_count': currentCount + 1,
        'played_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,song_id');
    } catch (e) {
      printERROR('Failed to record listening history in Supabase', e);
    }
  }

  /// Clear all listening history from Supabase Cloud
  static Future<bool> clearListeningHistory() async {
    if (!isReady) return false;

    try {
      await _client
          .from('user_history')
          .delete()
          .eq('user_id', _userId!);
      return true;
    } catch (e) {
      printERROR('Failed to clear listening history from Supabase', e);
      return false;
    }
  }

  /// Fetch recently played songs
  static Future<List<SongModel>> fetchListeningHistory({int limit = 30}) async {
    if (!isReady) return [];

    try {
      final data = await _client
          .from('user_history')
          .select()
          .order('played_at', ascending: false)
          .limit(limit);

      final List<SongModel> history = [];
      for (final row in data) {
        final map = asStringMap(row);
        history.add(
          SongModel(
            id: asText(map['song_id']),
            title: asText(map['title']),
            artist: asText(map['artist']),
            album: asText(map['album']),
            artUri: asText(map['art_uri']),
            duration: Duration(milliseconds: asInt(map['duration_ms'])),
            extras: asStringMap(map['extras']),
          ),
        );
      }
      return history;
    } catch (e) {
      printERROR('Failed to fetch listening history from Supabase', e);
      return [];
    }
  }

  /// Fetch "On Repeat" (most played songs by this user)
  static Future<List<SongModel>> fetchOnRepeat({int limit = 25}) async {
    if (!isReady) return [];

    try {
      final data = await _client
          .from('user_history')
          .select()
          .order('play_count', ascending: false)
          .limit(limit);

      final List<SongModel> onRepeat = [];
      for (final row in data) {
        final map = asStringMap(row);
        onRepeat.add(
          SongModel(
            id: asText(map['song_id']),
            title: asText(map['title']),
            artist: asText(map['artist']),
            album: asText(map['album']),
            artUri: asText(map['art_uri']),
            duration: Duration(milliseconds: asInt(map['duration_ms'])),
            extras: asStringMap(map['extras']),
          ),
        );
      }
      return onRepeat;
    } catch (e) {
      printERROR('Failed to fetch On-Repeat songs from Supabase', e);
      return [];
    }
  }

  // ==========================================
  // 4. USER PROFILE & PREFERENCES
  // ==========================================

  /// Fetch user preferences (languages, display name)
  static Future<Map<String, dynamic>?> fetchUserProfile() async {
    if (!isReady) return null;

    try {
      final data = await _client
          .from('user_profiles')
          .select()
          .eq('id', _userId!)
          .maybeSingle();

      return data != null ? asStringMap(data) : null;
    } catch (e) {
      printERROR('Failed to fetch user profile from Supabase', e);
      return null;
    }
  }

  /// Update preferred music languages
  static Future<bool> savePreferredLanguages(List<String> languages) async {
    if (!isReady) return false;

    try {
      await _client.from('user_profiles').upsert({
        'id': _userId,
        'preferred_languages': languages,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      printERROR('Failed to save preferred languages in Supabase', e);
      return false;
    }
  }
}
