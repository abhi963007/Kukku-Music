import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../screens/player_screen.dart';
import '../theme/app_theme.dart';

/// Tag shared with [PlayerScreen] so the artwork animates between the two.
const String kPlayerArtHeroTag = 'kukku-player-artwork';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static void openPlayer() {
    Get.to(
      () => const PlayerScreen(),
      transition: Transition.downToUp,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();

    // Outer Obx depends only on the current track, so the ~10 Hz position
    // updates no longer rebuild the artwork and text (they now live in their
    // own Obx below). Previously one Obx wrapped everything, re-decoding the
    // thumbnail on every tick.
    return Obx(() {
      final song = playerController.currentSong.value;
      if (song == null) return const SizedBox.shrink();

      return Material(
        color: AppTheme.surface,
        child: InkWell(
          onTap: openPlayer,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
              ),
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // Swipe up anywhere on the bar to expand, matching the
              // downToUp page transition.
              onVerticalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -120) openPlayer();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _MiniProgressBar(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Hero(
                          tag: kPlayerArtHeroTag,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: _MiniArtwork(artUri: song.artUri),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                  color: AppTheme.textPrimary,
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
                        const SizedBox(width: 4),
                        const _MiniPlayPauseButton(),
                        IconButton(
                          icon: const Icon(Icons.skip_next_rounded, size: 26),
                          color: AppTheme.textSecondary,
                          tooltip: 'Next track',
                          onPressed: playerController.skipNext,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _MiniArtwork extends StatelessWidget {
  final String artUri;

  const _MiniArtwork({required this.artUri});

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: AppTheme.surfaceLight,
      child: Icon(Icons.music_note_rounded, color: AppTheme.textSecondary, size: 22),
    );
    if (artUri.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: artUri,
      fit: BoxFit.cover,
      // Decode at display size instead of full resolution.
      memCacheWidth: 132,
      memCacheHeight: 132,
      placeholder: (context, url) => const ColoredBox(color: AppTheme.surfaceLight),
      errorWidget: (context, url, error) => fallback,
    );
  }
}

/// Thin progress line at the top of the bar. Isolated so its high-frequency
/// rebuilds stay cheap.
class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    return Obx(() {
      final total = controller.totalDuration.value.inMilliseconds;
      final pos = controller.position.value.inMilliseconds;
      final progress = total > 0 ? (pos / total).clamp(0.0, 1.0) : 0.0;
      return LinearProgressIndicator(
        value: progress,
        minHeight: 2.0,
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
      );
    });
  }
}

class _MiniPlayPauseButton extends StatelessWidget {
  const _MiniPlayPauseButton();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    return Obx(() {
      if (controller.isBuffering.value) {
        return const SizedBox(
          width: AppTheme.minTouchTarget,
          height: AppTheme.minTouchTarget,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
          ),
        );
      }
      final playing = controller.isPlaying.value;
      return IconButton(
        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
        color: AppTheme.textPrimary,
        tooltip: playing ? 'Pause' : 'Play',
        onPressed: controller.togglePlayPause,
      );
    });
  }
}
