import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/search/data/search_repository.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(searchControllerProvider.notifier).loadNextPage();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchControllerProvider);
    final notifier = ref.read(searchControllerProvider.notifier);
    final genresAsync = ref.watch(genresProvider);
    final countriesAsync = ref.watch(countriesProvider);
    final recentSearches = notifier.recentSearches;

    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm & Khám phá VSMOV')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: NamCinemaSearchBar(
              controller: _textController,
              onChanged: notifier.onQueryChanged,
              onClear: () {
                _textController.clear();
                notifier.onQueryChanged('');
              },
            ),
          ),

          // Content Type & Year Filter Row
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                GenreChip(
                  label: 'Tất cả',
                  selected: searchState.contentType == 'all',
                  onTap: () => notifier.setContentType('all'),
                ),
                const SizedBox(width: 8),
                GenreChip(
                  label: 'Phim lẻ',
                  selected: searchState.contentType == 'movie',
                  onTap: () => notifier.setContentType('movie'),
                ),
                const SizedBox(width: 8),
                GenreChip(
                  label: 'Phim bộ',
                  selected: searchState.contentType == 'tv',
                  onTap: () => notifier.setContentType('tv'),
                ),
                const SizedBox(width: 12),
                for (final year in [2026, 2025, 2024, 2023, 2022]) ...[
                  GenreChip(
                    label: 'Năm $year',
                    selected: searchState.releaseYear == year,
                    onTap: () => notifier.setReleaseYear(year),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // VSMOV Genre Filter Row (/the-loai)
          genresAsync.when(
            data: (genres) => genres.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: genres.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final g = genres[idx];
                        final isSelected = (g.slug != null &&
                                searchState.genreSlug == g.slug) ||
                            searchState.genreId == g.id;
                        return GenreChip(
                          label: g.name,
                          selected: isSelected,
                          onTap: () => notifier.setGenre(g.id, slug: g.slug),
                        );
                      },
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),

          // VSMOV Country Filter Row (/quoc-gia)
          countriesAsync.when(
            data: (countries) => countries.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: countries.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final c = countries[idx];
                        return GenreChip(
                          label: c.name,
                          selected: searchState.countrySlug == c.slug,
                          onTap: () => notifier.setCountrySlug(c.slug),
                        );
                      },
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Recent Searches Bar when input is empty
          if (searchState.query.isEmpty && recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Gần đây:',
                    style: TextStyle(
                      color: NamCinemaColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  for (final item in recentSearches.take(5))
                    ActionChip(
                      label: Text(item, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        _textController.text = item;
                        notifier.onQueryChanged(item);
                      },
                    ),
                  TextButton(
                    onPressed: notifier.clearRecentSearches,
                    child: const Text(
                      'Xóa',
                      style: TextStyle(
                        color: NamCinemaColors.primaryAccent,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Results Grid
          Expanded(
            child: searchState.isLoading
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 160,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.56,
                    ),
                    itemCount: 9,
                    itemBuilder: (_, __) => const LoadingSkeleton(),
                  )
                : searchState.errorMessage != null
                    ? ErrorState(
                        message: searchState.errorMessage!,
                        onRetry: () => notifier.executeSearch(resetPage: true),
                      )
                    : searchState.results.isEmpty
                        ? const EmptyState(
                            icon: Icons.movie_filter_outlined,
                            title: 'Không tìm thấy kết quả phù hợp',
                            subtitle:
                                'Thử tìm kiếm với từ khóa khác hoặc bỏ bộ lọc năm/thể loại/quốc gia.',
                          )
                        : GridView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 160,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.56,
                            ),
                            itemCount: searchState.results.length +
                                (searchState.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, idx) {
                              if (idx >= searchState.results.length) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final item = searchState.results[idx];
                              return MoviePosterCard(
                                item: item,
                                onTap: () {
                                  final id = item.routeIdentifier;
                                  if (item.contentType == 'tv') {
                                    context.push('/tv/$id');
                                  } else {
                                    context.push('/movie/$id');
                                  }
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
