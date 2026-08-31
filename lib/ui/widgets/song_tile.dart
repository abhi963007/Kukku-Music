import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/download_controller.dart';
import '../../controllers/player_controller.dart';
import '../../controllers/user_data_controller.dart';
import '../../models/song_model.dart';
import '../../utils/helper.dart';
import '../theme/app_theme.dart';
import 'add_to_playlist_sheet.dart';

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
      // `isDownloaded` now reads an observable id set instead of hitting the
      // filesystem synchronously on every rebuild.
      final isDownloading = downloadController.downloader.isDownloading(song.id);
      final downloadProgress = downloadController.downloader.getProgress(song.id);
      final isDownloaded = downloadController.downloader.isDownloaded(song.id);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppTheme.primary.withValues(alpha: 0.12)
              : AppTheme.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isCurrent
                ? AppTheme.primary.withValues(alpha: 0.4)
                : AppTheme.cardBorder,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: ListTile(
            onTap: onTap ?? () => playerController.playSong(song),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            // Keeps the thumbnail column a predictable width so titles line up
            // across every list in the app.
            leading: _Thumbnail(artUri: song.artUri, isPlaying: isPlaying),
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
            subtitle: _Subtitle(song: song, isDownloaded: isDownloaded),
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
                    ? _SongMenu(
                        song: song,
                        isDownloaded: isDownloaded,
                        onRemoveFromRecent: onRemoveFromRecent,
                      )
                    : null,
          ),
        ),
      );
    });
  }
}

class _Thumbnail extends StatelessWidget {
  final String artUri;
  final bool isPlaying;

  const _Thumbnail({required this.artUri, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: AppTheme.surfaceLight,
      child: Icon(Icons.music_note_rounded, color: AppTheme.textMuted),
    );

    return SizedBox(
      width: 50,
      height: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (artUri.isEmpty)
              fallback
            else
              CachedNetworkImage(
                imageUrl: artUri,
                fit: BoxFit.cover,
                memCacheWidth: 150,
                memCacheHeight: 150,
                placeholder: (_, _) => const ColoredBox(color: AppTheme.surfaceLight),
                errorWidget: (_, _, _) => fallback,
              ),
            if (isPlaying)
              const ColoredBox(
                color: Colors.black54,
                child: Icon(Icons.equalizer_rounded, color: AppTheme.primary, size: 24),
              ),
          ],
        ),
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  final SongModel song;
  final bool isDownloaded;

  const _Subtitle({required this.song, required this.isDownloaded});

  @override
  Widget build(BuildContext context) {
    return Row(
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
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
          ),
        ),
        if (song.duration > Duration.zero) ...[
          const SizedBox(width: 6),
          Text(
            formatDuration(song.duration),
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _SongMenu extends StatelessWidget {
  final SongModel song;
  final bool isDownloaded;
  final VoidCallback? onRemoveFromRecent;

  const _SongMenu({
    required this.song,
    required this.isDownloaded,
    this.onRemoveFromRecent,
  });

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final downloadController = Get.find<DownloadViewController>();
    final userData = Get.find<UserDataController>();

    final isFav = userData.isFavorite(song.id);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary, size: 20),
      tooltip: 'Track options',
      onSelected: (value) async {
        switch (value) {
          case 'favorite':
            await userData.toggleFavorite(song);
          case 'add_playlist':
            if (context.mounted) AddToPlaylistSheet.show(context, song);
          case 'play_next':
            await playerController.addToQueue(song);
            Get.snackbar(
              'Queue',
              "Added '${song.title}' to queue",
              snackPosition: SnackPosition.BOTTOM,
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            );
          case 'download':
            await downloadController.download(song);
          case 'delete':
            await downloadController.removeDownload(song.id);
          case 'remove_recent':
            onRemoveFromRecent?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'favorite',
          child: _MenuRow(
            icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: isFav ? 'Remove from Favorites' : 'Add to Favorites',
            iconColor: isFav ? Colors.redAccent : null,
          ),
        ),
        const PopupMenuItem(
          value: 'add_playlist',
          child: _MenuRow(icon: Icons.playlist_add_rounded, label: 'Add to Playlist'),
        ),
        const PopupMenuItem(
          value: 'play_next',
          child: _MenuRow(icon: Icons.queue_music_rounded, label: 'Play Next / Queue'),
        ),
        if (!isDownloaded)
          const PopupMenuItem(
            value: 'download',
            child: _MenuRow(icon: Icons.download_rounded, label: 'Download'),
          )
        else
          const PopupMenuItem(
            value: 'delete',
            child: _MenuRow(
              icon: Icons.delete_outline_rounded,
              label: 'Remove Download',
              muted: true,
            ),
          ),
        if (onRemoveFromRecent != null)
          const PopupMenuItem(
            value: 'remove_recent',
            child: _MenuRow(
              icon: Icons.history_toggle_off_rounded,
              label: 'Remove from History',
              muted: true,
            ),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool muted;
  final Color? iconColor;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.muted = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted ? AppTheme.textSecondary : AppTheme.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor ?? color),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}
