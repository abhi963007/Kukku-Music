import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../../controllers/user_data_controller.dart';
import '../../models/song_model.dart';
import '../theme/app_theme.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/mini_player.dart';
import '../widgets/palette_background.dart';
import '../widgets/progress_slider.dart';
import '../widgets/song_details_sheet.dart';
import '../widgets/state_placeholder.dart';
import '../widgets/yt_track_options_sheet.dart';
import 'player_layout.dart';

/// Full-screen player in YouTube Music style.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Dynamic palette ambient backdrop
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

    final artSize = PlayerLayout.portraitArtworkSize(c.maxWidth, c.maxHeight);
    if (artSize == null) return _compactLayout(context, song);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _TopBar(song: song),
          Expanded(
            child: Center(
              child: _Artwork(song: song, size: artSize),
            ),
          ),
          _TrackMeta(song: song),
          const SizedBox(height: 14),
          _ActionPillsRow(song: song),
          const SizedBox(height: 14),
          const _ProgressSection(),
          const SizedBox(height: 6),
          const _ControlsRow(),
          const SizedBox(height: 10),
          _BottomUpNextBar(song: song),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _landscapeLayout(BuildContext context, BoxConstraints c, SongModel song) {
    final artSize = PlayerLayout.landscapeArtworkSize(c.maxWidth, c.maxHeight);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                  const SizedBox(height: 10),
                  _ActionPillsRow(song: song),
                  const SizedBox(height: 12),
                  const _ProgressSection(),
                  const SizedBox(height: 6),
                  const _ControlsRow(),
                  const SizedBox(height: 6),
                  _BottomUpNextBar(song: song),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactLayout(BuildContext context, SongModel song) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          _TopBar(song: song),
          const SizedBox(height: 12),
          _Artwork(song: song, size: 160),
          const SizedBox(height: 14),
          _TrackMeta(song: song),
          const SizedBox(height: 12),
          _ActionPillsRow(song: song),
          const SizedBox(height: 12),
          const _ProgressSection(),
          const SizedBox(height: 6),
          const _ControlsRow(),
          const SizedBox(height: 8),
          _BottomUpNextBar(song: song),
        ],
      ),
    );
  }

  static void showQueueSheet(BuildContext context) {
    final controller = Get.find<PlayerController>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (ctx) => _QueueSheet(controller: controller),
    );
  }
}

/// 1. Top Bar: Chevron down + Audio/Video Switcher + Cast + 3-dots Menu (YT Music)
class _TopBar extends StatelessWidget {
  final SongModel song;
  final bool compact;

  const _TopBar({required this.song, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          color: AppTheme.textPrimary,
          tooltip: 'Close player',
          onPressed: () => Navigator.of(context).maybePop(),
        ),

        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Obx(() => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      playerController.audioBadge.value,
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )),
            ],
          ),
        ),

        IconButton(
          icon: const Icon(Icons.more_vert_rounded, size: 24),
          color: AppTheme.textPrimary,
          tooltip: 'Track options',
          onPressed: () => YtTrackOptionsSheet.show(context, song),
        ),
      ],
    );
  }
}

/// 2. Artwork: Smooth rounded square (YT Music)
class _Artwork extends StatelessWidget {
  final SongModel song;
  final double size;

  const _Artwork({required this.song, required this.size});

  @override
  Widget build(BuildContext context) {
    final decodeSide = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 28,
            spreadRadius: 1,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Hero(
        tag: kPlayerArtHeroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: _artImage(decodeSide),
        ),
      ),
    );
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
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, _) => const ColoredBox(color: AppTheme.surfaceLight),
      errorWidget: (_, _, _) => fallback,
    );
  }
}

/// 3. Track Metadata: Title with '>' chevron + Artist (YT Music)
class _TrackMeta extends StatelessWidget {
  final SongModel song;

  const _TrackMeta({required this.song});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => SongDetailsSheet.show(context, song),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 24),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 4. Action Pills Row (YouTube Music Action Bar: Fav, Credits, Save)
class _ActionPillsRow extends StatelessWidget {
  final SongModel song;

  const _ActionPillsRow({required this.song});

  @override
  Widget build(BuildContext context) {
    final userData = Get.find<UserDataController>();

    return Row(
      children: [
        // 1. Fav (Favorite) Pill
        Expanded(
          child: Obx(() {
            final isFav = userData.isFavorite(song.id);
            return _ActionPill(
              icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              iconColor: isFav ? Colors.redAccent : Colors.white,
              label: isFav ? "Favorited" : "Fav",
              textColor: isFav ? Colors.redAccent : Colors.white,
              onTap: () => userData.toggleFavorite(song),
            );
          }),
        ),

        const SizedBox(width: 10),

        // 2. Credits / Info Pill
        Expanded(
          child: _ActionPill(
            icon: Icons.info_outline_rounded,
            label: "Credits",
            onTap: () => SongDetailsSheet.show(context, song),
          ),
        ),

        const SizedBox(width: 10),

        // 3. Save to Playlist Pill
        Expanded(
          child: _ActionPill(
            icon: Icons.playlist_add_rounded,
            label: "Save",
            onTap: () => AddToPlaylistSheet.show(context, song),
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF262626),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: iconColor ?? Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5. Progress Section: Slim seek bar with elapsed time & remaining/total duration
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

/// 6. Playback Controls Row (Shuffle, Previous, Big Circular Play/Pause, Next, Repeat)
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
            color: on ? AppTheme.primary : Colors.white70,
            tooltip: on ? 'Shuffle on' : 'Shuffle off',
            onPressed: controller.toggleShuffle,
          );
        }),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 40),
          color: Colors.white,
          tooltip: 'Previous track',
          onPressed: controller.skipPrevious,
        ),
        const _PlayPauseButton(),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 40),
          color: Colors.white,
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
            color: mode != AudioServiceRepeatMode.none ? AppTheme.primary : Colors.white70,
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: isBuffering
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.black,
                      ),
                    )
                  : Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 38,
                      color: Colors.black,
                    ),
            ),
          ),
        ),
      );
    });
  }
}

/// 7. Bottom Up Next Bar (YouTube Music Style: Drag handle + Station/Queue name)
class _BottomUpNextBar extends StatelessWidget {
  final SongModel song;

  const _BottomUpNextBar({required this.song});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PlayerController>();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => PlayerScreen.showQueueSheet(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 6),
          Obx(() {
            final queueLen = controller.queue.length;
            final subtitle = queueLen > 0
                ? "Up Next • $queueLen tracks in queue"
                : (song.album.isNotEmpty && song.album != 'Unknown Album'
                    ? "${song.album} Mix"
                    : "Continuous Auto Radio");

            return Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// 8. Queue Bottom Sheet
class _QueueSheet extends StatelessWidget {
  final PlayerController controller;

  const _QueueSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Up Next',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
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
          const Divider(color: Colors.white10, height: 1),
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

      final activeIndex = controller.currentQueueIndex.value;

      return ListView.builder(
        padding: EdgeInsets.only(bottom: bottomInset + 16),
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
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
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
            trailing: IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 18),
              onPressed: () => YtTrackOptionsSheet.show(context, item),
            ),
            onTap: () => controller.skipToQueueItem(index),
          );
        },
      );
    });
  }
}
