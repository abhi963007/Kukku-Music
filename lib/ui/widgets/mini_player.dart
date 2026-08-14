// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../screens/player_screen.dart';
import '../theme/app_theme.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();

    return Obx(() {
      final song = playerController.currentSong.value;
      if (song == null) return const SizedBox.shrink();

      final isPlaying = playerController.isPlaying.value;
      final isBuffering = playerController.isBuffering.value;
      final pos = playerController.position.value.inMilliseconds.toDouble();
      final total = playerController.totalDuration.value.inMilliseconds.toDouble();
      final progress = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;

      return Material(
        color: AppTheme.surface,
        child: InkWell(
          onTap: () {
            Get.to(
              () => const PlayerScreen(),
              transition: Transition.downToUp,
              duration: const Duration(milliseconds: 280),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                  width: 0.8,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top micro progress bar
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2.0,
                  backgroundColor: Colors.white.withOpacity(0.06),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      // Song Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: song.artUri.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: song.artUri,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => Container(
                                    color: AppTheme.surfaceLight,
                                    child: const Icon(Icons.music_note, color: Colors.white70, size: 22),
                                  ),
                                )
                              : Container(
                                  color: AppTheme.surfaceLight,
                                  child: const Icon(Icons.music_note, color: Colors.white70, size: 22),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Song Title & Artist
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Controls
                      if (isBuffering)
                        const SizedBox(
                          width: 38,
                          height: 38,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: playerController.togglePlayPause,
                          splashRadius: 20,
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: AppTheme.textSecondary,
                          size: 26,
                        ),
                        onPressed: playerController.skipNext,
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
