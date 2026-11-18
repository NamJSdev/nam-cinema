import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/authentication/presentation/auth_screen.dart';
import 'package:nam_cinema/features/discover/presentation/catalog_listing_screen.dart';
import 'package:nam_cinema/features/history/presentation/history_screen.dart';
import 'package:nam_cinema/features/home/presentation/home_screen.dart';
import 'package:nam_cinema/features/movie_details/presentation/movie_detail_screen.dart';
import 'package:nam_cinema/features/player/presentation/video_player_screen.dart';
import 'package:nam_cinema/features/profile/presentation/profile_screen.dart';
import 'package:nam_cinema/features/search/presentation/search_screen.dart';
import 'package:nam_cinema/features/settings/presentation/settings_screen.dart';
import 'package:nam_cinema/features/tv_series/presentation/tv_detail_screen.dart';
import 'package:nam_cinema/features/watchlist/presentation/watchlist_screen.dart';

class MainShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScaffold({
    super.key,
    required this.navigationShell,
  });

  void _onSelectTab(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWideDevice = width >= 720;

    if (isWideDevice) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: const Color(0xFF0A0C14),
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelectTab,
              extended: width >= 1100,
              labelType: width >= 1100
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50935),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'N',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Trang Chủ'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore_rounded),
                  label: Text('Khám Phá'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.favorite_border_rounded),
                  selectedIcon: Icon(Icons.favorite_rounded),
                  label: Text('Tủ Phim'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.tune_rounded),
                  selectedIcon: Icon(Icons.tune_rounded),
                  label: Text('Cá Nhân'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1, color: Color(0xFF1E2436)),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NamCinemaBottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onSelectTab,
      ),
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/watchlist',
                builder: (context, state) => const WatchlistScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/discover',
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return CatalogListingScreen(
            title: q['title'] ?? 'Khám Phá Kho Phim',
            initialType: q['type'],
            initialCategorySlug: q['category'],
            initialCountrySlug: q['country'],
          );
        },
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/movie/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '10378';
          return MovieDetailScreen(identifier: id);
        },
      ),
      GoRoute(
        path: '/tv/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '60625';
          return TvDetailScreen(identifier: id);
        },
      ),
      GoRoute(
        path: '/player/:assetId',
        builder: (context, state) {
          final assetId = state.pathParameters['assetId'] ?? '';
          final title = state.uri.queryParameters['title'] ?? 'Nam Cinema';
          return VideoPlayerScreen(assetId: assetId, titleHint: title);
        },
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
