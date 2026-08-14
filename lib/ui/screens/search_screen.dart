import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/player_controller.dart';
import '../../controllers/search_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/song_tile.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final searchController = Get.find<SearchViewController>();
    final playerController = Get.find<PlayerController>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController.textEditingController,
                  builder: (context, textValue, _) {
                    return TextField(
                      controller: searchController.textEditingController,
                      onChanged: searchController.onQueryChanged,
                      onSubmitted: searchController.performSearch,
                      autofocus: false,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: "Search songs, artists, hits...",
                        hintStyle: const TextStyle(color: AppTheme.textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                        suffixIcon: Obx(() {
                          if (searchController.isLoading.value) {
                            return const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                              ),
                            );
                          }
                          if (textValue.text.isNotEmpty) {
                            return IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                              onPressed: searchController.clearSearch,
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Content Area (Results, Recent Searches List, or Empty State)
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: searchController.textEditingController,
                builder: (context, textValue, _) {
                  return Obx(() {
                    if (searchController.isLoading.value) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      );
                    }

                    // 1. Search Query is Active
                    if (textValue.text.trim().isNotEmpty) {
                      if (searchController.searchResults.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.music_off_rounded, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                              const SizedBox(height: 12),
                              const Text(
                                "No results found",
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Try searching for a different song or artist",
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120, top: 4),
                        itemCount: searchController.searchResults.length,
                        itemBuilder: (context, index) {
                          final song = searchController.searchResults[index];
                          return SongTile(
                            song: song,
                            onTap: () => playerController.playQueue(searchController.searchResults, index),
                          );
                        },
                      );
                    }

                    // 2. Query is Empty -> Show Recent Searches as a Vertical Suggestion List
                    if (searchController.recentSearches.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Recent Searches",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                TextButton(
                                  onPressed: searchController.clearAllRecentSearches,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    "Clear all",
                                    style: TextStyle(
                                      color: AppTheme.primary,
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
                              padding: const EdgeInsets.only(top: 4, bottom: 120),
                              itemCount: searchController.recentSearches.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                thickness: 0.5,
                                color: Colors.white.withValues(alpha: 0.04),
                                indent: 52,
                                endIndent: 16,
                              ),
                              itemBuilder: (context, index) {
                                final term = searchController.recentSearches[index];
                                return InkWell(
                                  onTap: () {
                                    searchController.textEditingController.text = term;
                                    searchController.textEditingController.selection =
                                        TextSelection.fromPosition(TextPosition(offset: term.length));
                                    searchController.performSearch(term);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.history_rounded,
                                          size: 22,
                                          color: AppTheme.textMuted,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            term,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                            color: AppTheme.textMuted,
                                          ),
                                          splashRadius: 18,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          onPressed: () => searchController.removeRecentSearch(term),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }

                    // 3. Query is Empty & No Recent Searches
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              size: 38,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Play what you love",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Search for artists, songs, or albums",
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
