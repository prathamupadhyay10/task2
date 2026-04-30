import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/video_item.dart';
import '../core/theme/app_theme.dart';

/// Full-screen video player that matches the design reference:
/// - Portrait orientation, video fills screen with BoxFit.cover
/// - "High-Density Masonry Video Tiles" title at top-left
/// - Tap to toggle minimal play/pause controls
/// - Progress bar at the bottom on tap
/// - Safe disposal on exit
class FullscreenPlayerScreen extends StatefulWidget {
  final VideoItem item;
  final Duration startPosition;
  final String heroTag;

  const FullscreenPlayerScreen({
    super.key,
    required this.item,
    required this.startPosition,
    required this.heroTag,
  });

  @override
  State<FullscreenPlayerScreen> createState() => _FullscreenPlayerScreenState();
}

class _FullscreenPlayerScreenState extends State<FullscreenPlayerScreen> {
  late VideoPlayerController _ctrl;
  bool _initialised = false;
  bool _showControls = false; // hidden by default, tap to reveal

  @override
  void initState() {
    super.initState();
    // Stay portrait — immersive with transparent bars
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initController();
  }

  Future<void> _initController() async {
    _ctrl = VideoPlayerController.asset(widget.item.assetPath);
    await _ctrl.initialize();
    _ctrl.setLooping(true);
    await _ctrl.seekTo(widget.startPosition);
    await _ctrl.play();
    if (mounted) setState(() => _initialised = true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _togglePlay() {
    setState(() {
      _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-cover video ─────────────────────────────────────────────
            Hero(
              tag: widget.heroTag,
              child: _initialised
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: _ctrl.value.size.width,
                          height: _ctrl.value.size.height,
                          child: VideoPlayer(_ctrl),
                        ),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accentRed,
                        strokeWidth: 2,
                      ),
                    ),
            ),

            // ── Always-visible top title bar ─────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(context),
            ),

            // ── Tap-to-reveal controls overlay ───────────────────────────────
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: _buildControlsOverlay(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top bar: back arrow + "High-Density Masonry Video Tiles" title
  Widget _buildTopBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 16,
        bottom: 20,
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Title matching reference exactly
          const Expanded(
            child: Text(
              textAlign: TextAlign.center,
              'High-Density Masonry Video Tiles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Centre play/pause + bottom progress bar (visible only when tapped)
  Widget _buildControlsOverlay() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dim background
        Container(color: const Color(0x55000000)),

        // Centre play/pause button
        Center(
          child: GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30, width: 1.5),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  _ctrl.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey(_ctrl.value.isPlaying),
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        ),

        // Bottom progress + time
        if (_initialised)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 24,
      ),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _ctrl,
        builder: (_, val, __) {
          final pos = val.position.inMilliseconds.toDouble();
          final dur = val.duration.inMilliseconds.toDouble();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tile label
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.item.label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.accentRed,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 5),
                  trackHeight: 2,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: dur > 0 ? pos.clamp(0, dur) : 0,
                  min: 0,
                  max: dur > 0 ? dur : 1,
                  onChanged: (v) =>
                      _ctrl.seekTo(Duration(milliseconds: v.toInt())),
                ),
              ),
              // Times
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(val.position),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 10)),
                    Text(_fmt(val.duration),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 10)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
