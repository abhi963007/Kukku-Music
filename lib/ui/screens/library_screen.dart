import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/download_controller.dart';
import '../../controllers/player_controller.dart';
import '../../controllers/user_data_controller.dart';
import '../../models/playlist_model.dart';
import '../../models/song_model.dart';
import '../../utils/helper.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_placeholder.dart';
import 'playlist_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 4, vsync: this);
  final DownloadViewController _downloadController = Get.find<DownloadViewController>();
  final PlayerController _playerController = Get.find<PlayerController>();
  final UserDataController _userDataController = Get.find<UserDataController>();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Your Library",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Obx(() {
                        if (_userDataController.isSyncing.value) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  "Syncing...",
                                  style: TextStyle(color: AppTheme.primary, fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StatsCard(
                    downloads: _downloadController,
                    userData: _userDataController,
                  ),
                  const SizedBox(height: 16),
                  _TabSelector(controller: _tabController),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 1. Favorites
                  _FavoritesList(
                    userData: _userDataController,
                    player: _playerController,
                  ),

                  // 2. Playlists
                  _PlaylistsList(
                    userData: _userDataController,
                    player: _playerController,
                  ),

                  // 3. Downloads
                  _OfflineList(
                    songs: _downloadController.downloadedSongs,
                    emptyIcon: Icons.download_for_offline_outlined,
                    emptyTitle: "No downloaded songs",
                    emptyMessage:
                        "Use the ⋮ menu on any track to download it for offline listening.",
                    onRefresh: _downloadController.loadOfflineData,
                    onPlay: _playerController.playQueue,
                  ),

                  // 4. Cached Streams
                  _OfflineList(
                    songs: _downloadController.cachedSongs,
                    emptyIcon: Icons.cloud_done_outlined,
                    emptyTitle: "No cached streams yet",
                    emptyMessage:
                        "Tracks you stream are cached automatically for instant offline replay. "
                        "You can turn this off in Settings.",
                    onRefresh: _downloadController.loadOfflineData,
                    onPlay: _playerController.playQueue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final DownloadViewController downloads;
  final UserDataController userData;

  const _StatsCard({required this.downloads, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            _StatItem(
              icon: Icons.favorite_rounded,
              iconColor: Colors.redAccent,
              value: '${userData.favorites.length}',
              label: "Favorites",
            ),
            const _StatDivider(),
            _StatItem(
              icon: Icons.queue_music_rounded,
              iconColor: AppTheme.primary,
              value: '${userData.playlists.length}',
              label: "Playlists",
            ),
            const _StatDivider(),
            _StatItem(
              icon: Icons.download_done_rounded,
              iconColor: AppTheme.success,
              value: '${downloads.downloadedSongs.length}',
              label: "Downloads",
            ),
            const _StatDivider(),
            _StatItem(
              icon: Icons.storage_rounded,
              iconColor: AppTheme.textSecondary,
              value: formatBytes(
                downloads.totalCacheSizeBytes.value + downloads.totalDownloadSizeBytes.value,
              ),
              label: "Disk Used",
            ),
          ],
        ),
      );
    });
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: Colors.white12);
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  final TabController controller;

  const _TabSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppTheme.background,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
        splashBorderRadius: BorderRadius.circular(12),
        tabs: const [
          Tab(text: "Favorites ❤️"),
          Tab(text: "Playlists 📂"),
          Tab(text: "Downloads ⬇️"),
          Tab(text: "Cached ⚡"),
        ],
      ),
    );
  }
}

/// Favorites Tab View
class _FavoritesList extends StatelessWidget {
  final UserDataController userData;
  final PlayerController player;

  const _FavoritesList({required this.userData, required this.player});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: userData.syncWithCloud,
      child: Obx(() {
        final items = userData.favorites;
        if (items.isEmpty) {
          return const StatePlaceholder(
            icon: Icons.favorite_border_rounded,
            title: "No favorite tracks yet",
            message: "Tap the heart icon on any song or in the player to save it to your cloud favorites.",
            scrollable: true,
          );
        }

        final songsList = items.toList(growable: false);

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          itemCount: songsList.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text("Play All", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => player.playQueue(songsList, 0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(color: AppTheme.cardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        label: const Text("Shuffle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () {
                          final shuffled = List.of(songsList)..shuffle();
                          player.playQueue(shuffled, 0);
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            final song = songsList[index - 1];
            return SongTile(
              song: song,
              onTap: () => player.playQueue(songsList, index - 1),
            );
          },
        );
      }),
    );
  }
}

/// Custom Playlists Tab View
class _PlaylistsList extends StatelessWidget {
  final UserDataController userData;
  final PlayerController player;

  const _PlaylistsList({required this.userData, required this.player});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: userData.syncWithCloud,
      child: Obx(() {
        final playlists = userData.playlists;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Create New Playlist Card
            InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              onTap: () => _showCreatePlaylistDialog(context, userData),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.4),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(Icons.add_rounded, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Create New Playlist",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            "Curate songs and sync to your cloud library",
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (playlists.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.queue_music_rounded, size: 48, color: AppTheme.textMuted),
                      SizedBox(height: 12),
                      Text(
                        "No custom playlists yet",
                        style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...playlists.map((playlist) => _PlaylistCard(playlist: playlist)),
          ],
        );
      }),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, UserDataController userData) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Text(
          "Create Playlist",
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Playlist name...",
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Description (optional)...",
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final title = nameController.text.trim();
              if (title.isNotEmpty) {
                userData.createPlaylist(
                  name: title,
                  description: descController.text.trim(),
                );
                Navigator.of(ctx).pop();
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final CustomPlaylistModel playlist;

  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: SizedBox(
            width: 50,
            height: 50,
            child: playlist.coverArt.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: playlist.coverArt,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => _fallbackArt(),
                  )
                : _fallbackArt(),
          ),
        ),
        title: Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
          ),
        ),
        subtitle: Text(
          "${playlist.songCount} tracks${playlist.description.isNotEmpty ? ' • ${playlist.description}' : ''}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
        onTap: () => Get.to(() => PlaylistDetailScreen(playlistId: playlist.id)),
      ),
    );
  }

  Widget _fallbackArt() {
    return Container(
      color: AppTheme.surfaceLight,
      child: const Icon(Icons.queue_music_rounded, color: AppTheme.primary, size: 24),
    );
  }
}

/// Offline list view (for Downloads and Cached streams)
class _OfflineList extends StatelessWidget {
  final RxList<SongModel> songs;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final void Function(List<SongModel>, int) onPlay;

  const _OfflineList({
    required this.songs,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: onRefresh,
      child: Obx(() {
        if (songs.isEmpty) {
          return StatePlaceholder(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
            scrollable: true,
          );
        }

        final items = songs.toList(growable: false);
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: items.length,
          itemBuilder: (context, index) => SongTile(
            song: items[index],
            onTap: () => onPlay(items, index),
          ),
        );
      }),
    );
  }
}
