import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/download_controller.dart';
import '../../controllers/player_controller.dart';
import '../../controllers/user_data_controller.dart';
import '../../models/song_model.dart';
import '../../utils/helper.dart';
import '../theme/app_theme.dart';
import 'add_to_playlist_sheet.dart';
import 'song_details_sheet.dart';

class YtTrackOptionsSheet extends StatelessWidget {
  final SongModel song;

  const YtTrackOptionsSheet({super.key, required this.song});

  static void show(BuildContext context, SongModel song) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (_) => YtTrackOptionsSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final downloadController = Get.find<DownloadViewController>();
    final userData = Get.find<UserDataController>();

    final durationStr = formatDuration(song.duration);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${song.artist}${durationStr.isNotEmpty ? ' • $durationStr' : ''}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Obx(() {
                  final isFav = userData.isFavorite(song.id);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? Colors.redAccent : AppTheme.textSecondary,
                      size: 22,
                    ),
                    tooltip: isFav ? 'Favorited' : 'Add to Fav',
                    onPressed: () => userData.toggleFavorite(song),
                  );
                }),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Top 3 Quick-Action Cards (Play Next, Save to Playlist, Share)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.playlist_play_rounded,
                    label: "Play next",
                    onTap: () {
                      Navigator.of(context).pop();
                      playerController.addToQueue(song);
                      Get.snackbar(
                        'Queue',
                        "Playing '${song.title}' next",
                        snackPosition: SnackPosition.BOTTOM,
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.playlist_add_rounded,
                    label: "Save to playlist",
                    onTap: () {
                      Navigator.of(context).pop();
                      AddToPlaylistSheet.show(context, song);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.share_rounded,
                    label: "Share",
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: "${song.title} by ${song.artist} on Kukku Music"),
                      );
                      Navigator.of(context).pop();
                      Get.rawSnackbar(
                        message: "Song link copied to clipboard! 📋",
                        duration: const Duration(seconds: 2),
                        margin: const EdgeInsets.all(16),
                        borderRadius: 12,
                        backgroundColor: AppTheme.surface,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),

          // Action List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                _OptionTile(
                  icon: Icons.sensors_rounded,
                  title: "Start mix / Radio",
                  onTap: () async {
                    Navigator.of(context).pop();
                    await playerController.playSong(song);
                  },
                ),
                _OptionTile(
                  icon: Icons.queue_music_rounded,
                  title: "Add to queue",
                  onTap: () {
                    Navigator.of(context).pop();
                    playerController.addToQueue(song);
                    Get.snackbar(
                      'Queue',
                      "Added '${song.title}' to queue",
                      snackPosition: SnackPosition.BOTTOM,
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    );
                  },
                ),
                Obx(() {
                  final isFav = userData.isFavorite(song.id);
                  return _OptionTile(
                    icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    iconColor: isFav ? Colors.redAccent : null,
                    title: isFav ? "Remove from favorites" : "Save to favorites",
                    onTap: () {
                      userData.toggleFavorite(song);
                    },
                  );
                }),
                Obx(() {
                  final isDownloaded = downloadController.downloader.isDownloaded(song.id);
                  return _OptionTile(
                    icon: isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                    iconColor: isDownloaded ? AppTheme.success : null,
                    title: isDownloaded ? "Remove download" : "Download offline",
                    onTap: () {
                      Navigator.of(context).pop();
                      if (isDownloaded) {
                        downloadController.removeDownload(song.id);
                      } else {
                        downloadController.download(song);
                      }
                    },
                  );
                }),
                _OptionTile(
                  icon: Icons.people_outline_rounded,
                  title: "View song credits & info",
                  onTap: () {
                    Navigator.of(context).pop();
                    SongDetailsSheet.show(context, song);
                  },
                ),
                _OptionTile(
                  icon: Icons.playlist_remove_rounded,
                  title: "Dismiss queue",
                  muted: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    playerController.queue.clear();
                    Get.snackbar(
                      'Queue',
                      'Queue dismissed',
                      snackPosition: SnackPosition.BOTTOM,
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 2),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF282828),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool muted;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? (muted ? Colors.white54 : Colors.white),
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: muted ? Colors.white54 : Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      onTap: onTap,
    );
  }
}
