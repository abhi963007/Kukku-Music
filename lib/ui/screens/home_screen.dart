// ignore_for_file: deprecated_member_use

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../../controllers/search_controller.dart';
import '../../models/song_model.dart';
import '../../services/music_service.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigateTab;
  const HomeScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MusicServices _musicServices = Get.find<MusicServices>();
  final PlayerController _playerController = Get.find<PlayerController>();

  final List<Map<String, dynamic>> _languages = [
    {"label": "Trending", "code": "trending", "icon": "🔥"},
    {"label": "Malayalam", "code": "malayalam", "icon": "🌴"},
    {"label": "Tamil", "code": "tamil", "icon": "⚡"},
    {"label": "Hindi", "code": "hindi", "icon": "🎵"},
    {"label": "Telugu", "code": "telugu", "icon": "⭐"},
    {"label": "Kannada", "code": "kannada", "icon": "🎶"},
    {"label": "Punjabi", "code": "punjabi", "icon": "💥"},
    {"label": "English", "code": "english", "icon": "🌍"},
  ];

  String _selectedLanguage = "Trending";
  LanguageHomeData? _homeData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLanguageContent(_selectedLanguage);
  }

  Future<void> _loadLanguageContent(String language) async {
    _playerController.loadRecentSongs();
    setState(() {
      _selectedLanguage = language;
      _isLoading = true;
    });

    final data = await _musicServices.getLanguageHomeSections(language);
    if (mounted) {
      setState(() {
        _homeData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          onRefresh: () => _loadLanguageContent(_selectedLanguage),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header & Branding ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppTheme.primaryGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x66FF2A6D),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Kukku",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    "Free • Ad-Free • HQ Audio",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.35)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: AppTheme.primaryAccent, size: 15),
                                SizedBox(width: 4),
                                Text(
                                  "PREMIUM",
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryAccent,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search Trigger Bar
                      GestureDetector(
                        onTap: () => widget.onNavigateTab(1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 22),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Search songs, artists, movie soundtracks...",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Language Filter Chips Bar ───────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 46,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _languages.length,
                    itemBuilder: (context, index) {
                      final lang = _languages[index];
                      final isSelected = _selectedLanguage.toLowerCase() == (lang["label"] as String).toLowerCase();

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _loadLanguageContent(lang["label"] as String),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected ? AppTheme.primaryGradient : null,
                              color: isSelected ? null : AppTheme.surface.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : AppTheme.cardBorder,
                                width: 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withOpacity(0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(lang["icon"] as String, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  lang["label"] as String,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Content Loading Skeleton or Categorized Sections ───────────
              if (_isLoading)
                SliverToBoxAdapter(
                  child: Container(
                    height: 280,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
                        const SizedBox(height: 16),
                        Text(
                          "Loading $_selectedLanguage hits...",
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // ── SECTION 1: Trending & Top Hits (Horizontal Cards) ────────
                if (_homeData != null && _homeData!.trending.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: "$_selectedLanguage Trending Hits",
                    subtitle: "Hottest tracks right now",
                    onPlayAll: () => _playerController.playQueue(_homeData!.trending, 0),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 225,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _homeData!.trending.length,
                        itemBuilder: (context, index) {
                          final song = _homeData!.trending[index];
                          return _buildLargeSongCard(song, _homeData!.trending, index);
                        },
                      ),
                    ),
                  ),
                ],

                // ── SECTION 2: Popular Artists in Language ──────────────────
                if (_homeData != null && _homeData!.artists.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: "Popular Artists",
                    subtitle: "Top musicians & singers",
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 105,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _homeData!.artists.length,
                        itemBuilder: (context, index) {
                          final artistName = _homeData!.artists[index];
                          return _buildArtistAvatar(artistName);
                        },
                      ),
                    ),
                  ),
                ],

                // ── SECTION 3: Movie Soundtracks & Albums ────────────────────
                if (_homeData != null && _homeData!.movieHits.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: "Movie Soundtracks & Albums",
                    subtitle: "Original film hits & albums",
                    onPlayAll: () => _playerController.playQueue(_homeData!.movieHits, 0),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 215,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _homeData!.movieHits.length,
                        itemBuilder: (context, index) {
                          final song = _homeData!.movieHits[index];
                          return _buildSquareMovieCard(song, _homeData!.movieHits, index);
                        },
                      ),
                    ),
                  ),
                ],

                // ── SECTION 4: Top Melodies & Picks (List View) ──────────────
                if (_homeData != null && _homeData!.topPicks.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: "Essential Melodies & Hits",
                    subtitle: "Handpicked for your playlist",
                    onPlayAll: () => _playerController.playQueue(_homeData!.topPicks, 0),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = _homeData!.topPicks[index];
                        return SongTile(
                          song: song,
                          onTap: () => _playerController.playQueue(_homeData!.topPicks, index),
                        );
                      },
                      childCount: _homeData!.topPicks.take(8).length,
                    ),
                  ),
                ],

                // ── Empty State / Error Fallback ─────────────────────────────
                if (_homeData != null &&
                    _homeData!.trending.isEmpty &&
                    _homeData!.movieHits.isEmpty &&
                    _homeData!.topPicks.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.refresh_rounded, color: AppTheme.primaryAccent, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            "Could not load $_selectedLanguage hits",
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Tap below to refresh and load songs",
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _loadLanguageContent(_selectedLanguage),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text("Retry"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],

              // ── SECTION 5: Recently Played (with Clear All) ────────────────
              Obx(() {
                final recents = _playerController.recentSongs;
                if (recents.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Recently Played",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  "Jump back into your favorites",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _showClearRecentsDialog(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.cardBorder),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.clear_all_rounded, color: AppTheme.textSecondary.withOpacity(0.9), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Clear",
                                      style: TextStyle(
                                        color: AppTheme.textSecondary.withOpacity(0.9),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = recents[index];
                          return SongTile(
                            song: song,
                            onTap: () => _playerController.playSong(song),
                            onRemoveFromRecent: () => _playerController.removeRecentSong(song.id),
                          );
                        },
                        childCount: recents.take(8).length,
                      ),
                    ),
                  ],
                );
              }),

              const SliverToBoxAdapter(
                child: SizedBox(height: 110),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  SliverToBoxAdapter _buildSectionHeader({
    required String title,
    required String subtitle,
    VoidCallback? onPlayAll,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
            if (onPlayAll != null)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onPlayAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.play_arrow_rounded, color: AppTheme.primaryAccent, size: 16),
                      SizedBox(width: 2),
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeSongCard(SongModel song, List<SongModel> queue, int index) {
    return GestureDetector(
      onTap: () => _playerController.playQueue(queue, index),
      child: Container(
        width: 150,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 150,
                    height: 150,
                    child: song.artUri.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: song.artUri,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppTheme.surfaceLight),
                            errorWidget: (context, url, error) => Container(color: AppTheme.surfaceLight),
                          )
                        : Container(color: AppTheme.surfaceLight),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [
                      BoxShadow(color: Colors.black45, blurRadius: 8),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareMovieCard(SongModel song, List<SongModel> queue, int index) {
    return GestureDetector(
      onTap: () => _playerController.playQueue(queue, index),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 140,
                height: 140,
                child: song.artUri.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: song.artUri,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: AppTheme.surfaceLight),
                        errorWidget: (context, url, error) => Container(color: AppTheme.surfaceLight),
                      )
                    : Container(color: AppTheme.surfaceLight),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    );
  }

  static final Map<String, String> _artistImageMap = {
    // English & Global
    "the weeknd": "https://lh3.googleusercontent.com/U-SAmNOu4TynE818gLCfKsuHZ0U5YNEtO9mrjSI9WCCKERs98LzrCal5kajBBTQNwdcisoB2Bn-pHp4=w300-h300-l90-rj",
    "taylor swift": "https://yt3.googleusercontent.com/RCpTA6EXJQyjVFDosWOKa2SMmqkua_lA9mHPDWWciLwgqpZLz-k8rXWRF_367trrQ7up9BUwCbk6kRk=w300-h300-l90-rj",
    "ed sheeran": "https://lh3.googleusercontent.com/jQoBIAS6JjFGpcqQY1M_Mh3AasOvFENCdVRxkgax1a0K6qiq7AgE3MbJ6Jtt-Jndcarvoawmrg66KTny=w300-h300-l90-rj",
    "dua lipa": "https://lh3.googleusercontent.com/aFx8s1fTuelgxONGbezmTG0EKR8r82uB5H-Q6ZJtssyCWLJWF8GfZNr4tHo84sXdFCPBKrA4R6zXOss=w300-h300-l90-rj",
    "bruno mars": "https://lh3.googleusercontent.com/hnefGBrazRhn4Z92bdSZBUENl40ONjRiVDsmZKZh-WZ2iCKE-2c7KKR7SNcZfzLHoRyB3E6as8L87YA=w300-h300-l90-rj",
    "billie eilish": "https://lh3.googleusercontent.com/tQC4rOL6xz6FhmFr0ggQExxyGbYSOsyveXVSnPBh2WjEyIzQ9pMHablLJ-0GlMBrLBlBrbWQGmzrV6KN=w300-h300-l90-rj",

    // Malayalam
    "sushin shyam": "https://yt3.googleusercontent.com/YlcHWu5-x5LKoVkv80_D533SdNG_mly1WtLAkcUcFwuVGWSHgU_q-3-SFQgj8XXg8q8UZXPacg=w300-h300-l90-rj",
    "vineeth sreenivasan": "https://yt3.googleusercontent.com/isgoBrKE_FX5f7p62FOWXZhF6XaIxghoNgn_DfEN4UpzDk6HhyEvR0TIg1xAdBG3_bWRlV9gY5XPnFQW=w300-h300-l90-rj",
    "k.j. yesudas": "https://yt3.googleusercontent.com/R6D0x83Uvnnhdy55hbdpi4SS0I3xqYZsqr_WcsGY0SlQOimmh2HJrkq3KMunG0l9ymm1gGbvtYp_HJw=w300-h300-l90-rj",
    "ks chithra": "https://yt3.googleusercontent.com/cFho6QFr9dAAQ7bspBLLi6jkuASqcgmFpgC4s3mnuSZkrUnGU9Zj6EZS5AlbKNv0gVFdw3CEVEGKaQ=w300-h300-l90-rj",
    "shaan rahman": "https://yt3.googleusercontent.com/k5pNm8lS42NNm5OY97Ic0tKps-6zg-AAp_0h0MfHzCcSmiXSgV6U3HkHvPNjDS6-v_fQuYm6sk2AodfT=w300-h300-l90-rj",

    // Tamil
    "anirudh": "https://lh3.googleusercontent.com/wBG4jypwBcEGHd-qSbM2_4B46WPEhlOCjusCOEkxdnsoIC4WLS9LmFARZsE854pB-vAEYlsp4x2yiHE=w300-h300-l90-rj",
    "anirudh ravichander": "https://lh3.googleusercontent.com/wBG4jypwBcEGHd-qSbM2_4B46WPEhlOCjusCOEkxdnsoIC4WLS9LmFARZsE854pB-vAEYlsp4x2yiHE=w300-h300-l90-rj",
    "a.r. rahman": "https://yt3.googleusercontent.com/vHMOuDn8gr3SW9Pm8yFgmtYzM5kj4ayng5HKRjW0OyjG9mPK923XMVtTZTt4NUG_1aemWNLSQ27zjtA=w300-h300-l90-rj",
    "harris jayaraj": "https://yt3.googleusercontent.com/W_a-fL77QPLAfg_VjUFgI5yUqGV7iPWjJV2cen9SudtT4p1Ivpx-8CxyAJX9y7xK_ts7rHzpAqvob_J9=w300-h300-l90-rj",
    "yuvan shankar raja": "https://lh3.googleusercontent.com/-IRVL5B0n7-V9Gh9XZvQG161HYqkH_SNSHfJwWYeIcVVh35sMq9-jHTk1FCeAmeUHSdEq7UMpoVzUPw=w300-h300-l90-rj",
    "sid sriram": "https://yt3.googleusercontent.com/Ip35qauI_vMztXkJ3Wd6etvLwiyRrHIGvDyKK3714vyWMBx1ogHxPxkA8ohPnOLyy68wzEVBblPmsHHU=w300-h300-l90-rj",
    "dhibu ninan": "https://lh3.googleusercontent.com/wBG4jypwBcEGHd-qSbM2_4B46WPEhlOCjusCOEkxdnsoIC4WLS9LmFARZsE854pB-vAEYlsp4x2yiHE=w300-h300-l90-rj",

    // Hindi
    "arijit singh": "https://lh3.googleusercontent.com/W_yOqnKSDYyeVOY_AsXhuAtb6rW3vCL3GtJ9DA1GxWOrJfyeSOqzvTv_TkFHijdkVPXWutASBlRFPg=w300-h300-l90-rj",
    "shreya ghoshal": "https://yt3.ggpht.com/PgINZNe0qVxgMSXKG5vF82bNN4WCC12zgWsz9I7OLs4CLF9Cn0Vxq7Xc1ToupnzXrCv0nKfe3VM=w300-h300-l90-rj",
    "pritam": "https://yt3.googleusercontent.com/sjGMYJQ1J3FZEIBsMYUztMjjYOM4-NJ24CjmIHqxTWCxAM1YgjL-d_17u7_PRhTouOwwAjbu-2x5S6I=w300-h300-l90-rj",
    "atif aslam": "https://yt3.googleusercontent.com/ykJkyILKum4B2oudDxjnf5WNenWWZAp-WEz0_CHp4cu0VnqB2-uaNDylItqC68WLXV62rdHDun-ahbg=w300-h300-l90-rj",
    "armaan malik": "https://lh3.googleusercontent.com/ZksW8_EkjShyDT_9OMxSw-yMRMG3FNDU6DPI0YtGowyfD5aSlWd63qbm3q4guIqVcGQ6cgFylRQ1EQ=w300-h300-l90-rj",
    "vishal-shekhar": "https://yt3.googleusercontent.com/sjGMYJQ1J3FZEIBsMYUztMjjYOM4-NJ24CjmIHqxTWCxAM1YgjL-d_17u7_PRhTouOwwAjbu-2x5S6I=w300-h300-l90-rj",

    // Telugu
    "thaman s": "https://yt3.googleusercontent.com/1u69o5eBH1yxnBh5QZ65vkQGwmgdwVv-ILISp-MLhkpXHK7AXgE52JbouQpDMhvDRwpHy3By6ETcRA4=w300-h300-l90-rj",
    "devi sri prasad": "https://yt3.googleusercontent.com/Jn3s6U5foBczx3HoJuiVN6euF7QRB1b8rsp3lecxZ7EwumQ-27E_iR2uu8fJV0H6cctb74s5nut_dhM=w300-h300-l90-rj",
    "anurag kulkarni": "https://yt3.googleusercontent.com/Ip35qauI_vMztXkJ3Wd6etvLwiyRrHIGvDyKK3714vyWMBx1ogHxPxkA8ohPnOLyy68wzEVBblPmsHHU=w300-h300-l90-rj",
    "ram miriyala": "https://yt3.googleusercontent.com/Jn3s6U5foBczx3HoJuiVN6euF7QRB1b8rsp3lecxZ7EwumQ-27E_iR2uu8fJV0H6cctb74s5nut_dhM=w300-h300-l90-rj",

    // Kannada
    "ravi basrur": "https://yt3.googleusercontent.com/1u69o5eBH1yxnBh5QZ65vkQGwmgdwVv-ILISp-MLhkpXHK7AXgE52JbouQpDMhvDRwpHy3By6ETcRA4=w300-h300-l90-rj",
    "arjun janya": "https://yt3.googleusercontent.com/vHMOuDn8gr3SW9Pm8yFgmtYzM5kj4ayng5HKRjW0OyjG9mPK923XMVtTZTt4NUG_1aemWNLSQ27zjtA=w300-h300-l90-rj",
    "charan raj": "https://yt3.googleusercontent.com/YlcHWu5-x5LKoVkv80_D533SdNG_mly1WtLAkcUcFwuVGWSHgU_q-3-SFQgj8XXg8q8UZXPacg=w300-h300-l90-rj",
    "sanjith hegde": "https://yt3.googleusercontent.com/Ip35qauI_vMztXkJ3Wd6etvLwiyRrHIGvDyKK3714vyWMBx1ogHxPxkA8ohPnOLyy68wzEVBblPmsHHU=w300-h300-l90-rj",
    "vijay prakash": "https://yt3.googleusercontent.com/R6D0x83Uvnnhdy55hbdpi4SS0I3xqYZsqr_WcsGY0SlQOimmh2HJrkq3KMunG0l9ymm1gGbvtYp_HJw=w300-h300-l90-rj",

    // Punjabi
    "diljit dosanjh": "https://yt3.googleusercontent.com/7EYXXMXY594V8y4sZT2aawmdKgDAGTu5jNm9C-HpR3jY9cZJ0NMxS__nZKBdWZ1PUpJPjc2BAA=w300-h300-l90-rj",
    "karan aujla": "https://lh3.googleusercontent.com/k7sgqqcV5VScaMZtTmS8W_tfouLVBpgyJII0epYE2Vjw1-zzhGgUCV51aHxZn6cmZKKJgUfNlIVpZg=w300-h300-l90-rj",
    "ap dhillon": "https://lh3.googleusercontent.com/yJh1MZL2FvtJz3YeDAUhTRpfdUSwdotWw8XmB_An-4coKiVG4pDpUGRAPV7ooqmzBP4HAWrtjPyAfI4=w300-h300-l90-rj",
    "shubh": "https://lh3.googleusercontent.com/k7sgqqcV5VScaMZtTmS8W_tfouLVBpgyJII0epYE2Vjw1-zzhGgUCV51aHxZn6cmZKKJgUfNlIVpZg=w300-h300-l90-rj",
    "sidhu moose wala": "https://yt3.ggpht.com/ytc/AIdro_kiQJ0Hhp0O-tdaY1dy81-gSNujjccUlWstnpFr686ZlMk=w300-h300-l90-rj",
    "guru randhawa": "https://yt3.googleusercontent.com/7EYXXMXY594V8y4sZT2aawmdKgDAGTu5jNm9C-HpR3jY9cZJ0NMxS__nZKBdWZ1PUpJPjc2BAA=w300-h300-l90-rj",
  };

  String _getArtistImage(String name) {
    final key = name.trim().toLowerCase();
    return _artistImageMap[key] ??
        "https://api.dicebear.com/7.x/identicon/png?seed=${Uri.encodeComponent(name)}&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf";
  }

  Widget _buildArtistAvatar(String artistName) {
    final imageUrl = _getArtistImage(artistName);

    return GestureDetector(
      onTap: () {
        // Trigger search for this artist and navigate to search tab
        final searchController = Get.find<SearchViewController>();
        searchController.textEditingController.text = artistName;
        searchController.performSearch(artistName);
        widget.onNavigateTab(1);
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.surfaceLight,
                      child: const Center(
                        child: Icon(Icons.person_rounded, color: AppTheme.primaryAccent, size: 24),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.surfaceLight,
                      child: const Center(
                        child: Icon(Icons.person_rounded, color: AppTheme.primaryAccent, size: 24),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artistName,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearRecentsDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.history_toggle_off_rounded, color: Colors.orangeAccent, size: 22),
            SizedBox(width: 10),
            Text("Clear Recent Songs?", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Are you sure you want to clear your recently played songs history?",
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Cancel", style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              _playerController.clearRecentSongs();
              Get.back();
              Get.snackbar(
                "History Cleared",
                "Recently played songs have been cleared",
                backgroundColor: AppTheme.surface,
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              );
            },
            child: const Text("Clear All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
