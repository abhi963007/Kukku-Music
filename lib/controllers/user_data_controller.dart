import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/supabase_service.dart';
import '../services/supabase_sync_service.dart';
import '../ui/theme/app_theme.dart';
import '../utils/helper.dart';

class UserDataController extends GetxController {
  final RxList<SongModel> favorites = <SongModel>[].obs;
  final RxSet<String> favoriteIds = <String>{}.obs;

  final RxList<CustomPlaylistModel> playlists = <CustomPlaylistModel>[].obs;
  final RxList<SongModel> history = <SongModel>[].obs;
  final RxList<SongModel> onRepeat = <SongModel>[].obs;
  final RxList<String> preferredLanguages = <String>['malayalam', 'tamil', 'hindi', 'english'].obs;

  final RxBool isSyncing = false.obs;
  final RxString syncStatus = 'Synced'.obs;

  StreamSubscription? _authSubscription;

  @override
  void onInit() {
    super.onInit();
    loadLocalData();

    // Listen to real-time auth changes to automatically sync when user logs in
    try {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((data) {
        if (data.session != null) {
          syncWithCloud();
        }
      });
    } catch (_) {}

    if (SupabaseService.isAuthenticated) {
      syncWithCloud();
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }

  // ==========================================
  // 1. LOCAL STORAGE PERSISTENCE (Hive)
  // ==========================================

  void loadLocalData() {
    try {
      // 1. Load favorites
      final rawFavs = boxGet<List<dynamic>>('AppPrefs', 'user_favorites_local', const []);
      final List<SongModel> favList = [];
      final Set<String> idSet = {};
      for (final item in rawFavs) {
        final song = SongModel.fromJson(item);
        if (song.id.isNotEmpty) {
          favList.add(song);
          idSet.add(song.id);
        }
      }
      favorites.assignAll(favList);
      favoriteIds.assignAll(idSet);

      // 2. Load playlists
      final rawPlaylists = boxGet<List<dynamic>>('AppPrefs', 'user_playlists_local', const []);
      final List<CustomPlaylistModel> pList = [];
      for (final item in rawPlaylists) {
        final p = CustomPlaylistModel.fromJson(item);
        if (p.id.isNotEmpty) pList.add(p);
      }
      playlists.assignAll(pList);

      // 3. Load history
      final rawHist = boxGet<List<dynamic>>('AppPrefs', 'recentSongs', const []);
      final List<SongModel> histList = [];
      for (final item in rawHist) {
        final song = SongModel.fromJson(item);
        if (song.id.isNotEmpty) histList.add(song);
      }
      history.assignAll(histList);

      // 4. Load preferred languages
      final rawLangs = boxGet<List<dynamic>>('AppPrefs', 'preferredLanguages', const []);
      if (rawLangs.isNotEmpty) {
        preferredLanguages.assignAll(rawLangs.map((e) => e.toString().toLowerCase()).toList());
      }
    } catch (e) {
      printERROR('Failed to load local user data from Hive', e);
    }
  }

  Future<void> _saveLocalFavorites() async {
    try {
      final jsonList = favorites.map((s) => s.toJson()).toList();
      await boxPut('AppPrefs', 'user_favorites_local', jsonList);
    } catch (e) {
      printERROR('Failed to save local favorites', e);
    }
  }

  Future<void> _saveLocalPlaylists() async {
    try {
      final jsonList = playlists.map((p) => p.toJson()).toList();
      await boxPut('AppPrefs', 'user_playlists_local', jsonList);
    } catch (e) {
      printERROR('Failed to save local playlists', e);
    }
  }

  // ==========================================
  // 2. CLOUD SYNCHRONIZATION
  // ==========================================

  Future<void> syncWithCloud() async {
    if (!SupabaseSyncService.isReady) return;

    isSyncing.value = true;
    syncStatus.value = 'Syncing...';

    try {
      // 1. Sync Favorites
      final cloudFavs = await SupabaseSyncService.fetchFavorites();
      if (cloudFavs.isNotEmpty) {
        // Merge cloud with any local-only songs
        final Set<String> cloudIds = cloudFavs.map((s) => s.id).toSet();
        for (final local in favorites) {
          if (!cloudIds.contains(local.id)) {
            await SupabaseSyncService.addFavorite(local);
            cloudFavs.add(local);
          }
        }
        favorites.assignAll(cloudFavs);
        favoriteIds.assignAll(cloudFavs.map((s) => s.id));
        await _saveLocalFavorites();
      } else if (favorites.isNotEmpty) {
        // Push local favorites to newly logged-in account
        for (final song in favorites) {
          await SupabaseSyncService.addFavorite(song);
        }
      }

      // 2. Sync Playlists
      final cloudPlaylists = await SupabaseSyncService.fetchPlaylists();
      if (cloudPlaylists.isNotEmpty) {
        playlists.assignAll(cloudPlaylists);
        await _saveLocalPlaylists();
      }

      // 3. Sync History & On-Repeat
      final cloudHistory = await SupabaseSyncService.fetchListeningHistory();
      if (cloudHistory.isNotEmpty) {
        history.assignAll(cloudHistory);
      }

      final cloudOnRepeat = await SupabaseSyncService.fetchOnRepeat();
      if (cloudOnRepeat.isNotEmpty) {
        onRepeat.assignAll(cloudOnRepeat);
      }

      // 4. Sync Profile preferences
      final profile = await SupabaseSyncService.fetchUserProfile();
      if (profile != null && profile['preferred_languages'] is List) {
        final langs = (profile['preferred_languages'] as List).map((e) => e.toString()).toList();
        if (langs.isNotEmpty) {
          preferredLanguages.assignAll(langs);
          await boxPut('AppPrefs', 'preferredLanguages', langs);
        }
      }

      syncStatus.value = 'Synced with Cloud ☁️';
    } catch (e) {
      printERROR('Error during cloud sync', e);
      syncStatus.value = 'Sync failed';
    } finally {
      isSyncing.value = false;
    }
  }

  // ==========================================
  // 3. FAVORITES ACTIONS
  // ==========================================

  bool isFavorite(String songId) => favoriteIds.contains(songId);

  Future<void> toggleFavorite(SongModel song) async {
    if (song.id.isEmpty) return;

    HapticFeedback.lightImpact();

    final isFav = isFavorite(song.id);
    if (isFav) {
      // Remove from favorites
      favoriteIds.remove(song.id);
      favorites.removeWhere((s) => s.id == song.id);
      _showToast("Removed from Favorites", Icons.favorite_border_rounded);

      await _saveLocalFavorites();
      if (SupabaseSyncService.isReady) {
        unawaited(SupabaseSyncService.removeFavorite(song.id));
      }
    } else {
      // Add to favorites
      favoriteIds.add(song.id);
      favorites.insert(0, song);
      _showToast("Added to Favorites ❤️", Icons.favorite_rounded, isFavorite: true);

      await _saveLocalFavorites();
      if (SupabaseSyncService.isReady) {
        unawaited(SupabaseSyncService.addFavorite(song));
      }
    }
  }

  // ==========================================
  // 4. PLAYLIST ACTIONS
  // ==========================================

  Future<CustomPlaylistModel?> createPlaylist({
    required String name,
    String description = '',
  }) async {
    if (name.trim().isEmpty) return null;

    final newPlaylist = CustomPlaylistModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      description: description.trim(),
    );

    playlists.insert(0, newPlaylist);
    await _saveLocalPlaylists();

    if (SupabaseSyncService.isReady) {
      final cloudCreated = await SupabaseSyncService.createPlaylist(
        name: name,
        description: description,
      );
      if (cloudCreated != null) {
        final idx = playlists.indexWhere((p) => p.id == newPlaylist.id);
        if (idx != -1) {
          playlists[idx] = cloudCreated;
          await _saveLocalPlaylists();
        }
        return cloudCreated;
      }
    }

    _showToast("Created playlist '$name'", Icons.playlist_add_check_rounded);
    return newPlaylist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    playlists.removeWhere((p) => p.id == playlistId);
    await _saveLocalPlaylists();

    if (SupabaseSyncService.isReady) {
      unawaited(SupabaseSyncService.deletePlaylist(playlistId));
    }
    _showToast("Playlist deleted", Icons.delete_outline_rounded);
  }

  Future<void> addSongToPlaylist(String playlistId, SongModel song) async {
    final idx = playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;

    final target = playlists[idx];
    if (target.songs.any((s) => s.id == song.id)) {
      _showToast("Already in ${target.name}", Icons.info_outline_rounded);
      return;
    }

    final updatedSongs = List<SongModel>.from(target.songs)..insert(0, song);
    final updatedPlaylist = target.copyWith(
      songs: updatedSongs,
      songCount: updatedSongs.length,
      coverArt: target.coverArt.isEmpty ? song.artUri : target.coverArt,
      updatedAt: DateTime.now(),
    );

    playlists[idx] = updatedPlaylist;
    await _saveLocalPlaylists();

    if (SupabaseSyncService.isReady) {
      unawaited(SupabaseSyncService.addSongToPlaylist(playlistId, song));
    }

    _showToast("Added to ${target.name}", Icons.playlist_add_check_rounded);
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final idx = playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;

    final target = playlists[idx];
    final updatedSongs = target.songs.where((s) => s.id != songId).toList();
    final updatedPlaylist = target.copyWith(
      songs: updatedSongs,
      songCount: updatedSongs.length,
      updatedAt: DateTime.now(),
    );

    playlists[idx] = updatedPlaylist;
    await _saveLocalPlaylists();

    if (SupabaseSyncService.isReady) {
      unawaited(SupabaseSyncService.removeSongFromPlaylist(playlistId, songId));
    }

    _showToast("Removed track", Icons.remove_circle_outline_rounded);
  }

  // ==========================================
  // 5. HISTORY & STATS ACTIONS
  // ==========================================

  Future<void> recordPlay(SongModel song) async {
    if (song.id.isEmpty || song.title.isEmpty) return;

    // Update local history
    history.removeWhere((s) => s.id == song.id);
    history.insert(0, song);
    if (history.length > 50) history.removeLast();

    try {
      final jsonList = history.map((s) => s.toJson()).toList();
      await boxPut('AppPrefs', 'recentSongs', jsonList);
    } catch (_) {}

    if (SupabaseSyncService.isReady) {
      unawaited(SupabaseSyncService.recordPlayHistory(song));
    }
  }

  void _showToast(String message, IconData icon, {bool isFavorite = false}) {
    Get.rawSnackbar(
      messageText: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isFavorite ? Colors.redAccent : AppTheme.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppTheme.surface.withValues(alpha: 0.95),
      borderRadius: AppTheme.radiusMd,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
      animationDuration: const Duration(milliseconds: 250),
    );
  }
}
