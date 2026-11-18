import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/app/router.dart';
import 'package:nam_cinema/core/config/env_config.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';

class NamCinemaApp extends ConsumerWidget {
  const NamCinemaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppEnvConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: NamCinemaTheme.darkTheme,
      darkTheme: NamCinemaTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
