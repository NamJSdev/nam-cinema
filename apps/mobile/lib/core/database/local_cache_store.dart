import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be initialized in bootstrap.dart');
});

class LocalCacheStore {
  final SharedPreferences _prefs;

  const LocalCacheStore(this._prefs);

  static const String _recentSearchesKey = 'nam_cinema_recent_searches';
  static const String _watchlistCacheKey = 'nam_cinema_watchlist_cache';
  static const String _historyCacheKey = 'nam_cinema_history_cache';

  List<String> getRecentSearches() {
    return _prefs.getStringList(_recentSearchesKey) ?? const [];
  }

  Future<void> addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final current = List<String>.from(getRecentSearches());
    current.removeWhere((item) => item.toLowerCase() == trimmed.toLowerCase());
    current.insert(0, trimmed);
    if (current.length > 12) {
      current.removeRange(12, current.length);
    }
    await _prefs.setStringList(_recentSearchesKey, current);
  }

  Future<void> removeRecentSearch(String query) async {
    final current = List<String>.from(getRecentSearches())
      ..removeWhere((item) => item == query);
    await _prefs.setStringList(_recentSearchesKey, current);
  }

  Future<void> clearRecentSearches() async {
    await _prefs.remove(_recentSearchesKey);
  }

  Future<void> saveWatchlistJson(List<Map<String, dynamic>> items) async {
    await _prefs.setString(_watchlistCacheKey, jsonEncode(items));
  }

  List<Map<String, dynamic>> readWatchlistJson() {
    final raw = _prefs.getString(_watchlistCacheKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> saveHistoryJson(List<Map<String, dynamic>> items) async {
    await _prefs.setString(_historyCacheKey, jsonEncode(items));
  }

  List<Map<String, dynamic>> readHistoryJson() {
    final raw = _prefs.getString(_historyCacheKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }
}

final localCacheStoreProvider = Provider<LocalCacheStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalCacheStore(prefs);
});
