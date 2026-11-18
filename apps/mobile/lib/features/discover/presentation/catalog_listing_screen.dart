import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nam_cinema/core/network/api_client.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/home/domain/media_models.dart';
import 'package:nam_cinema/features/search/data/search_repository.dart';

class CatalogListingScreen extends ConsumerStatefulWidget {
  final String title;
  final String? initialType; // 'newly_updated' | 'single' | 'series'
  final String? initialCategorySlug;
  final String? initialCountrySlug;

  const CatalogListingScreen({
    super.key,
    required this.title,
    this.initialType,
    this.initialCategorySlug,
    this.initialCountrySlug,
  });

  @override
  ConsumerState<CatalogListingScreen> createState() =>
      _CatalogListingScreenState();
}

class _CatalogListingScreenState extends ConsumerState<CatalogListingScreen> {
  final _scrollController = ScrollController();
  final List<MediaItem> _items = [];
  String? _selectedType;
  String? _selectedCategorySlug;
  String? _selectedCountrySlug;
  int _page = 1;
  int _totalPages = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _selectedCategorySlug = widget.initialCategorySlug;
    _selectedCountrySlug = widget.initialCountrySlug;
    _scrollController.addListener(_onScroll);
    _fetchPage(reset: true);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoading && !_isLoadingMore && _page < _totalPages) {
        _fetchPage(reset: false);
      }
    }
  }

  Future<void> _fetchPage({required bool reset}) async {
    final targetPage = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _isLoading = true;
        _errorMessage = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.rawDio.get<Map<String, dynamic>>(
        '/catalog',
        queryParameters: {
          'page': targetPage,
          'limit': 24,
          if (_selectedType != null && _selectedType!.isNotEmpty)
            'type': _selectedType,
          if (_selectedCategorySlug != null &&
              _selectedCategorySlug!.isNotEmpty)
            'category': _selectedCategorySlug,
          if (_selectedCountrySlug != null && _selectedCountrySlug!.isNotEmpty)
            'country': _selectedCountrySlug,
        },
      );
      final data = response.data!;
      final parsed = (data['results'] as List<dynamic>? ?? const [])
          .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _page = (data['page'] as num?)?.toInt() ?? targetPage;
          _totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
          if (reset) {
            _items
              ..clear()
              ..addAll(parsed);
          } else {
            _items.addAll(parsed);
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = ref.read(apiClientProvider).mapDioError(error).message;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genresAsync = ref.watch(genresProvider);
    final countriesAsync = ref.watch(countriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type Filter Row
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                GenreChip(
                  label: 'Mới cập nhật',
                  selected: _selectedType == 'newly_updated',
                  onTap: () {
                    setState(() => _selectedType = 'newly_updated');
                    _fetchPage(reset: true);
                  },
                ),
                const SizedBox(width: 8),
                GenreChip(
                  label: 'Phim lẻ',
                  selected: _selectedType == 'single',
                  onTap: () {
                    setState(() => _selectedType = 'single');
                    _fetchPage(reset: true);
                  },
                ),
                const SizedBox(width: 8),
                GenreChip(
                  label: 'Phim bộ',
                  selected: _selectedType == 'series',
                  onTap: () {
                    setState(() => _selectedType = 'series');
                    _fetchPage(reset: true);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // VSMOV Categories Filter Row (/the-loai)
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
                        return GenreChip(
                          label: g.name,
                          selected: _selectedCategorySlug == g.slug,
                          onTap: () {
                            setState(() {
                              _selectedCategorySlug =
                                  _selectedCategorySlug == g.slug
                                      ? null
                                      : g.slug;
                              if (_selectedCategorySlug != null) {
                                _selectedType = null;
                              }
                            });
                            _fetchPage(reset: true);
                          },
                        );
                      },
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),

          // VSMOV Countries Filter Row (/quoc-gia)
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
                          selected: _selectedCountrySlug == c.slug,
                          onTap: () {
                            setState(() {
                              _selectedCountrySlug =
                                  _selectedCountrySlug == c.slug
                                      ? null
                                      : c.slug;
                              if (_selectedCountrySlug != null) {
                                _selectedType = null;
                              }
                            });
                            _fetchPage(reset: true);
                          },
                        );
                      },
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
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
                : _errorMessage != null
                    ? ErrorState(
                        message: _errorMessage!,
                        onRetry: () => _fetchPage(reset: true),
                      )
                    : _items.isEmpty
                        ? const EmptyState(
                            icon: Icons.movie_filter_outlined,
                            title: 'Chưa có phim trong mục này',
                            subtitle: 'Thử chọn thể loại hoặc quốc gia khác.',
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
                            itemCount:
                                _items.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, idx) {
                              if (idx >= _items.length) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final item = _items[idx];
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
