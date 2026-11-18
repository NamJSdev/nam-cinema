import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/core/config/env_config.dart';
import 'package:nam_cinema/core/constants/app_constants.dart';
import 'package:nam_cinema/core/database/local_cache_store.dart';
import 'package:nam_cinema/core/network/dio_client.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';
import 'package:nam_cinema/features/history/data/history_repository.dart';
import 'package:nam_cinema/features/watchlist/data/watchlist_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _subtitleFontSize = AppConstants.defaultSubtitleFontSize;
  bool _subtitleEnabled = true;
  double _defaultPlaybackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _subtitleFontSize = prefs.getDouble(AppConstants.prefSubtitleFontSizeKey) ??
        AppConstants.defaultSubtitleFontSize;
    _subtitleEnabled =
        prefs.getBool(AppConstants.prefSubtitleEnabledKey) ?? true;
    _defaultPlaybackSpeed =
        prefs.getDouble(AppConstants.prefPlaybackSpeedKey) ?? 1.0;
  }

  Future<void> _saveSubtitleSize(double size) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(AppConstants.prefSubtitleFontSizeKey, size);
    setState(() => _subtitleFontSize = size);
  }

  Future<void> _saveSubtitleEnabled(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConstants.prefSubtitleEnabledKey, enabled);
    setState(() => _subtitleEnabled = enabled);
  }

  Future<void> _savePlaybackSpeed(double speed) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setDouble(AppConstants.prefPlaybackSpeedKey, speed);
    setState(() => _defaultPlaybackSpeed = speed);
  }

  Future<void> _clearWatchHistory() async {
    try {
      await ref.read(dioProvider).delete('/me/history');
      ref.invalidate(watchHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa toàn bộ lịch sử xem phim')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa lịch sử: $e')),
        );
      }
    }
  }

  Future<void> _clearWatchlist() async {
    try {
      await ref.read(dioProvider).delete('/me/watchlist');
      ref.invalidate(watchlistProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa toàn bộ tủ phim yêu thích')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể xóa tủ phim: $e')),
        );
      }
    }
  }

  Future<void> _resetAllData() async {
    try {
      await ref.read(dioProvider).post('/me/reset-all');
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.clear();
      ref.invalidate(watchHistoryProvider);
      ref.invalidate(watchlistProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa sạch toàn bộ dữ liệu và khôi phục mặc định'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khôi phục: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt & Quản lý dữ liệu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            tileColor: NamCinemaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Tự động bật phụ đề (WebVTT)'),
            subtitle: const Text('Ưu tiên hiển thị phụ đề tiếng Việt'),
            value: _subtitleEnabled,
            activeColor: NamCinemaColors.primaryAccent,
            onChanged: _saveSubtitleEnabled,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NamCinemaColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kích thước chữ phụ đề: ${_subtitleFontSize.round()} pt',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Slider(
                  min: 12,
                  max: 26,
                  divisions: 7,
                  activeColor: NamCinemaColors.primaryAccent,
                  value: _subtitleFontSize,
                  onChanged: _saveSubtitleSize,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NamCinemaColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tốc độ phát mặc định',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                    return ChoiceChip(
                      label: Text('${speed}x'),
                      selected: _defaultPlaybackSpeed == speed,
                      onSelected: (_) => _savePlaybackSpeed(speed),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'QUẢN LÝ & XOÁ DỮ LIỆU CÁ NHÂN',
            style: TextStyle(
              color: NamCinemaColors.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: NamCinemaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(
              Icons.history_toggle_off_rounded,
              color: Colors.orangeAccent,
            ),
            title: const Text('Xoá toàn bộ lịch sử xem phim'),
            subtitle: const Text('Xoá danh sách Tiếp tục xem và vị trí đang phát'),
            onTap: _clearWatchHistory,
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: NamCinemaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(
              Icons.bookmark_remove_outlined,
              color: Colors.amberAccent,
            ),
            title: const Text('Xoá toàn bộ Tủ Phim yêu thích'),
            subtitle: const Text('Xoá tất cả phim lẻ và phim bộ đã lưu'),
            onTap: _clearWatchlist,
          ),
          const SizedBox(height: 10),
          ListTile(
            tileColor: NamCinemaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(
              Icons.delete_forever_rounded,
              color: NamCinemaColors.primaryAccent,
            ),
            title: const Text(
              'Xoá sạch mọi dữ liệu & Khôi phục gốc',
              style: TextStyle(
                color: NamCinemaColors.primaryAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text('Xoá lịch sử, tủ phim, bộ nhớ đệm và tuỳ chỉnh'),
            onTap: _resetAllData,
          ),
          const SizedBox(height: 16),
          ListTile(
            tileColor: NamCinemaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Máy chủ API hiện tại'),
            subtitle: Text(AppEnvConfig.apiBaseUrl),
          ),
        ],
      ),
    );
  }
}
