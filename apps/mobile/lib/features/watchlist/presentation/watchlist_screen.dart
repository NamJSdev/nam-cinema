import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/authentication/data/auth_repository.dart';
import 'package:nam_cinema/features/watchlist/data/watchlist_repository.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final watchlistAsync = ref.watch(watchlistControllerProvider);

    if (!authState.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Danh sách của tôi')),
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Đăng nhập để lưu danh sách phim',
          subtitle:
              'Đồng bộ bộ sưu tập phim yêu thích của bạn giữa điện thoại và máy tính bảng.',
          action: PremiumButton(
            label: 'Đăng Nhập Ngay',
            icon: Icons.login_rounded,
            onPressed: () => context.push('/auth'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách của tôi')),
      body: watchlistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          message: err.toString(),
          onRetry: () => ref.read(watchlistControllerProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Danh sách của bạn đang trống',
              subtitle:
                  'Nhấn nút "+ Danh sách" trên bất kỳ bộ phim lẻ hoặc phim bộ nào để lưu lại xem sau.',
              action: PremiumButton(
                label: 'Khám Phá Phim',
                icon: Icons.explore_outlined,
                onPressed: () => context.go('/search'),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.56,
            ),
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final entry = items[idx];
              final media = entry.toMediaItem();
              return MoviePosterCard(
                item: media,
                onTap: () {
                  if (entry.contentType == 'tv') {
                    context.push('/tv/${entry.tmdbId}');
                  } else {
                    context.push('/movie/${entry.tmdbId}');
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
