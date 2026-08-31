import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../../models/song_model.dart';
import '../../services/saavn_service.dart';
import '../data/artist_images.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_placeholder.dart';
import 'album_sheet.dart';

class ArtistScreen extends StatefulWidget {
  final String artistName;

  const ArtistScreen({super.key, required this.artistName});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  final PlayerController _playerController = Get.find<PlayerController>();

  bool _isLoading = true;
  String? _error;
  List<SongModel> _topSongs = [];
  List<AlbumModel> _albums = [];
  bool _isFollowing = false;
  String? _resolvedAvatar;

  @override
  void initState() {
    super.initState();
    _resolvedAvatar = ArtistImages.urlFor(widget.artistName);
    _fetchArtistData();
  }

  Future<void> _fetchArtistData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final name = widget.artistName.trim();
      final results = await Future.wait([
        SaavnService.searchSongs("$name hits", limit: 30),
        SaavnService.searchAlbums(name, limit: 15),
        ArtistImages.fetchDynamically(name),
      ]);

      final songs = results[0] as List<SongModel>;
      final albums = results[1] as List<AlbumModel>;
      final resolvedImg = results[2] as String?;

      // If "$name hits" returned few results, fallback to search with just name
      List<SongModel> finalSongs = songs;
      if (finalSongs.length < 5) {
        final fallback = await SaavnService.searchSongs(name, limit: 30);
        if (fallback.isNotEmpty) finalSongs = fallback;
      }

      if (mounted) {
        setState(() {
          _topSongs = finalSongs;
          _albums = albums;
          if (resolvedImg != null && resolvedImg.isNotEmpty) {
            _resolvedAvatar = resolvedImg;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load artist tracks. Please check connection.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _resolvedAvatar ?? ArtistImages.urlFor(widget.artistName);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Hero Sliver App Bar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: AppTheme.surface,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  onPressed: () => Get.back(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Blurred Background
                  CachedNetworkImage(
                    imageUrl: avatarUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const ColoredBox(color: AppTheme.surfaceLight),
                  ),
                  // Dark Gradient Overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                          AppTheme.background,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                  // Artist Hero Content
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Large Circular Avatar
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => const ColoredBox(color: AppTheme.surfaceLight),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Artist Name & Badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFF3897F0),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Verified Artist",
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.artistName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${_topSongs.length} Tracks • Discography",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Action Buttons (Play All, Shuffle, Follow)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  // Play All Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _topSongs.isEmpty
                          ? null
                          : () => _playerController.playQueue(_topSongs, 0),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: const Text(
                        "Play All",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.background,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Shuffle Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _topSongs.isEmpty
                          ? null
                          : () {
                              final shuffled = List<SongModel>.from(_topSongs)..shuffle();
                              _playerController.playQueue(shuffled, 0);
                            },
                      icon: const Icon(Icons.shuffle_rounded, size: 18),
                      label: const Text(
                        "Shuffle",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Follow Button
                  IconButton(
                    onPressed: () {
                      setState(() => _isFollowing = !_isFollowing);
                    },
                    icon: Icon(
                      _isFollowing ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFollowing ? Colors.redAccent : AppTheme.textPrimary,
                      size: 24,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceLight,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Body Content
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryAccent),
                    SizedBox(height: 16),
                    Text(
                      "Loading artist tracks & albums…",
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: StatePlaceholder(
                  icon: Icons.error_outline_rounded,
                  title: "Unable to load artist",
                  message: _error!,
                  actionLabel: "Try Again",
                  onAction: _fetchArtistData,
                ),
              ),
            )
          else ...[
            // Top Songs Section
            if (_topSongs.isNotEmpty) ...[
              _sectionTitle("Popular Tracks", "Most played hits by ${widget.artistName}"),
              SliverList.builder(
                itemCount: _topSongs.length,
                itemBuilder: (context, index) {
                  final song = _topSongs[index];
                  return SongTile(
                    song: song,
                    onTap: () => _playerController.playQueue(_topSongs, index),
                  );
                },
              ),
            ],

            // Albums & Soundtracks Section
            if (_albums.isNotEmpty) ...[
              _sectionTitle("Albums & Soundtracks", "Discography and featured releases"),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _albums.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final album = _albums[index];
                      return _ArtistAlbumCard(
                        album: album,
                        onTap: () => AlbumSheet.show(context, album),
                      );
                    },
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistAlbumCard extends StatelessWidget {
  final AlbumModel album;
  final VoidCallback onTap;

  const _ArtistAlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: album.artUri,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    color: AppTheme.surfaceLight,
                    child: const Icon(Icons.album_rounded, color: AppTheme.textMuted, size: 36),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            // Year & Songs
            Text(
              album.year.isNotEmpty
                  ? "${album.year} • Album"
                  : (album.songCount > 0 ? "${album.songCount} songs" : "Album"),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
