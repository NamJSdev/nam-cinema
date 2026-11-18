import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/core/config/env_config.dart';
import 'package:nam_cinema/core/database/local_cache_store.dart';
import 'package:nam_cinema/core/network/api_client.dart';
import 'package:nam_cinema/features/home/domain/media_models.dart';
import 'package:nam_cinema/features/search/domain/search_models.dart';

class SearchRepository {
  final ApiClient _apiClient;

  const SearchRepository(this._apiClient);

  Future<({int page, int totalPages, List<MediaItem> results})> search({
    required String query,
    required String type,
    int? genreId,
    String? genreSlug,
    String? countrySlug,
    int? year,
    String sortBy = 'popularity.desc',
    int page = 1,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _apiClient.rawDio.get<Map<String, dynamic>>(
        '/search',
        cancelToken: cancelToken,
        queryParameters: {
          'q': query,
          'type': type,
          if (genreId != null) 'genre_id': genreId,
          if (genreSlug != null && genreSlug.isNotEmpty)
            'genre_slug': genreSlug,
          if (countrySlug != null && countrySlug.isNotEmpty)
            'country_slug': countrySlug,
          if (year != null) 'year': year,
          'sort_by': sortBy,
          'page': page,
        },
      );
      final data = response.data!;
      final items = (data['results'] as List<dynamic>? ?? const [])
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return (
        page: (data['page'] as num?)?.toInt() ?? 1,
        totalPages: (data['total_pages'] as num?)?.toInt() ?? 1,
        results: items,
      );
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }

  Future<List<GenreModel>> fetchGenres() async {
    try {
      final response = await _apiClient.rawDio.get<List<dynamic>>('/genres');
      return (response.data ?? const [])
          .map((e) => GenreModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<CountryModel>> fetchCountries() async {
    try {
      final response = await _apiClient.rawDio.get<List<dynamic>>('/countries');
      return (response.data ?? const [])
          .map((e) => CountryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(apiClientProvider));
});

final genresProvider = FutureProvider<List<GenreModel>>((ref) async {
  return ref.watch(searchRepositoryProvider).fetchGenres();
});

final countriesProvider = FutureProvider<List<CountryModel>>((ref) async {
  return ref.watch(searchRepositoryProvider).fetchCountries();
});

class SearchController extends StateNotifier<SearchFilterState> {
  final SearchRepository _repository;
  final LocalCacheStore _localCache;
  Timer? _debounceTimer;
  CancelToken? _activeCancelToken;

  SearchController({
    required SearchRepository repository,
    required LocalCacheStore localCache,
  })  : _repository = repository,
        _localCache = localCache,
        super(const SearchFilterState()) {
    executeSearch(resetPage: true);
  }

  List<String> get recentSearches => _localCache.getRecentSearches();

  void onQueryChanged(String newQuery) {
    state = state.copyWith(query: newQuery);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(AppEnvConfig.searchDebounceDuration, () {
      if (newQuery.trim().isNotEmpty) {
        _localCache.addRecentSearch(newQuery.trim());
      }
      executeSearch(resetPage: true);
    });
  }

  void setContentType(String contentType) {
    if (state.contentType == contentType) return;
    state = state.copyWith(contentType: contentType);
    executeSearch(resetPage: true);
  }

  void setGenre(int? genreId, {String? slug}) {
    if (state.genreId == genreId && state.genreSlug == slug) {
      state = state.copyWith(clearGenre: true, clearGenreSlug: true);
    } else {
      state = state.copyWith(
        genreId: genreId,
        genreSlug: slug,
        clearCountrySlug: true,
      );
    }
    executeSearch(resetPage: true);
  }

  void setCountrySlug(String? slug) {
    if (state.countrySlug == slug) {
      state = state.copyWith(clearCountrySlug: true);
    } else {
      state = state.copyWith(
        countrySlug: slug,
        clearGenre: true,
        clearGenreSlug: true,
      );
    }
    executeSearch(resetPage: true);
  }

  void setReleaseYear(int? year) {
    if (state.releaseYear == year) {
      state = state.copyWith(clearYear: true);
    } else {
      state = state.copyWith(releaseYear: year);
    }
    executeSearch(resetPage: true);
  }

  Future<void> clearRecentSearches() async {
    await _localCache.clearRecentSearches();
    state = state.copyWith();
  }

  Future<void> executeSearch({bool resetPage = true}) async {
    _activeCancelToken?.cancel();
    _activeCancelToken = CancelToken();

    final nextPage = resetPage ? 1 : state.page + 1;
    state = state.copyWith(
      isLoading: resetPage,
      isLoadingMore: !resetPage,
      clearError: true,
    );

    try {
      final result = await _repository.search(
        query: state.query,
        type: state.contentType,
        genreId: state.genreId,
        genreSlug: state.genreSlug,
        countrySlug: state.countrySlug,
        year: state.releaseYear,
        sortBy: state.sortBy,
        page: nextPage,
        cancelToken: _activeCancelToken,
      );

      state = state.copyWith(
        page: result.page,
        totalPages: result.totalPages,
        results: resetPage
            ? result.results
            : [...state.results, ...result.results],
        isLoading: false,
        isLoadingMore: false,
      );
    } catch (error) {
      if (error.toString().contains('cancel')) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    await executeSearch(resetPage: false);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _activeCancelToken?.cancel();
    super.dispose();
  }
}

final searchControllerProvider =
    StateNotifierProvider<SearchController, SearchFilterState>((ref) {
  return SearchController(
    repository: ref.watch(searchRepositoryProvider),
    localCache: ref.watch(localCacheStoreProvider),
  );
});
