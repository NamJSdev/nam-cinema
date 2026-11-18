import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/core/config/env_config.dart';
import 'package:nam_cinema/core/constants/app_constants.dart';
import 'package:nam_cinema/core/database/local_cache_store.dart';
import 'package:nam_cinema/core/player/webvtt_parser.dart';
import 'package:nam_cinema/core/theme/app_theme.dart';
import 'package:nam_cinema/core/widgets/cinematic_widgets.dart';
import 'package:nam_cinema/features/history/data/history_repository.dart';
import 'package:nam_cinema/features/home/data/home_repository.dart';
import 'package:nam_cinema/features/player/data/playback_repository.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final String assetId;
  final String titleHint;

  const VideoPlayerScreen({
    super.key,
    required this.assetId,
    required this.titleHint,
  });

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  PlaybackSessionModel? _session;
  List<SubtitleCue> _activeCues = const [];
  SubtitleTrackModel? _selectedSubtitle;
  bool _subtitlesEnabled = true;
  double _subtitleFontSize = AppConstants.defaultSubtitleFontSize;
  double _playbackSpeed = 1.0;
  bool _showControls = true;
  bool _isFullscreen = true;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _heartbeatTimer;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _enterLandscapeFullscreen();
    _initSessionAndPlayer();
  }

  void _loadPreferences() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      _subtitleFontSize = prefs.getDouble(AppConstants.prefSubtitleFontSizeKey) ??
          AppConstants.defaultSubtitleFontSize;
      _subtitlesEnabled =
          prefs.getBool(AppConstants.prefSubtitleEnabledKey) ?? true;
      _playbackSpeed =
          prefs.getDouble(AppConstants.prefPlaybackSpeedKey) ?? 1.0;
    } catch (_) {}
  }

  Future<void> _enterLandscapeFullscreen() async {
    await WakelockPlus.enable();
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitLandscapeFullscreen() async {
    await WakelockPlus.disable();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller?.pause();
      _persistProgressNow(isPaused: true);
    }
  }

  Future<void> _initSessionAndPlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(playbackRepositoryProvider);
      final session = await repo.createPlaybackSession(widget.assetId);
      _session = session;

      if (session.sources.isEmpty) {
        throw Exception('Không tìm thấy nguồn phát HLS hợp lệ cho nội dung này.');
      }

      final manifestUrl = session.sources.first.manifestUrl;
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(manifestUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      _controller = controller;
      await controller.initialize();
      await controller.setPlaybackSpeed(_playbackSpeed);

      if (session.resumePositionSeconds > 3 &&
          session.resumePositionSeconds < session.durationSeconds - 10) {
        await controller.seekTo(
          Duration(seconds: session.resumePositionSeconds),
        );
      }

      if (session.subtitles.isNotEmpty) {
        final defaultTrack = session.subtitles.firstWhere(
          (s) => s.isDefault,
          orElse: () => session.subtitles.first,
        );
        await _selectSubtitleTrack(defaultTrack);
      }

      controller.addListener(_onPlayerTick);
      await controller.play();

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(
        AppEnvConfig.progressSyncInterval,
        (_) => _persistProgressNow(),
      );

      _scheduleHideControls();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  Future<void> _selectSubtitleTrack(SubtitleTrackModel? track) async {
    _selectedSubtitle = track;
    if (track == null) {
      setState(() {
        _subtitlesEnabled = false;
        _activeCues = const [];
      });
      return;
    }

    final repo = ref.read(playbackRepositoryProvider);
    final cues = await repo.loadSubtitleCues(track.url);
    if (mounted) {
      setState(() {
        _subtitlesEnabled = true;
        _activeCues = cues;
      });
    }
  }

  void _onPlayerTick() {
    if (!mounted) return;
    final ctrl = _controller;
    if (ctrl != null && ctrl.value.hasError) {
      setState(() {
        _errorMessage =
            ctrl.value.errorDescription ?? 'Lỗi giải mã luồng phát HLS.';
      });
      return;
    }
    setState(() {});
  }

  Future<void> _persistProgressNow({bool isPaused = false}) async {
    final session = _session;
    final ctrl = _controller;
    if (session == null || ctrl == null || !ctrl.value.isInitialized) return;
    final posSec = ctrl.value.position.inSeconds;
    final durSec = ctrl.value.duration.inSeconds > 0
        ? ctrl.value.duration.inSeconds
        : session.durationSeconds;

    await ref.read(playbackRepositoryProvider).sendHeartbeat(
          sessionId: session.sessionId,
          positionSeconds: posSec,
          durationSeconds: durSec,
          isPaused: isPaused,
        );
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleHideControls();
    }
  }

  String _activeSubtitleText(Duration position) {
    if (!_subtitlesEnabled || _activeCues.isEmpty) return '';
    for (final cue in _activeCues) {
      if (cue.isActiveAt(position)) {
        return cue.text;
      }
    }
    return '';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _hideControlsTimer?.cancel();
    final session = _session;
    final ctrl = _controller;
    if (session != null && ctrl != null && ctrl.value.isInitialized) {
      ref.read(playbackRepositoryProvider).sendHeartbeat(
            sessionId: session.sessionId,
            positionSeconds: ctrl.value.position.inSeconds,
            durationSeconds: ctrl.value.duration.inSeconds,
            isPaused: true,
          );
      ref.read(playbackRepositoryProvider).endSession(session.sessionId);
      ref.invalidate(homeFeedProvider);
      ref.invalidate(watchHistoryProvider);
    }
    _controller?.removeListener(_onPlayerTick);
    _controller?.dispose();
    _exitLandscapeFullscreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final position = ctrl?.value.position ?? Duration.zero;
    final duration = ctrl?.value.duration ??
        Duration(seconds: _session?.durationSeconds ?? 1);
    final subtitleText = _activeSubtitleText(position);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: NamCinemaColors.primaryAccent,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Đang xác thực phiên phát HLS hợp pháp...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? ErrorState(
                    message: _errorMessage!,
                    onRetry: _initSessionAndPlayer,
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleControls,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (ctrl != null && ctrl.value.isInitialized)
                          Center(
                            child: AspectRatio(
                              aspectRatio: ctrl.value.aspectRatio > 0
                                  ? ctrl.value.aspectRatio
                                  : 16 / 9,
                              child: VideoPlayer(ctrl),
                            ),
                          ),

                        // Buffering Indicator
                        if (ctrl != null && ctrl.value.isBuffering)
                          const Center(
                            child: CircularProgressIndicator(
                              color: NamCinemaColors.primaryAccent,
                            ),
                          ),

                        // WebVTT Vietnamese / English Subtitle Overlay
                        if (subtitleText.isNotEmpty)
                          Positioned(
                            left: 36,
                            right: 36,
                            bottom: _showControls ? 86 : 28,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  subtitleText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: _subtitleFontSize,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Player Controls Overlay
                        if (_showControls && ctrl != null)
                          Container(
                            color: Colors.black.withOpacity(0.45),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top Bar
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.arrow_back_rounded,
                                          color: Colors.white,
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _session?.title ??
                                                  widget.titleHint,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            if (_session != null)
                                              Text(
                                                _session!.licenseName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Speed Selector
                                      PopupMenuButton<double>(
                                        initialValue: _playbackSpeed,
                                        tooltip: 'Tốc độ phát',
                                        onSelected: (speed) async {
                                          setState(
                                            () => _playbackSpeed = speed,
                                          );
                                          await ctrl.setPlaybackSpeed(speed);
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 0.75,
                                            child: Text('0.75x'),
                                          ),
                                          PopupMenuItem(
                                            value: 1.0,
                                            child: Text('1.0x (Chuẩn)'),
                                          ),
                                          PopupMenuItem(
                                            value: 1.25,
                                            child: Text('1.25x'),
                                          ),
                                          PopupMenuItem(
                                            value: 1.5,
                                            child: Text('1.5x'),
                                          ),
                                          PopupMenuItem(
                                            value: 2.0,
                                            child: Text('2.0x'),
                                          ),
                                        ],
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Text(
                                            '${_playbackSpeed}x',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Subtitle Menu
                                      IconButton(
                                        icon: Icon(
                                          _subtitlesEnabled
                                              ? Icons.subtitles_rounded
                                              : Icons.subtitles_off_outlined,
                                          color: _subtitlesEnabled
                                              ? NamCinemaColors.primaryAccent
                                              : Colors.white,
                                        ),
                                        onPressed: _showSubtitleSheet,
                                      ),
                                    ],
                                  ),
                                ),

                                // Center Transport Controls
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      iconSize: 38,
                                      icon: const Icon(
                                        Icons.replay_10_rounded,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        final target = position -
                                            const Duration(seconds: 10);
                                        ctrl.seekTo(
                                          target < Duration.zero
                                              ? Duration.zero
                                              : target,
                                        );
                                        _scheduleHideControls();
                                      },
                                    ),
                                    const SizedBox(width: 28),
                                    IconButton(
                                      iconSize: 64,
                                      icon: Icon(
                                        ctrl.value.isPlaying
                                            ? Icons.pause_circle_filled_rounded
                                            : Icons.play_circle_filled_rounded,
                                        color: NamCinemaColors.primaryAccent,
                                      ),
                                      onPressed: () {
                                        if (ctrl.value.isPlaying) {
                                          ctrl.pause();
                                          _persistProgressNow(isPaused: true);
                                        } else {
                                          ctrl.play();
                                          _scheduleHideControls();
                                        }
                                        setState(() {});
                                      },
                                    ),
                                    const SizedBox(width: 28),
                                    IconButton(
                                      iconSize: 38,
                                      icon: const Icon(
                                        Icons.forward_10_rounded,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        final target = position +
                                            const Duration(seconds: 10);
                                        ctrl.seekTo(
                                          target > duration ? duration : target,
                                        );
                                        _scheduleHideControls();
                                      },
                                    ),
                                  ],
                                ),

                                // Bottom Seek Bar
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _formatDuration(position),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      Expanded(
                                        child: Slider(
                                          activeColor:
                                              NamCinemaColors.primaryAccent,
                                          inactiveColor: Colors.white24,
                                          min: 0.0,
                                          max: duration.inSeconds
                                              .toDouble()
                                              .clamp(1.0, 86400.0),
                                          value: position.inSeconds
                                              .toDouble()
                                              .clamp(
                                                0.0,
                                                duration.inSeconds
                                                    .toDouble()
                                                    .clamp(1.0, 86400.0),
                                              ),
                                          onChanged: (val) {
                                            ctrl.seekTo(
                                              Duration(seconds: val.round()),
                                            );
                                            _scheduleHideControls();
                                          },
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(duration),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _isFullscreen
                                              ? Icons.fullscreen_exit_rounded
                                              : Icons.fullscreen_rounded,
                                          color: Colors.white,
                                        ),
                                        onPressed: () async {
                                          if (_isFullscreen) {
                                            await _exitLandscapeFullscreen();
                                          } else {
                                            await _enterLandscapeFullscreen();
                                          }
                                          setState(
                                            () =>
                                                _isFullscreen = !_isFullscreen,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  void _showSubtitleSheet() {
    final tracks = _session?.subtitles ?? const [];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NamCinemaColors.surface,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cài đặt Phụ đề (WebVTT)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(
                    !_subtitlesEnabled
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: NamCinemaColors.primaryAccent,
                  ),
                  title: const Text('Tắt phụ đề'),
                  onTap: () {
                    _selectSubtitleTrack(null);
                    Navigator.pop(ctx);
                  },
                ),
                for (final t in tracks)
                  ListTile(
                    leading: Icon(
                      _subtitlesEnabled && _selectedSubtitle?.id == t.id
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: NamCinemaColors.primaryAccent,
                    ),
                    title: Text('${t.label} (${t.languageCode.toUpperCase()})'),
                    onTap: () {
                      _selectSubtitleTrack(t);
                      Navigator.pop(ctx);
                    },
                  ),
                const Divider(),
                Row(
                  children: [
                    const Text('Cỡ chữ phụ đề:'),
                    const SizedBox(width: 12),
                    for (final size in [14.0, 16.0, 20.0, 24.0])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${size.round()}pt'),
                          selected: _subtitleFontSize == size,
                          onSelected: (_) {
                            setState(() => _subtitleFontSize = size);
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
