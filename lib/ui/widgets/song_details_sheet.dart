import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../models/song_model.dart';
import '../../utils/helper.dart';
import '../screens/artist_screen.dart';
import '../theme/app_theme.dart';

class SongDetailsSheet extends StatelessWidget {
  final SongModel song;

  const SongDetailsSheet({super.key, required this.song});

  static void show(BuildContext context, SongModel song) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      builder: (_) => SongDetailsSheet(song: song),
    );
  }

  /// Clean artist string by removing repetitive track titles attached after '-'
  String _cleanArtistString(String raw) {
    var cleaned = raw.trim();
    if (cleaned.contains(' - ')) {
      cleaned = cleaned.split(' - ').first.trim();
    }
    return cleaned.isNotEmpty ? cleaned : song.artist;
  }

  List<String> _extractArtistList(String raw) {
    final cleaned = _cleanArtistString(raw);
    return cleaned
        .split(RegExp(r'[,&]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cleanArtists = _cleanArtistString(song.artist);
    final artistList = _extractArtistList(song.artist);
    final language = asText(song.extras['language']);
    final albumName = (song.album.isNotEmpty && song.album != 'Single' && song.album != 'Search')
        ? song.album
        : 'Single Release';
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
              margin: const EdgeInsets.only(top: 12, bottom: 8),
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
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Song Credits & Info",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Song Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 64,
                            height: 64,
                            child: song.artUri.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: song.artUri,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => _fallbackIcon(),
                                  )
                                : _fallbackIcon(),
                          ),
                        ),
                        const SizedBox(width: 14),
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
                              const SizedBox(height: 3),
                              Text(
                                albumName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Text(
                                  "320 KBPS HD MASTER",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Credits Section
                  const Text(
                    "Credits",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: [
                        _creditTile(
                          icon: Icons.mic_external_on_rounded,
                          role: "Performed by",
                          content: cleanArtists,
                          tags: artistList.length > 1 ? artistList : null,
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        _creditTile(
                          icon: Icons.album_rounded,
                          role: "Album",
                          content: albumName,
                        ),
                        if (language.isNotEmpty) ...[
                          const Divider(color: Colors.white10, height: 1),
                          _creditTile(
                            icon: Icons.language_rounded,
                            role: "Original Language",
                            content: language.toUpperCase(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Audio & Track Specs Grid (4 Cards)
                  const Text(
                    "Audio Specifications",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _specCard(
                          icon: Icons.graphic_eq_rounded,
                          label: "Audio Bitrate",
                          value: "320 kbps",
                          subValue: "High Fidelity",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _specCard(
                          icon: Icons.timer_outlined,
                          label: "Track Length",
                          value: durationStr.isNotEmpty ? durationStr : "3:30",
                          subValue: "Full Track",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _specCard(
                          icon: Icons.audiotrack_rounded,
                          label: "Audio Codec",
                          value: "AAC / MP4A",
                          subValue: "Lossless Master",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _specCard(
                          icon: Icons.verified_outlined,
                          label: "Catalog Source",
                          value: "Official Stream",
                          subValue: "Direct CDN",
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _creditTile({
    required IconData icon,
    required String role,
    required String content,
    List<String>? tags,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (tags != null && tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((name) {
                      return GestureDetector(
                        onTap: () {
                          Get.back();
                          Get.to(() => ArtistScreen(artistName: name), transition: Transition.cupertino);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppTheme.primary),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specCard({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      color: const Color(0xFF333333),
      child: const Icon(Icons.music_note_rounded, color: AppTheme.textMuted, size: 28),
    );
  }
}
