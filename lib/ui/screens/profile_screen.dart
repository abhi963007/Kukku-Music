import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/download_controller.dart';
import '../../controllers/player_controller.dart';
import '../../controllers/user_data_controller.dart';
import '../../models/playlist_model.dart';
import '../../services/supabase_service.dart';
import '../../utils/helper.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_placeholder.dart';
import 'auth/login_screen.dart';
import 'playlist_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);
  final UserDataController _userData = Get.find<UserDataController>();
  final PlayerController _player = Get.find<PlayerController>();
  final DownloadViewController _downloads = Get.find<DownloadViewController>();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getUserName() {
    final user = SupabaseService.currentUser;
    if (user != null) {
      final name = user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          user.email?.split('@').first ??
          '';
      if (name.toString().isNotEmpty) return name.toString();
    }
    return boxGet<String>('AppPrefs', 'user_custom_name', 'Music Lover');
  }

  String _getUserEmail() {
    final user = SupabaseService.currentUser;
    if (user != null && user.email != null) {
      return user.email!;
    }
    return 'Guest User • Offline Mode';
  }

  String _getAvatarUrl() {
    final user = SupabaseService.currentUser;
    if (user != null) {
      final avatar = user.userMetadata?['avatar_url'] ??
          user.userMetadata?['picture'] ??
          '';
      if (avatar.toString().isNotEmpty) return avatar.toString();
    }
    return boxGet<String>('AppPrefs', 'user_custom_avatar', '');
  }

  void _editNameDialog() {
    final current = _getUserName();
    final textController = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Edit Profile Name", style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: "Enter your name",
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = textController.text.trim();
              if (newName.isNotEmpty) {
                boxPut('AppPrefs', 'user_custom_name', newName);
                setState(() {});
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _editAvatarDialog() {
    final textController = TextEditingController(text: _getAvatarUrl());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("Change Profile Picture", style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter an image URL for your profile avatar:",
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: "https://example.com/avatar.jpg",
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              boxPut('AppPrefs', 'user_custom_avatar', '');
              setState(() {});
              Navigator.of(ctx).pop();
            },
            child: const Text("Reset Default", style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () {
              final newUrl = textController.text.trim();
              boxPut('AppPrefs', 'user_custom_avatar', newUrl);
              setState(() {});
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _getAvatarUrl();
    final name = _getUserName();
    final email = _getUserEmail();
    final isAuth = SupabaseService.isAuthenticated;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          "Profile & Library",
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Obx(() {
            if (_userData.isSyncing.value) {
              return const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
              );
            }
            return IconButton(
              icon: const Icon(Icons.cloud_sync_rounded, color: AppTheme.primary),
              tooltip: "Sync with Cloud",
              onPressed: () => _userData.syncWithCloud(),
            );
          }),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: [
                  // 1. User Avatar & Info Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        // Avatar with Edit badge
                        GestureDetector(
                          onTap: _editAvatarDialog,
                          child: Stack(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.secondary],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: avatar.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: avatar,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => _avatarFallback(name),
                                        )
                                      : _avatarFallback(name),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Name & Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: _editNameDialog,
                                    child: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.primary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Cloud Auth Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isAuth
                                      ? Colors.greenAccent.withValues(alpha: 0.15)
                                      : AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isAuth
                                        ? Colors.greenAccent.withValues(alpha: 0.3)
                                        : Colors.white10,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isAuth ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                      size: 12,
                                      color: isAuth ? Colors.greenAccent : AppTheme.textMuted,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isAuth ? "Supabase Synced" : "Offline Guest",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isAuth ? Colors.greenAccent : AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Stats Row (Favorites, Playlists, History, Downloads)
                  Obx(() {
                    return Row(
                      children: [
                        _statPill("Favorites", _userData.favorites.length, Icons.favorite_rounded, Colors.redAccent, 0),
                        const SizedBox(width: 8),
                        _statPill("Playlists", _userData.playlists.length, Icons.playlist_play_rounded, AppTheme.primary, 1),
                        const SizedBox(width: 8),
                        _statPill("History", _userData.history.length, Icons.history_rounded, Colors.amberAccent, 2),
                        const SizedBox(width: 8),
                        _statPill("Downloads", _downloads.downloadedSongs.length, Icons.download_rounded, Colors.lightBlueAccent, 3),
                      ],
                    );
                  }),
                  const SizedBox(height: 16),

                  // 3. Tab Bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: Colors.black,
                      unselectedLabelColor: AppTheme.textSecondary,
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: "Favorites"),
                        Tab(text: "Playlists"),
                        Tab(text: "History"),
                        Tab(text: "Downloads"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Favorites
            _FavoritesTab(userData: _userData, player: _player),

            // Tab 2: Custom Playlists
            _PlaylistsTab(userData: _userData, player: _player),

            // Tab 3: History
            _HistoryTab(userData: _userData, player: _player),

            // Tab 4: Downloads
            _DownloadsTab(downloads: _downloads, player: _player),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: isAuth
            ? OutlinedButton.icon(
                onPressed: () async {
                  await SupabaseService.signOut();
                  setState(() {});
                },
                icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                label: const Text("Sign Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              )
            : ElevatedButton.icon(
                onPressed: () => Get.to(() => const LoginScreen()),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text("Sign In with Supabase / Google", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: AppTheme.surfaceLight,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'A',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primary),
        ),
      ),
    );
  }

  Widget _statPill(String label, int count, IconData icon, Color color, int tabIndex) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(tabIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 1: FAVORITES
// ----------------------------------------------------
class _FavoritesTab extends StatelessWidget {
  final UserDataController userData;
  final PlayerController player;

  const _FavoritesTab({required this.userData, required this.player});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final favs = userData.favorites;
      if (favs.isEmpty) {
        return const Center(
          child: StatePlaceholder(
            icon: Icons.favorite_border_rounded,
            title: "No Favorites Yet",
            message: "Songs you favorite in the player will appear here.",
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: favs.length,
        itemBuilder: (context, index) {
          final song = favs[index];
          return SongTile(
            song: song,
            onTap: () => player.playQueue(favs, index),
          );
        },
      );
    });
  }
}

// ----------------------------------------------------
// TAB 2: PLAYLISTS
// ----------------------------------------------------
class _PlaylistsTab extends StatelessWidget {
  final UserDataController userData;
  final PlayerController player;

  const _PlaylistsTab({required this.userData, required this.player});

  void _createPlaylistDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text("New Playlist", style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: "Playlist name",
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                userData.createPlaylist(name: name);
              }
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final playlists = userData.playlists;

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          // Create New Playlist Card
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _createPlaylistDialog(context),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: Icon(Icons.add_rounded, color: Colors.black),
                  ),
                  SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Create New Playlist",
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Curate custom collections of music",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text("No custom playlists created yet.", style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ...playlists.map((playlist) => _PlaylistCard(playlist: playlist)),
        ],
      );
    });
  }
}

class _PlaylistCard extends StatelessWidget {
  final CustomPlaylistModel playlist;

  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 50,
            height: 50,
            child: playlist.coverArt.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: playlist.coverArt,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: AppTheme.surfaceLight,
                      child: Icon(Icons.playlist_play_rounded, color: AppTheme.primary),
                    ),
                  )
                : const ColoredBox(
                    color: AppTheme.surfaceLight,
                    child: Icon(Icons.playlist_play_rounded, color: AppTheme.primary),
                  ),
          ),
        ),
        title: Text(
          playlist.name,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          "${playlist.songs.length} tracks",
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
        onTap: () => Get.to(() => PlaylistDetailScreen(playlistId: playlist.id)),
      ),
    );
  }
}

// ----------------------------------------------------
// TAB 3: HISTORY
// ----------------------------------------------------
class _HistoryTab extends StatelessWidget {
  final UserDataController userData;
  final PlayerController player;

  const _HistoryTab({required this.userData, required this.player});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final history = userData.history;
      if (history.isEmpty) {
        return const Center(
          child: StatePlaceholder(
            icon: Icons.history_rounded,
            title: "No Listening History",
            message: "Songs you stream will appear here in chronological order.",
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final song = history[index];
          return SongTile(
            song: song,
            onTap: () => player.playQueue(history, index),
          );
        },
      );
    });
  }
}

// ----------------------------------------------------
// TAB 4: DOWNLOADS
// ----------------------------------------------------
class _DownloadsTab extends StatelessWidget {
  final DownloadViewController downloads;
  final PlayerController player;

  const _DownloadsTab({required this.downloads, required this.player});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = downloads.downloadedSongs;
      if (items.isEmpty) {
        return const Center(
          child: StatePlaceholder(
            icon: Icons.download_done_rounded,
            title: "No Downloaded Music",
            message: "Save songs offline for high quality playback without internet.",
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final song = items[index];
          return SongTile(
            song: song,
            onTap: () => player.playQueue(items, index),
          );
        },
      );
    });
  }
}
