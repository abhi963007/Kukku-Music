import 'package:audio_service/audio_service.dart';

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
    if (json == null) {
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
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'] ?? 'Unknown Album',
      artUri: json['artUri'] ?? '',
      duration: Duration(milliseconds: json['durationMs'] ?? 0),
      extras: json['extras'] != null ? Map<String, dynamic>.from(json['extras']) : {},
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
    return MediaItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'] ?? 'Unknown Album',
      artUri: json['artUri'] != null ? Uri.tryParse(json['artUri']) : null,
      duration: Duration(milliseconds: json['duration'] ?? 0),
      extras: json['extras'] != null ? Map<String, dynamic>.from(json['extras']) : {},
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
    if (json == null) {
      return AlbumModel(id: '', title: '', artist: '', artUri: '');
    }
    final rawSongs = json['songs'] as List? ?? [];
    return AlbumModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? '',
      artUri: json['artUri']?.toString() ?? '',
      year: json['year']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      songCount: int.tryParse(json['songCount']?.toString() ?? '0') ?? 0,
      songs: rawSongs.map((e) => SongModel.fromJson(e)).toList(),
    );
  }
}
