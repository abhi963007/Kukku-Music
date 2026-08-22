import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/song_model.dart';
import '../services/music_service.dart';
import '../utils/helper.dart';

class SearchViewController extends GetxController {
  final MusicServices musicServices = Get.find<MusicServices>();
  final TextEditingController textEditingController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();

  final RxList<SongModel> searchResults = <SongModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxList<String> recentSearches = <String>[].obs;

  Timer? _debounce;

  /// Monotonic token identifying the newest in-flight request. A slow response
  /// for an older query must not overwrite results for a newer one.
  int _requestToken = 0;

  /// The query whose results are currently displayed.
  String activeQuery = '';

  @override
  void onInit() {
    super.onInit();
    _loadRecentSearches();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    textEditingController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }

  void _loadRecentSearches() {
    final list = boxGet<List<dynamic>>('AppPrefs', 'recentSearchQueries', const []);
    recentSearches.value =
        list.map((e) => asText(e)).where((e) => e.isNotEmpty).toList();
  }

  void onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      // Invalidate any in-flight request so its results cannot land after the
      // field has been cleared.
      _requestToken++;
      searchResults.clear();
      errorMessage.value = '';
      isLoading.value = false;
      activeQuery = '';
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      performSearch(query);
    });
  }

  Future<void> performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _debounce?.cancel();
    final token = ++_requestToken;

    isLoading.value = true;
    errorMessage.value = '';
    activeQuery = trimmed;

    try {
      final results = await musicServices.searchTracks(trimmed);
      if (token != _requestToken) return; // Superseded by a newer query.
      searchResults.value = results;
      if (results.isEmpty) {
        errorMessage.value = '';
      }
      _saveSearchQuery(trimmed);
    } catch (e) {
      printERROR('Search failed for "$trimmed"', e);
      if (token != _requestToken) return;
      searchResults.clear();
      errorMessage.value = 'Something went wrong while searching. Check your connection.';
    } finally {
      // `isLoading` previously stayed true forever if the request threw.
      if (token == _requestToken) isLoading.value = false;
    }
  }

  /// Runs a search and moves focus off the field (used by the artist chips on
  /// the home screen).
  void searchFor(String query) {
    textEditingController.text = query;
    textEditingController.selection =
        TextSelection.fromPosition(TextPosition(offset: query.length));
    performSearch(query);
  }

  void _saveSearchQuery(String query) {
    if (query.isEmpty) return;
    recentSearches.remove(query);
    recentSearches.insert(0, query);
    while (recentSearches.length > 25) {
      recentSearches.removeLast();
    }
    boxPut('AppPrefs', 'recentSearchQueries', recentSearches.toList());
  }

  void clearSearch() {
    _debounce?.cancel();
    _requestToken++;
    textEditingController.clear();
    searchResults.clear();
    errorMessage.value = '';
    isLoading.value = false;
    activeQuery = '';
  }

  void removeRecentSearch(String query) {
    recentSearches.remove(query);
    boxPut('AppPrefs', 'recentSearchQueries', recentSearches.toList());
  }

  void clearAllRecentSearches() {
    recentSearches.clear();
    boxPut('AppPrefs', 'recentSearchQueries', <String>[]);
  }

  Future<void> retryLastSearch() async {
    if (activeQuery.isNotEmpty) {
      await performSearch(activeQuery);
    }
  }
}
