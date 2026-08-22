import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../../models/song_model.dart';
import '../../services/saavn_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_placeholder.dart';

/// Bottom sheet showing an album's tracklist.
class AlbumSheet extends StatefulWidget {
  final AlbumModel album;

  const AlbumSheet({super.key, required this.album});

  static Future<void> show(BuildContext context, AlbumModel album) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (_) => AlbumSheet(album: album),
    );
  }

  @override
  State<AlbumSheet> createState() => _AlbumSheetState();
}

class _AlbumSheetState extends State<AlbumSheet> {
  // Created once in initState. Building the future inside `FutureBuilder`
  // re-issued the network request on every rebuild of the sheet.
  late final Future<AlbumModel?> _details =
      SaavnService.getAlbumDetails(widget.album.id);

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      height: maxHeight,
      child: FutureBuilder<AlbumModel?>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryAccent),
                  SizedBox(height: 16),
                  Text("Loading album tracks…",
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                ],
              ),
            );
          }

          final albumData = snapshot.data ?? widget.album;
          final songs = albumData.songs;

          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(album: albumData),
                const SizedBox(height: 16),
                if (songs.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        playerController.playQueue(songs, 0);
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 24),
                      label: Text(
                        "Play all (${songs.length} ${songs.length == 1 ? 'track' : 'tracks'})",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.background,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Divider(),
                Expanded(
                  child: songs.isEmpty
                      ? StatePlaceholder(
                          icon: Icons.library_music_outlined,
                          title: snapshot.hasError
                              ? "Couldn't load this album"
                              : "No tracks found",
                          message: snapshot.hasError
                              ? 'Check your connection and try again.'
                              : 'This album has no playable tracks right now.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 4),
                          itemCount: songs.length,
                          itemBuilder: (context, index) => SongTile(
                            song: songs[index],
                            onTap: () {
                              Navigator.of(context).pop();
                              playerController.playQueue(songs, index);
                            },
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AlbumModel album;

  const _Header({required this.album});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 80,
            height: 80,
            child: album.artUri.isEmpty
                ? const ColoredBox(
                    color: AppTheme.surfaceLight,
                    child: Center(
                      child: Icon(Icons.album_rounded, color: AppTheme.textMuted),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: album.artUri,
                    fit: BoxFit.cover,
                    memCacheWidth: 240,
                    memCacheHeight: 240,
                    placeholder: (_, _) => const ColoredBox(color: AppTheme.surfaceLight),
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: AppTheme.surfaceLight),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                album.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                album.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              if (album.year.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  "Released ${album.year}",
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
