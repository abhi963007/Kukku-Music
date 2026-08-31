import '../utils/helper.dart';
import 'song_model.dart';

class CustomPlaylistModel {
  final String id;
  final String name;
  final String description;
  final String coverArt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int songCount;
  final List<SongModel> songs;

  CustomPlaylistModel({
    required this.id,
    required this.name,
    this.description = '',
    this.coverArt = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.songCount = 0,
    this.songs = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  CustomPlaylistModel copyWith({
    String? id,
    String? name,
    String? description,
    String? coverArt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? songCount,
    List<SongModel>? songs,
  }) {
    return CustomPlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverArt: coverArt ?? this.coverArt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      songCount: songCount ?? this.songCount,
      songs: songs ?? this.songs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'cover_art': coverArt,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'song_count': songCount,
      'songs': songs.map((s) => s.toJson()).toList(),
    };
  }

  factory CustomPlaylistModel.fromJson(dynamic json) {
    final map = asStringMap(json);
    if (map.isEmpty) {
      return CustomPlaylistModel(id: '', name: 'Untitled Playlist');
    }

    final rawSongs = map['songs'] as List? ?? const [];
    return CustomPlaylistModel(
      id: asText(map['id']),
      name: asText(map['name']).isNotEmpty ? asText(map['name']) : 'Untitled Playlist',
      description: asText(map['description']),
      coverArt: asText(map['cover_art']),
      createdAt: DateTime.tryParse(asText(map['created_at'])) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(asText(map['updated_at'])) ?? DateTime.now(),
      songCount: asInt(map['song_count'], rawSongs.length),
      songs: rawSongs.map((s) => SongModel.fromJson(s)).toList(),
    );
  }
}
