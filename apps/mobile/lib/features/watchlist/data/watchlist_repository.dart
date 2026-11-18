import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/core/database/local_cache_store.dart';
import 'package:nam_cinema/core/network/api_client.dart';
import 'package:nam_cinema/features/authentication/data/auth_repository.dart';
import 'package:nam_cinema/features/watchlist/domain/watchlist_models.dart';

class WatchlistRepository {
  final ApiClient _apiClient;
  final LocalCacheStore _localCache;

  const WatchlistRepository({
    required ApiClient apiClient,
    required LocalCacheStore localCache,
  })  : _apiClient = apiClient,
        _localCache = localCache;

  Future<List<WatchlistEntryModel>> fetchWatchlist() async {
    try {
      final response =
          await _apiClient.rawDio.get<List<dynamic>>('/me/watchlist');
      final list = (response.data ?? const [])
          .map((e) => WatchlistEntryModel.fromJson(e as Map<String, dynamic>))
          .toList();
      await _localCache.saveWatchlistJson(
        list.map((e) => e.toJson()).toList(),
      );
      return list;
    } catch (_) {
      // Offline fallback to cached local entries
      return _localCache
          .readWatchlistJson()
          .map(WatchlistEntryModel.fromJson)
          .toList();
    }
  }

  Future<WatchlistEntryModel> addToWatchlist({
    required int tmdbId,
    required String contentType,
    required String title,
    String? posterPath,
    String? backdropPath,
    double voteAverage = 0.0,
    String? releaseYear,
  }) async {
    try {
      final response = await _apiClient.rawDio.post<Map<String, dynamic>>(
        '/me/watchlist',
        data: {
          'tmdb_id': tmdbId,
          'content_type': contentType,
          'title': title,
          'poster_path': posterPath,
          'backdrop_path': backdropPath,
          'vote_average': voteAverage,
          'release_year': releaseYear,
        },
      );
      return WatchlistEntryModel.fromJson(response.data!);
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }

  Future<void> removeFromWatchlist(String idOrTmdbId) async {
    try {
      await _apiClient.rawDio.delete<Map<String, dynamic>>(
        '/me/watchlist/$idOrTmdbId',
      );
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }
}

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return WatchlistRepository(
    apiClient: ref.watch(apiClientProvider),
    localCache: ref.watch(localCacheStoreProvider),
  );
});

class WatchlistController
    extends StateNotifier<AsyncValue<List<WatchlistEntryModel>>> {
  final WatchlistRepository _repository;
  final bool _isAuthenticated;

  WatchlistController({
    required WatchlistRepository repository,
    required bool isAuthenticated,
  })  : _repository = repository,
        _isAuthenticated = isAuthenticated,
        super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    if (!_isAuthenticated) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final items = await _repository.fetchWatchlist();
      state = AsyncValue.data(items);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  bool isSaved(int tmdbId, String contentType) {
    final items = state.valueOrNull ?? const [];
    return items.any(
      (e) => e.tmdbId == tmdbId && e.contentType == contentType,
    );
  }

  Future<void> toggleWatchlist({
    required int tmdbId,
    required String contentType,
    required String title,
    String? posterPath,
    String? backdropPath,
    double voteAverage = 0.0,
    String? releaseYear,
  }) async {
    final current = List<WatchlistEntryModel>.from(state.valueOrNull ?? const []);
    final existingIdx = current.indexWhere(
      (e) => e.tmdbId == tmdbId && e.contentType == contentType,
    );

    if (existingIdx >= 0) {
      final existing = current[existingIdx];
      current.removeAt(existingIdx);
      state = AsyncValue.data(current);
      await _repository.removeFromWatchlist(existing.id);
    } else {
      final created = await _repository.addToWatchlist(
        tmdbId: tmdbId,
        contentType: contentType,
        title: title,
        posterPath: posterPath,
        backdropPath: backdropPath,
        voteAverage: voteAverage,
        releaseYear: releaseYear,
      );
      state = AsyncValue.data([created, ...current]);
    }
  }
}

final watchlistControllerProvider = StateNotifierProvider<WatchlistController,
    AsyncValue<List<WatchlistEntryModel>>>((ref) {
  final isAuth = ref.watch(authControllerProvider.select((s) => s.isAuthenticated));
  return WatchlistController(
    repository: ref.watch(watchlistRepositoryProvider),
    isAuthenticated: isAuth,
  );
});
