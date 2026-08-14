import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' as getx;
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/audio.dart';
import '../models/song_model.dart';
import '../models/streaming_data.dart';
import '../utils/helper.dart';
import 'background_task.dart';
import 'music_service.dart';
import 'piped_stream_service.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.kukku.music.channel.audio',
      androidNotificationChannelName: 'Kukku Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // ── Harmony-style: persistent ConcatenatingAudioSource ──────────────────
  final _playList = ConcatenatingAudioSource(
    children: [],
    useLazyPreparation: false,
  );

  // ── AudioPlayer with Harmony-style AndroidLoadControl ───────────────────
  late final AudioPlayer _player;

  String _cacheDir = '';
  bool isPlayingUsingLockCachingSource = false;
  bool isSongLoading = true;
  bool loopModeEnabled = false;
  bool shuffleModeEnabled = false;
  String? currentSongUrl;
  int _currentIndex = 0;
  bool _isTransitioning = false;

  AudioPlayer get player => _player;
  int get currentIndex => _currentIndex;

  MyAudioHandler() {
    _player = AudioPlayer(
      audioLoadConfiguration: const AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: Duration(seconds: 50),
          maxBufferDuration: Duration(minutes: 2),
          bufferForPlaybackDuration: Duration(milliseconds: 500),
          bufferForPlaybackAfterRebufferDuration: Duration(seconds: 5),
        ),
      ),
    );
    _initAsync();
  }

  Future<void> _initAsync() async {
    // Configure audio session (Harmony does this but not explicitly, we keep it)
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      printERROR('AudioSession configure failed', e);
    }

    // Create cache directory
    try {
      final tmpDir = await getTemporaryDirectory();
      _cacheDir = tmpDir.path;
      final cacheFolder = Directory('$_cacheDir/cachedSongs');
      if (!cacheFolder.existsSync()) {
        cacheFolder.createSync(recursive: true);
      }
    } catch (e) {
      printERROR('Cache dir creation failed', e);
    }

    // Load prefs
    final appPrefsBox = Hive.box('AppPrefs');
    loopModeEnabled = appPrefsBox.get('isLoopModeEnabled', defaultValue: false) as bool;
    shuffleModeEnabled = appPrefsBox.get('isShuffleModeEnabled', defaultValue: false) as bool;

    // Set the persistent playlist as the audio source (Harmony pattern)
    try {
      await _player.setAudioSource(_playList);
    } catch (e) {
      printERROR('Failed to set empty playlist source', e);
    }

    _notifyPlaybackEvents();
    _listenForDurationChanges();
    _listenForCompletion();
  }

  // ── Broadcast playback state to AudioService ─────────────────────────────
  void _notifyPlaybackEvents() {
    _player.playbackEventStream.listen(
      (PlaybackEvent event) {
        final playing = _player.playing;
        playbackState.add(playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {MediaAction.seek},
          androidCompactActionIndices: const [0, 1, 2],
          processingState: isSongLoading
              ? AudioProcessingState.loading
              : const {
                  ProcessingState.idle: AudioProcessingState.idle,
                  ProcessingState.loading: AudioProcessingState.loading,
                  ProcessingState.buffering: AudioProcessingState.buffering,
                  ProcessingState.ready: AudioProcessingState.ready,
                  ProcessingState.completed: AudioProcessingState.completed,
                }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: _currentIndex,
        ));
      },
      onError: (Object e, StackTrace st) async {
        if (e is PlayerException) {
          printERROR('PlayerException code=${e.code}: ${e.message}');
        } else {
          printERROR('Playback stream error, retrying with fresh URL', e);
          final curPos = _player.position;
          await _player.stop();

          // Harmony's workaround: fetch fresh URL and retry
          if (queue.value.isNotEmpty && _currentIndex < queue.value.length) {
            await _playSongAtIndex(_currentIndex, generateNewUrl: true);
            await _player.seek(curPos);
          }
        }
      },
    );
  }

  void _listenForDurationChanges() {
    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current != null && duration != null && duration > Duration.zero) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });
  }

  void _listenForCompletion() {
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && !_isTransitioning) {
        if (loopModeEnabled) {
          _player.seek(Duration.zero);
          _player.play();
        } else {
          skipToNext();
        }
      }
    });
  }

  // ── Core: Create audio source ─────────────────────────────────────────────
  AudioSource _createAudioSource(MediaItem item) {
    final url = item.extras?['url'] as String? ?? '';

    if (url.isEmpty) {
      throw Exception('Empty stream URL for song ${item.id}');
    }

    // Local file (download/cache) → plain file source
    if (url.startsWith('file://')) {
      final path = url.replaceFirst('file://', '');
      printINFO('Playing local file: $path');
      isPlayingUsingLockCachingSource = false;
      return AudioSource.file(path, tag: item);
    }

    // Remote stream → AudioSource.uri with NO custom headers
    // YouTube stream URLs are self-authenticating (all auth tokens are in the URL).
    // Adding headers interferes with ExoPlayer's DASH/segment loading.
    // This is the same approach Harmony Music uses by default.
    printINFO('Playing via AudioSource.uri (direct stream, no headers)');
    isPlayingUsingLockCachingSource = false;
    return AudioSource.uri(
      Uri.parse(url),
      tag: item,
    );
  }

  // ── Core: Resolve stream URL (3-tier cache: download → disk → network) ───
  Future<HMStreamingData> checkNGetUrl(
    String songId, {
    bool generateNewUrl = false,
    bool offlineReplacementUrl = false,
  }) async {
    printINFO('checkNGetUrl: $songId (fresh=$generateNewUrl)');

    // 1. Cached song on disk (from LockCachingAudioSource auto-cache)
    if (!offlineReplacementUrl) {
      final cacheBox = Hive.box('SongsCache');
      if (cacheBox.containsKey(songId)) {
        printINFO('Got song from SongsCache box: $songId');
        final streamInfo = cacheBox.get(songId)?['streamInfo'];
        Audio cacheAudio;
        if (streamInfo != null && (streamInfo as List).isNotEmpty) {
          (streamInfo[1] as Map)['url'] = 'file://$_cacheDir/cachedSongs/$songId.mp3';
          cacheAudio = Audio.fromJson(streamInfo[1] as Map<String, dynamic>);
        } else {
          cacheAudio = Audio(
            itag: 0,
            audioCodec: Codec.mp4a,
            bitrate: 0,
            duration: 0,
            loudnessDb: 0,
            url: 'file://$_cacheDir/cachedSongs/$songId.mp3',
            size: 0,
          );
        }
        return HMStreamingData(
          playable: true,
          statusMSG: 'OK',
          lowQualityAudio: cacheAudio,
          highQualityAudio: cacheAudio,
        );
      }
    }

    // 2. Downloaded song
    if (!offlineReplacementUrl) {
      final downloadsBox = Hive.box('SongDownloads');
      if (downloadsBox.containsKey(songId)) {
        final song = downloadsBox.get(songId) as Map;
        final path = song['url'] as String? ?? song['extras']?['url'] as String? ?? '';
        if (path.isNotEmpty && File(path).existsSync()) {
          final Audio audio = Audio(
            itag: 140,
            audioCodec: Codec.mp4a,
            bitrate: 0,
            duration: 0,
            loudnessDb: 0,
            url: path.startsWith('file://') ? path : 'file://$path',
            size: 0,
          );
          return HMStreamingData(
            playable: true,
            statusMSG: 'OK',
            highQualityAudio: audio,
            lowQualityAudio: audio,
          );
        }
        // file missing → fall through to stream
        return checkNGetUrl(songId, offlineReplacementUrl: true);
      }
    }

    // 3. Cached stream URL (SongsUrlCache)
    final songsUrlCacheBox = Hive.box('SongsUrlCache');
    final qualityIndex = Hive.box('AppPrefs').get('streamingQuality', defaultValue: 1) as int;
    HMStreamingData? streamInfo;

    if (!generateNewUrl && songsUrlCacheBox.containsKey(songId)) {
      final streamInfoJson = songsUrlCacheBox.get(songId);
      if (streamInfoJson is Map) {
        final rawUrl = streamInfoJson['lowQualityAudio']?['url'] as String? ??
            streamInfoJson['highQualityAudio']?['url'] as String?;
        if (rawUrl != null && !isExpired(url: rawUrl)) {
          printINFO('Using cached URL for $songId');
          streamInfo = HMStreamingData.fromJson(streamInfoJson as Map<String, dynamic>);
        }
      }
    }

    // 4. Fetch fresh stream via youtube_explode_dart (using anandnet's signature deciphering fork)
    if (streamInfo == null || !streamInfo.playable) {
      printINFO('Fetching stream for $songId via youtube_explode_dart');
      final token = RootIsolateToken.instance;
      final streamInfoJson = await Isolate.run(() => getStreamInfo(songId, token));
      streamInfo = HMStreamingData.fromJson(streamInfoJson);

      // 5. If unplayable or failed, fallback to Piped API
      if (!streamInfo.playable || streamInfo.activeAudio == null) {
        printINFO('youtube_explode failed, trying Piped API fallback for $songId');
        final pipedResult = await PipedStreamService.fetchAudioUrl(songId);
        if (pipedResult.playable && pipedResult.audio != null) {
          streamInfo = HMStreamingData(
            playable: true,
            statusMSG: 'OK',
            highQualityAudio: pipedResult.audio,
            lowQualityAudio: pipedResult.audio,
          );
        }
      }

      if (streamInfo.playable) {
        songsUrlCacheBox.put(songId, streamInfo.toJson());
      }
    }

    streamInfo.setQualityIndex(qualityIndex);
    return streamInfo;
  }

  // ── Core: Play song at index (Harmony's playByIndex pattern) ─────────────
  Future<void> _playSongAtIndex(int index, {bool generateNewUrl = false}) async {
    if (index < 0 || index >= queue.value.length) return;

    _currentIndex = index;
    _isTransitioning = true;
    final currentSong = queue.value[index];

    isSongLoading = true;
    playbackState.add(
      playbackState.value.copyWith(processingState: AudioProcessingState.loading),
    );

    // Stop the player first to prevent completion events during transition
    try {
      await _player.stop();
    } catch (_) {}

    // Clear the playlist (Harmony pattern)
    if (_playList.children.isNotEmpty) {
      await _playList.clear();
    }

    mediaItem.add(currentSong);

    // Resolve stream URL
    final streamInfo = await checkNGetUrl(currentSong.id, generateNewUrl: generateNewUrl);

    // Guard: if index changed while awaiting, abort
    if (index != _currentIndex) {
      _isTransitioning = false;
      return;
    }

    if (!streamInfo.playable || streamInfo.activeAudio == null) {
      currentSongUrl = null;
      isSongLoading = false;
      _isTransitioning = false;
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        errorMessage: streamInfo.statusMSG,
      ));
      printERROR('Cannot play: ${streamInfo.statusMSG}');
      return;
    }

    // Attach URL to the MediaItem extras (Harmony pattern)
    currentSongUrl = streamInfo.activeAudio!.url;
    currentSong.extras!['url'] = currentSongUrl;
    currentSong.extras!['bitrate'] = streamInfo.activeAudio!.bitrate;
    currentSong.extras!['codec'] = streamInfo.activeAudio!.audioCodec.name;

    playbackState.add(
      playbackState.value.copyWith(queueIndex: _currentIndex),
    );

    // Add to playlist and play (Harmony pattern: _playList.add → _player.play)
    await _playList.add(_createAudioSource(currentSong));
    isSongLoading = false;
    _isTransitioning = false;

    // Always start from the beginning — prevents resuming a previously-played song mid-way
    await _player.seek(Duration.zero);
    await _player.play();

    _addToRecentHistory(currentSong);

    // If remaining queue is small (<= 3 songs), auto-replenish with continuous radio recommendations
    if (_currentIndex >= queue.value.length - 3 || queue.value.length <= 4) {
      _autoReplenishRadioQueue(currentSong.id);
    }
  }

  bool _isReplenishingQueue = false;

  /// Fetch and append similar radio tracks in the background for endless playback
  Future<void> _autoReplenishRadioQueue(String seedSongId) async {
    if (_isReplenishingQueue || seedSongId.isEmpty) return;
    _isReplenishingQueue = true;

    try {
      printINFO('Auto-replenishing radio queue for seed: $seedSongId');
      final MusicServices musicService = getx.Get.isRegistered<MusicServices>()
          ? getx.Get.find<MusicServices>()
          : MusicServices();

      final recommendedSongs = await musicService.getRadioTracks(seedSongId);

      if (recommendedSongs.isNotEmpty) {
        final currentQueue = List<MediaItem>.from(queue.value);
        final existingIds = currentQueue.map((e) => e.id).toSet();

        final List<MediaItem> newItems = [];
        for (final song in recommendedSongs) {
          if (!existingIds.contains(song.id)) {
            newItems.add(song.toMediaItem());
            existingIds.add(song.id);
          }
        }

        if (newItems.isNotEmpty) {
          currentQueue.addAll(newItems);
          queue.add(currentQueue);
          printINFO('Appended ${newItems.length} continuous radio tracks to queue. New total: ${currentQueue.length}');
        }
      }
    } catch (e) {
      printERROR('Failed to replenish radio queue', e);
    } finally {
      _isReplenishingQueue = false;
    }
  }

  void _addToRecentHistory(MediaItem item) {
    try {
      final box = Hive.box('AppPrefs');
      final List<dynamic> recent = List.from(box.get('recentSongs', defaultValue: []));
      recent.removeWhere((e) => e['id'] == item.id);
      recent.insert(0, MediaItemBuilder.toJson(item));
      if (recent.length > 50) recent.removeLast();
      box.put('recentSongs', recent);
    } catch (_) {}
  }

  // ── AudioService API ──────────────────────────────────────────────────────

  @override
  Future<void> play() async {
    if (currentSongUrl == null && queue.value.isNotEmpty) {
      await _playSongAtIndex(_currentIndex);
      return;
    }
    await _player.play();
  }

  @override
  Future<void> pause() async => await _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async => await _player.seek(position);

  @override
  Future<void> skipToNext() async {
    final q = queue.value;
    if (q.isEmpty) return;

    if (_currentIndex + 1 < q.length) {
      await _playSongAtIndex(_currentIndex + 1);
    } else {
      // Reached the end of queue! Immediately replenish radio tracks and continue playing
      final lastSongId = q.isNotEmpty ? q[_currentIndex].id : '';
      if (lastSongId.isNotEmpty) {
        await _autoReplenishRadioQueue(lastSongId);
        if (_currentIndex + 1 < queue.value.length) {
          await _playSongAtIndex(_currentIndex + 1);
          return;
        }
      }

      if (loopModeEnabled) {
        await _playSongAtIndex(0);
      } else {
        await _player.seek(Duration.zero);
        await _player.pause();
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final q = queue.value;
    if (q.isEmpty) return;
    if (_player.position.inSeconds > 4) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex - 1 >= 0) {
      await _playSongAtIndex(_currentIndex - 1);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < queue.value.length) {
      await _playSongAtIndex(index);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    loopModeEnabled = repeatMode != AudioServiceRepeatMode.none;
    Hive.box('AppPrefs').put('isLoopModeEnabled', loopModeEnabled);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    shuffleModeEnabled = shuffleMode == AudioServiceShuffleMode.all;
    Hive.box('AppPrefs').put('isShuffleModeEnabled', shuffleModeEnabled);
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'playSong':
        if (extras == null) return false;
        final item = MediaItemBuilder.fromJson(extras['song'] as Map<String, dynamic>);
        final currentQueue = List<MediaItem>.from(queue.value);
        if (!currentQueue.any((q) => q.id == item.id)) {
          currentQueue.add(item);
          queue.add(currentQueue);
        }
        final idx = currentQueue.indexWhere((q) => q.id == item.id);
        await _playSongAtIndex(idx);
        // Pre-fetch infinite radio recommendations in background
        _autoReplenishRadioQueue(item.id);
        return true;

      case 'playQueue':
        if (extras == null) return false;
        final rawList = extras['queue'] as List? ?? [];
        final initialIndex = extras['index'] as int? ?? 0;
        final items = rawList
            .map((e) => MediaItemBuilder.fromJson(e as Map<String, dynamic>))
            .toList();
        queue.add(items);
        if (items.isNotEmpty && initialIndex < items.length) {
          await _playSongAtIndex(initialIndex);
        }
        return true;

      case 'addToQueue':
        if (extras == null) return false;
        final item = MediaItemBuilder.fromJson(extras['song'] as Map<String, dynamic>);
        final currentQueue = List<MediaItem>.from(queue.value);
        currentQueue.add(item);
        queue.add(currentQueue);
        return true;

      case 'clearQueue':
        queue.add([]);
        currentSongUrl = null;
        await _player.stop();
        return true;

      case 'dispose':
        await _player.dispose();
        await super.stop();
        return true;

      default:
        return false;
    }
  }

  // ── Math helper for loudness normalization (Harmony pattern) ─────────────
  void normalizeVolume(double loudnessDb) {
    final diff = -5.0 - loudnessDb;
    final vol = pow(10.0, diff / 20.0).toDouble().clamp(0.0, 1.0);
    _player.setVolume(vol);
  }
}
