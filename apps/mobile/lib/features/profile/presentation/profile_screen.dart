import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nam_cinema/core/config/env_config.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/authentication/data/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user ?? AuthRepository.defaultPersonalUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rạp Phim Cá Nhân 4K'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NamCinemaColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NamCinemaColors.divider),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: NamCinemaColors.primaryAccent,
                  child: const Text(
                    'VIP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Chế độ Cá Nhân Tự Động • Không cần đăng nhập',
                        style: TextStyle(
                          color: NamCinemaColors.playableBadge,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: NamCinemaColors.surface,
            leading: const Icon(
              Icons.history_rounded,
              color: NamCinemaColors.primaryAccent,
            ),
            title: const Text('Lịch sử đã xem'),
            subtitle: const Text('Quản lý tiến trình phát và xem lại'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/history'),
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: NamCinemaColors.surface,
            leading: const Icon(
              Icons.bookmark_outline_rounded,
              color: NamCinemaColors.secondaryAccent,
            ),
            title: const Text('Danh sách yêu thích'),
            subtitle: const Text('Phim lẻ và phim bộ đã lưu'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.go('/watchlist'),
          ),
          const SizedBox(height: 10),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tileColor: NamCinemaColors.surface,
            leading: const Icon(
              Icons.tune_rounded,
              color: NamCinemaColors.playableBadge,
            ),
            title: const Text('Cài đặt ứng dụng & Phụ đề'),
            subtitle: const Text('Tùy chỉnh cỡ chữ phụ đề, tốc độ phát mặc định'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/settings'),
          ),
          if (user != null) ...[
            const SizedBox(height: 24),
            PremiumButton(
              label: 'Đăng Xuất',
              icon: Icons.logout_rounded,
              isPrimary: false,
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
          const SizedBox(height: 32),
          const Center(
            child: Text(
              'Nam Cinema v1.0.0 • ${AppEnvConfig.appTagline}\nDữ liệu phim được cung cấp bởi TMDB.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: NamCinemaColors.secondaryText,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
