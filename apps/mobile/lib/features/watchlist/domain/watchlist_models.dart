import 'package:flutter/foundation.dart';
import 'package:nam_cinema/features/home/domain/media_models.dart';

@immutable
class WatchlistEntryModel {
  final String id;
  final int tmdbId;
  final String contentType;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String? releaseYear;
  final DateTime createdAt;

  const WatchlistEntryModel({
    required this.id,
    required this.tmdbId,
    required this.contentType,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.voteAverage,
    this.releaseYear,
    required this.createdAt,
  });

  factory WatchlistEntryModel.fromJson(Map<String, dynamic> json) {
    return WatchlistEntryModel(
      id: (json['id'] as String?) ?? '',
      tmdbId: (json['tmdb_id'] as num).toInt(),
      contentType: (json['content_type'] as String?) ?? 'movie',
      title: (json['title'] as String?) ?? 'Untitled',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseYear: json['release_year'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tmdb_id': tmdbId,
      'content_type': contentType,
      'title': title,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'vote_average': voteAverage,
      'release_year': releaseYear,
      'created_at': createdAt.toIso8601String(),
    };
  }

  MediaItem toMediaItem() {
    return MediaItem(
      tmdbId: tmdbId,
      contentType: contentType,
      title: title,
      posterUrl: posterPath,
      backdropUrl: backdropPath,
      releaseDate: releaseYear,
      voteAverage: voteAverage,
    );
  }
}
