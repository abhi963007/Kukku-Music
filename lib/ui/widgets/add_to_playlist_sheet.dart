import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/user_data_controller.dart';
import '../../models/song_model.dart';
import '../theme/app_theme.dart';

class AddToPlaylistSheet extends StatelessWidget {
  final SongModel song;

  const AddToPlaylistSheet({super.key, required this.song});

  static void show(BuildContext context, SongModel song) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (_) => AddToPlaylistSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = Get.find<UserDataController>();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Add to Playlist",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Choose or create a playlist",
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  backgroundColor: AppTheme.surfaceLight,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("New Playlist", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showCreatePlaylistDialog(context, userData),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: AppTheme.cardBorder, height: 1),
          const SizedBox(height: 12),

          Expanded(
            child: Obx(() {
              final playlists = userData.playlists;
              if (playlists.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.playlist_add_rounded,
                          size: 48,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "No playlists yet",
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Create your first custom playlist above",
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final p = playlists[index];
                  final isInPlaylist = p.songs.any((s) => s.id == song.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isInPlaylist
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : AppTheme.surfaceLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: isInPlaylist ? AppTheme.primary : AppTheme.cardBorder,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: const Icon(
                          Icons.queue_music_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        "${p.songCount} track${p.songCount == 1 ? '' : 's'}",
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                      ),
                      trailing: isInPlaylist
                          ? const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 22)
                          : const Icon(Icons.add_circle_outline_rounded,
                              color: AppTheme.textSecondary, size: 22),
                      onTap: () {
                        if (isInPlaylist) {
                          userData.removeSongFromPlaylist(p.id, song.id);
                        } else {
                          userData.addSongToPlaylist(p.id, song);
                        }
                      },
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, UserDataController userData) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Text(
          "New Playlist",
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Playlist title...",
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Description (optional)...",
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final title = nameController.text.trim();
              if (title.isNotEmpty) {
                final created = await userData.createPlaylist(
                  name: title,
                  description: descController.text.trim(),
                );
                if (created != null) {
                  await userData.addSongToPlaylist(created.id, song);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text("Create & Add"),
          ),
        ],
      ),
    );
  }
}
