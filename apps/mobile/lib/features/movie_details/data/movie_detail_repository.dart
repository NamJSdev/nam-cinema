import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/core/network/api_client.dart';
import 'package:nam_cinema/features/home/domain/media_models.dart';

@immutable
class MovieDetailModel {
  final int tmdbId;
  final String? slug;
  final String title;
  final String originalTitle;
  final String overview;
  final String? posterUrl;
  final String? backdropUrl;
  final String? releaseDate;
  final int? runtimeMinutes;
  final String? durationLabel;
  final String? quality;
  final String? lang;
  final String? episodeCurrent;
  final String? episodeTotal;
  final double voteAverage;
  final int voteCount;
  final List<GenreModel> genres;
  final List<CountryModel> countries;
  final String? director;
  final List<CastMemberModel> cast;
  final List<VideoTrailerModel> trailers;
  final List<MediaItem> recommendations;
  final List<MediaItem> similar;
  final TitleAvailabilityModel availability;

  const MovieDetailModel({
    required this.tmdbId,
    this.slug,
    required this.title,
    required this.originalTitle,
    required this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.releaseDate,
    this.runtimeMinutes,
    this.durationLabel,
    this.quality,
    this.lang,
    this.episodeCurrent,
    this.episodeTotal,
    required this.voteAverage,
    required this.voteCount,
    this.genres = const [],
    this.countries = const [],
    this.director,
    this.cast = const [],
    this.trailers = const [],
    this.recommendations = const [],
    this.similar = const [],
    required this.availability,
  });

  factory MovieDetailModel.fromJson(Map<String, dynamic> json) {
    return MovieDetailModel(
      tmdbId: (json['tmdb_id'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String?,
      title: (json['title'] as String?) ?? 'Untitled',
      originalTitle: (json['original_title'] as String?) ?? '',
      overview: (json['overview'] as String?) ?? '',
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      releaseDate: json['release_date'] as String?,
      runtimeMinutes: (json['runtime_minutes'] as num?)?.toInt(),
      durationLabel: json['duration_label'] as String?,
      quality: json['quality'] as String?,
      lang: json['lang'] as String?,
      episodeCurrent: json['episode_current'] as String?,
      episodeTotal: json['episode_total'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      genres: (json['genres'] as List<dynamic>? ?? const [])
          .map((e) => GenreModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      countries: (json['countries'] as List<dynamic>? ?? const [])
          .map((e) => CountryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      director: json['director'] as String?,
      cast: (json['cast'] as List<dynamic>? ?? const [])
          .map((e) => CastMemberModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      trailers: (json['trailers'] as List<dynamic>? ?? const [])
          .map((e) => VideoTrailerModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendations: (json['recommendations'] as List<dynamic>? ?? const [])
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      similar: (json['similar'] as List<dynamic>? ?? const [])
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      availability: TitleAvailabilityModel.fromJson(
        json['availability'] as Map<String, dynamic>,
      ),
    );
  }
}

class MovieDetailRepository {
  final ApiClient _apiClient;

  const MovieDetailRepository(this._apiClient);

  Future<MovieDetailModel> fetchMovieDetail(String identifier) async {
    try {
      final response = await _apiClient.rawDio.get<Map<String, dynamic>>(
        '/movies/$identifier',
      );
      return MovieDetailModel.fromJson(response.data!);
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }
}

final movieDetailRepositoryProvider = Provider<MovieDetailRepository>((ref) {
  return MovieDetailRepository(ref.watch(apiClientProvider));
});

final movieDetailProvider =
    FutureProvider.family<MovieDetailModel, String>((ref, identifier) async {
  return ref
      .watch(movieDetailRepositoryProvider)
      .fetchMovieDetail(identifier);
});
