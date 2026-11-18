import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/core/database/local_cache_store.dart';
import 'package:nam_cinema/core/network/api_client.dart';
import 'package:nam_cinema/features/authentication/data/auth_repository.dart';
import 'package:nam_cinema/features/home/domain/media_models.dart';

class HistoryRepository {
  final ApiClient _apiClient;
  final LocalCacheStore _localCache;

  const HistoryRepository({
    required ApiClient apiClient,
    required LocalCacheStore localCache,
  })  : _apiClient = apiClient,
        _localCache = localCache;

  Future<List<WatchHistoryModel>> fetchHistory() async {
    try {
      final response =
          await _apiClient.rawDio.get<List<dynamic>>('/me/history');
      final items = (response.data ?? const [])
          .map((e) => WatchHistoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      await _localCache.saveHistoryJson(
        items.map((e) => e.toJson()).toList(),
      );
      return items;
    } catch (_) {
      return _localCache
          .readHistoryJson()
          .map(WatchHistoryModel.fromJson)
          .toList();
    }
  }

  Future<WatchHistoryModel> updateProgress({
    required int tmdbId,
    required String contentType,
    int? seasonNumber,
    int? episodeNumber,
    String? assetId,
    required String title,
    String? posterPath,
    String? backdropPath,
    required int currentPositionSeconds,
    required int durationSeconds,
    bool? isCompleted,
  }) async {
    try {
      final response = await _apiClient.rawDio.put<Map<String, dynamic>>(
        '/me/progress',
        data: {
          'tmdb_id': tmdbId,
          'content_type': contentType,
          'season_number': seasonNumber,
          'episode_number': episodeNumber,
          'asset_id': assetId,
          'title': title,
          'poster_path': posterPath,
          'backdrop_path': backdropPath,
          'current_position_seconds': currentPositionSeconds,
          'duration_seconds': durationSeconds,
          if (isCompleted != null) 'is_completed': isCompleted,
        },
      );
      return WatchHistoryModel.fromJson(response.data!);
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }

  Future<void> deleteHistoryEntry(String historyId) async {
    try {
      await _apiClient.rawDio.delete<Map<String, dynamic>>(
        '/me/history/$historyId',
      );
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }
}

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository(
    apiClient: ref.watch(apiClientProvider),
    localCache: ref.watch(localCacheStoreProvider),
  );
});

final watchHistoryProvider =
    FutureProvider<List<WatchHistoryModel>>((ref) async {
  final isAuth = ref.watch(authControllerProvider.select((s) => s.isAuthenticated));
  if (!isAuth) return const [];
  return ref.watch(historyRepositoryProvider).fetchHistory();
});
