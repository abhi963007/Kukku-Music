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
                child: TextField(
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
                      if (searchController.textEditingController.text.isNotEmpty) {
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
                ),
              ),
            ),

            // Search History Chips (when query is empty)
            Obx(() {
              if (searchController.searchResults.isEmpty &&
                  !searchController.isLoading.value &&
                  searchController.recentSearches.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Recent Searches",
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: searchController.recentSearches.map((term) {
                          return ActionChip(
                            label: Text(term, style: const TextStyle(fontSize: 12, color: Colors.white)),
                            backgroundColor: AppTheme.surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            side: const BorderSide(color: AppTheme.cardBorder),
                            onPressed: () {
                              searchController.textEditingController.text = term;
                              searchController.performSearch(term);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            // Results List
            Expanded(
              child: Obx(() {
                if (searchController.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                if (searchController.searchResults.isEmpty &&
                    searchController.textEditingController.text.isNotEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_off_rounded, size: 48, color: AppTheme.textMuted),
                        SizedBox(height: 12),
                        Text(
                          "No results found",
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
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
              }),
            ),
          ],
        ),
      ),
    );
  }
}
