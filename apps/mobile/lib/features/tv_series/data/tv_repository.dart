import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/core/network/api_client.dart';
import 'package:nam_cinema/features/home/domain/media_models.dart';

@immutable
class SeasonSummaryModel {
  final int id;
  final int seasonNumber;
  final String name;
  final int episodeCount;
  final String overview;
  final String? posterUrl;
  final String? airDate;

  const SeasonSummaryModel({
    required this.id,
    required this.seasonNumber,
    required this.name,
    required this.episodeCount,
    this.overview = '',
    this.posterUrl,
    this.airDate,
  });

  factory SeasonSummaryModel.fromJson(Map<String, dynamic> json) {
    return SeasonSummaryModel(
      id: (json['id'] as num?)?.toInt() ?? 1,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 1,
      name: (json['name'] as String?) ?? '',
      episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
      overview: (json['overview'] as String?) ?? '',
      posterUrl: json['poster_url'] as String?,
      airDate: json['air_date'] as String?,
    );
  }
}

@immutable
class EpisodeModel {
  final int id;
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String? slug;
  final String? serverName;
  final String overview;
  final String? stillUrl;
  final String? airDate;
  final int? runtimeMinutes;
  final double voteAverage;
  final bool isPlayable;
  final String? playableAssetId;
  final String? embedReferenceUrl;

  const EpisodeModel({
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    this.slug,
    this.serverName,
    this.overview = '',
    this.stillUrl,
    this.airDate,
    this.runtimeMinutes,
    this.voteAverage = 0.0,
    this.isPlayable = false,
    this.playableAssetId,
    this.embedReferenceUrl,
  });

  factory EpisodeModel.fromJson(Map<String, dynamic> json) {
    return EpisodeModel(
      id: (json['id'] as num?)?.toInt() ?? 1,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 1,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 1,
      name: (json['name'] as String?) ?? '',
      slug: json['slug'] as String?,
      serverName: json['server_name'] as String?,
      overview: (json['overview'] as String?) ?? '',
      stillUrl: json['still_url'] as String?,
      airDate: json['air_date'] as String?,
      runtimeMinutes: (json['runtime_minutes'] as num?)?.toInt(),
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      isPlayable: (json['is_playable'] as bool?) ?? false,
      playableAssetId: json['playable_asset_id'] as String?,
      embedReferenceUrl: json['embed_reference_url'] as String?,
    );
  }
}

@immutable
class TvDetailModel {
  final int tmdbId;
  final String? slug;
  final String title;
  final String originalTitle;
  final String overview;
  final String? posterUrl;
  final String? backdropUrl;
  final String? firstAirDate;
  final String? quality;
  final String? lang;
  final String? episodeCurrent;
  final String? episodeTotal;
  final int numberOfSeasons;
  final int numberOfEpisodes;
  final double voteAverage;
  final int voteCount;
  final List<GenreModel> genres;
  final List<CountryModel> countries;
  final List<CastMemberModel> cast;
  final List<VideoTrailerModel> trailers;
  final List<SeasonSummaryModel> seasons;
  final List<MediaItem> recommendations;
  final List<MediaItem> similar;
  final TitleAvailabilityModel availability;

  const TvDetailModel({
    required this.tmdbId,
    this.slug,
    required this.title,
    required this.originalTitle,
    required this.overview,
    this.posterUrl,
    this.backdropUrl,
    this.firstAirDate,
    this.quality,
    this.lang,
    this.episodeCurrent,
    this.episodeTotal,
    required this.numberOfSeasons,
    required this.numberOfEpisodes,
    required this.voteAverage,
    required this.voteCount,
    this.genres = const [],
    this.countries = const [],
    this.cast = const [],
    this.trailers = const [],
    this.seasons = const [],
    this.recommendations = const [],
    this.similar = const [],
    required this.availability,
  });

  factory TvDetailModel.fromJson(Map<String, dynamic> json) {
    return TvDetailModel(
      tmdbId: (json['tmdb_id'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String?,
      title: (json['title'] as String?) ?? 'Untitled',
      originalTitle: (json['original_title'] as String?) ?? '',
      overview: (json['overview'] as String?) ?? '',
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      firstAirDate: json['first_air_date'] as String?,
      quality: json['quality'] as String?,
      lang: json['lang'] as String?,
      episodeCurrent: json['episode_current'] as String?,
      episodeTotal: json['episode_total'] as String?,
      numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt() ?? 0,
      numberOfEpisodes: (json['number_of_episodes'] as num?)?.toInt() ?? 0,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      genres: (json['genres'] as List<dynamic>? ?? const [])
          .map((e) => GenreModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      countries: (json['countries'] as List<dynamic>? ?? const [])
          .map((e) => CountryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      cast: (json['cast'] as List<dynamic>? ?? const [])
          .map((e) => CastMemberModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      trailers: (json['trailers'] as List<dynamic>? ?? const [])
          .map((e) => VideoTrailerModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      seasons: (json['seasons'] as List<dynamic>? ?? const [])
          .map((e) => SeasonSummaryModel.fromJson(e as Map<String, dynamic>))
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

class TvRepository {
  final ApiClient _apiClient;

  const TvRepository(this._apiClient);

  Future<TvDetailModel> fetchTvDetail(String identifier) async {
    try {
      final response = await _apiClient.rawDio.get<Map<String, dynamic>>(
        '/tv/$identifier',
      );
      return TvDetailModel.fromJson(response.data!);
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }

  Future<List<EpisodeModel>> fetchSeasonEpisodes(
    String identifier,
    int seasonNumber,
  ) async {
    try {
      final response = await _apiClient.rawDio.get<Map<String, dynamic>>(
        '/tv/$identifier/seasons/$seasonNumber',
      );
      final data = response.data!;
      return (data['episodes'] as List<dynamic>? ?? const [])
          .map((e) => EpisodeModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }
}

final tvRepositoryProvider = Provider<TvRepository>((ref) {
  return TvRepository(ref.watch(apiClientProvider));
});

final tvDetailProvider =
    FutureProvider.family<TvDetailModel, String>((ref, identifier) async {
  return ref.watch(tvRepositoryProvider).fetchTvDetail(identifier);
});

final tvSeasonEpisodesProvider = FutureProvider.family<List<EpisodeModel>,
    ({String identifier, int seasonNumber})>((ref, args) async {
  return ref
      .watch(tvRepositoryProvider)
      .fetchSeasonEpisodes(args.identifier, args.seasonNumber);
});
