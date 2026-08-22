import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../../controllers/search_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/shimmer.dart';
import '../widgets/song_tile.dart';
import '../widgets/state_placeholder.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final searchController = Get.find<SearchViewController>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SearchField(controller: searchController),
            Expanded(child: _SearchBody(controller: searchController)),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final SearchViewController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: TextField(
          controller: controller.textEditingController,
          focusNode: controller.searchFocusNode,
          onChanged: controller.onQueryChanged,
          onSubmitted: controller.performSearch,
          textInputAction: TextInputAction.search,
          autofocus: false,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: "Search songs, artists, hits…",
            hintStyle: const TextStyle(color: AppTheme.textMuted),
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
            suffixIcon: _SuffixAction(controller: controller),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
}

/// Spinner while searching, clear button when there is text.
///
/// Driven by a [ValueListenableBuilder] on the text controller rather than by
/// rebuilding the whole `TextField`, which used to reset the field's internal
/// state on every keystroke.
class _SuffixAction extends StatelessWidget {
  final SearchViewController controller;

  const _SuffixAction({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const SizedBox(
          width: AppTheme.minTouchTarget,
          height: AppTheme.minTouchTarget,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
            ),
          ),
        );
      }
      return ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller.textEditingController,
        builder: (context, value, _) {
          if (value.text.isEmpty) return const SizedBox.shrink();
          return IconButton(
            icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
            tooltip: 'Clear search',
            onPressed: controller.clearSearch,
          );
        },
      );
    });
  }
}

class _SearchBody extends StatelessWidget {
  final SearchViewController controller;

  const _SearchBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final playerController = Get.find<PlayerController>();

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller.textEditingController,
      builder: (context, textValue, _) {
        return Obx(() {
          final hasQuery = textValue.text.trim().isNotEmpty;

          // Skeleton rows instead of a bare centred spinner, so the layout does
          // not jump when results arrive.
          if (controller.isLoading.value) {
            return ListView.builder(
              itemCount: 8,
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              itemBuilder: (_, _) => const Shimmer(child: _SearchTileSkeleton()),
            );
          }

          if (controller.errorMessage.value.isNotEmpty) {
            return StatePlaceholder(
              icon: Icons.wifi_off_rounded,
              title: 'Search failed',
              message: controller.errorMessage.value,
              actionLabel: 'Retry',
              onAction: controller.retryLastSearch,
            );
          }

          if (hasQuery) {
            if (controller.searchResults.isEmpty) {
              return StatePlaceholder(
                icon: Icons.music_off_rounded,
                title: 'No results found',
                message: 'Nothing matched "${textValue.text.trim()}". '
                    'Try a different song, artist or album.',
              );
            }

            return ListView.builder(
              // The parent Scaffold already reserves space for the mini player
              // and nav bar, so the old 120px bottom pad was dead space.
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: controller.searchResults.length,
              itemBuilder: (context, index) => SongTile(
                song: controller.searchResults[index],
                onTap: () =>
                    playerController.playSong(controller.searchResults[index]),
              ),
            );
          }

          if (controller.recentSearches.isNotEmpty) {
            return _RecentSearches(controller: controller);
          }

          return const StatePlaceholder(
            icon: Icons.search_rounded,
            title: 'Play what you love',
            message: 'Search for artists, songs or albums to start listening.',
          );
        });
      },
    );
  }
}

class _RecentSearches extends StatelessWidget {
  final SearchViewController controller;

  const _RecentSearches({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  "Recent Searches",
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              TextButton(
                onPressed: controller.clearAllRecentSearches,
                child: const Text(
                  "Clear all",
                  style: TextStyle(
                    color: AppTheme.primaryAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: controller.recentSearches.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.white.withValues(alpha: 0.05),
              indent: 52,
              endIndent: 16,
            ),
            itemBuilder: (context, index) {
              final term = controller.recentSearches[index];
              return _RecentSearchRow(
                term: term,
                onTap: () => controller.searchFor(term),
                onRemove: () => controller.removeRecentSearch(term),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentSearchRow extends StatelessWidget {
  final String term;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _RecentSearchRow({
    required this.term,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 4),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, size: 22, color: AppTheme.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                term,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textMuted),
              tooltip: 'Remove "$term"',
              // Full 48dp target — it was a 32dp box before.
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton matching [SongTile]'s footprint while a search is in flight.
class _SearchTileSkeleton extends StatelessWidget {
  const _SearchTileSkeleton();

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
