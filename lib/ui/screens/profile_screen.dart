import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/download_controller.dart';
import '../../controllers/player_controller.dart';
import '../../controllers/user_data_controller.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
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
  void initState() {
    super.initState();
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

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
    return 'Guest User • Local Device Mode';
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
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Edit Profile Name",
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: "Enter your name",
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: const Color(0xFF2C2C2C),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
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
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
      body: SafeArea(
        top: false,
        bottom: true,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                child: Column(
                  children: [
                    // 1. VIP Profile Hero Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF222222),
                            Color(0xFF161616),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Clean Avatar with glowing gradient ring (no camera badge)
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppTheme.primary, AppTheme.secondary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2.5),
                              child: ClipOval(
                                child: Container(
                                  color: const Color(0xFF1A1A1A),
                                  child: avatar.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: avatar,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => _avatarFallback(name),
                                        )
                                      : _avatarFallback(name),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          // Name, Email, Auth status
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
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: _editNameDialog,
                                      child: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.primary),
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
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Cloud status pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isAuth
                                        ? Colors.greenAccent.withValues(alpha: 0.12)
                                        : Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isAuth
                                          ? Colors.greenAccent.withValues(alpha: 0.3)
                                          : Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isAuth ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                        size: 11,
                                        color: isAuth ? Colors.greenAccent : AppTheme.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isAuth ? "Supabase Cloud Synced" : "Guest Mode",
                                        style: TextStyle(
                                          fontSize: 10,
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

                    // 2. Interactive Segmented Selector Cards (NO duplicate pills!)
                    Obx(() {
                      return Row(
                        children: [
                          _segmentedCard("Favorites", _userData.favorites.length, Icons.favorite_rounded, Colors.redAccent, 0),
                          const SizedBox(width: 8),
                          _segmentedCard("Playlists", _userData.playlists.length, Icons.queue_music_rounded, AppTheme.primary, 1),
                          const SizedBox(width: 8),
                          _segmentedCard("History", _userData.history.length, Icons.history_rounded, Colors.amberAccent, 2),
                          const SizedBox(width: 8),
                          _segmentedCard("Downloads", _downloads.downloadedSongs.length, Icons.download_rounded, Colors.lightBlueAccent, 3),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Favorites
              _FavoritesTab(userData: _userData, player: _player, isAuth: isAuth, bottomInset: bottomInset),

              // Tab 2: Custom Playlists
              _PlaylistsTab(userData: _userData, player: _player, isAuth: isAuth, bottomInset: bottomInset),

              // Tab 3: History
              _HistoryTab(userData: _userData, player: _player, isAuth: isAuth, bottomInset: bottomInset),

              // Tab 4: Downloads
              _DownloadsTab(downloads: _downloads, player: _player, isAuth: isAuth, bottomInset: bottomInset),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'A',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
      ),
    );
  }

  Widget _segmentedCard(String label, int count, IconData icon, Color color, int tabIndex) {
    final isSelected = _tabController.index == tabIndex;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(tabIndex);
          setState(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.15)
                : const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : color.withValues(alpha: 0.7),
                size: 20,
              ),
              const SizedBox(height: 5),
              Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
  final bool isAuth;
  final double bottomInset;

  const _FavoritesTab({
    required this.userData,
    required this.player,
    required this.isAuth,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final favs = userData.favorites;
      if (favs.isEmpty) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 30),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const StatePlaceholder(
                icon: Icons.favorite_border_rounded,
                title: "No Favorites Yet",
                message: "Songs you favorite in the player will appear here automatically.",
              ),
              const SizedBox(height: 30),
              _AuthActionCard(isAuth: isAuth),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 80),
        itemCount: favs.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            // Action Header (Play All & Shuffle)
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => player.playQueue(favs, 0),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text("Play All", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final shuffled = List<SongModel>.from(favs)..shuffle();
                        player.playQueue(shuffled, 0);
                      },
                      icon: const Icon(Icons.shuffle_rounded, size: 16),
                      label: const Text("Shuffle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (index == favs.length + 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: _AuthActionCard(isAuth: isAuth),
            );
          }

          final song = favs[index - 1];
          return SongTile(
            song: song,
            onTap: () => player.playQueue(favs, index - 1),
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
  final bool isAuth;
  final double bottomInset;

  const _PlaylistsTab({
    required this.userData,
    required this.player,
    required this.isAuth,
    required this.bottomInset,
  });

  void _createPlaylistDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Create New Playlist", style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: "Playlist title",
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            filled: true,
            fillColor: const Color(0xFF2C2C2C),
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
        padding: EdgeInsets.fromLTRB(18, 6, 18, bottomInset + 80),
        children: [
          // Create New Playlist Card
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _createPlaylistDialog(context),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
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
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text("No custom playlists created yet.", style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ...playlists.map((playlist) => _PlaylistCard(playlist: playlist)),

          const SizedBox(height: 16),
          _AuthActionCard(isAuth: isAuth),
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
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: playlist.coverArt.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: playlist.coverArt,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const ColoredBox(
                      color: Color(0xFF282828),
                      child: Icon(Icons.playlist_play_rounded, color: AppTheme.primary),
                    ),
                  )
                : const ColoredBox(
                    color: Color(0xFF282828),
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
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.textMuted),
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
  final bool isAuth;
  final double bottomInset;

  const _HistoryTab({
    required this.userData,
    required this.player,
    required this.isAuth,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final history = userData.history;
      if (history.isEmpty) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 30),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const StatePlaceholder(
                icon: Icons.history_rounded,
                title: "No Listening History",
                message: "Songs you stream will appear here in chronological order.",
              ),
              const SizedBox(height: 30),
              _AuthActionCard(isAuth: isAuth),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 80),
        itemCount: history.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recently Played (${history.length})",
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => userData.clearHistory(),
                    icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppTheme.textMuted),
                    label: const Text("Clear All", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ),
                ],
              ),
            );
          }

          if (index == history.length + 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: _AuthActionCard(isAuth: isAuth),
            );
          }

          final song = history[index - 1];
          return SongTile(
            song: song,
            onTap: () => player.playQueue(history, index - 1),
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
  final bool isAuth;
  final double bottomInset;

  const _DownloadsTab({
    required this.downloads,
    required this.player,
    required this.isAuth,
    required this.bottomInset,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final items = downloads.downloadedSongs;
      if (items.isEmpty) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 30),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const StatePlaceholder(
                icon: Icons.download_done_rounded,
                title: "No Downloaded Music",
                message: "Save songs offline for high quality playback without internet.",
              ),
              const SizedBox(height: 30),
              _AuthActionCard(isAuth: isAuth),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.fromLTRB(0, 8, 0, bottomInset + 80),
        itemCount: items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => player.playQueue(items, 0),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: Text("Play All (${items.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (index == items.length + 1) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: _AuthActionCard(isAuth: isAuth),
            );
          }

          final song = items[index - 1];
          return SongTile(
            song: song,
            onTap: () => player.playQueue(items, index - 1),
          );
        },
      );
    });
  }
}

// ----------------------------------------------------
// AUTH & ACCOUNT ACTION CARD (Placed cleanly inside scroll)
// ----------------------------------------------------
class _AuthActionCard extends StatelessWidget {
  final bool isAuth;

  const _AuthActionCard({required this.isAuth});

  @override
  Widget build(BuildContext context) {
    if (isAuth) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await SupabaseService.signOut();
            Get.back();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  "Sign Out from Supabase",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.to(() => const LoginScreen()),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login_rounded, color: Colors.black, size: 18),
              SizedBox(width: 8),
              Text(
                "Sign In / Sync Cloud Account",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
