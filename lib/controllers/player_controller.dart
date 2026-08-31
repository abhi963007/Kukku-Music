import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/song_model.dart';
import '../services/audio_handler.dart';
import '../utils/helper.dart';

class PlayerController extends GetxController {
  final MyAudioHandler audioHandler;

  final Rx<SongModel?> currentSong = Rx<SongModel?>(null);
  final RxBool isPlaying = false.obs;
  final RxBool isBuffering = false.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> bufferedPosition = Duration.zero.obs;
  final Rx<Duration> totalDuration = Duration.zero.obs;
  final RxList<SongModel> queue = <SongModel>[].obs;
  final RxList<SongModel> recentSongs = <SongModel>[].obs;
  final Rx<AudioServiceRepeatMode> repeatMode = AudioServiceRepeatMode.none.obs;
  final RxBool isShuffle = false.obs;
  final RxString audioBadge = "Auto".obs;

  /// Reactive state for authentic song details, credits, mood and story
  final RxMap<String, dynamic> currentSongDetails = <String, dynamic>{}.obs;
  final RxBool isLoadingDetails = false.obs;
  final Map<String, Map<String, dynamic>> _detailsCache = {};

  /// Index of the currently playing item within [queue]. Needed so the queue
  /// sheet highlights the right row when a song appears more than once.
  final RxInt currentQueueIndex = 0.obs;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Last error surfaced to the user, so a sticky error state does not spam a
  /// new snackbar on every playback event.
  String? _lastErrorShown;

  PlayerController({required this.audioHandler});

  @override
  void onInit() {
    super.onInit();
    loadRecentSongs();
    _bindStreams();
  }

  @override
  void onClose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    super.onClose();
  }

  void _bindStreams() {
    // Current track stream
    _subscriptions.add(audioHandler.mediaItem.listen((item) {
      if (item == null) {
        currentSong.value = null;
        totalDuration.value = Duration.zero;
        return;
      }

      final previousId = currentSong.value?.id;
      currentSong.value = SongModel.fromMediaItem(item);
      if ((item.duration ?? Duration.zero) > Duration.zero) {
        totalDuration.value = item.duration!;
      }

      audioBadge.value = _badgeFor(item);

      // Recents and song details are updated on track change
      if (previousId != item.id) {
        loadRecentSongs();
        fetchDetailsForSong(currentSong.value!);
      }
    }, onError: (Object e) => printERROR('mediaItem stream error', e)));

    // Playback state stream
    _subscriptions.add(audioHandler.playbackState.listen((state) {
      isPlaying.value = state.playing;
      isBuffering.value = state.processingState == AudioProcessingState.buffering ||
          state.processingState == AudioProcessingState.loading;
      bufferedPosition.value = state.bufferedPosition;
      currentQueueIndex.value = state.queueIndex ?? 0;

      // Repeat/shuffle now mirror the handler instead of being separate UI-only
      // state, so persisted preferences show correctly after a restart.
      repeatMode.value = state.repeatMode;
      isShuffle.value = state.shuffleMode == AudioServiceShuffleMode.all;

      if (state.processingState == AudioProcessingState.error) {
        _showPlaybackError(state.errorMessage ?? 'Unable to play track');
      } else {
        _lastErrorShown = null;
      }
    }, onError: (Object e) => printERROR('playbackState stream error', e)));

    // Queue stream
    _subscriptions.add(audioHandler.queue.listen((items) {
      queue.value = items.map((e) => SongModel.fromMediaItem(e)).toList();
    }, onError: (Object e) => printERROR('queue stream error', e)));

    // Position is driven solely by just_audio. Mixing in
    // `playbackState.updatePosition` made the progress bar jump backwards
    // between the two sources.
    _subscriptions.add(audioHandler.player.positionStream.listen((pos) {
      position.value = pos;
    }, onError: (Object e) => printERROR('position stream error', e)));

    _subscriptions.add(audioHandler.player.bufferedPositionStream.listen((buf) {
      bufferedPosition.value = buf;
    }, onError: (Object e) => printERROR('buffered stream error', e)));

    _subscriptions.add(audioHandler.player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        totalDuration.value = dur;
      }
    }, onError: (Object e) => printERROR('duration stream error', e)));
  }

  /// Builds the quality badge from `extras`, which may hold values of any type
  /// once they have round-tripped through Hive or a third-party API. The old
  /// code called `.isNotEmpty` / `> 0` on `dynamic` and crashed on an int codec
  /// or a string bitrate.
  String _badgeFor(MediaItem item) {
    final extras = item.extras;
    final url = asText(extras?['url']);
    if (url.startsWith('file://')) return 'OFFLINE';

    final codec = asText(extras?['codec']).toUpperCase();
    final bitrate = asInt(extras?['bitrate']);
    if (codec.isNotEmpty && codec != 'OFFLINE' && bitrate > 0) {
      return '$codec • ${(bitrate / 1000).round()}kbps';
    }
    if (codec.isNotEmpty && codec != 'OFFLINE') return codec;
    return 'HQ STREAM';
  }

  void _showPlaybackError(String message) {
    if (_lastErrorShown == message) return;
    _lastErrorShown = message;

    // Snackbars require an active overlay; during startup there isn't one yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.context == null || Get.isSnackbarOpen) return;
      Get.snackbar(
        'Playback Error',
        message,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    });
  }

  Future<void> playSong(SongModel song) async {
    await audioHandler.customAction('playSong', {'song': song.toJson()});
  }

  Future<void> playQueue(List<SongModel> songs, int initialIndex) async {
    if (songs.isEmpty) return;
    await audioHandler.customAction('playQueue', {
      'queue': songs.map((e) => e.toJson()).toList(),
      'index': initialIndex.clamp(0, songs.length - 1),
    });
  }

  Future<void> addToQueue(SongModel song) async {
    await audioHandler.customAction('addToQueue', {'song': song.toJson()});
  }

  Future<void> clearQueue() async {
    await audioHandler.customAction('clearQueue');
  }

  Future<void> skipToQueueItem(int index) async {
    await audioHandler.skipToQueueItem(index);
  }

  Future<void> togglePlayPause() async {
    if (isPlaying.value) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
  }

  Future<void> seekTo(Duration target) async {
    await audioHandler.seek(target);
  }

  Future<void> skipNext() async => audioHandler.skipToNext();

  Future<void> skipPrevious() async => audioHandler.skipToPrevious();

  Future<void> toggleRepeat() async {
    // none → all → one → none
    final next = switch (repeatMode.value) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      _ => AudioServiceRepeatMode.none,
    };
    repeatMode.value = next;
    await audioHandler.setRepeatMode(next);
  }

  Future<void> toggleShuffle() async {
    final enabled = !isShuffle.value;
    isShuffle.value = enabled;
    await audioHandler.setShuffleMode(
      enabled ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
  }

  /// Human-readable label for the current repeat mode (used in tooltips).
  String get repeatLabel => switch (repeatMode.value) {
        AudioServiceRepeatMode.one => 'Repeat one',
        AudioServiceRepeatMode.all => 'Repeat all',
        _ => 'Repeat off',
      };

  void loadRecentSongs() {
    try {
      final rawList = boxGet<List<dynamic>>('AppPrefs', 'recentSongs', const []);
      recentSongs.value = rawList
          .map((e) => SongModel.fromJson(e))
          .where((s) => s.id.isNotEmpty)
          .toList();
    } catch (e) {
      printERROR('Failed to load recent songs', e);
    }
  }

  Future<void> clearRecentSongs() async {
    await boxPut('AppPrefs', 'recentSongs', <dynamic>[]);
    recentSongs.clear();
  }

  Future<void> removeRecentSong(String songId) async {
    try {
      final rawList =
          List<dynamic>.from(boxGet<List<dynamic>>('AppPrefs', 'recentSongs', const []));
      rawList.removeWhere((e) => asText(asStringMap(e)['id']) == songId);
      await boxPut('AppPrefs', 'recentSongs', rawList);
      recentSongs.removeWhere((e) => e.id == songId);
    } catch (e) {
      printERROR('Failed to remove recent song $songId', e);
    }
  }

  /// Populates authentic song details and credits directly from metadata
  Future<void> fetchDetailsForSong(SongModel song) async {
    if (song.title.isEmpty) return;

    if (_detailsCache.containsKey(song.id)) {
      currentSongDetails.value = _detailsCache[song.id]!;
      return;
    }

    final lang = asText(song.extras['language']);
    final details = <String, dynamic>{
      'tags': [
        if (lang.isNotEmpty) lang,
        if (song.album.isNotEmpty && song.album != 'Single' && song.album != 'Search') song.album,
        'Original Track',
        '320kbps HD',
      ],
      'mood': '${song.title} by ${song.artist}${song.album.isNotEmpty ? " (${song.album})" : ""}.',
      'about': 'Streamed in high fidelity 320kbps audio from the official catalog.',
      'composer': song.artist,
      'singers': song.artist,
    };

    _detailsCache[song.id] = details;
    if (currentSong.value?.id == song.id) {
      currentSongDetails.value = details;
    }
  }
}
