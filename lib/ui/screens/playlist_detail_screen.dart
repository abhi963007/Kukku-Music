import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../../controllers/user_data_controller.dart';
import '../../models/playlist_model.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_placeholder.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final userData = Get.find<UserDataController>();
    final player = Get.find<PlayerController>();

    return Obx(() {
      final playlist = userData.playlists.firstWhereOrNull((p) => p.id == playlistId);
      if (playlist == null) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
              onPressed: () => Get.back(),
            ),
          ),
          body: const Center(
            child: Text("Playlist not found", style: TextStyle(color: AppTheme.textMuted)),
          ),
        );
      }

      final songs = playlist.songs;

      return Scaffold(
        backgroundColor: AppTheme.background,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 240,
              pinned: true,
              backgroundColor: AppTheme.surface,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                onPressed: () => Get.back(),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
                  tooltip: 'Delete Playlist',
                  onPressed: () => _confirmDelete(context, userData, playlist),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (playlist.coverArt.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: playlist.coverArt,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const ColoredBox(color: AppTheme.surfaceLight),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.3),
                              AppTheme.surfaceLight,
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.queue_music_rounded, size: 64, color: AppTheme.textMuted),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (playlist.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              playlist.description,
                              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            "${songs.length} tracks • Custom Playlist",
                            style: const TextStyle(color: AppTheme.primaryAccent, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Controls Bar (Play All, Shuffle)
            if (songs.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: const Text("Play All", style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => player.playQueue(songs, 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: const BorderSide(color: AppTheme.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                          icon: const Icon(Icons.shuffle_rounded, size: 20),
                          label: const Text("Shuffle", style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            final shuffled = List.of(songs)..shuffle();
                            player.playQueue(shuffled, 0);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Song List
            if (songs.isEmpty)
              const SliverFillRemaining(
                child: StatePlaceholder(
                  icon: Icons.playlist_add_rounded,
                  title: "Playlist is empty",
                  message: "Tap 'Add to Playlist' on any track to populate this playlist.",
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = songs[index];
                      return SongTile(
                        song: song,
                        onTap: () => player.playQueue(songs, index),
                      );
                    },
                    childCount: songs.length,
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  void _confirmDelete(BuildContext context, UserDataController userData, CustomPlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Text("Delete Playlist?", style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          "Are you sure you want to delete '${playlist.name}'? This cannot be undone.",
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              userData.deletePlaylist(playlist.id);
              Navigator.of(ctx).pop();
              Get.back();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
