import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/authentication/data/auth_repository.dart';
import 'package:nam_cinema/features/tv_series/data/tv_repository.dart';
import 'package:nam_cinema/features/watchlist/data/watchlist_repository.dart';

class EpisodeCard extends StatelessWidget {
  final EpisodeModel episode;
  final VoidCallback? onPlayTap;

  const EpisodeCard({
    super.key,
    required this.episode,
    this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NamCinemaColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NamCinemaColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CinematicNetImage(
                imageUrl: episode.stillUrl,
                width: 128,
                height: 76,
                borderRadius: BorderRadius.circular(8),
              ),
              if (episode.isPlayable && onPlayTap != null)
                GestureDetector(
                  onTap: onPlayTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NamCinemaColors.primaryAccent.withOpacity(0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        episode.name.startsWith('Tập')
                            ? episode.name
                            : 'Tập ${episode.episodeNumber}. ${episode.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: NamCinemaColors.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (episode.isPlayable)
                      const StreamingProviderBadge(availabilityBadge: 'playable')
                    else if (episode.serverName != null)
                      StreamingProviderBadge(
                        availabilityBadge: 'metadata_only',
                        customLabel: episode.serverName,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (episode.runtimeMinutes != null)
                  Text(
                    '${episode.runtimeMinutes} phút',
                    style: const TextStyle(
                      color: NamCinemaColors.secondaryText,
                      fontSize: 11.5,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  episode.overview.isNotEmpty
                      ? episode.overview
                      : 'Chưa có tóm tắt cho tập phim này.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: NamCinemaColors.secondaryText,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TvDetailScreen extends ConsumerStatefulWidget {
  final String identifier;

  const TvDetailScreen({super.key, required this.identifier});

  @override
  ConsumerState<TvDetailScreen> createState() => _TvDetailScreenState();
}

class _TvDetailScreenState extends ConsumerState<TvDetailScreen> {
  int _selectedSeasonNumber = 1;

  @override
  Widget build(BuildContext context) {
    final asyncTv = ref.watch(tvDetailProvider(widget.identifier));
    final watchlistAsync = ref.watch(watchlistControllerProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(),
      body: asyncTv.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(tvDetailProvider(widget.identifier)),
        ),
        data: (tv) {
          final isSaved = watchlistAsync.valueOrNull?.any(
                (e) => e.tmdbId == tv.tmdbId && e.contentType == 'tv',
              ) ??
              false;

          final seasons = tv.seasons;
          if (seasons.isNotEmpty &&
              !seasons.any((s) => s.seasonNumber == _selectedSeasonNumber)) {
            _selectedSeasonNumber = seasons.first.seasonNumber;
          }

          final episodesAsync = ref.watch(
            tvSeasonEpisodesProvider((
              identifier: widget.identifier,
              seasonNumber: _selectedSeasonNumber,
            )),
          );

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 340,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CinematicNetImage(
                        imageUrl: tv.backdropUrl ?? tv.posterUrl,
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x6608090D),
                              Colors.transparent,
                              NamCinemaColors.primaryBackground,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            CinematicNetImage(
                              imageUrl: tv.posterUrl,
                              width: 108,
                              height: 160,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      StreamingProviderBadge(
                                        availabilityBadge:
                                            tv.availability.availabilityType,
                                      ),
                                      if (tv.episodeCurrent != null &&
                                          tv.episodeCurrent!.isNotEmpty)
                                        StreamingProviderBadge(
                                          availabilityBadge: 'external',
                                          customLabel: tv.episodeCurrent,
                                        ),
                                      if (tv.lang != null &&
                                          tv.lang!.isNotEmpty)
                                        StreamingProviderBadge(
                                          availabilityBadge: 'metadata_only',
                                          customLabel: tv.lang,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    tv.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      RatingBadge(rating: tv.voteAverage),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${tv.numberOfSeasons} mùa • ${tv.numberOfEpisodes} tập',
                                        style: const TextStyle(
                                          color: NamCinemaColors.secondaryText,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: PremiumButton(
                    label: isSaved ? 'Đã Lưu Danh Sách' : '+ Lưu Vào Danh Sách',
                    icon: isSaved
                        ? Icons.check_rounded
                        : Icons.bookmark_add_outlined,
                    isPrimary: false,
                    onPressed: () {
                      if (!authState.isAuthenticated) {
                        context.push('/auth');
                        return;
                      }
                      ref
                          .read(watchlistControllerProvider.notifier)
                          .toggleWatchlist(
                            tmdbId: tv.tmdbId,
                            contentType: 'tv',
                            title: tv.title,
                            posterPath: tv.posterUrl,
                            backdropPath: tv.backdropUrl,
                            voteAverage: tv.voteAverage,
                            releaseYear: tv.firstAirDate,
                          );
                    },
                  ),
                ),

                // Genres & Countries
                if (tv.genres.isNotEmpty || tv.countries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final g in tv.genres)
                          GenreChip(
                            label: g.name,
                            onTap: g.slug != null
                                ? () => context.push(
                                      Uri(
                                        path: '/discover',
                                        queryParameters: {
                                          'title': 'Thể loại: ${g.name}',
                                          'category': g.slug!,
                                        },
                                      ).toString(),
                                    )
                                : null,
                          ),
                        for (final c in tv.countries)
                          GenreChip(
                            label: 'Quốc gia: ${c.name}',
                            selected: true,
                            onTap: () => context.push(
                              Uri(
                                path: '/discover',
                                queryParameters: {
                                  'title': 'Quốc gia: ${c.name}',
                                  'country': c.slug,
                                },
                              ).toString(),
                            ),
                          ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    tv.overview.isNotEmpty
                        ? tv.overview
                        : 'Chưa có mô tả cho bộ phim này.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),

                // Season Selector & Episode List
                if (seasons.isNotEmpty) ...[
                  const SectionHeader(title: 'Danh sách mùa & tập phim'),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: seasons.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, idx) {
                        final s = seasons[idx];
                        return GenreChip(
                          label: '${s.name} (${s.episodeCount} tập)',
                          selected: s.seasonNumber == _selectedSeasonNumber,
                          onTap: () {
                            setState(
                              () => _selectedSeasonNumber = s.seasonNumber,
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  episodesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        err.toString(),
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    data: (episodes) => ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: episodes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final ep = episodes[idx];
                        return EpisodeCard(
                          episode: ep,
                          onPlayTap: ep.isPlayable && ep.playableAssetId != null
                              ? () {
                                  if (!authState.isAuthenticated) {
                                    context.push('/auth');
                                    return;
                                  }
                                  context.push(
                                    '/player/${ep.playableAssetId}?title=${Uri.encodeComponent("${tv.title} - Tập ${ep.episodeNumber}")}',
                                  );
                                }
                              : null,
                        );
                      },
                    ),
                  ),
                ],

                // Recommendations
                if (tv.recommendations.isNotEmpty) ...[
                  const SectionHeader(title: 'Đề xuất tương tự'),
                  SizedBox(
                    height: 250,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: tv.recommendations.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final item = tv.recommendations[idx];
                        return MoviePosterCard(
                          item: item,
                          onTap: () =>
                              context.push('/tv/${item.routeIdentifier}'),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
