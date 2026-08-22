import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/download_controller.dart';
import '../../controllers/player_controller.dart';
import '../../models/song_model.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/palette_background.dart';
import '../widgets/progress_slider.dart';
import '../widgets/scrolling_text.dart';
import '../widgets/song_details_sheet.dart';
import '../widgets/state_placeholder.dart';
import 'player_layout.dart';

/// Full-screen player.
///
/// Layout is driven by [LayoutBuilder] rather than fixed fractions of the screen
/// width. The previous version sized the artwork at `width * 0.76` inside a
/// `spaceBetween` Column that also held two `Spacer`s, which overflowed in
/// landscape and at large system font scales.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Keyed on the art URL alone so position ticks never rebuild the
          // blur + palette work.
          Positioned.fill(
            child: Obx(() => PaletteBackground(
                  artUri: playerController.currentSong.value?.artUri ?? '',
                )),
          ),
          SafeArea(
            child: Obx(() {
              final song = playerController.currentSong.value;
              if (song == null) {
                return const StatePlaceholder(
                  icon: Icons.music_note_rounded,
                  title: 'Nothing playing',
                  message: 'Pick a track from Home, Search or your Library to start listening.',
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) => _buildLayout(context, constraints, song),
              );
            }),
          ),
        ],
      ),
    );
  }
  Widget _buildLayout(BuildContext context, BoxConstraints c, SongModel song) {
    if (PlayerLayout.isWide(c.maxWidth, c.maxHeight)) {
      return _landscapeLayout(context, c, song);
    }

    // Artwork is sized from the space actually left over (see PlayerLayout), so
    // the column can never overflow. A null result means the viewport is too
    // short for artwork at all.
    final artSize = PlayerLayout.portraitArtworkSize(c.maxWidth, c.maxHeight);
    if (artSize == null) return _compactLayout(context, song);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _TopBar(song: song),
          Expanded(
            child: Center(
              child: _Artwork(song: song, size: artSize),
            ),
          ),
          _TrackMeta(song: song),
          const SizedBox(height: 18),
          const _ProgressSection(),
          const SizedBox(height: 10),
          const _ControlsRow(),
          const SizedBox(height: 10),
          _BottomActions(song: song),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  /// Side-by-side layout for landscape and large tablets, where a square that
  /// fills the width would leave no room for the controls.
  Widget _landscapeLayout(BuildContext context, BoxConstraints c, SongModel song) {
    final artSize = PlayerLayout.landscapeArtworkSize(c.maxWidth, c.maxHeight);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Artwork(song: song, size: artSize),
          const SizedBox(width: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TopBar(song: song, compact: true),
                  const SizedBox(height: 8),
                  _TrackMeta(song: song),
                  const SizedBox(height: 14),
                  const _ProgressSection(),
                  const SizedBox(height: 8),
                  const _ControlsRow(),
                  const SizedBox(height: 8),
                  _BottomActions(song: song),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  /// Very short viewports (split screen, tiny devices, huge font scale):
  /// everything scrolls rather than overflowing.
  Widget _compactLayout(BuildContext context, SongModel song) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          _TopBar(song: song),
          const SizedBox(height: 12),
          _Artwork(song: song, size: 160),
          const SizedBox(height: 16),
          _TrackMeta(song: song),
          const SizedBox(height: 14),
          const _ProgressSection(),
          const SizedBox(height: 8),
          const _ControlsRow(),
          const SizedBox(height: 8),
          _BottomActions(song: song),
        ],
      ),
    );
  }
  static void showQueueSheet(BuildContext context) {
    final controller = Get.find<PlayerController>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (ctx) => _QueueSheet(controller: controller),
    );
  }
}

class _TopBar extends StatelessWidget {
  final SongModel song;
  final bool compact;

  const _TopBar({required this.song, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          color: AppTheme.textPrimary,
          tooltip: 'Close player',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                song.album.isNotEmpty && song.album != 'Unknown Album'
                    ? song.album.toUpperCase()
                    : 'PLAYING FROM STREAM',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              const _AudioBadge(),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.queue_music_rounded, size: 26),
          color: AppTheme.textPrimary,
          tooltip: 'Playing queue',
          onPressed: () => PlayerScreen.showQueueSheet(context),
        ),
      ],
    );
  }
}
class _AudioBadge extends StatelessWidget {
  const _AudioBadge();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    return Obx(() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35), width: 0.8),
          ),
          child: Text(
            controller.audioBadge.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.primaryAccent,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ));
  }
}
class _Artwork extends StatelessWidget {
  final SongModel song;
  final double size;

  const _Artwork({required this.song, required this.size});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    // Artwork is a fixed square, so the source is decoded at the size actually
    // painted (device pixels), avoiding full-resolution decodes of 500x500+ art.
    final decodeSide = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return Obx(() {
      final isPlaying = controller.isPlaying.value;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isPlaying ? 0.55 : 0.35),
              blurRadius: isPlaying ? 34 : 20,
              spreadRadius: isPlaying ? 2 : 0,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Hero(
          tag: kPlayerArtHeroTag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            child: _artImage(decodeSide),
          ),
        ),
      );
    });
  }

  Widget _artImage(int decodeSide) {
    const fallback = ColoredBox(
      color: AppTheme.surfaceLight,
      child: Center(
        child: Icon(Icons.music_note_rounded, size: 72, color: AppTheme.textMuted),
      ),
    );
    if (song.artUri.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: song.artUri,
      fit: BoxFit.cover,
      memCacheWidth: decodeSide,
      memCacheHeight: decodeSide,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => const ColoredBox(color: AppTheme.surfaceLight),
      errorWidget: (_, _, _) => fallback,
    );
  }
}
class _TrackMeta extends StatelessWidget {
  final SongModel song;

  const _TrackMeta({required this.song});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Long titles scroll instead of being truncated.
        ScrollingText(
          text: song.title,
          height: 28,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        ScrollingText(
          text: song.artist,
          height: 22,
          velocity: 22,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Progress bar + time labels. Isolated so the rest of the player does not
/// rebuild on every position tick.
class _ProgressSection extends StatelessWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    return Obx(() => AudioProgressSlider(
          position: controller.position.value,
          bufferedPosition: controller.bufferedPosition.value,
          totalDuration: controller.totalDuration.value,
          onSeek: controller.seekTo,
        ));
  }
}
class _ControlsRow extends StatelessWidget {
  const _ControlsRow();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Obx(() {
          final on = controller.isShuffle.value;
          return IconButton(
            icon: const Icon(Icons.shuffle_rounded, size: 24),
            color: on ? AppTheme.primary : AppTheme.textMuted,
            tooltip: on ? 'Shuffle on' : 'Shuffle off',
            onPressed: controller.toggleShuffle,
          );
        }),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 36),
          color: AppTheme.textPrimary,
          tooltip: 'Previous track',
          onPressed: controller.skipPrevious,
        ),
        const _PlayPauseButton(),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 36),
          color: AppTheme.textPrimary,
          tooltip: 'Next track',
          onPressed: controller.skipNext,
        ),
        Obx(() {
          final mode = controller.repeatMode.value;
          return IconButton(
            icon: Icon(
              mode == AudioServiceRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              size: 24,
            ),
            color: mode != AudioServiceRepeatMode.none ? AppTheme.primary : AppTheme.textMuted,
            tooltip: controller.repeatLabel,
            onPressed: controller.toggleRepeat,
          );
        }),
      ],
    );
  }
}
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();
    return Obx(() {
      final isBuffering = controller.isBuffering.value;
      final isPlaying = controller.isPlaying.value;
      return Semantics(
        button: true,
        label: isPlaying ? 'Pause' : 'Play',
        child: InkWell(
          onTap: controller.togglePlayPause,
          customBorder: const CircleBorder(),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: isBuffering
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        // On the white gradient button a white spinner was
                        // invisible.
                        color: AppTheme.background,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppTheme.background,
                      size: 38,
                    ),
            ),
          ),
        ),
      );
    });
  }
}
class _BottomActions extends StatelessWidget {
  final SongModel song;

  const _BottomActions({required this.song});

  @override
  Widget build(BuildContext context) {
    final downloads = Get.find<DownloadViewController>();

    return Obx(() {
      final isDownloading = downloads.downloader.isDownloading(song.id);
      final isDownloaded = downloads.downloader.isDownloaded(song.id);
      final progress = downloads.downloader.getProgress(song.id);

      Widget downloadWidget;

      if (isDownloading) {
        downloadWidget = _pill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress / 100 : null,
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text('Downloading $progress%',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
            ],
          ),
        );
      } else if (isDownloaded) {
        downloadWidget = _pill(
          borderColor: AppTheme.success.withValues(alpha: 0.3),
          background: AppTheme.success.withValues(alpha: 0.12),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_done_rounded, color: AppTheme.success, size: 16),
              SizedBox(width: 6),
              Text('Offline',
                  style: TextStyle(
                      color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      } else {
        downloadWidget = TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            backgroundColor: AppTheme.surfaceLight.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Download', style: TextStyle(fontSize: 12)),
          onPressed: () => downloads.download(song),
        );
      }

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          downloadWidget,
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            onTap: () => SongDetailsSheet.show(context, song),
            child: _pill(
              background: AppTheme.surfaceLight.withValues(alpha: 0.6),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _pill({required Widget child, Color? background, Color? borderColor}) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppTheme.minTouchTarget - 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background ?? AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Center(child: child),
    );
  }
}
class _QueueSheet extends StatelessWidget {
  final PlayerController controller;

  const _QueueSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    // `useSafeArea: true` on the sheet handles the top inset; the bottom inset
    // is applied to the list so the final row clears the navigation bar.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.65,
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
            padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Playing Queue',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await controller.clearQueue();
                    if (context.mounted) Navigator.of(context).maybePop();
                  },
                  child: const Text('Clear', style: TextStyle(color: AppTheme.primaryAccent)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _QueueList(controller: controller, bottomInset: bottomInset)),
        ],
      ),
    );
  }
}
class _QueueList extends StatelessWidget {
  final PlayerController controller;
  final double bottomInset;

  const _QueueList({required this.controller, required this.bottomInset});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final queue = controller.queue;
      if (queue.isEmpty) {
        return const StatePlaceholder(
          icon: Icons.queue_music_rounded,
          title: 'Queue is empty',
          message: 'Tracks you play or add will show up here.',
        );
      }

      // Compare by index, not by song id: the same track can legitimately
      // appear more than once and the old id check highlighted every copy.
      final activeIndex = controller.currentQueueIndex.value;

      return ListView.builder(
        padding: EdgeInsets.only(bottom: bottomInset + 12),
        itemCount: queue.length,
        itemExtent: 64,
        itemBuilder: (context, index) {
          final item = queue[index];
          final isCurrent = index == activeIndex;
          return ListTile(
            leading: SizedBox(
              width: 24,
              child: isCurrent
                  ? const Icon(Icons.equalizer_rounded, color: AppTheme.primary, size: 20)
                  : Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                    ),
            ),
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent ? AppTheme.primaryAccent : AppTheme.textPrimary,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                fontSize: 14.5,
              ),
            ),
            subtitle: Text(
              item.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            onTap: () => controller.skipToQueueItem(index),
          );
        },
      );
    });
  }
}

