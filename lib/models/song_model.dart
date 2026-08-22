import 'package:audio_service/audio_service.dart';

import '../utils/helper.dart';

class SongModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String artUri;
  final Duration duration;
  final Map<String, dynamic> extras;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.artUri,
    required this.duration,
    Map<String, dynamic>? extras,
  }) : extras = extras ?? {};

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri.isNotEmpty ? Uri.tryParse(artUri) : null,
      duration: duration,
      extras: Map<String, dynamic>.from(extras),
    );
  }

  factory SongModel.fromMediaItem(MediaItem item) {
    return SongModel(
      id: item.id,
      title: item.title,
      artist: item.artist ?? "Unknown Artist",
      album: item.album ?? "Single",
      artUri: item.artUri?.toString() ?? "",
      duration: item.duration ?? Duration.zero,
      extras: item.extras != null ? Map<String, dynamic>.from(item.extras!) : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'artUri': artUri,
      'durationMs': duration.inMilliseconds,
      'extras': extras,
    };
  }

  factory SongModel.fromJson(dynamic json) {
    final map = asStringMap(json);
    if (map.isEmpty) {
      return SongModel(
        id: '',
        title: 'Unknown Title',
        artist: 'Unknown Artist',
        album: 'Unknown Album',
        artUri: '',
        duration: Duration.zero,
      );
    }
    return SongModel(
      id: asText(map['id']),
      title: asText(map['title']).isNotEmpty ? asText(map['title']) : 'Unknown Title',
      artist: asText(map['artist']).isNotEmpty ? asText(map['artist']) : 'Unknown Artist',
      album: asText(map['album']).isNotEmpty ? asText(map['album']) : 'Unknown Album',
      artUri: asText(map['artUri']),
      duration: Duration(milliseconds: asInt(map['durationMs'])),
      extras: asStringMap(map['extras']),
    );
  }
}

class MediaItemBuilder {
  static Map<String, dynamic> toJson(MediaItem item) {
    return {
      'id': item.id,
      'title': item.title,
      'artist': item.artist,
      'album': item.album,
      'artUri': item.artUri?.toString(),
      'duration': item.duration?.inMilliseconds,
      'extras': item.extras,
    };
  }

  static MediaItem fromJson(dynamic json) {
    final map = asStringMap(json);
    final artUri = asText(map['artUri']);
    return MediaItem(
      id: asText(map['id']),
      title: asText(map['title']).isNotEmpty ? asText(map['title']) : 'Unknown Title',
      artist: asText(map['artist']).isNotEmpty ? asText(map['artist']) : 'Unknown Artist',
      album: asText(map['album']).isNotEmpty ? asText(map['album']) : 'Unknown Album',
      artUri: artUri.isNotEmpty ? Uri.tryParse(artUri) : null,
      duration: Duration(milliseconds: asInt(map['duration'])),
      extras: asStringMap(map['extras']),
    );
  }
}

class AlbumModel {
  final String id;
  final String title;
  final String artist;
  final String artUri;
  final String year;
  final String language;
  final int songCount;
  final List<SongModel> songs;

  AlbumModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.artUri,
    this.year = '',
    this.language = '',
    this.songCount = 0,
    this.songs = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'artUri': artUri,
      'year': year,
      'language': language,
      'songCount': songCount,
      'songs': songs.map((e) => e.toJson()).toList(),
    };
  }

  factory AlbumModel.fromJson(dynamic json) {
    final map = asStringMap(json);
    if (map.isEmpty) {
      return AlbumModel(id: '', title: '', artist: '', artUri: '');
    }
    final rawSongs = map['songs'] as List? ?? const [];
    return AlbumModel(
      id: asText(map['id']),
      title: asText(map['title']),
      artist: asText(map['artist']),
      artUri: asText(map['artUri']),
      year: asText(map['year']),
      language: asText(map['language']),
      songCount: asInt(map['songCount']),
      songs: rawSongs.map((e) => SongModel.fromJson(e)).toList(),
    );
  }
}
