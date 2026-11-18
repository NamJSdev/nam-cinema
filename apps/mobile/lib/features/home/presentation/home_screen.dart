import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/home/data/home_repository.dart';
import 'package:nam_cinema/features/home/domain/media_models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openDetails(BuildContext context, MediaItem item) {
    final id = item.routeIdentifier;
    if (item.contentType == 'tv') {
      context.push('/tv/$id');
    } else {
      context.push('/movie/$id');
    }
  }

  void _openPlayer(BuildContext context, String assetId, String title) {
    context.push('/player/$assetId?title=${Uri.encodeComponent(title)}');
  }

  void _openListing(
    BuildContext context, {
    required String title,
    String? type,
    String? category,
    String? country,
  }) {
    final query = <String, String>{
      'title': title,
      if (type != null) 'type': type,
      if (category != null) 'category': category,
      if (country != null) 'country': country,
    };
    final uri = Uri(path: '/discover', queryParameters: query);
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFeed = ref.watch(homeFeedProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: NamCinemaColors.primaryAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text('NAM CINEMA'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Khám phá Thể loại & Quốc gia',
            icon: const Icon(Icons.grid_view_rounded),
            onPressed: () => _openListing(
              context,
              title: 'Kho Phim Mới Cập Nhật',
              type: 'newly_updated',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.go('/search'),
          ),
        ],
      ),
      body: asyncFeed.when(
        loading: () => ListView(
          padding: const EdgeInsets.only(top: 90, left: 16, right: 16),
          children: const [
            LoadingSkeleton(height: 320),
            SizedBox(height: 24),
            LoadingSkeleton(height: 190),
            SizedBox(height: 24),
            LoadingSkeleton(height: 190),
          ],
        ),
        error: (err, _) => ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(homeFeedProvider),
        ),
        data: (feed) => RefreshIndicator(
          color: NamCinemaColors.primaryAccent,
          onRefresh: () async => ref.refresh(homeFeedProvider.future),
          child: CustomScrollView(
            slivers: [
              // 1. Featured cinematic hero
              SliverToBoxAdapter(
                child: FeaturedCarousel(
                  items: feed.featuredHero,
                  onDetailsTap: (item) => _openDetails(context, item),
                  onPlayTap: (item) {
                    if (item.isDirectlyPlayable) {
                      _openPlayer(context, item.playableAssetId!, item.title);
                    }
                  },
                ),
              ),
              if (feed.upstreamNotice != null && feed.upstreamNotice!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NamCinemaColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: NamCinemaColors.warning.withOpacity(0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: NamCinemaColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            feed.upstreamNotice!,
                            style: const TextStyle(
                              color: NamCinemaColors.secondaryText,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 10. Continue watching
              if (feed.continueWatching.isNotEmpty)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'Tiếp tục xem',
                        subtitle: 'Khôi phục từ vị trí dừng gần nhất',
                      ),
                      SizedBox(
                        height: 175,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: feed.continueWatching.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, idx) {
                            final h = feed.continueWatching[idx];
                            return ContinueWatchingCard(
                              item: h,
                              onTap: () {
                                if (h.assetId != null && h.assetId!.isNotEmpty) {
                                  _openPlayer(context, h.assetId!, h.title);
                                } else if (h.contentType == 'tv') {
                                  context.push('/tv/${h.tmdbId}');
                                } else {
                                  context.push('/movie/${h.tmdbId}');
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              // 12. Recently added playable content
              if (feed.recentlyAddedPlayable.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildLandscapeSection(
                    context,
                    title: 'Phát trực tuyến ngay trên Nam Cinema',
                    subtitle: 'Nội dung HLS hợp pháp đã xác thực bản quyền',
                    items: feed.recentlyAddedPlayable,
                  ),
                ),

              // 2. Newly Updated / Trending today (VSMOV /danh-sach/phim-moi-cap-nhat)
              if (feed.trendingToday.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildPosterSection(
                    context,
                    title: 'Phim mới cập nhật hôm nay',
                    items: feed.trendingToday,
                    onSeeAll: () => _openListing(
                      context,
                      title: 'Phim Mới Cập Nhật',
                      type: 'newly_updated',
                    ),
                  ),
                ),

              // 3. Popular Single Movies (VSMOV /danh-sach?type=single)
              if (feed.popularMovies.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildPosterSection(
                    context,
                    title: 'Phim lẻ thịnh hành',
                    items: feed.popularMovies,
                    onSeeAll: () => _openListing(
                      context,
                      title: 'Phim Lẻ Thịnh Hành',
                      type: 'single',
                    ),
                  ),
                ),

              // 4. Popular TV Series (VSMOV /danh-sach?type=series)
              if (feed.popularTvSeries.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildPosterSection(
                    context,
                    title: 'Phim bộ nổi bật',
                    items: feed.popularTvSeries,
                    onSeeAll: () => _openListing(
                      context,
                      title: 'Phim Bộ Nổi Bật',
                      type: 'series',
                    ),
                  ),
                ),

              // 5. Top-rated movies
              if (feed.topRatedMovies.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildPosterSection(
                    context,
                    title: 'Đánh giá cao nhất',
                    items: feed.topRatedMovies,
                  ),
                ),

              // 6. Korean movies (VSMOV /quoc-gia/han-quoc)
              if (feed.koreanMovies.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildPosterSection(
                    context,
                    title: 'Điện ảnh Hàn Quốc',
                    items: feed.koreanMovies,
                    onSeeAll: () => _openListing(
                      context,
                      title: 'Phim Hàn Quốc',
                      country: 'han-quoc',
                    ),
                  ),
                ),

              // 7. Chinese movies (VSMOV /quoc-gia/trung-quoc)
              if (feed.chineseMovies.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildPosterSection(
                    context,
                    title: 'Điện ảnh Hoa Ngữ',
                    items: feed.chineseMovies,
                    onSeeAll: () => _openListing(
                      context,
                      title: 'Phim Hoa Ngữ',
                      country: 'trung-quoc',
                    ),
                  ),
                ),

              // 8. Hollywood / US-Europe movies (VSMOV /quoc-gia/au-my)
              if (feed.hollywoodMovies.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildPosterSection(
                    context,
                    title: 'Bom tấn Âu Mỹ',
                    items: feed.hollywoodMovies,
                    onSeeAll: () => _openListing(
                      context,
                      title: 'Phim Âu Mỹ',
                      country: 'au-my',
                    ),
                  ),
                ),

              // 9. Animation (VSMOV /the-loai/hoat-hinh)
              if (feed.animationMovies.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildPosterSection(
                    context,
                    title: 'Thế giới Hoạt Hình',
                    items: feed.animationMovies,
                    onSeeAll: () => _openListing(
                      context,
                      title: 'Phim Hoạt Hình',
                      category: 'hoat-hinh',
                    ),
                  ),
                ),

              // 11. Recommended titles
              if (feed.recommendedTitles.isNotEmpty)
                SliverToBoxAdapter(
                  child: _buildPosterSection(
                    context,
                    title: 'Đề xuất cho bạn',
                    items: feed.recommendedTitles,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 36)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPosterSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<MediaItem> items,
    VoidCallback? onSeeAll,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle, onSeeAll: onSeeAll),
        SizedBox(
          height: 252,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, idx) {
              final item = items[idx];
              return MoviePosterCard(
                item: item,
                onTap: () => _openDetails(context, item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<MediaItem> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        SizedBox(
          height: 152,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, idx) {
              final item = items[idx];
              return MovieLandscapeCard(
                item: item,
                onTap: () => _openDetails(context, item),
              );
            },
          ),
        ),
      ],
    );
  }
}
