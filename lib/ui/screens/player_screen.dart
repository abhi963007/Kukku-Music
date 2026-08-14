// ignore_for_file: deprecated_member_use, unnecessary_underscores

import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:audio_service/audio_service.dart';

import '../../controllers/download_controller.dart';
import '../../controllers/player_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/progress_slider.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final downloadController = Get.find<DownloadViewController>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Obx(() {
        final song = playerController.currentSong.value;
        if (song == null) {
          return const Center(child: Text("No track playing"));
        }

        final isPlaying = playerController.isPlaying.value;
        final isBuffering = playerController.isBuffering.value;
        final isDownloaded = downloadController.downloader.isDownloaded(song.id);
        final isDownloading = downloadController.downloader.isDownloading(song.id);

        return Stack(
          children: [
            // 1. Blurred background image
            if (song.artUri.isNotEmpty)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: song.artUri,
                  fit: BoxFit.cover,
                ),
              ),
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                child: Container(
                  color: AppTheme.background.withOpacity(0.82),
                ),
              ),
            ),

            // 2. Main Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top App Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32, color: Colors.white),
                          onPressed: () => Get.back(),
                        ),
                        Column(
                          children: [
                            const Text(
                              "PLAYING FROM STREAM",
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10.5,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 0.8),
                              ),
                              child: Text(
                                playerController.audioBadge.value,
                                style: const TextStyle(
                                  color: AppTheme.primaryAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.queue_music_rounded, size: 26, color: Colors.white),
                          onPressed: () => _showQueueBottomSheet(context, playerController),
                        ),
                      ],
                    ),

                    // Artwork Card
                    const Spacer(),
                    Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.76,
                        height: MediaQuery.of(context).size.width * 0.76,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(isPlaying ? 0.35 : 0.15),
                              blurRadius: isPlaying ? 35 : 20,
                              spreadRadius: isPlaying ? 2 : 0,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: song.artUri.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: song.artUri,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: AppTheme.surfaceLight,
                                    child: const Icon(Icons.music_note, size: 80, color: AppTheme.textMuted),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppTheme.surfaceLight,
                                    child: const Icon(Icons.music_note, size: 80, color: AppTheme.textMuted),
                                  ),
                                )
                              : Container(
                                  color: AppTheme.surfaceLight,
                                  child: const Icon(Icons.music_note, size: 80, color: AppTheme.textMuted),
                                ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Track Metadata
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          song.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          song.artist,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Progress Slider
                    AudioProgressSlider(
                      position: playerController.position.value,
                      bufferedPosition: playerController.bufferedPosition.value,
                      totalDuration: playerController.totalDuration.value,
                      onSeek: playerController.seekTo,
                    ),
                    const SizedBox(height: 12),

                    // Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Shuffle Button
                        IconButton(
                          icon: Icon(
                            Icons.shuffle_rounded,
                            color: playerController.isShuffle.value ? AppTheme.primary : AppTheme.textMuted,
                            size: 24,
                          ),
                          onPressed: playerController.toggleShuffle,
                        ),

                        // Skip Previous
                        IconButton(
                          icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
                          onPressed: playerController.skipPrevious,
                        ),

                        // Big Play / Pause Button
                        GestureDetector(
                          onTap: playerController.togglePlayPause,
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.4),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isBuffering
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Icon(
                                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 38,
                                    ),
                            ),
                          ),
                        ),

                        // Skip Next
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
                          onPressed: playerController.skipNext,
                        ),

                        // Repeat Button
                        IconButton(
                          icon: Icon(
                            playerController.repeatMode.value == AudioServiceRepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                            color: playerController.repeatMode.value != AudioServiceRepeatMode.none
                                ? AppTheme.primary
                                : AppTheme.textMuted,
                            size: 24,
                          ),
                          onPressed: playerController.toggleRepeat,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Bottom Action Row (Download Button)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isDownloading)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    value: downloadController.downloader.getProgress(song.id) > 0
                                        ? downloadController.downloader.getProgress(song.id) / 100
                                        : null,
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Downloading ${downloadController.downloader.getProgress(song.id)}%",
                                  style: const TextStyle(fontSize: 12, color: Colors.white),
                                ),
                              ],
                            ),
                          )
                        else if (isDownloaded)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.download_done_rounded, color: AppTheme.success, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "Downloaded for Offline",
                                  style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        else
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              backgroundColor: AppTheme.surfaceLight.withOpacity(0.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text("Download Offline", style: TextStyle(fontSize: 12)),
                            onPressed: () => downloadController.download(song),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showQueueBottomSheet(BuildContext context, PlayerController playerController) {
    Get.bottomSheet(
      Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Playing Queue",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  TextButton(
                    onPressed: () => playerController.audioHandler.customAction('clearQueue'),
                    child: const Text("Clear", style: TextStyle(color: AppTheme.primary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                final queue = playerController.queue;
                if (queue.isEmpty) {
                  return const Center(
                    child: Text("Queue is empty", style: TextStyle(color: AppTheme.textMuted)),
                  );
                }
                return ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    final isCurrent = playerController.currentSong.value?.id == item.id;
                    return ListTile(
                      leading: Text(
                        "${index + 1}",
                        style: TextStyle(
                          color: isCurrent ? AppTheme.primary : AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? AppTheme.primaryAccent : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        item.artist,
                        maxLines: 1,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.equalizer_rounded, color: AppTheme.primary)
                          : null,
                      onTap: () => playerController.audioHandler.skipToQueueItem(index),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
