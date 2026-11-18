import 'package:flutter/foundation.dart';

@immutable
class MediaItem {
  final int tmdbId;
  final String? slug;
  final String contentType; // 'movie' | 'tv'
  final String title;
  final String? originalTitle;
  final String overview;
  final String? posterUrl;
  final String? backdropUrl;
  final String? releaseDate;
  final double voteAverage;
  final int voteCount;
  final String? quality;
  final String? lang;
  final String? episodeCurrent;
  final List<int> genreIds;
  final List<String> categorySlugs;
  final List<String> countrySlugs;
  final String availabilityBadge; // 'playable' | 'external' | 'metadata_only'
  final String? playableAssetId;

  const MediaItem({
    required this.tmdbId,
    this.slug,
    required this.contentType,
    required this.title,
    this.originalTitle,
    this.overview = '',
    this.posterUrl,
    this.backdropUrl,
    this.releaseDate,
    this.voteAverage = 0.0,
    this.voteCount = 0,
    this.quality,
    this.lang,
    this.episodeCurrent,
    this.genreIds = const [],
    this.categorySlugs = const [],
    this.countrySlugs = const [],
    this.availabilityBadge = 'metadata_only',
    this.playableAssetId,
  });

  bool get isDirectlyPlayable =>
      availabilityBadge == 'playable' &&
      playableAssetId != null &&
      playableAssetId!.isNotEmpty;

  /// Identifier used for routing to movie/tv details (prefers VSMOV slug when present).
  String get routeIdentifier =>
      (slug != null && slug!.isNotEmpty) ? slug! : tmdbId.toString();

  String get releaseYear {
    if (releaseDate == null || releaseDate!.length < 4) return '';
    return releaseDate!.substring(0, 4);
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      tmdbId: (json['tmdb_id'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String?,
      contentType: (json['content_type'] as String?) ?? 'movie',
      title: (json['title'] as String?) ?? 'Untitled',
      originalTitle: json['original_title'] as String?,
      overview: (json['overview'] as String?) ?? '',
      posterUrl: json['poster_url'] as String?,
      backdropUrl: json['backdrop_url'] as String?,
      releaseDate: json['release_date'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? 0,
      quality: json['quality'] as String?,
      lang: json['lang'] as String?,
      episodeCurrent: json['episode_current'] as String?,
      genreIds: (json['genre_ids'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      categorySlugs: (json['category_slugs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      countrySlugs: (json['country_slugs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      availabilityBadge:
          (json['availability_badge'] as String?) ?? 'metadata_only',
      playableAssetId: json['playable_asset_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tmdb_id': tmdbId,
      'slug': slug,
      'content_type': contentType,
      'title': title,
      'original_title': originalTitle,
      'overview': overview,
      'poster_url': posterUrl,
      'backdrop_url': backdropUrl,
      'release_date': releaseDate,
      'vote_average': voteAverage,
      'vote_count': voteCount,
      'quality': quality,
      'lang': lang,
      'episode_current': episodeCurrent,
      'genre_ids': genreIds,
      'category_slugs': categorySlugs,
      'country_slugs': countrySlugs,
      'availability_badge': availabilityBadge,
      'playable_asset_id': playableAssetId,
    };
  }
}

@immutable
class GenreModel {
  final int id;
  final String name;
  final String? slug;

  const GenreModel({required this.id, required this.name, this.slug});

  factory GenreModel.fromJson(Map<String, dynamic> json) {
    return GenreModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      slug: json['slug'] as String?,
    );
  }
}

@immutable
class CountryModel {
  final int id;
  final String name;
  final String slug;

  const CountryModel({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    return CountryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
    );
  }
}

@immutable
class CastMemberModel {
  final int id;
  final String name;
  final String? character;
  final String? profileUrl;

  const CastMemberModel({
    required this.id,
    required this.name,
    this.character,
    this.profileUrl,
  });

  factory CastMemberModel.fromJson(Map<String, dynamic> json) {
    return CastMemberModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      character: json['character'] as String?,
      profileUrl: json['profile_url'] as String?,
    );
  }
}

@immutable
class VideoTrailerModel {
  final String id;
  final String key;
  final String name;
  final String site;
  final String type;
  final String? youtubeUrl;

  const VideoTrailerModel({
    required this.id,
    required this.key,
    required this.name,
    required this.site,
    required this.type,
    this.youtubeUrl,
  });

  factory VideoTrailerModel.fromJson(Map<String, dynamic> json) {
    return VideoTrailerModel(
      id: (json['id'] as String?) ?? '',
      key: (json['key'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Trailer',
      site: (json['site'] as String?) ?? 'YouTube',
      type: (json['type'] as String?) ?? 'Trailer',
      youtubeUrl: json['youtube_url'] as String?,
    );
  }
}

@immutable
class ExternalProviderModel {
  final String providerName;
  final String monetizationType;
  final String? logoUrl;
  final String? externalWatchUrl;
  final String region;

  const ExternalProviderModel({
    required this.providerName,
    required this.monetizationType,
    this.logoUrl,
    this.externalWatchUrl,
    this.region = 'VN',
  });

  factory ExternalProviderModel.fromJson(Map<String, dynamic> json) {
    return ExternalProviderModel(
      providerName: (json['provider_name'] as String?) ?? '',
      monetizationType: (json['monetization_type'] as String?) ?? 'flatrate',
      logoUrl: json['logo_url'] as String?,
      externalWatchUrl: json['external_watch_url'] as String?,
      region: (json['region'] as String?) ?? 'VN',
    );
  }
}

@immutable
class PlayableAssetModel {
  final String assetId;
  final String providerCategory;
  final int durationSeconds;
  final String licenseName;
  final String licenseUrl;
  final String attribution;
  final int? seasonNumber;
  final int? episodeNumber;

  const PlayableAssetModel({
    required this.assetId,
    required this.providerCategory,
    required this.durationSeconds,
    required this.licenseName,
    required this.licenseUrl,
    required this.attribution,
    this.seasonNumber,
    this.episodeNumber,
  });

  factory PlayableAssetModel.fromJson(Map<String, dynamic> json) {
    return PlayableAssetModel(
      assetId: (json['asset_id'] as String?) ?? '',
      providerCategory: (json['provider_category'] as String?) ?? 'public_demo',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      licenseName: (json['license_name'] as String?) ?? '',
      licenseUrl: (json['license_url'] as String?) ?? '',
      attribution: (json['attribution'] as String?) ?? '',
      seasonNumber: (json['season_number'] as num?)?.toInt(),
      episodeNumber: (json['episode_number'] as num?)?.toInt(),
    );
  }
}

@immutable
class ParsedEpisodeSourceModel {
  final String serverName;
  final String episodeName;
  final String episodeSlug;
  final String? filename;
  final String? embedUrl;
  final String? directStreamUrl;
  final bool isAuthorizedDirectStream;
  final String? playableAssetId;

  const ParsedEpisodeSourceModel({
    required this.serverName,
    required this.episodeName,
    required this.episodeSlug,
    this.filename,
    this.embedUrl,
    this.directStreamUrl,
    this.isAuthorizedDirectStream = false,
    this.playableAssetId,
  });

  factory ParsedEpisodeSourceModel.fromJson(Map<String, dynamic> json) {
    return ParsedEpisodeSourceModel(
      serverName: (json['server_name'] as String?) ?? 'Server #1',
      episodeName: (json['episode_name'] as String?) ?? '1',
      episodeSlug: (json['episode_slug'] as String?) ?? 'tap-1',
      filename: json['filename'] as String?,
      embedUrl: json['embed_url'] as String?,
      directStreamUrl: json['direct_stream_url'] as String?,
      isAuthorizedDirectStream:
          (json['is_authorized_direct_stream'] as bool?) ?? false,
      playableAssetId: json['playable_asset_id'] as String?,
    );
  }
}

@immutable
class ParsedServerGroupModel {
  final String serverName;
  final List<ParsedEpisodeSourceModel> episodes;

  const ParsedServerGroupModel({
    required this.serverName,
    this.episodes = const [],
  });

  factory ParsedServerGroupModel.fromJson(Map<String, dynamic> json) {
    return ParsedServerGroupModel(
      serverName: (json['server_name'] as String?) ?? 'Server #1',
      episodes: (json['episodes'] as List<dynamic>? ?? const [])
          .map((e) =>
              ParsedEpisodeSourceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

@immutable
class TitleAvailabilityModel {
  final int tmdbId;
  final String? slug;
  final String contentType;
  final String region;
  final bool isDirectlyPlayable;
  final String availabilityType; // 'playable' | 'external' | 'metadata_only'
  final List<PlayableAssetModel> playableAssets;
  final List<ExternalProviderModel> externalProviders;
  final List<ParsedServerGroupModel> catalogServers;

  const TitleAvailabilityModel({
    required this.tmdbId,
    this.slug,
    required this.contentType,
    required this.region,
    required this.isDirectlyPlayable,
    required this.availabilityType,
    this.playableAssets = const [],
    this.externalProviders = const [],
    this.catalogServers = const [],
  });

  factory TitleAvailabilityModel.fromJson(Map<String, dynamic> json) {
    return TitleAvailabilityModel(
      tmdbId: (json['tmdb_id'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String?,
      contentType: (json['content_type'] as String?) ?? 'movie',
      region: (json['region'] as String?) ?? 'VN',
      isDirectlyPlayable: (json['is_directly_playable'] as bool?) ?? false,
      availabilityType:
          (json['availability_type'] as String?) ?? 'metadata_only',
      playableAssets: (json['playable_assets'] as List<dynamic>?)
              ?.map(
                  (e) => PlayableAssetModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      externalProviders: (json['external_providers'] as List<dynamic>?)
              ?.map((e) =>
                  ExternalProviderModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      catalogServers: (json['catalog_servers'] as List<dynamic>?)
              ?.map((e) =>
                  ParsedServerGroupModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

@immutable
class WatchHistoryModel {
  final String id;
  final int tmdbId;
  final String contentType;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? assetId;
  final String title;
  final String? posterPath;
  final String? backdropPath;
  final int currentPositionSeconds;
  final int durationSeconds;
  final double progressRatio;
  final bool isCompleted;
  final DateTime lastWatchedAt;

  const WatchHistoryModel({
    required this.id,
    required this.tmdbId,
    required this.contentType,
    this.seasonNumber,
    this.episodeNumber,
    this.assetId,
    required this.title,
    this.posterPath,
    this.backdropPath,
    required this.currentPositionSeconds,
    required this.durationSeconds,
    required this.progressRatio,
    required this.isCompleted,
    required this.lastWatchedAt,
  });

  factory WatchHistoryModel.fromJson(Map<String, dynamic> json) {
    return WatchHistoryModel(
      id: (json['id'] as String?) ?? '',
      tmdbId: (json['tmdb_id'] as num).toInt(),
      contentType: (json['content_type'] as String?) ?? 'movie',
      seasonNumber: (json['season_number'] as num?)?.toInt(),
      episodeNumber: (json['episode_number'] as num?)?.toInt(),
      assetId: json['asset_id'] as String?,
      title: (json['title'] as String?) ?? 'Untitled',
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      currentPositionSeconds:
          (json['current_position_seconds'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 1,
      progressRatio: (json['progress_ratio'] as num?)?.toDouble() ?? 0.0,
      isCompleted: (json['is_completed'] as bool?) ?? false,
      lastWatchedAt:
          DateTime.tryParse((json['last_watched_at'] as String?) ?? '') ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tmdb_id': tmdbId,
      'content_type': contentType,
      'season_number': seasonNumber,
      'episode_number': episodeNumber,
      'asset_id': assetId,
      'title': title,
      'poster_path': posterPath,
      'backdrop_path': backdropPath,
      'current_position_seconds': currentPositionSeconds,
      'duration_seconds': durationSeconds,
      'progress_ratio': progressRatio,
      'is_completed': isCompleted,
      'last_watched_at': lastWatchedAt.toIso8601String(),
    };
  }
}
