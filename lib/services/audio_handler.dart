import 'dart:async';
import 'dart:io';
import 'dart:math';
// `show Color` only — dart:ui also exports a `Codec` that would clash with the
// audio `Codec` enum below.
import 'dart:ui' show Color;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audio.dart';
import '../models/song_model.dart';
import '../models/streaming_data.dart';
import '../utils/helper.dart';
import 'saavn_service.dart';
import 'storage_paths.dart';
import 'stream_service.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.kukku.music.channel.audio',
      androidNotificationChannelName: 'Kukku Music Playback',
      androidNotificationChannelDescription:
          'Media controls and playback status for Kukku Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: false,
      androidNotificationIcon: 'drawable/ic_stat_music',
      // Tapping the notification must reopen the app rather than start a new task.
      androidNotificationClickStartsActivity: true,
      androidResumeOnClick: true,
      notificationColor: Color(0xFF111111),
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );
}

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  // ── AudioPlayer with AndroidLoadControl ───────────────────────────────────
  late final AudioPlayer _player;

  bool isPlayingUsingLockCachingSource = false;
  // Nothing is loading until a track is actually requested; starting at `true`
  // published a spurious "loading" state to the notification on cold start.
  bool isSongLoading = false;
  String? currentSongUrl;

  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  bool _shuffleEnabled = false;

  /// Playback order over `queue.value` indices. Identity order normally,
  /// a shuffled permutation when shuffle is on. Keeping the visible queue
  /// untouched means the queue sheet never reorders under the user.
  List<int> _playOrder = <int>[];

  int _currentIndex = 0;
  bool _isTransitioning = false;
  bool _cacheStreamsEnabled = true;

  /// Set while playback is paused because another app took audio focus, so we
  /// know whether to resume automatically once focus returns.
  bool _pausedByInterruption = false;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _disposed = false;

  AudioPlayer get player => _player;
  int get currentIndex => _currentIndex;
  AudioServiceRepeatMode get currentRepeatMode => _repeatMode;
  bool get shuffleEnabled => _shuffleEnabled;

  MyAudioHandler() {
    _player = AudioPlayer(
      audioLoadConfiguration: const AudioLoadConfiguration(
        androidLoadControl: AndroidLoadControl(
          minBufferDuration: Duration(seconds: 15),
          maxBufferDuration: Duration(seconds: 60),
          bufferForPlaybackDuration: Duration(milliseconds: 500),
          bufferForPlaybackAfterRebufferDuration: Duration(seconds: 2),
        ),
      ),
    );
    _initAsync();
  }

  Future<void> _initAsync() async {
    // Configure the audio session and react to focus loss / route changes.
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      _listenForInterruptions(session);
    } catch (e) {
      printERROR('AudioSession configure failed', e);
    }

    // Warm the cache directory so the first cached play does not race on mkdir.
    try {
      await StoragePaths.cachedSongsDir();
    } catch (e) {
      printERROR('Cache dir creation failed', e);
    }

    // Load prefs (tolerant of a missing/failed Hive box).
    final loop = boxGet<bool>('AppPrefs', 'isLoopModeEnabled', false);
    final repeatOne = boxGet<bool>('AppPrefs', 'isRepeatOneEnabled', false);
    _repeatMode = repeatOne
        ? AudioServiceRepeatMode.one
        : (loop ? AudioServiceRepeatMode.all : AudioServiceRepeatMode.none);
    _shuffleEnabled = boxGet<bool>('AppPrefs', 'isShuffleModeEnabled', false);
    _cacheStreamsEnabled = boxGet<bool>('AppPrefs', 'cacheSongs', true);

    // Initialize playback listeners
    _notifyPlaybackEvents();
    _listenForDurationChanges();
    _listenForCompletion();
    _publishState();
  }

  // ── Audio focus / interruptions ───────────────────────────────────────────

  void _listenForInterruptions(AudioSession session) {
    // Another app (call, navigation prompt, other player) grabbed audio focus.
    _subscriptions.add(
      session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Transient, allow-ducking: drop volume instead of pausing.
              await _player.setVolume(0.3);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_player.playing) {
                _pausedByInterruption = true;
                await _player.pause();
              }
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              await _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              if (_pausedByInterruption) {
                _pausedByInterruption = false;
                await _player.play();
              }
              break;
            case AudioInterruptionType.unknown:
              // Focus was permanently lost — stay paused.
              _pausedByInterruption = false;
              break;
          }
        }
      }, onError: (Object e) => printERROR('Interruption stream error', e)),
    );

    // Headphones unplugged / bluetooth disconnected: pause, never blast audio
    // out of the phone speaker.
    _subscriptions.add(
      session.becomingNoisyEventStream.listen((_) {
        printINFO('Audio became noisy — pausing playback');
        _pausedByInterruption = false;
        _player.pause();
      }, onError: (Object e) => printERROR('Becoming-noisy stream error', e)),
    );
  }

  // ── Broadcast playback state to AudioService ─────────────────────────────

  static const Map<ProcessingState, AudioProcessingState> _processingStateMap =
      {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      };

  void _publishState() {
    if (_disposed) return;
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        // Exposing these lets the system UI, Android Auto and wearables drive
        // seeking and shuffle/repeat, which previously did nothing.
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.playPause,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: isSongLoading
            ? AudioProcessingState.loading
            : (_processingStateMap[_player.processingState] ??
                  AudioProcessingState.idle),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _currentIndex,
        repeatMode: _repeatMode,
        shuffleMode: _shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  void _notifyPlaybackEvents() {
    _subscriptions.add(
      _player.playbackEventStream.listen(
        (PlaybackEvent event) => _publishState(),
        onError: (Object e, StackTrace st) async {
          if (e is PlayerException) {
            printERROR('PlayerException code=${e.code}: ${e.message}');
            // A dead CDN link is the common case: re-resolve and resume in place.
            await _retryCurrentWithFreshUrl();
          } else {
            printERROR('Playback stream error, retrying with fresh URL', e);
            await _retryCurrentWithFreshUrl();
          }
        },
      ),
    );
  }

  /// Re-resolves the current track's URL and resumes from the same position.
  /// Bails out (surfacing an error state) rather than looping forever.
  bool _retrying = false;

  /// Retries already attempted for [_retryKey]. A permanently dead source would
  /// otherwise retry on every error event, forever.
  static const int _maxRetriesPerTrack = 2;
  String _retryKey = '';
  int _retryCount = 0;

  Future<void> _retryCurrentWithFreshUrl() async {
    if (_retrying || _disposed) return;
    final q = queue.value;
    if (q.isEmpty || _currentIndex < 0 || _currentIndex >= q.length) return;

    final key = q[_currentIndex].id;
    if (_retryKey != key) {
      _retryKey = key;
      _retryCount = 0;
    }
    if (_retryCount >= _maxRetriesPerTrack) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorMessage: 'Could not play "${q[_currentIndex].title}". Skipping.',
        ),
      );
      // Move on instead of stalling on a track that cannot be resolved.
      await skipToNext();
      return;
    }
    _retryCount++;

    _retrying = true;
    try {
      final resumePosition = _player.position;
      await _player.stop();
      await _playSongAtIndex(_currentIndex, generateNewUrl: true);
      if (resumePosition > Duration.zero) {
        await _player.seek(resumePosition);
      }
    } catch (e) {
      printERROR('Retry with fresh URL failed', e);
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          errorMessage: 'Playback failed. Tap another track to continue.',
        ),
      );
    } finally {
      _retrying = false;
    }
  }

  void _listenForDurationChanges() {
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        final current = mediaItem.value;
        if (current != null &&
            duration != null &&
            duration > Duration.zero &&
            current.duration != duration) {
          mediaItem.add(current.copyWith(duration: duration));
        }
      }),
    );
  }

  void _listenForCompletion() {
    _subscriptions.add(
      _player.processingStateStream.listen((state) {
        if (state != ProcessingState.completed || _isTransitioning || _disposed) {
          return;
        }

        if (_repeatMode == AudioServiceRepeatMode.one) {
          // Repeat-one: restart the same track.
          _player.seek(Duration.zero);
          _player.play();
        } else {
          // none / all: advance. `skipToNext` handles wrap-around for `all`.
          skipToNext();
        }
      }),
    );
  }

  // ── Play order (shuffle support) ──────────────────────────────────────────

  void _rebuildPlayOrder({int? keepCurrent}) {
    final length = queue.value.length;
    _playOrder = List<int>.generate(length, (i) => i);
    if (_shuffleEnabled && length > 1) {
      _playOrder.shuffle(Random());
      final anchor = keepCurrent ?? _currentIndex;
      if (anchor >= 0 && anchor < length) {
        // Keep the currently playing track at the head so shuffling does not
        // interrupt it.
        _playOrder.remove(anchor);
        _playOrder.insert(0, anchor);
      }
    }
  }

  /// Position of [queueIndex] within the play order.
  int _orderPositionOf(int queueIndex) {
    final pos = _playOrder.indexOf(queueIndex);
    return pos < 0 ? 0 : pos;
  }

  /// Queue index that follows [queueIndex], or `null` at the end of the order.
  int? _nextQueueIndex(int queueIndex) {
    if (_playOrder.length != queue.value.length) _rebuildPlayOrder();
    if (_playOrder.isEmpty) return null;
    final pos = _orderPositionOf(queueIndex);
    if (pos + 1 < _playOrder.length) return _playOrder[pos + 1];
    return null;
  }

  /// Queue index that precedes [queueIndex], or `null` at the start.
  int? _previousQueueIndex(int queueIndex) {
    if (_playOrder.length != queue.value.length) _rebuildPlayOrder();
    if (_playOrder.isEmpty) return null;
    final pos = _orderPositionOf(queueIndex);
    if (pos - 1 >= 0) return _playOrder[pos - 1];
    return null;
  }

  // ── Core: Create audio source ─────────────────────────────────────────────
  Future<AudioSource> _createAudioSource(MediaItem item) async {
    final url = asText(item.extras?['url']);

    if (url.isEmpty) {
      throw Exception('Empty stream URL for song ${item.id}');
    }

    // Local file (download/cache) → plain file source
    if (url.startsWith('file://')) {
      final path = Uri.parse(url).toFilePath();
      printINFO('Playing local file: $path');
      isPlayingUsingLockCachingSource = false;
      return AudioSource.file(path, tag: item);
    }

    // Progressive on-disk caching so a streamed track is replayable offline.
    // This is what makes the "Auto-Cache Streamed Tracks" setting real; before,
    // nothing ever wrote to the cache directory.
    if (_cacheStreamsEnabled && item.id.isNotEmpty) {
      try {
        final cachePath = await StoragePaths.cacheFilePathFor(item.id);
        printINFO('Playing cached stream: $url -> $cachePath');
        isPlayingUsingLockCachingSource = true;
        // Marked experimental upstream but stable throughout just_audio 0.9.x,
        // and the only built-in way to cache while streaming.
        // ignore: experimental_member_use
        final source = LockCachingAudioSource(
          Uri.parse(url),
          cacheFile: File(cachePath),
          tag: item,
        );
        _trackCacheCompletion(item, source, cachePath);
        return source;
      } catch (e) {
        printERROR(
          'LockCachingAudioSource failed, falling back to direct stream',
          e,
        );
      }
    }

    printINFO('Playing audio stream: $url');
    isPlayingUsingLockCachingSource = false;
    return AudioSource.uri(Uri.parse(url), tag: item);
  }

  /// Registers the song in `SongsCache` once its cache file is fully written,
  /// so the Library "Cached Songs" tab and offline replay can find it.
  void _trackCacheCompletion(
    MediaItem item,
    // ignore: experimental_member_use
    LockCachingAudioSource source,
    String cachePath,
  ) {
    late final StreamSubscription<double> sub;
    sub = source.downloadProgressStream.listen(
      (progress) async {
        if (progress < 1.0) return;
        await sub.cancel();
        try {
          final file = File(cachePath);
          if (!file.existsSync() || file.lengthSync() <= 0) return;
          await boxPut('SongsCache', item.id, {
            ...MediaItemBuilder.toJson(item),
            'cachePath': cachePath,
            'cachedAt': DateTime.now().toIso8601String(),
            'size': file.lengthSync(),
          });
          printINFO('Cached ${item.id} (${file.lengthSync()} bytes)');
        } catch (e) {
          printERROR('Failed to register cache entry for ${item.id}', e);
        }
      },
      onError: (Object e) {
        printERROR('Cache download failed for ${item.id}', e);
        sub.cancel();
      },
    );
    _subscriptions.add(sub);
  }

  // ── Core: Resolve stream URL (3-tier cache: download → disk → network) ───

  /// Disk-only lookup for a playable `file://` URL. Returns `null` when the
  /// song is not available offline — never performs network I/O, so it is safe
  /// to call on every track change.
  Future<String?> _resolveOfflineUrl(String songId) async {
    if (songId.isEmpty) return null;

    // Completed stream cache.
    final cacheFile = await StoragePaths.existingCacheFile(songId);
    if (cacheFile != null) return cacheFile.uri.toString();

    // User download.
    final downloadEntry = asStringMap(
      boxGet<dynamic>('SongDownloads', songId, null),
    );
    if (downloadEntry.isEmpty) return null;

    final path = asText(downloadEntry['url']).isNotEmpty
        ? asText(downloadEntry['url'])
        : asText(asStringMap(downloadEntry['extras'])['url']);
    if (path.isEmpty) return null;

    final file = File(
      path.startsWith('file://') ? Uri.parse(path).toFilePath() : path,
    );
    if (file.existsSync() && file.lengthSync() > 0) return file.uri.toString();
    return null;
  }

  Future<HMStreamingData> checkNGetUrl(
    String songId, {
    bool generateNewUrl = false,
    bool offlineReplacementUrl = false,
    String? title,
    String? artist,
  }) async {
    printINFO(
      'checkNGetUrl: $songId (fresh=$generateNewUrl, title=$title, artist=$artist)',
    );

    if (!offlineReplacementUrl) {
      // 1. Fully cached stream on disk. Verified to exist and be non-empty —
      //    the old code trusted the Hive entry and handed the player a path
      //    that may have been evicted.
      final cacheFile = await StoragePaths.existingCacheFile(songId);
      if (cacheFile != null) {
        printINFO('Got song from stream cache: ${cacheFile.path}');
        final cacheEntry = asStringMap(
          boxGet<dynamic>('SongsCache', songId, null),
        );
        final rawStreamInfo = cacheEntry['streamInfo'];
        Audio cacheAudio;
        if (rawStreamInfo is List && rawStreamInfo.length > 1) {
          final audioJson = asStringMap(rawStreamInfo[1]);
          audioJson['url'] = cacheFile.uri.toString();
          cacheAudio = Audio.fromJson(audioJson);
        } else {
          cacheAudio = Audio(
            itag: 140,
            audioCodec: Codec.mp4a,
            bitrate: asInt(cacheEntry['bitrate']),
            duration: asInt(cacheEntry['duration']),
            loudnessDb: 0,
            url: cacheFile.uri.toString(),
            size: cacheFile.lengthSync(),
          );
        }
        return HMStreamingData(
          playable: true,
          statusMSG: 'OK',
          lowQualityAudio: cacheAudio,
          highQualityAudio: cacheAudio,
        );
      }

      // 2. Downloaded song
      final downloadEntry = asStringMap(
        boxGet<dynamic>('SongDownloads', songId, null),
      );
      if (downloadEntry.isNotEmpty) {
        final path = asText(downloadEntry['url']).isNotEmpty
            ? asText(downloadEntry['url'])
            : asText(asStringMap(downloadEntry['extras'])['url']);
        if (path.isNotEmpty) {
          final file = File(
            path.startsWith('file://') ? Uri.parse(path).toFilePath() : path,
          );
          if (file.existsSync() && file.lengthSync() > 0) {
            final Audio audio = Audio(
              itag: 140,
              audioCodec: Codec.mp4a,
              bitrate: 0,
              duration: 0,
              loudnessDb: 0,
              url: file.uri.toString(),
              size: file.lengthSync(),
            );
            return HMStreamingData(
              playable: true,
              statusMSG: 'OK',
              highQualityAudio: audio,
              lowQualityAudio: audio,
            );
          }
        }
        // Registered but missing on disk → fall through to the network.
        return checkNGetUrl(
          songId,
          offlineReplacementUrl: true,
          title: title,
          artist: artist,
        );
      }
    }

    // 3. Cached stream URL (SongsUrlCache)
    final qualityIndex = boxGet<int>('AppPrefs', 'streamingQuality', 1);
    HMStreamingData? streamInfo;

    if (!generateNewUrl) {
      final cachedJson = asStringMap(
        boxGet<dynamic>('SongsUrlCache', songId, null),
      );
      if (cachedJson.isNotEmpty) {
        final rawUrl =
            asText(asStringMap(cachedJson['lowQualityAudio'])['url']).isNotEmpty
            ? asText(asStringMap(cachedJson['lowQualityAudio'])['url'])
            : asText(asStringMap(cachedJson['highQualityAudio'])['url']);
        if (rawUrl.isNotEmpty && !isExpired(url: rawUrl)) {
          printINFO('Using cached URL for $songId');
          streamInfo = HMStreamingData.fromJson(cachedJson);
        }
      }
    }

    // 4. Resolve direct 320kbps stream via SaavnService (fastest) or StreamProvider
    if (streamInfo == null || !streamInfo.playable) {
      if (title != null && title.isNotEmpty) {
        printINFO(
          'Resolving direct 320kbps stream for $title via SaavnService',
        );
        try {
          final saavnUrl = await SaavnService.resolveAudioUrl(title, artist);
          if (saavnUrl != null && saavnUrl.isNotEmpty) {
            final audio = Audio(
              itag: 140,
              audioCodec: Codec.mp4a,
              bitrate: 320000,
              duration: 0,
              loudnessDb: 0,
              url: saavnUrl,
              size: 0,
            );
            streamInfo = HMStreamingData(
              playable: true,
              statusMSG: 'OK',
              highQualityAudio: audio,
              lowQualityAudio: audio,
            );
          }
        } catch (e) {
          printERROR('SaavnService.resolveAudioUrl failed for $title', e);
        }
      }

      if (streamInfo == null || !streamInfo.playable) {
        printINFO('Fetching stream for $songId via StreamProvider');
        try {
          final res = await StreamProvider.fetch(
            songId,
            songTitle: title,
            artistName: artist,
          );
          if (res.playable) {
            streamInfo = HMStreamingData.fromJson(res.hmStreamingData);
          }
        } catch (e) {
          printERROR('StreamProvider.fetch failed for $songId', e);
        }
      }

      if (streamInfo != null && streamInfo.playable) {
        await boxPut('SongsUrlCache', songId, streamInfo.toJson());
      }
    }

    if (streamInfo != null) {
      streamInfo.setQualityIndex(qualityIndex);
      return streamInfo;
    }

    return HMStreamingData(
      playable: false,
      statusMSG: 'Unable to resolve audio stream',
    );
  }

  // ── Core: Play song at index ─────────────────────────────────────────────
  Future<void> _playSongAtIndex(
    int index, {
    bool generateNewUrl = false,
  }) async {
    if (index < 0 || index >= queue.value.length) return;

    _currentIndex = index;
    _isTransitioning = true;
    // Re-read the caching preference so toggling it in Settings takes effect on
    // the next track without an app restart.
    _cacheStreamsEnabled = boxGet<bool>('AppPrefs', 'cacheSongs', true);

    MediaItem currentSong = queue.value[index];
    // MediaItem.extras is nullable and was force-unwrapped below; normalise once.
    if (currentSong.extras == null) {
      currentSong = currentSong.copyWith(extras: <String, dynamic>{});
      final updatedQueue = List<MediaItem>.from(queue.value);
      updatedQueue[index] = currentSong;
      queue.add(updatedQueue);
    }

    isSongLoading = true;
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
      ),
    );

    // Stop the player first to prevent completion events during transition
    try {
      await _player.stop();
    } catch (_) {}

    mediaItem.add(currentSong);

    // 1. A local file (download or completed cache) always wins. This is a
    //    disk-only lookup — it must never trigger a network round-trip.
    String? streamUrl = await _resolveOfflineUrl(currentSong.id);

    // 2. Otherwise use the URL attached to the song, or re-resolve it.
    streamUrl ??= asText(currentSong.extras?['url']).isNotEmpty
        ? asText(currentSong.extras?['url'])
        : null;

    if ((streamUrl == null || streamUrl.isEmpty || generateNewUrl) &&
        currentSong.title.isNotEmpty) {
      try {
        final resolved = await SaavnService.resolveAudioUrl(
          currentSong.title,
          currentSong.artist,
        );
        if (resolved != null && resolved.isNotEmpty) streamUrl = resolved;
      } catch (e) {
        printERROR('Direct URL resolution failed for ${currentSong.title}', e);
      }
    }

    // 3. If still missing, fall back to the full resolver chain.
    if (streamUrl == null || streamUrl.isEmpty) {
      final streamInfo = await checkNGetUrl(
        currentSong.id,
        generateNewUrl: generateNewUrl,
        title: currentSong.title,
        artist: currentSong.artist,
      );
      if (streamInfo.playable && streamInfo.activeAudio != null) {
        streamUrl = streamInfo.activeAudio!.url;
      }
    }

    // Guard: if the user skipped while we were awaiting, abandon this attempt.
    if (index != _currentIndex || _disposed) {
      _isTransitioning = false;
      return;
    }

    if (streamUrl == null || streamUrl.isEmpty) {
      currentSongUrl = null;
      isSongLoading = false;
      _isTransitioning = false;
      printERROR(
        'Cannot play: Unable to resolve audio stream for "${currentSong.title}"',
      );
      // Resolution failures are transient catalogue issues. Never surface a
      // blocking error; advance quietly so radio remains continuous.
      unawaited(skipToNext());
      return;
    }

    // Attach the resolved URL to the MediaItem extras
    currentSongUrl = streamUrl;
    final isLocal = streamUrl.startsWith('file://');
    final extras = Map<String, dynamic>.from(currentSong.extras ?? const {});
    extras['url'] = streamUrl;
    extras['bitrate'] = isLocal ? 0 : 320000;
    extras['codec'] = isLocal ? 'OFFLINE' : 'MP4A';
    currentSong = currentSong.copyWith(extras: extras);

    final syncedQueue = List<MediaItem>.from(queue.value);
    if (index < syncedQueue.length) syncedQueue[index] = currentSong;
    queue.add(syncedQueue);
    mediaItem.add(currentSong);

    if (_playOrder.length != syncedQueue.length) _rebuildPlayOrder();

    playbackState.add(playbackState.value.copyWith(queueIndex: _currentIndex));

    // Add to player and play immediately
    try {
      final audioSource = await _createAudioSource(currentSong);
      await _player.setAudioSource(audioSource, preload: true);
      isSongLoading = false;
      _isTransitioning = false;

      // Always start from the beginning
      await _player.seek(Duration.zero);
      await _player.play();
      _publishState();

      _addToRecentHistory(currentSong);

      // If the remaining queue is short, replenish with radio recommendations
      // so playback never dead-ends.
      if (_currentIndex >= queue.value.length - 3 || queue.value.length <= 4) {
        _autoReplenishRadioQueue(currentSong.id);
      }
    } catch (e) {
      printERROR('Failed to start player for ${currentSong.id}', e);
      isSongLoading = false;
      _isTransitioning = false;
      // The stream may have expired or been removed. Keep this recovery in
      // the background rather than showing a "Could not play" popup.
      unawaited(skipToNext());
    }
  }

  bool _isReplenishingQueue = false;

  /// Fetch and append similar radio tracks in the background for continuous endless playback
  Future<void> _autoReplenishRadioQueue(String seedSongId) async {
    if (_isReplenishingQueue || _disposed) return;
    _isReplenishingQueue = true;

    try {
      final currentItem = mediaItem.value;
      final seedTitle = currentItem?.title ?? '';
      final seedArtist = currentItem?.artist ?? '';
      final seedAlbum = currentItem?.album ?? '';
      final seedLanguage = asText(currentItem?.extras?['language']);

      final currentQueue = List<MediaItem>.from(queue.value);
      final recent = boxGet<List<dynamic>>('AppPrefs', 'recentSongs', const []);
      final excludeTitles = <String>{
        ...currentQueue.map((e) => e.title.toLowerCase().trim()),
        ...recent.map((e) => asText(asStringMap(e)['title']).toLowerCase().trim()),
      }.where((title) => title.isNotEmpty).toSet();

      List<SongModel> recommendedSongs = [];

      // JioSaavn native related tracks and station recommendations
      if (seedTitle.isNotEmpty) {
        final related = await SaavnService.getRelatedSongs(
          seedTitle,
          seedArtist,
          seedAlbum,
        );

        final filtered = related
            .where((song) => !excludeTitles.contains(song.title.toLowerCase().trim()))
            .toList();

        if (seedLanguage.isNotEmpty) {
          recommendedSongs = filtered
              .where(
                (song) => SaavnService.isExactLanguageMatch(
                  asText(song.extras['language']),
                  seedLanguage,
                ),
              )
              .toList();
        }

        if (recommendedSongs.isEmpty) {
          recommendedSongs = filtered.isNotEmpty ? filtered : related;
        }
      }

      if (recommendedSongs.isNotEmpty) {
        final currentQueue = List<MediaItem>.from(queue.value);
        final existingIds = currentQueue.map((e) => e.id).toSet();

        final List<MediaItem> newItems = [];
        for (final song in recommendedSongs) {
          if (song.id.isNotEmpty && !existingIds.contains(song.id)) {
            newItems.add(song.toMediaItem());
            existingIds.add(song.id);
          }
        }

        if (newItems.isNotEmpty) {
          currentQueue.addAll(newItems);
          queue.add(currentQueue);
          _rebuildPlayOrder();
          printINFO(
            'Appended ${newItems.length} radio tracks. Total: ${currentQueue.length}',
          );
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
      if (item.id.isEmpty) return;
      final List<dynamic> recent = List<dynamic>.from(
        boxGet<List<dynamic>>('AppPrefs', 'recentSongs', const []),
      );
      recent.removeWhere((e) => asText(asStringMap(e)['id']) == item.id);
      recent.insert(0, MediaItemBuilder.toJson(item));
      while (recent.length > 50) {
        recent.removeLast();
      }
      boxPut('AppPrefs', 'recentSongs', recent);
    } catch (e) {
      printERROR('Failed to update recent history', e);
    }
  }

  // ── AudioService API ──────────────────────────────────────────────────────

  @override
  Future<void> play() async {
    if (currentSongUrl == null && queue.value.isNotEmpty) {
      await _playSongAtIndex(_currentIndex.clamp(0, queue.value.length - 1));
      return;
    }
    _pausedByInterruption = false;
    await _player.play();
  }

  @override
  Future<void> pause() async {
    _pausedByInterruption = false;
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _pausedByInterruption = false;
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    final total = _player.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : (total != null && position > total ? total : position);
    await _player.seek(target);
  }

  @override
  Future<void> skipToNext() async {
    final q = queue.value;
    if (q.isEmpty) return;

    // Bounds-guard: the queue can shrink (clearQueue / playQueue) while an
    // index from the previous queue is still held. Indexing blindly threw
    // RangeError here before.
    final safeIndex = _currentIndex.clamp(0, q.length - 1);
    final next = _nextQueueIndex(safeIndex);

    if (next != null) {
      await _playSongAtIndex(next);
      return;
    }

    // Reached the end of the order: try to extend with radio tracks.
    final lastSongId = q[safeIndex].id;
    if (lastSongId.isNotEmpty) {
      await _autoReplenishRadioQueue(lastSongId);
      final replenished = _nextQueueIndex(safeIndex);
      if (replenished != null) {
        await _playSongAtIndex(replenished);
        return;
      }
    }

    if (_repeatMode == AudioServiceRepeatMode.all) {
      if (_shuffleEnabled) _rebuildPlayOrder(keepCurrent: -1);
      await _playSongAtIndex(_playOrder.isNotEmpty ? _playOrder.first : 0);
    } else {
      await _player.seek(Duration.zero);
      await _player.pause();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    final q = queue.value;
    if (q.isEmpty) return;

    // Standard music-app behaviour: restart the track if we're past 4s in.
    if (_player.position.inSeconds > 4) {
      await _player.seek(Duration.zero);
      return;
    }

    final safeIndex = _currentIndex.clamp(0, q.length - 1);
    final previous = _previousQueueIndex(safeIndex);
    if (previous != null) {
      await _playSongAtIndex(previous);
    } else if (_repeatMode == AudioServiceRepeatMode.all) {
      await _playSongAtIndex(
        _playOrder.isNotEmpty ? _playOrder.last : q.length - 1,
      );
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
    // The old implementation collapsed `all` and `one` into a single boolean,
    // so repeat-all looped a single track instead of the queue.
    _repeatMode = repeatMode;
    await boxPut(
      'AppPrefs',
      'isLoopModeEnabled',
      repeatMode == AudioServiceRepeatMode.all,
    );
    await boxPut(
      'AppPrefs',
      'isRepeatOneEnabled',
      repeatMode == AudioServiceRepeatMode.one,
    );
    _publishState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    // Previously this only stored a flag that nothing read, so the shuffle
    // button was inert. Now it rebuilds the traversal order.
    _shuffleEnabled = shuffleMode == AudioServiceShuffleMode.all;
    await boxPut('AppPrefs', 'isShuffleModeEnabled', _shuffleEnabled);
    _rebuildPlayOrder();
    _publishState();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final updated = List<MediaItem>.from(queue.value)..add(mediaItem);
    queue.add(updated);
    _rebuildPlayOrder();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    final updated = List<MediaItem>.from(queue.value);
    if (index < 0 || index >= updated.length) return;
    updated.removeAt(index);
    queue.add(updated);
    if (index < _currentIndex) _currentIndex--;
    _currentIndex = updated.isEmpty
        ? 0
        : _currentIndex.clamp(0, updated.length - 1);
    _rebuildPlayOrder();
    _publishState();
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    switch (name) {
      case 'playSong':
        if (extras == null) return false;
        final item = MediaItemBuilder.fromJson(extras['song']);
        if (item.id.isEmpty) return false;
        // A direct song selection starts a fresh radio session. Retaining
        // prior search results here made unrelated songs leak into auto-next.
        _currentIndex = 0;
        queue.add(<MediaItem>[item]);
        _rebuildPlayOrder(keepCurrent: 0);
        await _playSongAtIndex(0);
        _autoReplenishRadioQueue(item.id);
        return true;

      case 'playQueue':
        if (extras == null) return false;
        final rawList = extras['queue'] as List? ?? const [];
        final items = rawList
            .map((e) => MediaItemBuilder.fromJson(e))
            .where((e) => e.id.isNotEmpty)
            .toList();
        if (items.isEmpty) return false;
        // Clamp instead of silently doing nothing on an out-of-range index.
        final initialIndex = asInt(extras['index']).clamp(0, items.length - 1);
        _currentIndex = initialIndex;
        queue.add(items);
        _rebuildPlayOrder(keepCurrent: initialIndex);
        await _playSongAtIndex(initialIndex);
        return true;

      case 'addToQueue':
        if (extras == null) return false;
        final item = MediaItemBuilder.fromJson(extras['song']);
        if (item.id.isEmpty) return false;
        await addQueueItem(item);
        return true;

      case 'clearQueue':
        queue.add(<MediaItem>[]);
        _playOrder = <int>[];
        _currentIndex = 0;
        currentSongUrl = null;
        await _player.stop();
        mediaItem.add(null);
        _publishState();
        return true;

      case 'setCacheEnabled':
        _cacheStreamsEnabled = asBool(extras?['enabled'], true);
        return true;

      case 'dispose':
        await _dispose();
        return true;

      default:
        return false;
    }
  }

  Future<void> _dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    await super.stop();
  }

  // ── Math helper for loudness normalization ────────────────────────────────
  void normalizeVolume(double loudnessDb) {
    final diff = -5.0 - loudnessDb;
    final vol = pow(10.0, diff / 20.0).toDouble().clamp(0.0, 1.0);
    _player.setVolume(vol);
  }
}
