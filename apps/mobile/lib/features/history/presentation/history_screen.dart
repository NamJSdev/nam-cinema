import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/history/data/history_repository.dart';
import 'package:nam_cinema/features/home/data/home_repository.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(watchHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử đã xem')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(watchHistoryProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.history_rounded,
              title: 'Chưa có lịch sử xem',
              subtitle:
                  'Các bộ phim bạn thưởng thức sẽ tự động lưu tiến trình tại đây.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final item = items[idx];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NamCinemaColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NamCinemaColors.divider),
                ),
                child: Row(
                  children: [
                    CinematicNetImage(
                      imageUrl: item.posterPath ?? item.backdropPath,
                      width: 72,
                      height: 102,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: NamCinemaColors.primaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.isCompleted
                                ? 'Đã hoàn thành'
                                : 'Đã xem ${(item.progressRatio * 100).round()}% (${item.currentPositionSeconds ~/ 60} phút)',
                            style: TextStyle(
                              color: item.isCompleted
                                  ? NamCinemaColors.playableBadge
                                  : NamCinemaColors.secondaryText,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: item.progressRatio.clamp(0.02, 1.0),
                            backgroundColor: NamCinemaColors.divider,
                            color: NamCinemaColors.primaryAccent,
                            minHeight: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.assetId != null && item.assetId!.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.play_circle_fill_rounded,
                          color: NamCinemaColors.primaryAccent,
                          size: 32,
                        ),
                        onPressed: () {
                          context.push(
                            '/player/${item.assetId}?title=${Uri.encodeComponent(item.title)}',
                          );
                        },
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: NamCinemaColors.secondaryText,
                      ),
                      onPressed: () async {
                        await ref
                            .read(historyRepositoryProvider)
                            .deleteHistoryEntry(item.id);
                        ref.invalidate(watchHistoryProvider);
                        ref.invalidate(homeFeedProvider);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
