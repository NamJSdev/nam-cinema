import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/core/network/api_client.dart';
import 'package:nam_cinema/core/player/webvtt_parser.dart';

@immutable
class StreamSourceModel {
  final String streamType;
  final String manifestUrl;
  final String qualityLabel;
  final int? bandwidthKbps;

  const StreamSourceModel({
    required this.streamType,
    required this.manifestUrl,
    required this.qualityLabel,
    this.bandwidthKbps,
  });

  factory StreamSourceModel.fromJson(Map<String, dynamic> json) {
    return StreamSourceModel(
      streamType: (json['stream_type'] as String?) ?? 'hls',
      manifestUrl: (json['manifest_url'] as String?) ?? '',
      qualityLabel: (json['quality_label'] as String?) ?? 'Auto',
      bandwidthKbps: (json['bandwidth_kbps'] as num?)?.toInt(),
    );
  }
}

@immutable
class SubtitleTrackModel {
  final String id;
  final String languageCode;
  final String label;
  final String format;
  final String url;
  final bool isDefault;

  const SubtitleTrackModel({
    required this.id,
    required this.languageCode,
    required this.label,
    required this.format,
    required this.url,
    required this.isDefault,
  });

  factory SubtitleTrackModel.fromJson(Map<String, dynamic> json) {
    return SubtitleTrackModel(
      id: (json['id'] as String?) ?? '',
      languageCode: (json['language_code'] as String?) ?? 'vi',
      label: (json['label'] as String?) ?? 'Tiếng Việt',
      format: (json['format'] as String?) ?? 'vtt',
      url: (json['url'] as String?) ?? '',
      isDefault: (json['is_default'] as bool?) ?? false,
    );
  }
}

@immutable
class AudioTrackModel {
  final String id;
  final String languageCode;
  final String label;
  final String channels;
  final bool isDefault;

  const AudioTrackModel({
    required this.id,
    required this.languageCode,
    required this.label,
    required this.channels,
    required this.isDefault,
  });

  factory AudioTrackModel.fromJson(Map<String, dynamic> json) {
    return AudioTrackModel(
      id: (json['id'] as String?) ?? '',
      languageCode: (json['language_code'] as String?) ?? 'en',
      label: (json['label'] as String?) ?? 'Original',
      channels: (json['channels'] as String?) ?? '2.0',
      isDefault: (json['is_default'] as bool?) ?? true,
    );
  }
}

@immutable
class PlaybackSessionModel {
  final String sessionId;
  final String assetId;
  final int tmdbId;
  final String contentType;
  final int? seasonNumber;
  final int? episodeNumber;
  final String title;
  final int durationSeconds;
  final int resumePositionSeconds;
  final DateTime expiresAt;
  final String licenseName;
  final String licenseUrl;
  final String attribution;
  final List<StreamSourceModel> sources;
  final List<SubtitleTrackModel> subtitles;
  final List<AudioTrackModel> audioTracks;

  const PlaybackSessionModel({
    required this.sessionId,
    required this.assetId,
    required this.tmdbId,
    required this.contentType,
    this.seasonNumber,
    this.episodeNumber,
    required this.title,
    required this.durationSeconds,
    required this.resumePositionSeconds,
    required this.expiresAt,
    required this.licenseName,
    required this.licenseUrl,
    required this.attribution,
    required this.sources,
    required this.subtitles,
    required this.audioTracks,
  });

  factory PlaybackSessionModel.fromJson(Map<String, dynamic> json) {
    return PlaybackSessionModel(
      sessionId: (json['session_id'] as String?) ?? '',
      assetId: (json['asset_id'] as String?) ?? '',
      tmdbId: (json['tmdb_id'] as num).toInt(),
      contentType: (json['content_type'] as String?) ?? 'movie',
      seasonNumber: (json['season_number'] as num?)?.toInt(),
      episodeNumber: (json['episode_number'] as num?)?.toInt(),
      title: (json['title'] as String?) ?? 'Nam Cinema Stream',
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      resumePositionSeconds:
          (json['resume_position_seconds'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.tryParse((json['expires_at'] as String?) ?? '') ??
          DateTime.now().add(const Duration(hours: 2)),
      licenseName: (json['license_name'] as String?) ?? '',
      licenseUrl: (json['license_url'] as String?) ?? '',
      attribution: (json['attribution'] as String?) ?? '',
      sources: (json['sources'] as List<dynamic>? ?? const [])
          .map((e) => StreamSourceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtitles: (json['subtitles'] as List<dynamic>? ?? const [])
          .map((e) => SubtitleTrackModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      audioTracks: (json['audio_tracks'] as List<dynamic>? ?? const [])
          .map((e) => AudioTrackModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PlaybackRepository {
  final ApiClient _apiClient;

  const PlaybackRepository(this._apiClient);

  Future<PlaybackSessionModel> createPlaybackSession(
    String assetId, {
    bool resumeFromHistory = true,
  }) async {
    try {
      final response = await _apiClient.rawDio.post<Map<String, dynamic>>(
        '/playback/sessions',
        data: {
          'asset_id': assetId,
          'resume_from_history': resumeFromHistory,
        },
      );
      return PlaybackSessionModel.fromJson(response.data!);
    } catch (error) {
      throw _apiClient.mapDioError(error);
    }
  }

  Future<void> sendHeartbeat({
    required String sessionId,
    required int positionSeconds,
    int? durationSeconds,
    bool isPaused = false,
  }) async {
    try {
      await _apiClient.rawDio.post<Map<String, dynamic>>(
        '/playback/sessions/$sessionId/heartbeat',
        data: {
          'position_seconds': positionSeconds,
          if (durationSeconds != null) 'duration_seconds': durationSeconds,
          'is_paused': isPaused,
        },
      );
    } catch (_) {
      // Non-fatal during transient network drops
    }
  }

  Future<void> endSession(String sessionId) async {
    try {
      await _apiClient.rawDio.delete<Map<String, dynamic>>(
        '/playback/sessions/$sessionId',
      );
    } catch (_) {}
  }

  Future<List<SubtitleCue>> loadSubtitleCues(String url) async {
    try {
      final response = await _apiClient.rawDio.get<String>(url);
      final raw = response.data;
      if (raw == null || raw.isEmpty) return const [];
      return WebVttParser.parse(raw);
    } catch (_) {
      return const [];
    }
  }
}

final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  return PlaybackRepository(ref.watch(apiClientProvider));
});
