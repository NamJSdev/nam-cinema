import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/authentication/data/auth_repository.dart';
import 'package:nam_cinema/features/movie_details/data/movie_detail_repository.dart';
import 'package:nam_cinema/features/watchlist/data/watchlist_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class MovieDetailScreen extends ConsumerWidget {
  final String identifier;

  const MovieDetailScreen({super.key, required this.identifier});

  Future<void> _launchExternalUrl(String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty) return;
    final uri = Uri.tryParse(rawUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMovie = ref.watch(movieDetailProvider(identifier));
    final watchlistAsync = ref.watch(watchlistControllerProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(),
      body: asyncMovie.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(movieDetailProvider(identifier)),
        ),
        data: (movie) {
          final isSaved = watchlistAsync.valueOrNull?.any(
                (e) => e.tmdbId == movie.tmdbId && e.contentType == 'movie',
              ) ??
              false;

          final playableAsset = movie.availability.playableAssets.isNotEmpty
              ? movie.availability.playableAssets.first
              : null;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Backdrop & Poster Header
                SizedBox(
                  height: 360,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CinematicNetImage(
                        imageUrl: movie.backdropUrl ?? movie.posterUrl,
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
                              imageUrl: movie.posterUrl,
                              width: 112,
                              height: 168,
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
                                            movie.availability.availabilityType,
                                      ),
                                      if (movie.quality != null &&
                                          movie.quality!.isNotEmpty)
                                        StreamingProviderBadge(
                                          availabilityBadge: 'external',
                                          customLabel: movie.quality,
                                        ),
                                      if (movie.lang != null &&
                                          movie.lang!.isNotEmpty)
                                        StreamingProviderBadge(
                                          availabilityBadge: 'metadata_only',
                                          customLabel: movie.lang,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    movie.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (movie.originalTitle != movie.title) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      movie.originalTitle,
                                      style: const TextStyle(
                                        color: NamCinemaColors.secondaryText,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      RatingBadge(rating: movie.voteAverage),
                                      if (movie.releaseDate != null)
                                        Text(
                                          movie.releaseDate!,
                                          style: const TextStyle(
                                            color:
                                                NamCinemaColors.secondaryText,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      if (movie.durationLabel != null &&
                                          movie.durationLabel!.isNotEmpty)
                                        Text(
                                          movie.durationLabel!,
                                          style: const TextStyle(
                                            color:
                                                NamCinemaColors.secondaryText,
                                            fontSize: 12.5,
                                          ),
                                        )
                                      else if (movie.runtimeMinutes != null)
                                        Text(
                                          '${movie.runtimeMinutes} phút',
                                          style: const TextStyle(
                                            color:
                                                NamCinemaColors.secondaryText,
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

                // Primary Actions (Authorized Play Button & Watchlist)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      if (playableAsset != null) ...[
                        Expanded(
                          child: PremiumButton(
                            label: 'Phát Phim (HLS)',
                            icon: Icons.play_arrow_rounded,
                            onPressed: () {
                              if (!authState.isAuthenticated) {
                                context.push('/auth');
                                return;
                              }
                              context.push(
                                '/player/${playableAsset.assetId}?title=${Uri.encodeComponent(movie.title)}',
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: PremiumButton(
                          label: isSaved ? 'Đã Lưu' : '+ Danh Sách',
                          icon: isSaved
                              ? Icons.check_rounded
                              : Icons.bookmark_add_outlined,
                          isPrimary: playableAsset == null,
                          onPressed: () {
                            if (!authState.isAuthenticated) {
                              context.push('/auth');
                              return;
                            }
                            ref
                                .read(watchlistControllerProvider.notifier)
                                .toggleWatchlist(
                                  tmdbId: movie.tmdbId,
                                  contentType: 'movie',
                                  title: movie.title,
                                  posterPath: movie.posterUrl,
                                  backdropPath: movie.backdropUrl,
                                  voteAverage: movie.voteAverage,
                                  releaseYear: movie.releaseDate,
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Legal Attribution / External Watch Provider / VSMOV Server Metadata
                if (playableAsset != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NamCinemaColors.playableBadge.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: NamCinemaColors.playableBadge.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: NamCinemaColors.playableBadge,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Bản quyền hợp pháp: ${playableAsset.licenseName} — ${playableAsset.attribution}',
                              style: const TextStyle(
                                color: NamCinemaColors.primaryText,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (movie.availability.externalProviders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NamCinemaColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: NamCinemaColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Xem hợp pháp trên nền tảng đối tác:',
                            style: TextStyle(
                              color: NamCinemaColors.primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: movie.availability.externalProviders
                                .map(
                                  (p) => ActionChip(
                                    label: Text(
                                      '${p.providerName} (${p.monetizationType})',
                                    ),
                                    avatar: const Icon(
                                      Icons.open_in_new_rounded,
                                      size: 16,
                                    ),
                                    onPressed: () =>
                                        _launchExternalUrl(p.externalWatchUrl),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Parsed VSMOV Server Metadata (without unauthorized auto-playback)
                if (movie.availability.catalogServers.isNotEmpty &&
                    playableAsset == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NamCinemaColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: NamCinemaColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thông tin máy chủ danh mục (VSMOV Metadata):',
                            style: TextStyle(
                              color: NamCinemaColors.primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final srv in movie.availability.catalogServers)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• Máy chủ ${srv.serverName}: ${srv.episodes.map((e) => e.episodeName).join(", ")} (Chờ xác thực bản quyền HLS trực tiếp)',
                                style: const TextStyle(
                                  color: NamCinemaColors.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // Genres & Countries (clickable to filter VSMOV catalog)
                if (movie.genres.isNotEmpty || movie.countries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final g in movie.genres)
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
                        for (final c in movie.countries)
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

                // Overview
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nội dung phim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        movie.overview.isNotEmpty
                            ? movie.overview
                            : 'Chưa có tóm tắt nội dung cho tác phẩm này.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (movie.director != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Đạo diễn: ${movie.director}',
                          style: const TextStyle(
                            color: NamCinemaColors.primaryText,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailers
                if (movie.trailers.isNotEmpty) ...[
                  const SectionHeader(title: 'Trailer chính thức'),
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: movie.trailers.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, idx) {
                        final t = movie.trailers[idx];
                        return ActionChip(
                          avatar: const Icon(
                            Icons.play_circle_outline_rounded,
                            color: NamCinemaColors.primaryAccent,
                          ),
                          label: Text(t.name),
                          onPressed: () => _launchExternalUrl(t.youtubeUrl),
                        );
                      },
                    ),
                  ),
                ],

                // Cast
                if (movie.cast.isNotEmpty) ...[
                  const SectionHeader(title: 'Diễn viên'),
                  SizedBox(
                    height: 126,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: movie.cast.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, idx) =>
                          CastCard(member: movie.cast[idx]),
                    ),
                  ),
                ],

                // Recommendations
                if (movie.recommendations.isNotEmpty) ...[
                  const SectionHeader(title: 'Đề xuất tương tự'),
                  SizedBox(
                    height: 250,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: movie.recommendations.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final item = movie.recommendations[idx];
                        return MoviePosterCard(
                          item: item,
                          onTap: () =>
                              context.push('/movie/${item.routeIdentifier}'),
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
