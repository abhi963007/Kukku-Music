import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/download_controller.dart';
import '../../controllers/player_controller.dart';
import '../../models/song_model.dart';
import '../../utils/helper.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_placeholder.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  final DownloadViewController _downloadController = Get.find<DownloadViewController>();
  final PlayerController _playerController = Get.find<PlayerController>();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A plain Column + TabBarView replaces the previous NestedScrollView: the
    // header was a SliverToBoxAdapter, so it never actually collapsed, and the
    // nested scroll coordination only got in the way of the inner lists.
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your Library",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatsCard(controller: _downloadController),
                  const SizedBox(height: 16),
                  _TabSelector(controller: _tabController),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _OfflineList(
                    songs: _downloadController.downloadedSongs,
                    emptyIcon: Icons.download_for_offline_outlined,
                    emptyTitle: "No downloaded songs",
                    emptyMessage:
                        "Use the ⋮ menu on any track to download it for offline listening.",
                    onRefresh: _downloadController.loadOfflineData,
                    onPlay: _playerController.playQueue,
                  ),
                  _OfflineList(
                    songs: _downloadController.cachedSongs,
                    emptyIcon: Icons.cloud_done_outlined,
                    emptyTitle: "No cached streams yet",
                    emptyMessage:
                        "Tracks you stream are cached automatically for instant offline replay. "
                        "You can turn this off in Settings.",
                    onRefresh: _downloadController.loadOfflineData,
                    onPlay: _playerController.playQueue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final DownloadViewController controller;

  const _StatsCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            // Expanded on each stat: with three fixed-width columns plus
            // dividers, a large font scale overflowed the card horizontally.
            _StatItem(
              icon: Icons.download_done_rounded,
              value: '${controller.downloadedSongs.length}',
              label: "Downloads",
            ),
            const _StatDivider(),
            _StatItem(
              icon: Icons.cached_rounded,
              value: '${controller.cachedSongs.length}',
              label: "Cached",
            ),
            const _StatDivider(),
            _StatItem(
              icon: Icons.storage_rounded,
              value: formatBytes(
                controller.totalCacheSizeBytes.value + controller.totalDownloadSizeBytes.value,
              ),
              label: "Disk Used",
            ),
          ],
        ),
      );
    });
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: Colors.white12);
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  final TabController controller;

  const _TabSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        // The indicator is a white gradient, so the selected label must be dark.
        labelColor: AppTheme.background,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        splashBorderRadius: BorderRadius.circular(12),
        tabs: const [
          Tab(text: "Downloads"),
          Tab(text: "Cached Songs"),
        ],
      ),
    );
  }
}

/// Downloads / cached list with pull-to-refresh and a shared empty state.
class _OfflineList extends StatelessWidget {
  final RxList<SongModel> songs;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function() onRefresh;
  final void Function(List<SongModel>, int) onPlay;

  const _OfflineList({
    required this.songs,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onRefresh,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: onRefresh,
      child: Obx(() {
        if (songs.isEmpty) {
          // `scrollable` keeps the pull-to-refresh gesture available on an
          // otherwise static empty state.
          return StatePlaceholder(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
            scrollable: true,
          );
        }

        final items = songs.toList(growable: false);
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          itemCount: items.length,
          itemBuilder: (context, index) => SongTile(
            song: items[index],
            onTap: () => onPlay(items, index),
          ),
        );
      }),
    );
  }
}
