import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/core/network/api_client.dart';
import 'package:nam_cinema/features/authentication/data/auth_repository.dart';
import 'package:nam_cinema/features/home/domain/media_models.dart';

@immutable
class HomeFeedData {
  final List<MediaItem> featuredHero;
  final List<MediaItem> trendingToday;
  final List<MediaItem> popularMovies;
  final List<MediaItem> popularTvSeries;
  final List<MediaItem> topRatedMovies;
  final List<MediaItem> koreanMovies;
  final List<MediaItem> chineseMovies;
  final List<MediaItem> hollywoodMovies;
  final List<MediaItem> animationMovies;
  final List<WatchHistoryModel> continueWatching;
  final List<MediaItem> recommendedTitles;
  final List<MediaItem> recentlyAddedPlayable;
  final bool tmdbConfigured;
  final String? upstreamNotice;

  const HomeFeedData({
    this.featuredHero = const [],
    this.trendingToday = const [],
    this.popularMovies = const [],
    this.popularTvSeries = const [],
    this.topRatedMovies = const [],
    this.koreanMovies = const [],
    this.chineseMovies = const [],
    this.hollywoodMovies = const [],
    this.animationMovies = const [],
    this.continueWatching = const [],
    this.recommendedTitles = const [],
    this.recentlyAddedPlayable = const [],
    this.tmdbConfigured = true,
    this.upstreamNotice,
  });

  factory HomeFeedData.fromJson(Map<String, dynamic> json) {
    List<MediaItem> parseList(String key) {
      final list = json[key] as List<dynamic>? ?? const [];
      return list
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return HomeFeedData(
      featuredHero: parseList('featured_hero'),
      trendingToday: parseList('trending_today'),
      popularMovies: parseList('popular_movies'),
      popularTvSeries: parseList('popular_tv_series'),
      topRatedMovies: parseList('top_rated_movies'),
      koreanMovies: parseList('korean_movies'),
      chineseMovies: parseList('chinese_movies'),
      hollywoodMovies: parseList('hollywood_movies'),
      animationMovies: parseList('animation_movies'),
      continueWatching: (json['continue_watching'] as List<dynamic>? ?? const [])
          .map((e) => WatchHistoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommendedTitles: parseList('recommended_titles'),
      recentlyAddedPlayable: parseList('recently_added_playable'),
      tmdbConfigured: (json['tmdb_configured'] as bool?) ?? true,
      upstreamNotice: json['upstream_notice'] as String?,
    );
  }
}

class HomeRepository {
  final ApiClient _apiClient;

  const HomeRepository(this._apiClient);

  Future<HomeFeedData> fetchHomeFeed() async {
    try {
      final response = await _apiClient.rawDio.get<Map<String, dynamic>>('/home');
      return HomeFeedData.fromJson(response.data!);
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }
}

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

final homeFeedProvider = FutureProvider<HomeFeedData>((ref) async {
  // Rebuild when auth user changes so Continue Watching reflects current user
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  final repo = ref.watch(homeRepositoryProvider);
  return repo.fetchHomeFeed();
});
