import 'package:audio_service/audio_service.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';

import '../models/song_model.dart';
import '../services/audio_handler.dart';

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

  PlayerController({required this.audioHandler});

  @override
  void onInit() {
    super.onInit();
    loadRecentSongs();
    _bindStreams();
  }

  void _bindStreams() {
    // Current track stream
    audioHandler.mediaItem.listen((item) {
      if (item != null) {
        currentSong.value = SongModel.fromMediaItem(item);
        totalDuration.value = item.duration ?? Duration.zero;

        final codec = item.extras?['codec'] ?? '';
        final bitrate = item.extras?['bitrate'] ?? 0;
        if (codec.isNotEmpty && bitrate > 0) {
          final kbps = (bitrate / 1000).round();
          audioBadge.value = "${codec.toString().toUpperCase()} • ${kbps}kbps";
        } else if (item.extras?['url']?.toString().startsWith('file://') ?? false) {
          audioBadge.value = "OFFLINE CACHE";
        } else {
          audioBadge.value = "HQ STREAM";
        }
        loadRecentSongs();
      } else {
        currentSong.value = null;
      }
    });

    // Playback state stream
    audioHandler.playbackState.listen((state) {
      isPlaying.value = state.playing;
      isBuffering.value = state.processingState == AudioProcessingState.buffering ||
          state.processingState == AudioProcessingState.loading;
      position.value = state.updatePosition;
      bufferedPosition.value = state.bufferedPosition;
    });

    // Queue stream
    audioHandler.queue.listen((items) {
      queue.value = items.map((e) => SongModel.fromMediaItem(e)).toList();
    });

    // Player position stream from just_audio
    audioHandler.player.positionStream.listen((pos) {
      position.value = pos;
    });

    audioHandler.player.bufferedPositionStream.listen((buf) {
      bufferedPosition.value = buf;
    });

    audioHandler.player.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero) {
        totalDuration.value = dur;
      }
    });
  }

  Future<void> playSong(SongModel song) async {
    await audioHandler.customAction('playSong', {
      'song': song.toJson(),
    });
  }

  Future<void> playQueue(List<SongModel> songs, int initialIndex) async {
    await audioHandler.customAction('playQueue', {
      'queue': songs.map((e) => e.toJson()).toList(),
      'index': initialIndex,
    });
  }

  Future<void> addToQueue(SongModel song) async {
    await audioHandler.customAction('addToQueue', {
      'song': song.toJson(),
    });
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

  Future<void> skipNext() async {
    await audioHandler.skipToNext();
  }

  Future<void> skipPrevious() async {
    await audioHandler.skipToPrevious();
  }

  Future<void> toggleRepeat() async {
    final next = repeatMode.value == AudioServiceRepeatMode.none
        ? AudioServiceRepeatMode.all
        : repeatMode.value == AudioServiceRepeatMode.all
            ? AudioServiceRepeatMode.one
            : AudioServiceRepeatMode.none;
    repeatMode.value = next;
    await audioHandler.setRepeatMode(next);
  }

  Future<void> toggleShuffle() async {
    isShuffle.value = !isShuffle.value;
    await audioHandler.setShuffleMode(
      isShuffle.value ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
  }

  void loadRecentSongs() {
    try {
      final box = Hive.box('AppPrefs');
      final List rawList = box.get('recentSongs', defaultValue: []);
      recentSongs.value = rawList.map((e) => SongModel.fromJson(e)).toList();
    } catch (_) {}
  }

  Future<void> clearRecentSongs() async {
    try {
      final box = Hive.box('AppPrefs');
      await box.put('recentSongs', []);
      recentSongs.clear();
    } catch (_) {}
  }

  Future<void> removeRecentSong(String songId) async {
    try {
      final box = Hive.box('AppPrefs');
      final List rawList = List.from(box.get('recentSongs', defaultValue: []));
      rawList.removeWhere((e) => e['id'] == songId);
      await box.put('recentSongs', rawList);
      recentSongs.removeWhere((e) => e.id == songId);
    } catch (_) {}
  }
}
