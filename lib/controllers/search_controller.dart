import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../models/song_model.dart';
import '../services/music_service.dart';

class SearchViewController extends GetxController {
  final MusicServices musicServices = Get.find<MusicServices>();
  final TextEditingController textEditingController = TextEditingController();

  final RxList<SongModel> searchResults = <SongModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxList<String> recentSearches = <String>[].obs;

  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    _loadRecentSearches();
  }

  @override
  void onClose() {
    textEditingController.dispose();
    _debounce?.cancel();
    super.onClose();
  }

  void _loadRecentSearches() {
    final box = Hive.box('AppPrefs');
    final List<dynamic> list = box.get('recentSearchQueries', defaultValue: []);
    recentSearches.value = list.map((e) => e.toString()).toList();
  }

  void onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      searchResults.clear();
      isLoading.value = false;
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 600), () {
      performSearch(query);
    });
  }

  Future<void> performSearch(String query) async {
    if (query.trim().isEmpty) return;

    isLoading.value = true;
    _saveSearchQuery(query.trim());

    final results = await musicServices.searchTracks(query);
    searchResults.value = results;
    isLoading.value = false;
  }

  void _saveSearchQuery(String query) {
    if (!recentSearches.contains(query)) {
      recentSearches.insert(0, query);
      if (recentSearches.length > 10) recentSearches.removeLast();
      Hive.box('AppPrefs').put('recentSearchQueries', recentSearches.toList());
    }
  }

  void clearSearch() {
    textEditingController.clear();
    searchResults.clear();
    isLoading.value = false;
  }

  void removeRecentSearch(String query) {
    recentSearches.remove(query);
    Hive.box('AppPrefs').put('recentSearchQueries', recentSearches.toList());
  }
}
