import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../../controllers/search_controller.dart';
import '../../controllers/user_data_controller.dart';
import '../../models/song_model.dart';
import '../../services/music_service.dart';
import '../data/artist_images.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_placeholder.dart';
import 'album_sheet.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int) onNavigateTab;
  const HomeScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MusicServices _musicServices = Get.find<MusicServices>();
  final PlayerController _playerController = Get.find<PlayerController>();

  static const List<String> _languages = [
    "Trending",
    "Malayalam",
    "Tamil",
    "Hindi",
    "Telugu",
    "Kannada",
    "Punjabi",
    "English",
  ];

  String _selectedLanguage = "Trending";
  LanguageHomeData? _homeData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLanguageContent(_selectedLanguage);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon ⚡';
    if (hour < 21) return 'Good Evening 🌙';
    return 'Late Night Melodies ✨';
  }

  Future<void> _loadLanguageContent(String language, {bool forceRefresh = false}) async {
    _playerController.loadRecentSongs();
    if (!mounted) return;
    setState(() {
      _selectedLanguage = language;
      _isLoading = true;
    });

    final userData = Get.isRegistered<UserDataController>() ? Get.find<UserDataController>() : null;
    final userSeeds = <SongModel>[
      if (userData != null) ...userData.favorites,
      if (userData != null) ...userData.history,
    ];

    final data = await _musicServices.getLanguageHomeSections(
      language,
      forceRefresh: forceRefresh,
      userSeeds: userSeeds,
    );
    if (!mounted) return;
    setState(() {
      _homeData = data;
      _isLoading = false;
    });
  }

  bool get _hasContent {
    final data = _homeData;
    return data != null &&
        (data.trending.isNotEmpty ||
            data.movieHits.isNotEmpty ||
            data.topPicks.isNotEmpty ||
            data.albums.isNotEmpty);
  }

  /// Height a carousel card needs, accounting for the user's font scale.
  /// Fixed pixel heights here were the source of overflow at large text sizes.
  double _cardHeight(double artSize, double titleSize, double subtitleSize) {
    final scaler = MediaQuery.textScalerOf(context);
    return artSize +
        10 +
        scaler.scale(titleSize) * 1.35 +
        scaler.scale(subtitleSize) * 1.35;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // The parent Scaffold's bottom bar already occupies the nav-bar inset, so
      // only the top (status bar / punch-hole) inset is consumed here.
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () => _loadLanguageContent(_selectedLanguage, forceRefresh: true),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            // Scrolling the feed dismisses the keyboard left over from Search.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              _searchTrigger(),
              _languageChips(),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (_isLoading)
                ..._loadingSkeleton()
              else if (!_hasContent)
                SliverToBoxAdapter(
                  child: StatePlaceholder(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load $_selectedLanguage hits",
                    message:
                        'Check your connection and pull down to refresh, or try again.',
                    actionLabel: 'Retry',
                    onAction: () =>
                        _loadLanguageContent(_selectedLanguage, forceRefresh: true),
                  ),
                )
              else
                ..._contentSlivers(),
              _recentlyPlayed(),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
  // ── Header ────────────────────────────────────────────────────────────────

  Widget _searchTrigger() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Personalized from your listening taste",
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _loadLanguageContent(_selectedLanguage, forceRefresh: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text(
                          "Refresh",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'Open search',
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                onTap: () => widget.onNavigateTab(1),
                child: Container(
                  constraints: const BoxConstraints(minHeight: AppTheme.minTouchTarget),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Search songs, artists, soundtracks…",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _languageChips() {
    final scaler = MediaQuery.textScalerOf(context);
    return SliverToBoxAdapter(
      child: SizedBox(
        // Grows with the font scale so the chips never clip.
        height: scaler.scale(13) * 1.4 + 28,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _languages.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final label = _languages[index];
            final isSelected = _selectedLanguage.toLowerCase() == label.toLowerCase();

            return Semantics(
              selected: isSelected,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                onTap: () => _loadLanguageContent(label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.primaryGradient : null,
                    color: isSelected ? null : AppTheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : AppTheme.cardBorder,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        // White-on-white was unreadable on the selected chip.
                        color: isSelected ? AppTheme.background : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  // ── Loading skeleton ──────────────────────────────────────────────────────

  List<Widget> _loadingSkeleton() {
    final cardHeight = _cardHeight(150, 13.5, 12);
    return [
      _sectionHeaderSkeleton(),
      SliverToBoxAdapter(
        child: Shimmer(
          child: SizedBox(
            height: cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: 4,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: 150,
                    height: 150,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  SizedBox(height: 10),
                  SkeletonBox(width: 120, height: 11),
                  SizedBox(height: 6),
                  SkeletonBox(width: 80, height: 9),
                ],
              ),
            ),
          ),
        ),
      ),
      _sectionHeaderSkeleton(),
      SliverToBoxAdapter(
        child: Shimmer(
          child: SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, _) => const Column(
                children: [
                  SkeletonCircle(size: 60),
                  SizedBox(height: 10),
                  SkeletonBox(width: 54, height: 9),
                ],
              ),
            ),
          ),
        ),
      ),
      _sectionHeaderSkeleton(),
      SliverList.builder(
        itemCount: 5,
        itemBuilder: (_, _) => const Shimmer(child: _TileSkeleton()),
      ),
    ];
  }
  Widget _sectionHeaderSkeleton() {
    return const SliverToBoxAdapter(
      child: Shimmer(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 160, height: 15),
              SizedBox(height: 8),
              SkeletonBox(width: 110, height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  List<Widget> _contentSlivers() {
    final data = _homeData!;
    return [
      if (data.dailyMix.isNotEmpty) ...[
        _sectionHeader(
          title: "✨ Made For You",
          subtitle: "Daily Mix curated from your listening mood",
          onPlayAll: () => _playerController.playQueue(data.dailyMix, 0),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: _cardHeight(150, 13.5, 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: data.dailyMix.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _SongCard(
                song: data.dailyMix[index],
                artSize: 150,
                titleSize: 13.5,
                subtitleSize: 12,
                showPlayBadge: true,
                onTap: () => _playerController.playQueue(data.dailyMix, index),
              ),
            ),
          ),
        ),
      ],
      if (data.trending.isNotEmpty) ...[
        _sectionHeader(
          title: _selectedLanguage == "Trending"
              ? "🔥 Trending Hits"
              : "$_selectedLanguage Trending Hits",
          subtitle: "Hottest fresh tracks right now",
          onPlayAll: () => _playerController.playQueue(data.trending, 0),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: _cardHeight(150, 13.5, 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: data.trending.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _SongCard(
                song: data.trending[index],
                artSize: 150,
                titleSize: 13.5,
                subtitleSize: 12,
                showPlayBadge: true,
                onTap: () => _playerController.playQueue(data.trending, index),
              ),
            ),
          ),
        ),
      ],
      if (data.artists.isNotEmpty) ...[
        _sectionHeader(title: "Popular Artists", subtitle: "Top musicians & singers"),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 66 + MediaQuery.textScalerOf(context).scale(11.5) * 1.4 + 10,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: data.artists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, index) => _ArtistAvatar(
                name: data.artists[index],
                onTap: () => _searchArtist(data.artists[index]),
              ),
            ),
          ),
        ),
      ],
      if (data.albums.isNotEmpty || data.movieHits.isNotEmpty) ...[
        _sectionHeader(
          title: "Movie Soundtracks & Albums",
          subtitle: "Original film hits & complete albums",
          onPlayAll: data.movieHits.isNotEmpty
              ? () => _playerController.playQueue(data.movieHits, 0)
              : null,
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: _cardHeight(140, 13, 11.5),
            child: data.albums.isNotEmpty
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    itemCount: data.albums.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _AlbumCard(
                      album: data.albums[index],
                      onTap: () => AlbumSheet.show(context, data.albums[index]),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    itemCount: data.movieHits.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _SongCard(
                      song: data.movieHits[index],
                      artSize: 140,
                      titleSize: 13,
                      subtitleSize: 11.5,
                      onTap: () => _playerController.playQueue(data.movieHits, index),
                    ),
                  ),
          ),
        ),
      ],
      if (data.topPicks.isNotEmpty) ...[
        _sectionHeader(
          title: "Essential Melodies & Hits",
          subtitle: "Handpicked for your playlist",
          onPlayAll: () => _playerController.playQueue(data.topPicks, 0),
        ),
        SliverList.builder(
          itemCount: data.topPicks.length,
          itemBuilder: (context, index) => SongTile(
            song: data.topPicks[index],
            onTap: () => _playerController.playQueue(data.topPicks, index),
          ),
        ),
      ],
    ];
  }

  void _searchArtist(String artistName) {
    Get.find<SearchViewController>().searchFor(artistName);
    widget.onNavigateTab(1);
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    VoidCallback? onPlayAll,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Row(
          children: [
            // Expanded so a long localised title cannot push the "Play All"
            // button off-screen.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            if (onPlayAll != null) _PlayAllButton(onTap: onPlayAll),
          ],
        ),
      ),
    );
  }
  // ── Recently played ───────────────────────────────────────────────────────

  Widget _recentlyPlayed() {
    return Obx(() {
      final recents = _playerController.recentSongs;
      if (recents.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

      const maxItems = 8;
      final visible = recents.length > maxItems ? recents.sublist(0, maxItems) : recents;

      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Recently Played",
                          style: TextStyle(
                            fontSize: 17.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          "Jump back into your favourites",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _ClearHistoryButton(onTap: _showClearRecentsDialog),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final song = visible[index];
              return SongTile(
                song: song,
                onTap: () => _playerController.playSong(song),
                onRemoveFromRecent: () => _playerController.removeRecentSong(song.id),
              );
            },
          ),
        ],
      );
    });
  }
  void _showClearRecentsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.history_toggle_off_rounded, color: AppTheme.textSecondary, size: 22),
            SizedBox(width: 10),
            Expanded(child: Text("Clear Recent Songs?")),
          ],
        ),
        content: const Text(
          "This removes your recently played history. Downloads and cached songs are not affected.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.background,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _playerController.clearRecentSongs();
              Get.snackbar(
                "History Cleared",
                "Recently played songs have been cleared",
                snackPosition: SnackPosition.BOTTOM,
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              );
            },
            child: const Text("Clear All"),
          ),
        ],
      ),
    );
  }}

/// Square artwork card used by the trending and movie-hits carousels.
class _SongCard extends StatelessWidget {
  final SongModel song;
  final double artSize;
  final double titleSize;
  final double subtitleSize;
  final bool showPlayBadge;
  final VoidCallback onTap;

  const _SongCard({
    required this.song,
    required this.artSize,
    required this.titleSize,
    required this.subtitleSize,
    required this.onTap,
    this.showPlayBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: onTap,
      child: SizedBox(
        width: artSize,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardArtwork(
              artUri: song.artUri,
              size: artSize,
              badge: showPlayBadge ? const _PlayBadge() : null,
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: titleSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: subtitleSize),
            ),
          ],
        ),
      ),
    );
  }
}
class _AlbumCard extends StatelessWidget {
  final AlbumModel album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Fall back through artist → year → generic label instead of showing an
    // empty second line.
    final subtitle = album.artist.isNotEmpty
        ? album.artist
        : (album.year.isNotEmpty ? "Released ${album.year}" : "Soundtrack");

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardArtwork(
              artUri: album.artUri,
              size: 140,
              badge: const _AlbumBadge(),
              badgeAlignment: Alignment.bottomRight,
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
class _CardArtwork extends StatelessWidget {
  final String artUri;
  final double size;
  final Widget? badge;
  final Alignment badgeAlignment;

  const _CardArtwork({
    required this.artUri,
    required this.size,
    this.badge,
    this.badgeAlignment = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    final decodeSide = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: badgeAlignment,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: artUri.isEmpty
                  ? const ColoredBox(
                      color: AppTheme.surfaceLight,
                      child: Center(
                        child: Icon(Icons.album_rounded, color: AppTheme.textMuted, size: 32),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: artUri,
                      fit: BoxFit.cover,
                      memCacheWidth: decodeSide,
                      memCacheHeight: decodeSide,
                      placeholder: (_, _) =>
                          const ColoredBox(color: AppTheme.surfaceLight),
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: AppTheme.surfaceLight,
                        child: Center(
                          child: Icon(Icons.album_rounded, color: AppTheme.textMuted, size: 32),
                        ),
                      ),
                    ),
            ),
          ),
          if (badge != null) Padding(padding: const EdgeInsets.all(8), child: badge),
        ],
      ),
    );
  }
}
class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient,
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
      ),
      // Dark glyph on the white gradient — it was white-on-white before.
      child: const Icon(Icons.play_arrow_rounded, color: AppTheme.background, size: 18),
    );
  }
}

class _AlbumBadge extends StatelessWidget {
  const _AlbumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.album_rounded, color: AppTheme.primaryAccent, size: 12),
          SizedBox(width: 3),
          Text(
            "Album",
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
class _ArtistAvatar extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _ArtistAvatar({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: AppTheme.surfaceLight,
      child: Center(child: Icon(Icons.person_rounded, color: AppTheme.primaryAccent, size: 24)),
    );

    return Semantics(
      button: true,
      label: 'Search for $name',
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: SizedBox(
          width: 80,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: CachedNetworkImage(
                      imageUrl: ArtistImages.urlFor(name),
                      fit: BoxFit.cover,
                      memCacheWidth: 174,
                      memCacheHeight: 174,
                      placeholder: (_, _) => fallback,
                      errorWidget: (_, _, _) => fallback,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _PlayAllButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PlayAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      onTap: onTap,
      child: Container(
        // 40dp minimum so the chip is comfortably tappable.
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, color: AppTheme.primaryAccent, size: 16),
            SizedBox(width: 3),
            Text(
              "Play All",
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ClearHistoryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ClearHistoryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear_all_rounded, color: AppTheme.textSecondary, size: 16),
            SizedBox(width: 4),
            Text(
              "Clear",
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton row matching [SongTile]'s footprint.
class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 50, height: 50, borderRadius: BorderRadius.all(Radius.circular(10))),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 120, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

