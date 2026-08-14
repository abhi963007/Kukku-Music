import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/download_controller.dart';
import '../../controllers/player_controller.dart';
import '../../utils/helper.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DownloadViewController _downloadController = Get.find<DownloadViewController>();
  final PlayerController _playerController = Get.find<PlayerController>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Your Library",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Cache Stats Card
                    Obx(() {
                      final cacheSize = formatBytes(_downloadController.totalCacheSizeBytes.value);
                      final downloadCount = _downloadController.downloadedSongs.length;
                      final cachedCount = _downloadController.cachedSongs.length;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(Icons.download_done_rounded, "$downloadCount", "Downloads"),
                            Container(width: 1, height: 32, color: Colors.white12),
                            _buildStatItem(Icons.cached_rounded, "$cachedCount", "Cached"),
                            Container(width: 1, height: 32, color: Colors.white12),
                            _buildStatItem(Icons.storage_rounded, cacheSize, "Disk Space"),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Tab Bar
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppTheme.textSecondary,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: const [
                          Tab(text: "Downloads"),
                          Tab(text: "Cached Songs"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // 1. Downloads Tab
              Obx(() {
                final downloads = _downloadController.downloadedSongs;
                if (downloads.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_for_offline_rounded, size: 54, color: AppTheme.textMuted),
                        SizedBox(height: 12),
                        Text(
                          "No downloaded songs",
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Tap the download icon on any song to listen offline",
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120, top: 8),
                  itemCount: downloads.length,
                  itemBuilder: (context, index) {
                    final song = downloads[index];
                    return SongTile(
                      song: song,
                      onTap: () => _playerController.playQueue(downloads, index),
                    );
                  },
                );
              }),

              // 2. Cached Songs Tab
              Obx(() {
                final cached = _downloadController.cachedSongs;
                if (cached.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done_rounded, size: 54, color: AppTheme.textMuted),
                        SizedBox(height: 12),
                        Text(
                          "No cached streams yet",
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Songs you stream are automatically cached here for offline replay",
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 120, top: 8),
                  itemCount: cached.length,
                  itemBuilder: (context, index) {
                    final song = cached[index];
                    return SongTile(
                      song: song,
                      onTap: () => _playerController.playQueue(cached, index),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
