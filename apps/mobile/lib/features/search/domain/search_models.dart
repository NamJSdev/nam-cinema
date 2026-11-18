import 'package:flutter/foundation.dart';
import 'package:nam_cinema/features/home/domain/media_models.dart';

@immutable
class SearchFilterState {
  final String query;
  final String contentType; // 'all' | 'movie' | 'tv' | 'person'
  final int? genreId;
  final String? genreSlug;
  final String? countrySlug;
  final int? releaseYear;
  final String sortBy;
  final int page;
  final int totalPages;
  final List<MediaItem> results;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  const SearchFilterState({
    this.query = '',
    this.contentType = 'all',
    this.genreId,
    this.genreSlug,
    this.countrySlug,
    this.releaseYear,
    this.sortBy = 'popularity.desc',
    this.page = 1,
    this.totalPages = 1,
    this.results = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  bool get hasMore => page < totalPages;

  SearchFilterState copyWith({
    String? query,
    String? contentType,
    int? genreId,
    bool clearGenre = false,
    String? genreSlug,
    bool clearGenreSlug = false,
    String? countrySlug,
    bool clearCountrySlug = false,
    int? releaseYear,
    bool clearYear = false,
    String? sortBy,
    int? page,
    int? totalPages,
    List<MediaItem>? results,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchFilterState(
      query: query ?? this.query,
      contentType: contentType ?? this.contentType,
      genreId: clearGenre ? null : (genreId ?? this.genreId),
      genreSlug: clearGenreSlug ? null : (genreSlug ?? this.genreSlug),
      countrySlug: clearCountrySlug ? null : (countrySlug ?? this.countrySlug),
      releaseYear: clearYear ? null : (releaseYear ?? this.releaseYear),
      sortBy: sortBy ?? this.sortBy,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
