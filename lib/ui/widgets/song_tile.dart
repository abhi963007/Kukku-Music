// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/download_controller.dart';
import '../../controllers/player_controller.dart';
import '../../models/song_model.dart';
import '../../utils/helper.dart';
import '../theme/app_theme.dart';

class SongTile extends StatelessWidget {
  final SongModel song;
  final VoidCallback? onTap;
  final VoidCallback? onRemoveFromRecent;
  final bool showMenu;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onRemoveFromRecent,
    this.showMenu = true,
  });

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final downloadController = Get.find<DownloadViewController>();

    return Obx(() {
      final isCurrent = playerController.currentSong.value?.id == song.id;
      final isPlaying = isCurrent && playerController.isPlaying.value;
      final isDownloading = downloadController.downloader.isDownloading(song.id);
      final downloadProgress = downloadController.downloader.getProgress(song.id);
      final isDownloaded = downloadController.downloader.isDownloaded(song.id);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isCurrent ? AppTheme.primary.withOpacity(0.12) : AppTheme.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent ? AppTheme.primary.withOpacity(0.4) : AppTheme.cardBorder,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            onTap: onTap ?? () => playerController.playSong(song),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: song.artUri.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: song.artUri,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppTheme.surfaceLight,
                            child: const Icon(Icons.music_note, color: AppTheme.textMuted),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppTheme.surfaceLight,
                            child: const Icon(Icons.music_note, color: AppTheme.textMuted),
                          ),
                        )
                      : Container(
                          color: AppTheme.surfaceLight,
                          child: const Icon(Icons.music_note, color: AppTheme.textMuted),
                        ),
                ),
              ),
              if (isPlaying)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.equalizer, color: AppTheme.primary, size: 24),
                ),
            ],
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent ? AppTheme.primaryAccent : AppTheme.textPrimary,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
          subtitle: Row(
            children: [
              if (isDownloaded)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.download_done_rounded, color: AppTheme.success, size: 14),
                ),
              Expanded(
                child: Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (song.duration > Duration.zero)
                Text(
                  formatDuration(song.duration),
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11.5,
                  ),
                ),
            ],
          ),
          trailing: isDownloading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: downloadProgress > 0 ? downloadProgress / 100.0 : null,
                    strokeWidth: 2.5,
                    color: AppTheme.primary,
                  ),
                )
              : showMenu
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
                      color: AppTheme.surfaceLight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) async {
                        if (value == 'play_next') {
                          await playerController.addToQueue(song);
                          Get.snackbar("Queue", "Added '${song.title}' to queue",
                              backgroundColor: AppTheme.surface, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
                        } else if (value == 'download') {
                          downloadController.download(song);
                        } else if (value == 'delete') {
                          await downloadController.removeDownload(song.id);
                        } else if (value == 'remove_recent') {
                          onRemoveFromRecent?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'play_next',
                          child: Row(
                            children: [
                              Icon(Icons.playlist_add_rounded, size: 18, color: Colors.white),
                              SizedBox(width: 10),
                              Text("Add to Queue"),
                            ],
                          ),
                        ),
                        if (!isDownloaded)
                          const PopupMenuItem(
                            value: 'download',
                            child: Row(
                              children: [
                                Icon(Icons.download_rounded, size: 18, color: Colors.white),
                                SizedBox(width: 10),
                                Text("Download"),
                              ],
                            ),
                          )
                        else
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.textSecondary),
                                SizedBox(width: 10),
                                Text("Remove Download", style: TextStyle(color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        if (onRemoveFromRecent != null)
                          const PopupMenuItem(
                            value: 'remove_recent',
                            child: Row(
                              children: [
                                Icon(Icons.history_toggle_off_rounded, size: 18, color: AppTheme.textSecondary),
                                SizedBox(width: 10),
                                Text("Remove from History", style: TextStyle(color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                      ],
                    )
                  : null,
          ),
        ),
      );
    });
  }
}
