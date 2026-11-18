import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nam_cinema/core/player/webvtt_parser.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/authentication/domain/auth_models.dart';
import 'package:nam_cinema/features/home/domain/media_models.dart';
import 'package:nam_cinema/features/search/domain/search_models.dart';
import 'package:nam_cinema/features/watchlist/domain/watchlist_models.dart';

void main() {
  group('WebVTT Subtitle Parser & Vietnamese Unicode Tests', () {
    test('parses Vietnamese Unicode WebVTT cues and matches active timestamps', () {
      const sampleVtt = '''WEBVTT

00:00:01.000 --> 00:00:06.000
Chào mừng bạn đến với Nam Cinema — Rạp phim của bạn, ở bất cứ đâu.

00:00:06.500 --> 00:00:12.000
Hỗ trợ phụ đề tiếng Việt Unicode đầy đủ.
''';

      final cues = WebVttParser.parse(sampleVtt);
      expect(cues.length, 2);
      expect(
        cues.first.text,
        'Chào mừng bạn đến với Nam Cinema — Rạp phim của bạn, ở bất cứ đâu.',
      );
      expect(cues.first.isActiveAt(const Duration(seconds: 3)), isTrue);
      expect(cues.first.isActiveAt(const Duration(seconds: 9)), isFalse);
      expect(cues[1].isActiveAt(const Duration(seconds: 8)), isTrue);
    });
  });

  group('VSMOV + TMDB Domain & Serialization Tests', () {
    test('MediaItem parses VSMOV slug, routeIdentifier, and distinguishes playable vs metadata_only', () {
      final vsmovSeries = MediaItem.fromJson(const {
        'tmdb_id': 225385,
        'slug': 'bo-cau-den-phan-1',
        'content_type': 'tv',
        'title': 'Bồ Câu Đen - Phần 1',
        'original_title': 'Black Doves - Season 1',
        'release_date': '2024',
        'vote_average': 7.2,
        'availability_badge': 'metadata_only',
      });
      expect(vsmovSeries.routeIdentifier, 'bo-cau-den-phan-1');
      expect(vsmovSeries.isDirectlyPlayable, isFalse);
      expect(vsmovSeries.releaseYear, '2024');

      final playable = MediaItem.fromJson(const {
        'tmdb_id': 10378,
        'slug': 'playable-10378',
        'content_type': 'movie',
        'title': 'Big Buck Bunny',
        'release_date': '2008-05-30',
        'vote_average': 7.8,
        'availability_badge': 'playable',
        'playable_asset_id': '11111111-2222-3333-4444-555555555501',
      });
      expect(playable.isDirectlyPlayable, isTrue);
      expect(playable.routeIdentifier, 'playable-10378');
    });

    test('TitleAvailabilityModel parses VSMOV catalogServers without granting unauthorized playback', () {
      final availability = TitleAvailabilityModel.fromJson(const {
        'tmdb_id': 225385,
        'slug': 'bo-cau-den-phan-1',
        'content_type': 'tv',
        'region': 'VN',
        'is_directly_playable': false,
        'availability_type': 'metadata_only',
        'playable_assets': [],
        'external_providers': [],
        'catalog_servers': [
          {
            'server_name': 'Vietsub #1',
            'episodes': [
              {
                'server_name': 'Vietsub #1',
                'episode_name': '1',
                'episode_slug': 'tap-1',
                'embed_url': 'https://v8.streamvsmov.com/video/sample',
                'is_authorized_direct_stream': false,
              }
            ]
          }
        ],
      });
      expect(availability.isDirectlyPlayable, isFalse);
      expect(availability.catalogServers.length, 1);
      expect(
        availability.catalogServers.first.episodes.first.isAuthorizedDirectStream,
        isFalse,
      );
    });

    test('AuthState transitions and WatchlistEntryModel conversion', () {
      const unauth = AuthState();
      expect(unauth.isAuthenticated, isFalse);

      final authed = unauth.copyWith(
        user: const AuthUser(
          id: 'u1',
          email: 'nam@namcinema.vn',
          fullName: 'Nam Nguyễn',
        ),
      );
      expect(authed.isAuthenticated, isTrue);

      final watchlistEntry = WatchlistEntryModel.fromJson(const {
        'id': 'w1',
        'tmdb_id': 136418,
        'content_type': 'movie',
        'title': 'Tears of Steel',
        'vote_average': 8.2,
        'release_year': '2012',
        'created_at': '2026-11-05T00:00:00Z',
      });
      expect(watchlistEntry.toMediaItem().title, 'Tears of Steel');
    });

    test('SearchFilterState pagination, genreSlug, and countrySlug updates', () {
      const initial = SearchFilterState();
      final filtered = initial.copyWith(
        query: 'Bồ Câu',
        contentType: 'tv',
        genreSlug: 'hanh-dong',
        countrySlug: 'han-quoc',
        releaseYear: 2024,
        page: 1,
        totalPages: 3,
      );
      expect(filtered.hasMore, isTrue);
      expect(filtered.genreSlug, 'hanh-dong');
      expect(filtered.countrySlug, 'han-quoc');
      expect(filtered.copyWith(clearGenreSlug: true).genreSlug, isNull);
    });
  });

  group('UI Component Widget Tests', () {
    testWidgets('RatingBadge, GenreChip, and StreamingProviderBadge render accurately',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NamCinemaTheme.darkTheme,
          home: const Scaffold(
            body: Column(
              children: [
                RatingBadge(rating: 8.6),
                GenreChip(label: 'Khoa Học Viễn Tưởng', selected: true),
                StreamingProviderBadge(availabilityBadge: 'playable'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('8.6'), findsOneWidget);
      expect(find.text('Khoa Học Viễn Tưởng'), findsOneWidget);
      expect(find.text('PHÁT NGAY'), findsOneWidget);
    });
  });
}
